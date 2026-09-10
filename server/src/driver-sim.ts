// Script standalone que simula un conductor moviéndose sobre una ruta fija
// (Escenario 3). Uso: npm run simulate -- <routeId>
import { readFileSync } from "fs";
import { createServer } from "net";
import { join } from "path";
import { io } from "socket.io-client";

interface SeedStop {
  name: string;
  lat: number;
  lng: number;
  sequence: number;
}

interface SeedRoute {
  id: number;
  name: string;
  mode: string;
  color_hex: string;
  stops: SeedStop[];
}

const seedPath = join(__dirname, "data", "seed-routes.json");
const { routes }: { routes: SeedRoute[] } = JSON.parse(readFileSync(seedPath, "utf-8"));

const routeId = Number(process.argv[2] ?? routes[0].id);
const found = routes.find((r) => r.id === routeId);

if (!found) {
  console.error(`Ruta ${routeId} no encontrada. IDs disponibles: ${routes.map((r) => r.id).join(", ")}`);
  process.exit(1);
}

// En una const aparte porque el estrechamiento del `if` de arriba no llega hasta dentro de
// `start()`, que ahora corre detrás del candado.
const route: SeedRoute = found;

// Convención del seed (server/src/db/seed.ts): un vehículo por ruta,
// insertado en el mismo orden → vehicle_id coincide con route_id.
const vehicleId = route.id;

const serverUrl = process.env.SERVER_URL ?? "http://localhost:3001";
const stops = [...route.stops].sort((a, b) => a.sequence - b.sequence);
let index = 0;

function start(): void {
  // Este script no mueve la unidad: la reaparece en la siguiente parada cada 3 segundos. Es a
  // propósito —sirve para comprobar rápido que el evento llega— pero en el mapa se ve como si
  // el icono del camión estuviera roto, y quien lo abre esperando ver el recorrido no tiene
  // cómo saberlo. Por eso lo dice antes de empezar, no en un README que ya no está leyendo.
  const jumps = stops.map((stop, i) => {
    const next = stops[(i + 1) % stops.length];
    return Math.round(haversine(stop, next));
  });

  console.warn(
    `
OJO: este simulador TELETRANSPORTA la unidad entre paradas cada 3 s ` +
      `(saltos de ${jumps.join(" / ")} m, incluido el de regreso al reiniciar el ciclo).
` +
      `Sirve para probar que el evento llega. Para ver el mapa —la unidad avanzando, la ` +
      `ventana de pago, el viaje— usa: npm run demo-drive
`
  );

  const socket = io(serverUrl);

  // El intervalo se guarda para poder apagarlo: `socket.io-client` reconecta solo y `connect`
  // vuelve a dispararse en cada reconexión. Sin esto, cada reconexión deja otro emisor vivo
  // para el mismo `vehicle_id` y la unidad reporta desde varias paradas a la vez — con el
  // servidor en `tsx watch`, que reinicia a cada cambio, se acumulan solos.
  let driver: NodeJS.Timeout | null = null;

  const stopDriving = (): void => {
    if (driver) clearInterval(driver);
    driver = null;
  };

  socket.on("connect", () => {
    stopDriving();
    console.log(`Conductor simulado conectado (vehicle_id=${vehicleId}), recorriendo "${route.name}"`);
    driver = setInterval(() => {
      const stop = stops[index % stops.length];
      socket.emit("driver:position", { vehicle_id: vehicleId, lat: stop.lat, lng: stop.lng });
      console.log(`-> ${stop.name} (${stop.lat}, ${stop.lng})`);
      index += 1;
    }, 3000);
  });

  socket.on("disconnect", stopDriving);
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
 * Candado de instancia única, **compartido con `scripts/demo-drive.ts`** (mismo puerto a
 * propósito).
 *
 * Los dos scripts emiten `driver:position` para el mismo `vehicle_id`. Corriendo a la vez —lo
 * que pasa al abrir el segundo en una terminal nueva sin cerrar el primero— el servidor reenvía
 * los dos sin distinguirlos y la unidad salta entre el recorrido continuo y el teletransporte
 * varias veces por segundo. Los dos procesos se ven sanos en su consola, así que el único lugar
 * donde el problema es visible es el mapa, y ahí parece un fallo de la app.
 *
 * Compartir el puerto los vuelve mutuamente excluyentes: el segundo se niega a arrancar y dice
 * por qué.
 */
const lockPort = Number(process.env.LOCK_PORT ?? 47654);
const lock = createServer();

lock.once("error", (error: NodeJS.ErrnoException) => {
  if (error.code !== "EADDRINUSE") throw error;
  console.error(
    `Ya hay un simulador corriendo (candado en el puerto ${lockPort}).
` +
      "Ciérralo antes de abrir otro: dos simuladores pelean por la misma unidad y en el mapa " +
      "la unidad salta entre las dos posiciones."
  );
  process.exit(1);
});

lock.listen(lockPort, "127.0.0.1", start);
