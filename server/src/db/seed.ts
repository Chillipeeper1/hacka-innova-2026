import { readFileSync } from "fs";
import { join } from "path";
import { db } from "./index";

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

interface SeedFile {
  routes: SeedRoute[];
}

export function seed(): void {
  const seedPath = join(__dirname, "..", "data", "seed-routes.json");
  const { routes }: SeedFile = JSON.parse(readFileSync(seedPath, "utf-8"));

  const insertRoute = db.prepare(
    "INSERT INTO routes (id, name, mode, color_hex) VALUES (?, ?, ?, ?)"
  );
  const insertStop = db.prepare(
    "INSERT INTO stops (route_id, name, lat, lng, sequence) VALUES (?, ?, ?, ?, ?)"
  );
  const insertVehicle = db.prepare(
    "INSERT INTO vehicles (route_id, label) VALUES (?, ?)"
  );

  for (const route of routes) {
    insertRoute.run(route.id, route.name, route.mode, route.color_hex);
    for (const stop of route.stops) {
      insertStop.run(route.id, stop.name, stop.lat, stop.lng, stop.sequence);
    }
    insertVehicle.run(route.id, `Unidad ${route.name}`);
  }

  // Usuario demo con tarjeta vinculada, para el Escenario 6 (tap simulado).
  db.prepare("INSERT INTO users (name, role, card_uid) VALUES (?, ?, ?)").run(
    "Pasajero Demo",
    "passenger",
    "DEMO-0001"
  );
}
