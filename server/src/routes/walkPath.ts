import { Router } from "express";
import { roadPathThrough } from "../lib/roadGeometry";

export const walkPathRouter = Router();

// El trazado a pie entre dos puntos: de donde esta el pasajero a la parada en
// la que va a subir.
//
// Va aparte de /journeys porque este tramo no forma parte de ningun itinerario
// calculado: en el flujo de camion el pasajero ya eligio su parada, y lo unico
// que falta es por donde llegar andando.
//
// `via` (opcional) son puntos intermedios, `lat,lng` separados por `;`. Con
// ellos el trazado pasa por donde el cliente ya decidio que tiene que pasar:
// los rodeos que esquivan una zona marcada, los extremos de una ciclovia. Sin
// eso, ajustar a calles se llevaria por delante el desvio que costo calcular.
//
// Devuelve `{ path: [] }` cuando no hay trazado (OSRM caido, o los dos puntos
// son el mismo) en vez de un error: el cliente dibuja la recta y sigue.
walkPathRouter.get("/walk-path", async (req, res) => {
  const fromLat = Number(req.query.from_lat);
  const fromLng = Number(req.query.from_lng);
  const toLat = Number(req.query.to_lat);
  const toLng = Number(req.query.to_lng);

  if ([fromLat, fromLng, toLat, toLng].some((n) => Number.isNaN(n))) {
    res.status(400).json({
      error: "from_lat, from_lng, to_lat y to_lng son requeridos y deben ser numeros",
    });
    return;
  }

  const via: { lat: number; lng: number }[] = [];
  if (typeof req.query.via === "string" && req.query.via.length > 0) {
    for (const pair of req.query.via.split(";")) {
      const [lat, lng] = pair.split(",").map(Number);
      if (Number.isNaN(lat) || Number.isNaN(lng)) {
        res.status(400).json({ error: `via invalido: "${pair}". Formato: lat,lng;lat,lng` });
        return;
      }
      via.push({ lat, lng });
    }
  }

  const path = await roadPathThrough([
    { lat: fromLat, lng: fromLng },
    ...via,
    { lat: toLat, lng: toLng },
  ]);
  res.json({ path: path ?? [] });
});
