// Recorre el flujo completo de la API contra un servidor ya corriendo.
// Uso: npm run dev (en una terminal) y luego npm run test:smoke (en otra).
import { io } from "socket.io-client";
import { MAX_BIKE_DISTANCE_KM } from "../src/lib/speeds";

const SERVER_URL = process.env.SERVER_URL ?? "http://localhost:3001";

interface JourneyLegBody {
  mode: string;
  from: { lat: number; lng: number };
  to: { lat: number; lng: number };
  geometry?: [number, number][];
}
const DEMO_CARD_UID = "DEMO-0001";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) {
    console.error(`✗ ${message}`);
    process.exit(1);
  }
  console.log(`✓ ${message}`);
}

async function get(path: string) {
  const res = await fetch(`${SERVER_URL}${path}`);
  return { status: res.status, body: await res.json() };
}

async function post(path: string, body: unknown) {
  const res = await fetch(`${SERVER_URL}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

async function patch(path: string, body: unknown) {
  const res = await fetch(`${SERVER_URL}${path}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

function waitingCountFor(stops: Array<{ stop_id: number; waiting_count: number }>, stopId: number): number {
  return stops.find((s) => s.stop_id === stopId)?.waiting_count ?? 0;
}

async function main() {
  const routesRes = await get("/routes");
  assert(routesRes.status === 200 && routesRes.body.length > 0, "GET /routes devuelve rutas");
  const route = routesRes.body[0];
  const stop = route.stops[0];
  // Convención del seed: un vehículo por ruta, vehicle_id == route_id (ver server/README.md).
  const vehicleId = route.id;

  const userRes = await post("/users", { name: "Smoke Test", role: "passenger" });
  assert(userRes.status === 201 && userRes.body.id, "POST /users crea un usuario");
  const userId = userRes.body.id;

  const before = await get("/demand/stops");
  const countBefore = waitingCountFor(before.body, stop.id);

  const signalRes = await post("/boarding-signals", {
    user_id: userId,
    stop_id: stop.id,
    route_id: route.id,
    intent: "boarding",
  });
  assert(
    signalRes.status === 201 && signalRes.body.status === "waiting",
    "POST /boarding-signals crea una señal en estado 'waiting'"
  );
  const signalId = signalRes.body.id;

  const afterWaiting = await get("/demand/stops");
  assert(
    waitingCountFor(afterWaiting.body, stop.id) === countBefore + 1,
    "GET /demand/stops refleja el incremento de la señal"
  );

  const patchRes = await patch(`/boarding-signals/${signalId}`, { status: "boarded" });
  assert(patchRes.status === 200 && patchRes.body.status === "boarded", "PATCH /boarding-signals/:id → boarded");

  const afterBoarded = await get("/demand/stops");
  assert(
    waitingCountFor(afterBoarded.body, stop.id) === countBefore,
    "GET /demand/stops vuelve al conteo previo tras abordar"
  );

  const etaBefore = await get(`/stops/${stop.id}/eta`);
  assert(
    etaBefore.status === 200 && etaBefore.body.eta_minutes === null,
    "GET /stops/:id/eta es null antes de conocer la posición del vehículo"
  );

  await new Promise<void>((resolve, reject) => {
    const socket = io(SERVER_URL);
    const timeout = setTimeout(() => reject(new Error("timeout esperando vehicle:position")), 5000);
    socket.on("connect", () => {
      socket.emit("driver:position", { vehicle_id: vehicleId, lat: stop.lat, lng: stop.lng });
    });
    socket.on("vehicle:position", (payload) => {
      if (payload.vehicle_id === vehicleId) {
        clearTimeout(timeout);
        socket.disconnect();
        resolve();
      }
    });
  });
  console.log("✓ WebSocket: driver:position → vehicle:position");

  const etaAfter = await get(`/stops/${stop.id}/eta`);
  assert(
    etaAfter.status === 200 && typeof etaAfter.body.eta_minutes === "number",
    "GET /stops/:id/eta devuelve un número tras conocer la posición"
  );

  const tapRes = await post("/card-taps", { card_uid: DEMO_CARD_UID, vehicle_id: vehicleId });
  assert(tapRes.status === 201 && tapRes.body.boarding_signal_id, "POST /card-taps confirma abordaje directo");

  const ratingRes = await post(`/trips/${tapRes.body.boarding_signal_id}/rating`, {
    rating: 5,
    comment: "Smoke test",
  });
  assert(ratingRes.status === 201, "POST /trips/:id/rating acepta la calificación");

  const incidentRes = await post("/incidents", {
    user_id: userId,
    route_id: route.id,
    category: "otro",
    description: "Smoke test",
  });
  assert(incidentRes.status === 201, "POST /incidents registra el reporte");

  const originStop = route.stops[0]; // Catedral de Morelia (ruta 1)
  const teleferico = routesRes.body.find((r: { id: number }) => r.id === 3);
  const shortHopStop = teleferico.stops[teleferico.stops.length - 1]; // Central de Autobuses, ~1-3 km
  const charo = routesRes.body.find((r: { id: number }) => r.id === 4);
  const longHopStop = charo.stops[charo.stops.length - 1]; // Charo Centro, ~9 km

  // Sin `modes`: debe devolver varias alternativas etiquetadas.
  const defaultRes = await get(
    `/journeys?origin_lat=${originStop.lat}&origin_lng=${originStop.lng}` +
      `&destination_lat=${shortHopStop.lat}&destination_lng=${shortHopStop.lng}`
  );
  assert(
    defaultRes.status === 200 && defaultRes.body.alternatives.length >= 1,
    "GET /journeys devuelve al menos una alternativa"
  );
  const labels = defaultRes.body.alternatives.map((alt: { label: string }) => alt.label);
  assert(labels.includes("Más rápida"), "GET /journeys incluye la alternativa 'Más rápida'");

  // `modes` excluyendo bici: una sola alternativa, sin ningún tramo `bike`.
  const noBikeRes = await get(
    `/journeys?origin_lat=${originStop.lat}&origin_lng=${originStop.lng}` +
      `&destination_lat=${shortHopStop.lat}&destination_lng=${shortHopStop.lng}` +
      `&modes=combi,bus,teleferico`
  );
  assert(
    noBikeRes.status === 200 && noBikeRes.body.alternatives.length === 1,
    "GET /journeys con `modes` devuelve exactamente una alternativa"
  );
  const noBikeModes = new Set(
    noBikeRes.body.alternatives[0].legs.map((leg: { mode: string }) => leg.mode)
  );
  assert(!noBikeModes.has("bike"), "GET /journeys respeta `modes` y excluye bici cuando se pide");

  // Y no basta con no contradecir el filtro: el viaje tiene que USAR algo de
  // lo pedido. El bug era que, si caminar de punta a punta salía antes, el
  // motor devolvía la caminata completa a quien había dicho "acepto combi" —
  // sin abordar nada, o sea sin generar la señal de demanda del proyecto.
  for (const [modos, destino] of [
    ["combi", shortHopStop],
    ["bus", shortHopStop],
    ["combi,bus", shortHopStop],
    ["teleferico", shortHopStop],
    ["combi,bus,teleferico", longHopStop],
  ] as [string, { lat: number; lng: number }][]) {
    const res = await get(
      `/journeys?origin_lat=${originStop.lat}&origin_lng=${originStop.lng}` +
        `&destination_lat=${destino.lat}&destination_lng=${destino.lng}&modes=${modos}`
    );
    const usados = new Set(res.body.alternatives[0].legs.map((leg: { mode: string }) => leg.mode));
    const pedidos = modos.split(",");
    assert(
      pedidos.some((modo) => usados.has(modo)),
      `GET /journeys con modes=${modos} arma un viaje que usa alguno de esos modos ` +
        `(devolvió: ${[...usados].join(", ")})`
    );
  }

  // La excepción legítima: la bici queda fuera por distancia (>6 km), así
  // que no hay viaje posible con lo pedido y se cae a caminar en vez de
  // contestar "no hay viaje".
  const bikeTooFarRes = await get(
    `/journeys?origin_lat=${originStop.lat}&origin_lng=${originStop.lng}` +
      `&destination_lat=${longHopStop.lat}&destination_lng=${longHopStop.lng}&modes=bike`
  );
  assert(
    bikeTooFarRes.status === 200 && bikeTooFarRes.body.alternatives.length === 1,
    "GET /journeys sigue devolviendo un viaje cuando lo pedido es imposible (bici fuera de rango)"
  );

  // `modes` inválido: 400.
  const invalidModesRes = await get(
    `/journeys?origin_lat=${originStop.lat}&origin_lng=${originStop.lng}` +
      `&destination_lat=${shortHopStop.lat}&destination_lng=${shortHopStop.lng}&modes=volador`
  );
  assert(invalidModesRes.status === 400, "GET /journeys rechaza un modo inválido en `modes`");

  // Trayecto largo (~9 km, a Charo): fuera de MAX_BIKE_DISTANCE_KM. La
  // propia alternativa "Más rápida" no debe encadenar tramos de bici que
  // sumen más que el límite (relevo de bici a través de una parada usada
  // solo como punto de paso) — verificarlo en TODAS las alternativas, no
  // solo la más rápida, porque el bug real fue justo que una alternativa
  // secundaria colaba el relevo mientras la primera se veía sana.
  const longRes = await get(
    `/journeys?origin_lat=${originStop.lat}&origin_lng=${originStop.lng}` +
      `&destination_lat=${longHopStop.lat}&destination_lng=${longHopStop.lng}`
  );
  for (const alt of longRes.body.alternatives as { label: string; legs: { mode: string; distance_km: number }[] }[]) {
    const bikeKm = alt.legs.filter((leg) => leg.mode === "bike").reduce((sum, leg) => sum + leg.distance_km, 0);
    assert(
      bikeKm <= MAX_BIKE_DISTANCE_KM,
      `GET /journeys: la alternativa "${alt.label}" no encadena bici más allá de MAX_BIKE_DISTANCE_KM (usó ${bikeKm} km)`
    );
  }

  // Trazado por calles: `geometry` es opcional a proposito -- una demo sin
  // internet, o con OSRM caido, devuelve los tramos pelados y el cliente
  // dibuja la recta. Lo que no puede pasar es que venga mal formado, que es
  // lo que dibujaria una linea en mitad del oceano.
  const geoRes = await get(
    `/journeys?origin_lat=${originStop.lat}&origin_lng=${originStop.lng}` +
      `&destination_lat=${shortHopStop.lat}&destination_lng=${shortHopStop.lng}` +
      `&modes=combi,bus,teleferico`
  );
  let conTrazado = 0;
  for (const alt of geoRes.body.alternatives as { legs: JourneyLegBody[] }[]) {
    for (const leg of alt.legs) {
      if (leg.geometry === undefined) continue;
      conTrazado++;
      assert(
        leg.geometry.length >= 2,
        `GET /journeys: el trazado del tramo ${leg.mode} trae al menos dos puntos`
      );
      const fuera = leg.geometry.filter(
        ([lat, lng]) => lat < 19.5 || lat > 19.9 || lng < -101.5 || lng > -100.9
      );
      assert(
        fuera.length === 0,
        `GET /journeys: el trazado del tramo ${leg.mode} cae dentro de Morelia ` +
          `(si no, lat/lng vienen invertidos: ${JSON.stringify(fuera[0])})`
      );
      const primero = leg.geometry[0];
      const ultimo = leg.geometry[leg.geometry.length - 1];
      assert(
        Math.abs(primero[0] - leg.from.lat) < 0.01 && Math.abs(ultimo[0] - leg.to.lat) < 0.01,
        `GET /journeys: el trazado del tramo ${leg.mode} empieza y acaba en sus extremos`
      );
      assert(
        leg.mode !== "teleferico",
        "GET /journeys: solo traen trazado por calles los tramos que van por calle (el teleferico va por el aire)"
      );
    }
  }
  console.log(
    conTrazado > 0
      ? `✓ GET /journeys: ${conTrazado} tramo(s) con trazado por calles, bien formados`
      : "- GET /journeys: sin trazado por calles (OSRM no disponible) - se dibujaran rectas"
  );

  // /routes: `shape` es el trazado por calles de la ruta entera. Opcional
  // por las mismas razones que `geometry`, y con las mismas garantias de
  // forma cuando viene.
  const shapeRes = await get("/routes");
  let rutasConTrazado = 0;
  for (const route of shapeRes.body as { name: string; mode: string; shape?: [number, number][] }[]) {
    if (route.shape === undefined) continue;
    rutasConTrazado++;
    assert(
      route.shape.length >= 2,
      `GET /routes: el trazado de "${route.name}" trae al menos dos puntos`
    );
    assert(
      route.mode !== "teleferico",
      "GET /routes: solo traen trazado por calles las rutas que van por calle"
    );
  }
  console.log(
    rutasConTrazado > 0
      ? `✓ GET /routes: ${rutasConTrazado} ruta(s) con trazado por calles`
      : "- GET /routes: sin trazado por calles (OSRM no disponible)"
  );

  // /walk-path: el tramo a pie hasta la parada.
  const walkRes = await get(
    `/walk-path?from_lat=19.7095&from_lng=-101.1955` +
      `&to_lat=${originStop.lat}&to_lng=${originStop.lng}`
  );
  assert(
    walkRes.status === 200 && Array.isArray(walkRes.body.path),
    "GET /walk-path devuelve un trazado (vacio si no hay OSRM, nunca un error)"
  );
  const malRes = await get("/walk-path?from_lat=abc&from_lng=1&to_lat=2&to_lng=3");
  assert(malRes.status === 400, "GET /walk-path rechaza coordenadas invalidas");

  console.log("\nTodo el flujo pasó correctamente.");
}

main().catch((err) => {
  console.error("✗ smoke test falló:", err);
  process.exit(1);
});
