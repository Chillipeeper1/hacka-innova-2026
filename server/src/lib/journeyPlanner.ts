import { db } from "../db";
import { haversineKm } from "./geo";
import { BIKE_SPEED_KMH, MAX_BIKE_DISTANCE_KM, speedForMode, WALK_SPEED_KMH } from "./speeds";

// Penalizaciones fijas de mockup: desalientan transbordos/abordajes
// innecesarios sin necesidad de un motor de ruteo real (CLAUDE.md lo
// descarta para esta fase).
const BOARDING_WAIT_MIN = 3;
const DEFAULT_TRANSFER_PENALTY_MIN = 3;
const FEW_TRANSFERS_PENALTY_MIN = 15;

const ORIGIN = "__origin__";
const DESTINATION = "__destination__";

// Único lugar que enumera los modos "elegibles" (filtrables por el
// cliente) — caminar queda fuera a propósito, es la conexión estructural
// mínima, no una elección real. Si se agrega un modo nuevo al seed, hay que
// sumarlo aquí para que /journeys pueda filtrarlo/excluirlo.
export const KNOWN_JOURNEY_MODES = ["bike", "combi", "bus", "teleferico"] as const;

interface LatLng {
  lat: number;
  lng: number;
}

interface StopRow {
  id: number;
  name: string;
  lat: number;
  lng: number;
  route_id: number;
}

interface RouteRow {
  id: number;
  name: string;
  mode: string;
}

interface JourneyPoint {
  stop_id: number | null;
  name: string | null;
  lat: number;
  lng: number;
}

export interface JourneyLeg {
  mode: string;
  route_id: number | null;
  route_name: string | null;
  from: JourneyPoint;
  to: JourneyPoint;
  distance_km: number;
  eta_minutes: number;
  // Trazado por calles, como pares [lat, lng]. Lo añade `roadGeometry.ts`
  // después de planear, y puede faltar (OSRM caído, tramo de longitud cero,
  // teleférico) — sin él el cliente dibuja la recta entre los extremos.
  // `distance_km` y `eta_minutes` NO lo miden: siguen siendo la línea recta
  // a velocidad fija con la que el motor eligió este viaje.
  geometry?: [number, number][];
}

export interface JourneyResult {
  legs: JourneyLeg[];
  total_distance_km: number;
  total_eta_minutes: number;
}

export interface JourneyAlternative extends JourneyResult {
  label: string;
}

interface PlanOptions {
  // null = todos los modos permitidos. Caminar nunca se filtra.
  allowedModes: Set<string> | null;
  transferPenaltyMin: number;
  // Exige que el viaje use al menos un tramo de `allowedModes`, en vez de
  // devolver el camino más rápido a secas. Aplica solo cuando el cliente
  // declaró sus modos: quien pidió "combi" está preguntando cómo llegar en
  // combi, y contestarle "camina 26 minutos" no responde esa pregunta
  // —además de no generar ninguna señal de abordaje, que es el punto del
  // proyecto—. Sin declaración de modos no aplica: ahí "Más rápida" tiene
  // que poder ser caminar o pedalear si de verdad lo es.
  requireAllowedMode: boolean;
}

interface Edge {
  to: string;
  weightMinutes: number;
  distanceKm: number;
  mode: string;
  routeId: number | null;
  routeName: string | null;
}

function isAllowed(mode: string, allowedModes: Set<string> | null): boolean {
  return allowedModes === null || allowedModes.has(mode);
}

function excludingBike(allowedModes: Set<string> | null): Set<string> {
  const base = allowedModes ?? new Set(KNOWN_JOURNEY_MODES);
  return new Set([...base].filter((mode) => mode !== "bike"));
}

