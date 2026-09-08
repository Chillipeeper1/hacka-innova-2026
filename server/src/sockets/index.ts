import type { Server, Socket } from "socket.io";
import { db } from "../db";

interface DriverPositionPayload {
  vehicle_id: number;
  lat: number;
  lng: number;
}

const updateVehiclePosition = db.prepare(
  "UPDATE vehicles SET last_lat = ?, last_lng = ?, last_recorded_at = ? WHERE id = ?"
);

export function registerSocketHandlers(io: Server): void {
  io.on("connection", (socket: Socket) => {
    // Emitido por el script/cliente que simula al conductor (Escenario 3).
    socket.on("driver:position", ({ vehicle_id, lat, lng }: DriverPositionPayload) => {
      const recordedAt = new Date().toISOString();
      updateVehiclePosition.run(lat, lng, recordedAt, vehicle_id);
      io.emit("vehicle:position", { vehicle_id, lat, lng, recorded_at: recordedAt });
    });
  });
}
