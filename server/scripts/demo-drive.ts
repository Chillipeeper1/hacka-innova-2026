// Conductor simulado con movimiento continuo, para demostrar el flujo del pasajero.
//
// `npm run simulate` (src/driver-sim.ts) salta de parada en parada cada 3 segundos: la unidad
// se teletransporta y cruza los 613 m entre la Catedral y las Tarascas a ~200 m/s. Sirve para
// comprobar que el evento `vehicle:position` llega, pero no para demostrar la app: el pasajero
// nunca alcanza a ver la unidad acercarse, ni le da tiempo de pagar.
//
// Este script recorre el trazado de forma continua, a velocidad de camión urbano, y **se
// detiene en cada parada** — que es lo que le da tiempo al pasajero de pasar su tarjeta.
//
// Uso:
//   npx tsx scripts/demo-drive.ts              # todas las rutas
//   npx tsx scripts/demo-drive.ts 2            # solo la ruta 2
//   SPEED_KMH=18 DWELL_MS=12000 npx tsx scripts/demo-drive.ts
import { readFileSync } from "fs";
import { createServer } from "net";
import { join } from "path";
import { io, type Socket } from "socket.io-client";

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
}

const seedPath = join(__dirname, "..", "src", "data", "seed-routes.json");
const { routes }: { routes: SeedRoute[] } = JSON.parse(
  readFileSync(seedPath, "utf-8")
);

const serverUrl = process.env.SERVER_URL ?? "http://localhost:3001";

/**
 * Velocidad del recorrido.
 *
 * Por encima de un camión real a propósito: las paradas del seed están a 600-1300 m, y a
 * velocidad realista cada tramo tomaría minutos. Para demostrar el flujo conviene comprimir
 * el tiempo; bajarlo a 20-25 si lo que se quiere es ver el ritmo verdadero.
 */
const speedMps = (Number(process.env.SPEED_KMH ?? 45) * 1000) / 3600;

/** Cuánto se detiene en cada parada. Es la ventana para pagar. */
const dwellMs = Number(process.env.DWELL_MS ?? 9000);

/** Cada cuánto se emite una posición. Más corto = movimiento más fluido en el mapa. */
const tickMs = Number(process.env.TICK_MS ?? 500);

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

const EARTH_RADIUS_M = 6371000;
const toRad = (degrees: number): number => (degrees * Math.PI) / 180;

function haversine(a: SeedStop, b: SeedStop): number {
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
function drive(socket: Socket, route: SeedRoute): void {
  const stops = [...route.stops].sort((a, b) => a.sequence - b.sequence);
  if (stops.length < 2) return;

  let leg = 0;
  let forward = true;
  let travelled = 0;
  let dwellingUntil = Date.now() + dwellMs;

  const emit = (lat: number, lng: number): void => {
    socket.emit("driver:position", { vehicle_id: route.id, lat, lng });
  };

  const from = (): SeedStop => (forward ? stops[leg] : stops[leg + 1]);
  const to = (): SeedStop => (forward ? stops[leg + 1] : stops[leg]);

  console.log(
    `Ruta ${route.id} "${route.name}": ${stops.length} paradas, ` +
      `${Math.round(speedMps * 3.6)} km/h, ${dwellMs / 1000}s por parada`
  );

  setInterval(() => {
    const now = Date.now();

    // Detenido en la parada: es la ventana en la que el pasajero puede pagar.
    if (now < dwellingUntil) {
      const stop = from();
      emit(stop.lat, stop.lng);
      return;
    }

    const origin = from();
    const target = to();
    const legMeters = haversine(origin, target);

    travelled += (speedMps * tickMs) / 1000;

    if (travelled >= legMeters) {
      // Llegó a la siguiente parada: se detiene ahí.
      emit(target.lat, target.lng);
      travelled = 0;
      dwellingUntil = now + dwellMs;

      const atEnd = forward ? leg + 2 >= stops.length : leg === 0;
      if (atEnd) {
        forward = !forward;
      } else {
        leg += forward ? 1 : -1;
      }

      console.log(`Ruta ${route.id} -> ${target.name}`);
      return;
    }

    // Interpolación lineal sobre el tramo. Suficiente para el mockup: el trazado real por
    // calles necesitaría un motor de ruteo, que CLAUDE.md deja fuera de esta fase.
    const fraction = travelled / legMeters;
    emit(
      origin.lat + (target.lat - origin.lat) * fraction,
      origin.lng + (target.lng - origin.lng) * fraction
    );
  }, tickMs);
}

function start(): void {
  const socket = io(serverUrl);

  socket.on("connect", () => {
    console.log(`Conectado a ${serverUrl}`);
    for (const route of selected) drive(socket, route);
  });

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

lock.listen(lockPort, "127.0.0.1", start);
