// Conductor simulado con movimiento continuo, para demostrar el flujo del pasajero.
//
// `npm run simulate` (src/driver-sim.ts) salta de parada en parada cada 3 segundos: la unidad
// se teletransporta y cruza los 613 m entre la Catedral y las Tarascas a ~200 m/s. Sirve para
// comprobar que el evento `vehicle:position` llega, pero no para demostrar la app: el pasajero
// nunca alcanza a ver la unidad acercarse, ni le da tiempo de pagar.
//
// Este script recorre el trazado de forma continua, a velocidad comprimida para la demo, y
// **se detiene en cada parada** — que es lo que le da tiempo al pasajero de pasar su tarjeta.
// La detención (DWELL_MS) se comprime mucho menos que el trayecto: es la ventana para pagar,
// no tiempo de camino.
//
// Uso:
//   npx tsx scripts/demo-drive.ts              # todas las rutas
//   npx tsx scripts/demo-drive.ts 2            # solo la ruta 2
//   SPEED_KMH=150 DWELL_MS=9000 npx tsx scripts/demo-drive.ts   # el ritmo anterior, más calmado
import { readFileSync } from "fs";
import { createServer } from "net";
import { join } from "path";
import { io, type Socket } from "socket.io-client";
// La misma constante con la que el servidor calcula `GET /stops/:id/eta`: si el simulador
// corriera a una velocidad y el ETA se estimara con otra, la pantalla contradiría al mapa.
import { DEMO_VEHICLE_SPEED_KMH } from "../src/lib/speeds";

interface SeedStop {
  name: string;
  lat: number;
  lng: number;
  sequence: number;
}

interface SeedRoute {
  id: number;
  name: string;
  stops: SeedStop[];

  /**
   * El trazado por calles de la ruta entera, como pares `[lat, lng]`.
   *
   * No está en el seed: lo arma el servidor con OSRM y lo entrega en `GET /routes`. Es **la
   * misma polilínea que la app dibuja en el mapa**, y por eso este script la pide en vez de
   * conformarse con las paradas: si la unidad avanza en recta de parada a parada mientras el
   * mapa dibuja las calles, se ve al camión cruzando manzanas por fuera de su propia ruta —
   * hasta 1033 m fuera de la línea en la ruta a Charo, que es la que más rodea.
   *
   * Falta en el teleférico, que va por el aire; ahí la recta entre estaciones es lo correcto.
   */
  shape?: [number, number][];
}

const seedPath = join(__dirname, "..", "src", "data", "seed-routes.json");
const { routes }: { routes: SeedRoute[] } = JSON.parse(
  readFileSync(seedPath, "utf-8")
);

const serverUrl = process.env.SERVER_URL ?? "http://localhost:3001";

/**
 * Velocidad del recorrido.
 *
 * Muy por encima de un camión real a propósito: las paradas del seed están a 600-1300 m, y a
 * velocidad realista cada tramo tomaría minutos — el tramo Catedral-Tarascas solo se llevaba
 * casi un minuto de la demo.
 *
 * **Está calibrado para presentar contra reloj, no para ver el ritmo verdadero.** A 600 km/h
 * ese tramo son unos cuatro segundos, y la Ruta Centro - Acueducto entera —sus dos tramos más
 * las detenciones— unos quince, contra los treinta y seis que tomaba a 150 km/h con 9 s por
 * parada. Lo que se enseña es la mecánica —la unidad se acerca, se abre el pago, arranca el
 * viaje— y esperarla no es parte de lo que hay que explicar. Quien tenga tiempo de sobra puede bajarlo en caliente
 * sin tocar el código: `SPEED_KMH=150 npm run demo-drive` para el ritmo anterior, 20-25 para el
 * de un camión de verdad. **La misma variable hay que ponérsela al servidor** (`SPEED_KMH=150
 * npm run dev`) y a la app (`--dart-define=ETA_SPEED_KMH=150`), o el ETA seguirá contando con
 * la velocidad de aquí y anunciará una unidad que no llega cuando dice.
 *
 * El ETA que la app enseña (`GET /stops/:id/eta`) se calcula con **esta misma** velocidad
 * —por eso vive en `src/lib/speeds.ts` como `DEMO_VEHICLE_SPEED_KMH` y no aquí—, así que el
 * "llega en 8 s" de la pantalla es lo que de verdad tarda la unidad en llegar. Lo que no se
 * toca son los minutos del itinerario (`GET /journeys`), que siguen calculándose con la
 * velocidad real por modo: son la promesa del producto, no un detalle de la demostración.
 */
const speedMps = (DEMO_VEHICLE_SPEED_KMH * 1000) / 3600;

