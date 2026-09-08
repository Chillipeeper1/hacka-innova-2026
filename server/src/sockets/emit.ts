import type { Server } from "socket.io";
import { db } from "../db";

let io: Server | undefined;

export function attachIo(server: Server): void {
  io = server;
}

export function emitDemandUpdate(stopId: number): void {
  if (!io) return;
  const row = db
    .prepare(
      "SELECT COUNT(*) as count FROM boarding_signals WHERE stop_id = ? AND status = 'waiting'"
    )
    .get(stopId) as { count: number };
  io.emit("demand:update", { stop_id: stopId, waiting_count: row.count });
}
