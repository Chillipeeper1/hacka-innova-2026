import { Router } from "express";
import { db } from "../db";

export const routesRouter = Router();

interface RouteRow {
  id: number;
  name: string;
  mode: string;
  color_hex: string;
}

routesRouter.get("/routes", (_req, res) => {
  const routes = db
    .prepare("SELECT id, name, mode, color_hex FROM routes")
    .all() as RouteRow[];
  const stopStmt = db.prepare(
    "SELECT id, name, lat, lng, sequence FROM stops WHERE route_id = ? ORDER BY sequence"
  );
  const result = routes.map((route) => ({
    ...route,
    stops: stopStmt.all(route.id),
  }));
  res.json(result);
});