/**
 * Cuánto se detiene en cada parada. Es la ventana para pagar.
 *
 * No se acelera al mismo ritmo que el trayecto: es el único momento en el que hay algo que
 * hacer —pasar la tarjeta— y comprimirlo deja la pantalla de pago apareciendo y yéndose antes
 * de que dé tiempo de señalarla. Cinco segundos alcanzan para eso y dejan de sumar espera por
 * cada parada intermedia entre la unidad y el pasajero.
 */
const dwellMs = Number(process.env.DWELL_MS ?? 5000);

/**
 * Cada cuánto se emite una posición. Más corto = movimiento más fluido en el mapa.
 *
 * Va de la mano con la velocidad: cada paso mide `velocidad × tick`, así que al subir una hay
 * que bajar el otro o la unidad empieza a saltar de cuadra en cuadra. A 600 km/h con 100 ms el
 * paso son ~17 m — media cuadra, todavía un deslizamiento; con los 250 ms de antes serían 42 m
 * y el icono se vería brincar.
 */
const tickMs = Number(process.env.TICK_MS ?? 100);

const requested = process.argv[2]
  ? process.argv[2].split(",").map(Number)
  : routes.map((route) => route.id);

const selected = routes.filter((route) => requested.includes(route.id));
if (selected.length === 0) {
  console.error(
    `Ninguna ruta coincide. Disponibles: ${routes.map((r) => r.id).join(", ")}`
  );
  process.exit(1);
}

interface Point {
  lat: number;
  lng: number;
}

const EARTH_RADIUS_M = 6371000;
const toRad = (degrees: number): number => (degrees * Math.PI) / 180;

function haversine(a: Point, b: Point): number {
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(h));
}

/**
 * Recorre una ruta de ida y vuelta, deteniéndose en cada parada.
 *
 * La convención del seed (server/src/db/seed.ts) inserta un vehículo por ruta en el mismo
 * orden, así que `vehicle_id` coincide con `route_id`.
 */
function drive(socket: Socket, route: SeedRoute): NodeJS.Timeout | null {
  const stops = [...route.stops].sort((a, b) => a.sequence - b.sequence);
  if (stops.length < 2) return null;

  // El camino que se recorre: el trazado por calles si el servidor lo dio, y si no las paradas
  // en recta —que es lo correcto para el teleférico y lo único disponible sin OSRM—.
  const onStreets = (route.shape?.length ?? 0) >= 2;
  const path: Point[] = onStreets
    ? route.shape!.map(([lat, lng]) => ({ lat, lng }))
    : stops.map((stop) => ({ lat: stop.lat, lng: stop.lng }));

  // Distancia acumulada hasta cada vértice: convierte "dónde va la unidad" en un solo número
  // sobre el que avanzar, en vez de un índice de tramo más una fracción.
  const along: number[] = [0];
  for (let i = 1; i < path.length; i++) {
    along.push(along[i - 1] + haversine(path[i - 1], path[i]));
  }

  const pointAt = (meters: number): Point => {
    const clamped = Math.max(0, Math.min(meters, along[along.length - 1]));
    let i = 1;
    while (i < along.length - 1 && along[i] < clamped) i++;
    const span = along[i] - along[i - 1];
    const fraction = span === 0 ? 0 : (clamped - along[i - 1]) / span;
    return {
      lat: path[i - 1].lat + (path[i].lat - path[i - 1].lat) * fraction,
      lng: path[i - 1].lng + (path[i].lng - path[i - 1].lng) * fraction,
    };
  };

  // Dónde cae cada parada sobre el camino. Las paradas son puntos sueltos del seed y el trazado
  // viene de OSRM, así que no coinciden exactamente: se toma el vértice más cercano.
  const stopsAlong = stops
    .map((stop) => {
      let best = 0;
      let bestMeters = Infinity;
      for (let i = 0; i < path.length; i++) {
        const meters = haversine(stop, path[i]);
        if (meters < bestMeters) {
          bestMeters = meters;
          best = i;
        }
      }
      return { name: stop.name, meters: along[best] };
    })
    .sort((a, b) => a.meters - b.meters);

  let at = stopsAlong[0].meters;
  let target = 1;
  let forward = true;
  let dwellingUntil = Date.now() + dwellMs;

  const emit = (point: Point): void => {
    socket.emit("driver:position", {
      vehicle_id: route.id,
      lat: point.lat,
      lng: point.lng,
    });
  };

  console.log(
    `Ruta ${route.id} "${route.name}": ${stops.length} paradas, ` +
      `${Math.round(speedMps * 3.6)} km/h, ${dwellMs / 1000}s por parada, ` +
      `${onStreets ? `sobre el trazado por calles (${path.length} puntos)` : "en recta entre paradas"}`
  );

  return setInterval(() => {
    const now = Date.now();

    // Detenido en la parada: es la ventana en la que el pasajero puede pagar.
    if (now < dwellingUntil) {
      emit(pointAt(at));
      return;
    }

    const goal = stopsAlong[target].meters;
    const step = (speedMps * tickMs) / 1000;
    at += forward ? step : -step;

    const reached = forward ? at >= goal : at <= goal;
    if (reached) {
      at = goal;
      dwellingUntil = now + dwellMs;
      console.log(`Ruta ${route.id} -> ${stopsAlong[target].name}`);

      if (forward && target === stopsAlong.length - 1) {
        forward = false;
        target -= 1;
      } else if (!forward && target === 0) {
        forward = true;
        target += 1;
      } else {
        target += forward ? 1 : -1;
      }
    }

    emit(pointAt(at));
  }, tickMs);
}

