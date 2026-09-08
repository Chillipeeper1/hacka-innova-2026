import { scheduleAutoAlight } from "./autoAlight";
import { db } from "./index";
import { emitDemandUpdate } from "../sockets/emit";

export interface BoardingSignalRow {
  id: number;
  stop_id: number | null;
  status: string;
}

export function getBoardingSignal(id: number): BoardingSignalRow | undefined {
  return db
    .prepare("SELECT id, stop_id, status FROM boarding_signals WHERE id = ?")
    .get(id) as BoardingSignalRow | undefined;
}

// Único lugar que aplica un cambio de estado con sus efectos (recalcular
// demanda, agendar auto-liberación) — lo usan tanto el PATCH manual como
// /card-taps cuando reutiliza una señal ya declarada en una parada.
export function setBoardingSignalStatus(id: number, status: string, stopId: number | null): void {
  db.prepare(
    "UPDATE boarding_signals SET status = ?, updated_at = datetime('now') WHERE id = ?"
  ).run(status, id);
  if (stopId != null) emitDemandUpdate(stopId);
  if (status === "boarded") scheduleAutoAlight(id);
}
