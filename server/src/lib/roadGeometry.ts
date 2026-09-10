import { db } from "../db";
import type { JourneyAlternative, JourneyLeg } from "./journeyPlanner";

// Trazado real por calles para los tramos que ya eligió el planificador.
//
// El motor de `journeyPlanner.ts` decide con distancias en línea recta
// (haversine) — eso no cambia aquí: elegir qué tomar y dibujar por dónde va
// son dos preguntas distintas, y resolver la primera con ruteo real
// significaría una petición por cada par de paradas del grafo. Este módulo
// solo se ocupa de la segunda, ya con el viaje decidido: unos pocos tramos,
// una petición por tramo, cacheadas.
//
// El servidor público de OSRM solo tiene el perfil de coche — responde lo
// mismo a `foot`, `bike` y `driving`—, así que los tramos a pie y en bici
// siguen calles de coche. Es impreciso (sentidos únicos, andadores
// peatonales que no aparecen) pero sigue siendo mucho más cercano a la
// realidad que la línea recta que cruzaba manzanas. Con un OSRM propio y
// perfiles reales, basta apuntar OSRM_URL a él.

const OSRM_URL = process.env.OSRM_URL ?? "https://router.project-osrm.org";
const OSRM_TIMEOUT_MS = Number(process.env.OSRM_TIMEOUT_MS ?? 4000);

// Cuánto se deja de insistir tras un fallo. Sin esto, una demo sin internet
// paga el timeout completo en cada tramo de cada petición: cinco tramos son
// veinte segundos de espera para acabar dibujando las mismas rectas.
const BACKOFF_MS = 60_000;

interface Point {
  lat: number;
  lng: number;
}

// [lat, lng] en vez de {lat, lng}: una polilínea trae decenas de puntos por
// tramo y la forma de objeto multiplica el tamaño de la respuesta sin
// aportar nada — el orden es el mismo que en el resto de la API.
export type RoadLine = [number, number][];

const cache = new Map<string, RoadLine>();
let unavailableUntil = 0;

function cacheKey(points: Point[]): string {
  return points.map((p) => `${p.lat.toFixed(6)},${p.lng.toFixed(6)}`).join(";");
}

interface OsrmResponse {
  code?: string;
  routes?: { geometry?: { coordinates?: [number, number][] } }[];
}

// `null` = no se pudo, dibuja la recta. Nunca lanza: un viaje sin trazado
// bonito sigue siendo un viaje utilizable, y este módulo no debe poder
// tumbar GET /journeys.
async function fetchLine(points: Point[]): Promise<RoadLine | null> {
  if (points.length < 2) return null;

  const key = cacheKey(points);
  const cached = cache.get(key);
  if (cached) return cached;
  if (Date.now() < unavailableUntil) return null;

  // OSRM toma lng,lat — al revés que el resto de la API.
  const coords = points.map((p) => `${p.lng},${p.lat}`).join(";");
  const url = `${OSRM_URL}/route/v1/driving/${coords}?overview=full&geometries=geojson`;

  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(OSRM_TIMEOUT_MS) });
    if (!res.ok) throw new Error(`OSRM respondió ${res.status}`);

    const body = (await res.json()) as OsrmResponse;
    const coordinates = body.routes?.[0]?.geometry?.coordinates;
    if (body.code !== "Ok" || !coordinates || coordinates.length < 2) {
      throw new Error(`OSRM sin ruta (code=${body.code})`);
    }

    const line: RoadLine = coordinates.map(([lng, lat]) => [lat, lng]);
    cache.set(key, line);
    return line;
  } catch (error) {
    unavailableUntil = Date.now() + BACKOFF_MS;
    console.warn(
      `[roadGeometry] sin trazado por calles, se dibuja en línea recta ` +
        `(reintento en ${BACKOFF_MS / 1000}s): ${(error as Error).message}`
    );
    return null;
  }
}

interface StopRow {
  id: number;
  lat: number;
  lng: number;
  sequence: number;
}

// Las paradas que la unidad sirve entre subida y bajada, en orden de
// recorrido. Van como waypoints de OSRM para que la línea pase por donde el
// camión para de verdad y no por el atajo más corto entre las dos puntas.
function transitWaypoints(leg: JourneyLeg): Point[] | null {
  if (leg.route_id === null || leg.from.stop_id === null || leg.to.stop_id === null) return null;

  const stops = db
    .prepare("SELECT id, lat, lng, sequence FROM stops WHERE route_id = ? ORDER BY sequence")
    .all(leg.route_id) as StopRow[];

  const from = stops.findIndex((stop) => stop.id === leg.from.stop_id);
  const to = stops.findIndex((stop) => stop.id === leg.to.stop_id);
  if (from < 0 || to < 0) return null;

  const step = from <= to ? 1 : -1;
  const between: Point[] = [];
  for (let i = from; i !== to + step; i += step) between.push(stops[i]);
  return between;
}