/**
 * Pide al servidor el trazado por calles de cada ruta y lo pega a las rutas del seed.
 *
 * Es el mismo `GET /routes` que consume la app, a propósito: la unidad tiene que recorrer la
 * polilínea que el pasajero ve dibujada, no una geometría paralela. Si el servidor no contesta
 * —todavía arrancando, o sin OSRM— se sigue con las paradas en recta, como antes, y se dice.
 */
async function loadShapes(): Promise<void> {
  try {
    const response = await fetch(`${serverUrl}/routes`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);

    const published = (await response.json()) as SeedRoute[];
    const byId = new Map(published.map((route) => [route.id, route]));

    for (const route of selected) {
      const shape = byId.get(route.id)?.shape;
      if (shape && shape.length >= 2) route.shape = shape;
    }
  } catch (error) {
    console.warn(
      `No se pudo pedir el trazado a ${serverUrl}/routes (${error instanceof Error ? error.message : error}).
` +
        "La unidad va a recorrer rectas entre paradas, que no coinciden con la línea que dibuja la app."
    );
  }
}

async function start(): Promise<void> {
  await loadShapes();

  const socket = io(serverUrl);

  /**
   * Los conductores en curso, uno por ruta.
   *
   * Existen para poder **apagarlos**. `socket.io-client` reconecta solo, y `connect` vuelve a
   * dispararse en cada reconexión; sin limpiar los intervalos anteriores, cada reconexión deja
   * un conductor más recorriendo la misma ruta con su propio avance. Todos emiten para el mismo
   * `vehicle_id`, así que la unidad acaba reportando desde N puntos distintos del recorrido
   * varias veces por segundo y en el mapa el icono salta por toda la ruta.
   *
   * No es un caso raro: el servidor corre con `tsx watch`, que reinicia a cada cambio de
   * archivo, y este script se deja abierto entre reinicios. Un proceso vivo unas horas acumula
   * una docena de conductores sin que nada falle a la vista.
   */
  const drivers: NodeJS.Timeout[] = [];

  const stopDriving = (): void => {
    for (const driver of drivers) clearInterval(driver);
    drivers.length = 0;
  };

  socket.on("connect", () => {
    stopDriving();
    console.log(`Conectado a ${serverUrl}`);
    for (const route of selected) {
      const driver = drive(socket, route);
      if (driver) drivers.push(driver);
    }
  });

  socket.on("disconnect", stopDriving);

  socket.on("connect_error", (error) => {
    console.error(`No se pudo conectar a ${serverUrl}: ${error.message}`);
  });
}

/**
 * Candado de instancia única.
 *
 * Dos copias de este script emiten `driver:position` para el mismo `vehicle_id` desde puntos
 * distintos del recorrido, y el servidor reenvía las dos sin distinguirlas: en el mapa la unidad
 * salta cientos de metros adelante y atrás varias veces por segundo. Nada falla a la vista —los
 * dos procesos se ven sanos en la consola— así que la segunda copia debe negarse a arrancar en
 * lugar de ensuciar el stream en silencio.
 *
 * El candado es un puerto y no un archivo .lock porque el sistema operativo lo libera solo al
 * morir el proceso, incluso si lo matan a la fuerza; un archivo quedaría trabado tras un kill.
 */
const lockPort = Number(process.env.LOCK_PORT ?? 47654);
const lock = createServer();

lock.once("error", (error: NodeJS.ErrnoException) => {
  if (error.code !== "EADDRINUSE") throw error;
  console.error(
    `Ya hay un simulador corriendo (candado en el puerto ${lockPort}).\n` +
      "Ciérralo antes de abrir otro: dos simuladores pelean por la misma unidad."
  );
  process.exit(1);
});

lock.listen(lockPort, "127.0.0.1", () => void start());
