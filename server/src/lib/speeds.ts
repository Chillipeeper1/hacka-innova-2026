// Velocidad promedio fija por modo — regla simple de mockup, sin tráfico
// ni motor de ruteo real. Compartida entre GET /stops/:id/eta y el motor de
// recomendación de transbordos (GET /journeys) para que ambos midan igual.
export const AVERAGE_SPEED_KMH_BY_MODE: Record<string, number> = {
  combi: 15,
  bus: 15,
  teleferico: 20, // línea recta aérea, sin tráfico ni semáforos
};

export const DEFAULT_SPEED_KMH = 15;

export function speedForMode(mode: string): number {
  return AVERAGE_SPEED_KMH_BY_MODE[mode] ?? DEFAULT_SPEED_KMH;
}

export const WALK_SPEED_KMH = 4.5;

// Mismo valor que `bikeSpeedKmh` en app/lib/data/bike_network.dart — puerta
// a puerta, incluyendo altos y cruces, no la velocidad en movimiento.
export const BIKE_SPEED_KMH = 15;

// Más allá de esto, no se ofrece bici como opción — mismo criterio que usan
// apps de ruteo reales (nadie pedalea distancias así de largas para un
// viaje cotidiano). Sin este límite, como combi/bus comparten la misma
// velocidad que la bici pero cargan espera de abordaje, la bici nunca
// perdería contra transporte colectivo sin importar la distancia.
export const MAX_BIKE_DISTANCE_KM = 6;
