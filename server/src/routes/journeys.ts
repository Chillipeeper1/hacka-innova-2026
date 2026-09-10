import { Router } from "express";
import { KNOWN_JOURNEY_MODES, planJourneyAlternatives } from "../lib/journeyPlanner";
import { withRoadGeometry } from "../lib/roadGeometry";

export const journeysRouter = Router();

journeysRouter.get("/journeys", async (req, res) => {
  const originLat = Number(req.query.origin_lat);
  const originLng = Number(req.query.origin_lng);
  const destinationLat = Number(req.query.destination_lat);
  const destinationLng = Number(req.query.destination_lng);

  if ([originLat, originLng, destinationLat, destinationLng].some((n) => Number.isNaN(n))) {
    res.status(400).json({
      error:
        "origin_lat, origin_lng, destination_lat y destination_lng son requeridos y deben ser números",
    });
    return;
  }

  let requestedModes: Set<string> | null = null;
  if (typeof req.query.modes === "string" && req.query.modes.length > 0) {
    const requested = req.query.modes.split(",").map((mode) => mode.trim());
    const invalid = requested.filter((mode) => !KNOWN_JOURNEY_MODES.includes(mode as never));
    if (invalid.length > 0) {
      res.status(400).json({
        error: `modes inválidos: ${invalid.join(", ")}. Válidos: ${KNOWN_JOURNEY_MODES.join(", ")}`,
      });
      return;
    }
    requestedModes = new Set(requested);
  }

  const alternatives = planJourneyAlternatives(
    { lat: originLat, lng: originLng },
    { lat: destinationLat, lng: destinationLng },
    requestedModes
  );

  // El trazado por calles va aparte del cálculo: el viaje ya está decidido
  // y esto solo dice por dónde pasa la línea. Si OSRM no contesta, los
  // tramos salen sin `geometry` y el cliente dibuja la recta de siempre.
  res.json({ alternatives: await withRoadGeometry(alternatives) });
});
