import { Router } from "express";
import { db } from "../db";

export const tripsRouter = Router();

// El contrato no define un recurso /trips separado; para el mockup un "viaje"
// es un boarding_signal que llegó a 'boarded' (ver nota en schema.sql).
tripsRouter.post("/trips/:id/rating", (req, res) => {
  const id = Number(req.params.id);
  const { rating, comment } = req.body;
  if (!Number.isInteger(id) || !Number.isInteger(rating) || rating < 1 || rating > 5) {
    res.status(400).json({ error: "rating debe ser un entero entre 1 y 5" });
    return;
  }

  const signal = db
    .prepare("SELECT id FROM boarding_signals WHERE id = ? AND status = 'boarded'")
    .get(id);
  if (!signal) {
    res.status(404).json({ error: `No hay un viaje abordado con id ${id}` });
    return;
  }

  const result = db
    .prepare("INSERT INTO ratings (boarding_signal_id, rating, comment) VALUES (?, ?, ?)")
    .run(id, rating, comment ?? null);

  res.status(201).json({
    id: result.lastInsertRowid,
    boarding_signal_id: id,
    rating,
    comment: comment ?? null,
  });
});
