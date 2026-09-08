import { Router } from "express";
import { db } from "../db";
import { scheduleAutoAlight } from "../db/autoAlight";

export const cardTapsRouter = Router();

// Escenario 6: el tap confirma abordaje directo dentro del vehículo,
// sin pasar por 'waiting' — ver CLAUDE.md.
cardTapsRouter.post("/card-taps", (req, res) => {
  const { card_uid, vehicle_id, tapped_at } = req.body;
  if (!card_uid || !vehicle_id) {
    res.status(400).json({ error: "card_uid y vehicle_id son requeridos" });
    return;
  }

  const user = db.prepare("SELECT id FROM users WHERE card_uid = ?").get(card_uid) as
    | { id: number }
    | undefined;
  if (!user) {
    res.status(404).json({ error: `Ninguna tarjeta demo vinculada a card_uid "${card_uid}"` });
    return;
  }

  const vehicle = db.prepare("SELECT route_id FROM vehicles WHERE id = ?").get(vehicle_id) as
    | { route_id: number }
    | undefined;
  if (!vehicle) {
    res.status(404).json({ error: `vehicle_id ${vehicle_id} no existe` });
    return;
  }

  const signalResult = db
    .prepare(
      "INSERT INTO boarding_signals (user_id, stop_id, route_id, intent, status) VALUES (?, NULL, ?, 'boarding', 'boarded')"
    )
    .run(user.id, vehicle.route_id);

  const tapResult = db
    .prepare(
      "INSERT INTO card_taps (card_uid, vehicle_id, tapped_at, boarding_signal_id) VALUES (?, ?, COALESCE(?, datetime('now')), ?)"
    )
    .run(card_uid, vehicle_id, tapped_at ?? null, signalResult.lastInsertRowid);

  scheduleAutoAlight(Number(signalResult.lastInsertRowid));

  res.status(201).json({
    id: tapResult.lastInsertRowid,
    card_uid,
    vehicle_id,
    boarding_signal_id: signalResult.lastInsertRowid,
  });
});
