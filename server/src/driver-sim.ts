// Script standalone que simula un conductor moviéndose sobre una ruta fija
// (Escenario 3). Uso: npm run simulate -- <routeId>
import { readFileSync } from "fs";
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
const route = routes.find((r) => r.id === routeId);

if (!route) {
  console.error(`Ruta ${routeId} no encontrada. IDs disponibles: ${routes.map((r) => r.id).join(", ")}`);
  process.exit(1);
}

// Convención del seed (server/src/db/seed.ts): un vehículo por ruta,
// insertado en el mismo orden → vehicle_id coincide con route_id.
const vehicleId = route.id;

const serverUrl = process.env.SERVER_URL ?? "http://localhost:3001";
const socket = io(serverUrl);
const stops = [...route.stops].sort((a, b) => a.sequence - b.sequence);
let index = 0;

socket.on("connect", () => {
  console.log(`Conductor simulado conectado (vehicle_id=${vehicleId}), recorriendo "${route.name}"`);
  setInterval(() => {
    const stop = stops[index % stops.length];
    socket.emit("driver:position", { vehicle_id: vehicleId, lat: stop.lat, lng: stop.lng });
    console.log(`-> ${stop.name} (${stop.lat}, ${stop.lng})`);
    index += 1;
  }, 3000);
});