// El límite de bici (MAX_BIKE_DISTANCE_KM) se aplica por arista al construir
// el grafo, pero el camino más corto podría encadenar dos tramos de bici a
// través de una parada usada solo como punto de paso (sin usar su ruta),
// cada uno bajo el límite por separado, y así cubrir más distancia total en
// bici de la que el límite pretende permitir. Este wrapper valida el total
// y, si se pasa, recalcula sin bici — así el límite es real por viaje, no
// solo por tramo.
function planJourney(origin: LatLng, destination: LatLng, options: PlanOptions): JourneyResult {
  const result = runPlanner(origin, destination, options);
  if (!isAllowed("bike", options.allowedModes)) return result;

  const bikeKm = result.legs
    .filter((leg) => leg.mode === "bike")
    .reduce((sum, leg) => sum + leg.distance_km, 0);
  if (bikeKm <= MAX_BIKE_DISTANCE_KM) return result;

  return runPlanner(origin, destination, { ...options, allowedModes: excludingBike(options.allowedModes) });
}

// Grafo completo sobre origen, destino y cada parada — a esta escala (unas
// pocas rutas, una decena de paradas) es más simple que imponer radios de
// caminata arbitrarios: el peso de cada arista ya descarta por sí solo las
// combinaciones absurdas (caminar kilómetros quedaría siempre más caro que
// una alternativa razonable, si existe).
function runPlanner(origin: LatLng, destination: LatLng, options: PlanOptions): JourneyResult {
  const { allowedModes, transferPenaltyMin, requireAllowedMode } = options;
  const stops = db.prepare("SELECT id, name, lat, lng, route_id FROM stops").all() as StopRow[];
  const routes = db.prepare("SELECT id, name, mode FROM routes").all() as RouteRow[];
  const routeById = new Map(routes.map((r) => [r.id, r]));

  const nodeLocation = new Map<string, JourneyPoint>();
  nodeLocation.set(ORIGIN, { stop_id: null, name: null, lat: origin.lat, lng: origin.lng });
  nodeLocation.set(DESTINATION, {
    stop_id: null,
    name: null,
    lat: destination.lat,
    lng: destination.lng,
  });
  for (const stop of stops) {
    nodeLocation.set(String(stop.id), {
      stop_id: stop.id,
      name: stop.name,
      lat: stop.lat,
      lng: stop.lng,
    });
  }

  const graph = new Map<string, Edge[]>();
  const addEdge = (from: string, edge: Edge): void => {
    if (!graph.has(from)) graph.set(from, []);
    graph.get(from)!.push(edge);
  };
  const speedEdge =
    (mode: string, speedKmh: number) =>
    (to: string, distanceKm: number): Edge => ({
      to,
      weightMinutes: (distanceKm / speedKmh) * 60,
      distanceKm,
      mode,
      routeId: null,
      routeName: null,
    });
  const walkEdge = speedEdge("walk", WALK_SPEED_KMH);
  // Línea recta simple, sin el trazado de ciclovías que sí modela
  // app/lib/data/bike_network.dart — compite por tiempo con transporte
  // colectivo, no reemplaza esa lógica más fina del lado de la app.
  const bikeEdge = speedEdge("bike", BIKE_SPEED_KMH);
  const bikeAllowed = isAllowed("bike", allowedModes);

  // Caminar (siempre) y bici (si el filtro la permite y la distancia es
  // razonable): origen/destino <-> cada parada, y origen -> destino directo
  // (caminar es el fallback que garantiza que siempre hay al menos una
  // opción, pase lo que pase con el filtro de modos).
  for (const stop of stops) {
    const stopNode = String(stop.id);
    const originToStopKm = haversineKm(origin, stop);
    const stopToDestinationKm = haversineKm(stop, destination);
    addEdge(ORIGIN, walkEdge(stopNode, originToStopKm));
    addEdge(stopNode, walkEdge(DESTINATION, stopToDestinationKm));
    if (bikeAllowed) {
      if (originToStopKm <= MAX_BIKE_DISTANCE_KM) addEdge(ORIGIN, bikeEdge(stopNode, originToStopKm));
      if (stopToDestinationKm <= MAX_BIKE_DISTANCE_KM) addEdge(stopNode, bikeEdge(DESTINATION, stopToDestinationKm));
    }
  }
  const originToDestinationKm = haversineKm(origin, destination);
  addEdge(ORIGIN, walkEdge(DESTINATION, originToDestinationKm));
  if (bikeAllowed && originToDestinationKm <= MAX_BIKE_DISTANCE_KM) {
    addEdge(ORIGIN, bikeEdge(DESTINATION, originToDestinationKm));
  }

  // Viajar (misma ruta, si el modo está permitido) o transbordar a pie
  // (rutas distintas), entre cualquier par de paradas — las aristas de
  // viaje conectan cualquier par directo, no solo consecutivas, así que
  // cada arista del camino más corto ya es un tramo completo.
  for (const a of stops) {
    for (const b of stops) {
      if (a.id === b.id) continue;
      const distanceKm = haversineKm(a, b);

      if (a.route_id === b.route_id) {
        const route = routeById.get(a.route_id)!;
        if (!isAllowed(route.mode, allowedModes)) continue;
        addEdge(String(a.id), {
          to: String(b.id),
          weightMinutes: (distanceKm / speedForMode(route.mode)) * 60 + BOARDING_WAIT_MIN,
          distanceKm,
          mode: route.mode,
          routeId: route.id,
          routeName: route.name,
        });
      } else {
        addEdge(String(a.id), {
          to: String(b.id),
          weightMinutes: (distanceKm / WALK_SPEED_KMH) * 60 + transferPenaltyMin,
          distanceKm,
          mode: "walk",
          routeId: null,
          routeName: null,
        });
      }
    }
  }

  // Con exigencia: el mejor viaje que sí usa alguno de los modos elegidos.
  // Si no existe ninguno —el filtro no cubre ninguna ruta del grafo, o la
  // bici quedó fuera por distancia— se cae al camino más rápido, que en el
  // peor caso es caminar. Nunca se devuelve "no hay viaje".
  const required = requireAllowedMode && allowedModes !== null ? allowedModes : null;
  const legs = (required !== null ? dijkstra(graph, nodeLocation, required) : null) ?? dijkstra(graph, nodeLocation, null)!;
  const totalDistanceKm = legs.reduce((sum, leg) => sum + leg.distance_km, 0);
  const totalEtaMinutes = legs.reduce((sum, leg) => sum + leg.eta_minutes, 0);

  return {
    legs,
    total_distance_km: Number(totalDistanceKm.toFixed(3)),
    total_eta_minutes: Number(totalEtaMinutes.toFixed(1)),
  };
}

