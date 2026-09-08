import { Router } from "express";
import { db } from "../db";
import { scheduleAutoAlight } from "../db/autoAlight";
import { emitDemandUpdate } from "../sockets/emit";

export const boardingSignalsRouter = Router();

const VALID_STATUS = ["waiting", "boarded", "alighted", "expired"];

boardingSignalsRouter.post("/boarding-signals", (req, res) => {
  const { user_id, stop_id, route_id, intent } = req.body;
  if (!user_id || !stop_id || !route_id || !["boarding", "passing"].includes(intent)) {
    res.status(400).json({
      error: "user_id, stop_id, route_id e intent ('boarding'|'passing') son requeridos",
    });
    return;
  }

  // "solo paso" no genera demanda de abordaje.
  const status = intent === "boarding" ? "waiting" : "expired";
  const result = db
    .prepare(
      "INSERT INTO boarding_signals (user_id, stop_id, route_id, intent, status) VALUES (?, ?, ?, ?, ?)"
    )
    .run(user_id, stop_id, route_id, intent, status);

  if (status === "waiting") emitDemandUpdate(stop_id);

  res.status(201).json({ id: result.lastInsertRowid, user_id, stop_id, route_id, intent, status });
});

boardingSignalsRouter.patch("/boarding-signals/:id", (req, res) => {
  const id = Number(req.params.id);
  const { status } = req.body;
  if (!Number.isInteger(id) || !VALID_STATUS.includes(status)) {
    res.status(400).json({ error: `status debe ser uno de: ${VALID_STATUS.join(", ")}` });
    return;
  }

  const signal = db.prepare("SELECT stop_id FROM boarding_signals WHERE id = ?").get(id) as
    | { stop_id: number | null }
    | undefined;
  if (!signal) {
    res.status(404).json({ error: `boarding_signal ${id} no encontrado` });
    return;
  }

  db.prepare("UPDATE boarding_signals SET status = ?, updated_at = datetime('now') WHERE id = ?").run(
    status,
    id
  );
  if (signal.stop_id != null) emitDemandUpdate(signal.stop_id);
  if (status === "boarded") scheduleAutoAlight(id);

  res.json({ id, status });
});
