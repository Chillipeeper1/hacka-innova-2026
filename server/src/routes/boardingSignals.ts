import { Router } from "express";
import { db } from "../db";
import { getBoardingSignal, setBoardingSignalStatus } from "../db/boardingSignals";
import { emitDemandUpdate } from "../sockets/emit";

export const boardingSignalsRouter = Router();

const VALID_STATUS = ["waiting", "boarded", "alighted", "expired"];

boardingSignalsRouter.post("/boarding-signals", (req, res) => {
  const {
    user_id,
    stop_id,
    route_id,
    intent,
    destination_stop_id,
    destination_lat,
    destination_lng,
  } = req.body;
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
      `INSERT INTO boarding_signals
        (user_id, stop_id, route_id, intent, status, destination_stop_id, destination_lat, destination_lng)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .run(
      user_id,
      stop_id,
      route_id,
      intent,
      status,
      destination_stop_id ?? null,
      destination_lat ?? null,
      destination_lng ?? null
    );

  if (status === "waiting") emitDemandUpdate(stop_id);

  res.status(201).json({
    id: result.lastInsertRowid,
    user_id,
    stop_id,
    route_id,
    intent,
    status,
    destination_stop_id: destination_stop_id ?? null,
    destination_lat: destination_lat ?? null,
    destination_lng: destination_lng ?? null,
  });
});

boardingSignalsRouter.patch("/boarding-signals/:id", (req, res) => {
  const id = Number(req.params.id);
  const { status } = req.body;
  if (!Number.isInteger(id) || !VALID_STATUS.includes(status)) {
    res.status(400).json({ error: `status debe ser uno de: ${VALID_STATUS.join(", ")}` });
    return;
  }

  const signal = getBoardingSignal(id);
  if (!signal) {
    res.status(404).json({ error: `boarding_signal ${id} no encontrado` });
    return;
  }

  setBoardingSignalStatus(id, status, signal.stop_id);

  res.json({ id, status });
});
