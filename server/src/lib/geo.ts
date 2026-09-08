interface LatLng {
  lat: number;
  lng: number;
}

const EARTH_RADIUS_KM = 6371;

// Distancia en línea recta — suficiente para el ETA simplificado del
// mockup (no sigue el trazado real de la ruta, ver CLAUDE.md).
export function haversineKm(a: LatLng, b: LatLng): number {
  const dLat = toRadians(b.lat - a.lat);
  const dLng = toRadians(b.lng - a.lng);
  const lat1 = toRadians(a.lat);
  const lat2 = toRadians(b.lat);

  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(h));
}

function toRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}