function waypointsFor(leg: JourneyLeg): Point[] | null {
  // Tramos de relleno de longitud cero: el punto de subida coincide con el
  // origen, o el de bajada con el destino. No hay nada que trazar.
  if (leg.distance_km <= 0) return null;

  // El teleférico va por el aire: la recta no es una aproximación, es el
  // trazado correcto. Pedirle calles a OSRM lo empeoraría.
  if (leg.mode === "teleferico") return null;

  return transitWaypoints(leg) ?? [leg.from, leg.to];
}

// Añade `geometry` a cada tramo que lo admita. Los tramos sin trazado se
// quedan sin el campo y el cliente dibuja la recta, que es lo que hacía
// antes — así una caída de OSRM degrada el dibujo, no el viaje.
export async function withRoadGeometry(
  alternatives: JourneyAlternative[]
): Promise<JourneyAlternative[]> {
  const pending = new Map<string, Point[]>();
  for (const alternative of alternatives) {
    for (const leg of alternative.legs) {
      const points = waypointsFor(leg);
      if (points) pending.set(cacheKey(points), points);
    }
  }
  if (pending.size === 0) return alternatives;

  // En paralelo: un viaje con transbordos tiene cuatro o cinco tramos, y en
  // serie se notarían como medio segundo de espera antes de ver el mapa.
  const entries = [...pending.entries()];
  const lines = await Promise.all(entries.map(([, points]) => fetchLine(points)));
  const byKey = new Map(entries.map(([key], index) => [key, lines[index]]));

  return alternatives.map((alternative) => ({
    ...alternative,
    legs: alternative.legs.map((leg) => {
      const points = waypointsFor(leg);
      const line = points ? byKey.get(cacheKey(points)) : null;
      return line ? { ...leg, geometry: line } : leg;
    }),
  }));
}

// El trazado de una ruta completa, de su primera parada a la ultima y
// pasando por todas las intermedias.
//
// Es lo que dibujan las pantallas del viaje en camion (esperar la unidad, ir
// a bordo), que hasta ahora unian las paradas con rectas y cruzaban manzanas.
// `null` = no se pudo, y el cliente vuelve a unir las paradas como antes.
export async function routeShape(routeId: number): Promise<RoadLine | null> {
  const stops = db
    .prepare("SELECT lat, lng FROM stops WHERE route_id = ? ORDER BY sequence")
    .all(routeId) as Point[];
  return fetchLine(stops);
}

// El trazado por calles que pasa por todos estos puntos, en orden.
//
// Lo usa /walk-path: de donde esta el pasajero a la parada, y tambien los
// caminos que el cliente ya trazo por su cuenta —el rodeo que esquiva una zona
// marcada, los extremos de una ciclovia— pasandolos como puntos intermedios
// para que ajustarlos a las calles no deshaga el desvio.
export async function roadPathThrough(points: Point[]): Promise<RoadLine | null> {
  return fetchLine(points);
}

// Deja las formas de ruta en cache al arrancar, de una en una.
//
// El servidor publico de OSRM limita rafagas: pedir las cuatro rutas a la vez
// en la primera peticion a /routes hacia fallar alguna, y el corte por fallo
// (BACKOFF_MS) dejaba sin trazado tambien a las demas durante un minuto. Al
// hacerlo aqui, secuencial y sin prisa, la demo arranca con todo cacheado y
// /routes no depende de la red.
//
// No bloquea el arranque: si OSRM no esta, el servidor sirve igual y los
// clientes dibujan rectas.
export async function warmRouteShapes(): Promise<void> {
  const routes = db.prepare("SELECT id, mode FROM routes").all() as { id: number; mode: string }[];
  let listas = 0;
  for (const route of routes) {
    // El teleferico va por el aire: no tiene trazado por calles que precalentar.
    if (route.mode === "teleferico") continue;
    if (await routeShape(route.id)) listas++;
    // Un respiro entre peticiones, por el limite de rafaga del servidor publico.
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  console.log(`[roadGeometry] ${listas} ruta(s) con trazado por calles en cache`);
}
