import { Router } from "express";
import { db } from "../db";
import { haversineKm } from "../lib/geo";

export const stopsRouter = Router();

// Valor fijo de mockup — velocidad promedio de una combi urbana en Morelia.
// Ajustable; ver "ETA = distancia restante / velocidad promedio fija" en
// documento-base-maas-morelia.md.
const AVERAGE_SPEED_KMH = 15;

interface StopRow {
  id: number;
  lat: number;
  lng: number;
  route_id: number;
}

interface VehicleRow {
  id: number;
  last_lat: number | null;
  last_lng: number | null;
  last_recorded_at: string | null;
}

stopsRouter.get("/stops/:id/eta", (req, res) => {
  const stopId = Number(req.params.id);
  if (!Number.isInteger(stopId)) {
    res.status(400).json({ error: "id de parada inválido" });
    return;
  }

  const stop = db
    .prepare("SELECT id, lat, lng, route_id FROM stops WHERE id = ?")
    .get(stopId) as StopRow | undefined;
  if (!stop) {
    res.status(404).json({ error: `stop ${stopId} no encontrada` });
    return;
  }

  const vehicle = db
    .prepare("SELECT id, last_lat, last_lng, last_recorded_at FROM vehicles WHERE route_id = ?")
    .get(stop.route_id) as VehicleRow | undefined;
  if (!vehicle) {
    res.status(404).json({ error: `Ninguna unidad asignada a route_id ${stop.route_id}` });
    return;
  }

  if (vehicle.last_lat == null || vehicle.last_lng == null) {
    res.json({
      stop_id: stop.id,
      route_id: stop.route_id,
      vehicle_id: vehicle.id,
      distance_km: null,
      eta_minutes: null,
    });
    return;
  }

  const distanceKm = haversineKm(
    { lat: vehicle.last_lat, lng: vehicle.last_lng },
    { lat: stop.lat, lng: stop.lng }
  );
  const etaMinutes = (distanceKm / AVERAGE_SPEED_KMH) * 60;

  res.json({
    stop_id: stop.id,
    route_id: stop.route_id,
    vehicle_id: vehicle.id,
    distance_km: Number(distanceKm.toFixed(3)),
    eta_minutes: Number(etaMinutes.toFixed(1)),
  });
});
