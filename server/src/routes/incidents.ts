import { Router } from "express";
import { db } from "../db";

export const incidentsRouter = Router();

incidentsRouter.post("/incidents", (req, res) => {
  const { user_id, route_id, category, description } = req.body;
  if (!user_id || !route_id || !category) {
    res.status(400).json({ error: "user_id, route_id y category son requeridos" });
    return;
  }
  const result = db
    .prepare("INSERT INTO incidents (user_id, route_id, category, description) VALUES (?, ?, ?, ?)")
    .run(user_id, route_id, category, description ?? null);
  res.status(201).json({
    id: result.lastInsertRowid,
    user_id,
    route_id,
    category,
    description: description ?? null,
  });
});
