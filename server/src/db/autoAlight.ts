import { db } from "./index";

// Escenario 5 (opcional): además de la confirmación manual de descenso,
// un boarding_signal que llega a 'boarded' se libera solo tras un tiempo
// simulado, si nadie lo cambió de estado antes.
const TRIP_DURATION_MS = process.env.TRIP_DURATION_MS
  ? Number(process.env.TRIP_DURATION_MS)
  : 20000;

const alightIfStillBoarded = db.prepare(
  "UPDATE boarding_signals SET status = 'alighted', updated_at = datetime('now') WHERE id = ? AND status = 'boarded'"
);

export function scheduleAutoAlight(signalId: number): void {
  setTimeout(() => {
    alightIfStillBoarded.run(signalId);
  }, TRIP_DURATION_MS);
}
