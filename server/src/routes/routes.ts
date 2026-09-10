import { Router } from "express";
import { db } from "../db";
import { routeShape } from "../lib/roadGeometry";

export const routesRouter = Router();

interface RouteRow {
  id: number;
  name: string;
  mode: string;
  color_hex: string;
}

routesRouter.get("/routes", async (_req, res) => {
  const routes = db
    .prepare("SELECT id, name, mode, color_hex FROM routes")
    .all() as RouteRow[];
  const stopStmt = db.prepare(
    "SELECT id, name, lat, lng, sequence FROM stops WHERE route_id = ? ORDER BY sequence"
  );
  // `shape` es el trazado por calles de la ruta entera, pasando por todas sus
  // paradas. Va aqui y no en el cliente porque es lo mismo para todos y no
  // cambia nunca: se pide una vez a OSRM y queda cacheado. Puede faltar (sin
  // OSRM, o teleferico, que va por el aire) y entonces el cliente une las
  // paradas con rectas, que es lo que hacia antes.
  const result = await Promise.all(
    routes.map(async (route) => ({
      ...route,
      stops: stopStmt.all(route.id),
      shape: route.mode === "teleferico" ? undefined : ((await routeShape(route.id)) ?? undefined),
    }))
  );
  res.json(result);
});
