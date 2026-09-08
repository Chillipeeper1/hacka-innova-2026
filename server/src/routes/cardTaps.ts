import { Router } from "express";
import { db } from "../db";
import { scheduleAutoAlight } from "../db/autoAlight";
import { getBoardingSignal, setBoardingSignalStatus } from "../db/boardingSignals";

export const cardTapsRouter = Router();

// Escenario 6: el tap confirma abordaje directo. Si el body trae
// `boarding_signal_id`, reutiliza esa señal (ya declarada en una parada) y
// la marca 'boarded' en vez de crear una nueva — evita cerrarla como
// 'expired' (que significa justo lo contrario de lo que pasó, ver
// app/README.md). Sin `boarding_signal_id`, se comporta como antes: crea
// una señal nueva sin parada asociada.
cardTapsRouter.post("/card-taps", (req, res) => {
  const { card_uid, vehicle_id, tapped_at, boarding_signal_id } = req.body;
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

  let signalId: number;

  if (boarding_signal_id != null) {
    const existing = getBoardingSignal(Number(boarding_signal_id));
    if (!existing) {
      res.status(404).json({ error: `boarding_signal_id ${boarding_signal_id} no existe` });
      return;
    }
    setBoardingSignalStatus(existing.id, "boarded", existing.stop_id);
    signalId = existing.id;
  } else {
    const signalResult = db
      .prepare(
        "INSERT INTO boarding_signals (user_id, stop_id, route_id, intent, status) VALUES (?, NULL, ?, 'boarding', 'boarded')"
      )
      .run(user.id, vehicle.route_id);
    signalId = Number(signalResult.lastInsertRowid);
    scheduleAutoAlight(signalId);
  }

  const tapResult = db
    .prepare(
      "INSERT INTO card_taps (card_uid, vehicle_id, tapped_at, boarding_signal_id) VALUES (?, ?, COALESCE(?, datetime('now')), ?)"
    )
    .run(card_uid, vehicle_id, tapped_at ?? null, signalId);

  res.status(201).json({
    id: tapResult.lastInsertRowid,
    card_uid,
    vehicle_id,
    boarding_signal_id: signalId,
  });
});