function journeySignature(result: JourneyResult): string {
  return result.legs
    .map((leg) => `${leg.mode}:${leg.route_id ?? ""}:${leg.from.stop_id ?? "pt"}:${leg.to.stop_id ?? "pt"}`)
    .join("|");
}

// Hasta 3 alternativas etiquetadas. Si el cliente ya restringió `modes`,
// respeta esa elección tal cual (una sola alternativa) — generar variantes
// derivadas encima de un filtro que el propio cliente pidió sería ruido.
// Si no restringió nada, ofrece variantes genuinamente distintas: la más
// rápida, una sin bici, y una que penaliza transbordos — descartando
// cualquiera que resulte idéntica a una ya incluida.
export function planJourneyAlternatives(
  origin: LatLng,
  destination: LatLng,
  requestedModes: Set<string> | null
): JourneyAlternative[] {
  if (requestedModes !== null) {
    const result = planJourney(origin, destination, {
      allowedModes: requestedModes,
      transferPenaltyMin: DEFAULT_TRANSFER_PENALTY_MIN,
      requireAllowedMode: true,
    });
    return [{ label: "Tu selección", ...result }];
  }

  const modesWithoutBike = new Set(KNOWN_JOURNEY_MODES.filter((mode) => mode !== "bike"));
  const attempts: { label: string; options: PlanOptions }[] = [
    {
      label: "Más rápida",
      options: {
        allowedModes: null,
        transferPenaltyMin: DEFAULT_TRANSFER_PENALTY_MIN,
        requireAllowedMode: false,
      },
    },
    {
      label: "Sin bicicleta",
      options: {
        allowedModes: modesWithoutBike,
        transferPenaltyMin: DEFAULT_TRANSFER_PENALTY_MIN,
        requireAllowedMode: false,
      },
    },
    {
      label: "Con menos transbordos",
      options: {
        allowedModes: null,
        transferPenaltyMin: FEW_TRANSFERS_PENALTY_MIN,
        requireAllowedMode: false,
      },
    },
  ];

  const alternatives: JourneyAlternative[] = [];
  const seenSignatures = new Set<string>();
  for (const attempt of attempts) {
    const result = planJourney(origin, destination, attempt.options);
    const signature = journeySignature(result);
    if (seenSignatures.has(signature)) continue;
    seenSignatures.add(signature);
    alternatives.push({ label: attempt.label, ...result });
  }
  return alternatives;
}

