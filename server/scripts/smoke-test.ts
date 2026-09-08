// Recorre el flujo completo de la API contra un servidor ya corriendo.
// Uso: npm run dev (en una terminal) y luego npm run test:smoke (en otra).
import { io } from "socket.io-client";

const SERVER_URL = process.env.SERVER_URL ?? "http://localhost:3001";
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

  console.log("\nTodo el flujo pasó correctamente.");
}

main().catch((err) => {
  console.error("✗ smoke test falló:", err);
  process.exit(1);
});