// Dijkstra con selección lineal del mínimo — el grafo tiene decenas de
// nodos como mucho en este mockup, así que una cola de prioridad real
// sería complejidad sin beneficio medible.
//
// Con `requiredModes` corre sobre el grafo duplicado en dos capas: la 0 es
// "todavía no aborda nada de lo que pediste" y la 1 "ya abordó". Una arista
// de un modo exigido sube de capa; las demás se quedan donde están, y el
// destino solo cuenta en la capa 1. Así el camino más corto que encuentra ya
// es el mejor de los que sí usan lo elegido — no el mejor a secas, filtrado
// después, que es donde caminar de punta a punta ganaba siempre.
//
// Devuelve `null` si no existe ninguno (sin exigencia nunca pasa: la arista
// origen -> destino caminando siempre está).
type State = string;

const stateOf = (node: string, boarded: boolean): State => `${node}#${boarded ? 1 : 0}`;
const nodeOf = (state: State): string => state.slice(0, state.lastIndexOf("#"));
const boardedIn = (state: State): boolean => state.endsWith("#1");

function dijkstra(
  graph: Map<string, Edge[]>,
  nodeLocation: Map<string, JourneyPoint>,
  requiredModes: Set<string> | null
): JourneyLeg[] | null {
  const start = stateOf(ORIGIN, false);
  const target = stateOf(DESTINATION, requiredModes !== null);

  const dist = new Map<State, number>([[start, 0]]);
  const prevEdge = new Map<State, { from: State; edge: Edge }>();
  const visited = new Set<State>();

  while (true) {
    let current: State | null = null;
    let currentDist = Infinity;
    for (const [state, d] of dist) {
      if (!visited.has(state) && d < currentDist) {
        current = state;
        currentDist = d;
      }
    }
    if (current === null || current === target) break;
    visited.add(current);

    const boarded = boardedIn(current);
    for (const edge of graph.get(nodeOf(current)) ?? []) {
      const next = stateOf(edge.to, requiredModes !== null && (boarded || requiredModes.has(edge.mode)));
      const candidate = currentDist + edge.weightMinutes;
      if (candidate < (dist.get(next) ?? Infinity)) {
        dist.set(next, candidate);
        prevEdge.set(next, { from: current, edge });
      }
    }
  }

  if (!dist.has(target)) return null;

  const legs: JourneyLeg[] = [];
  let cursor = target;
  while (cursor !== start) {
    const step = prevEdge.get(cursor);
    if (!step) return null;
    legs.unshift({
      mode: step.edge.mode,
      route_id: step.edge.routeId,
      route_name: step.edge.routeName,
      from: nodeLocation.get(nodeOf(step.from))!,
      to: nodeLocation.get(nodeOf(cursor))!,
      distance_km: Number(step.edge.distanceKm.toFixed(3)),
      eta_minutes: Number(step.edge.weightMinutes.toFixed(1)),
    });
    cursor = step.from;
  }
  return legs;
}
