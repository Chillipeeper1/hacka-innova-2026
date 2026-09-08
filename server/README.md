# server/ — Backend del mockup MaaS Morelia

```
npm install
npm run dev          # levanta el servidor en http://localhost:3001
npm run simulate      # en otra terminal: teletransporta la unidad parada a parada cada 3s (rápido para probar el evento)
npm run demo-drive    # alternativa para presentar: recorrido continuo a velocidad de camión, con parada real en cada stop (ventana para pagar)
npm run test:smoke    # en otra terminal, con el servidor ya corriendo: recorre todo el flujo de la API
```

Variables de entorno opcionales: `PORT` (default `3001`), `TRIP_DURATION_MS`
(default 15 min, ver Escenario 5 abajo).

Base de datos: SQLite en memoria (`server/src/db/schema.sql`), sembrada al
arrancar desde `server/src/data/seed-routes.json`. Se reinicia en cada
reinicio del servidor — a propósito, para no arrastrar estado viejo entre
corridas de la demo.

## Endpoints REST
| Método | Ruta | Body | Notas |
|---|---|---|---|
| GET | `/routes` | — | Rutas con sus paradas anidadas |
| POST | `/users` | `{ name, role }` | `role`: `passenger` \| `driver` |
| POST | `/boarding-signals` | `{ user_id, stop_id, route_id, intent, destination_stop_id?, destination_lat?, destination_lng? }` | `intent`: `boarding` (→ `waiting`) \| `passing` (→ `expired`). Los `destination_*` son opcionales, para estimar carga por tramo en el panel institucional a futuro |
| PATCH | `/boarding-signals/:id` | `{ status }` | `status`: `waiting`\|`boarded`\|`alighted`\|`expired` |
| GET | `/demand/stops` | — | `[{ stop_id, waiting_count }]`, conteo de `waiting` |
| GET | `/stops/:id/eta` (Escenario 2) | — | `{ stop_id, route_id, vehicle_id, distance_km, eta_minutes }`; ambos `null` si el vehículo de esa ruta aún no emitió ninguna posición. ETA = distancia en línea recta / `AVERAGE_SPEED_KMH` (15 km/h fijo, en `routes/stops.ts`) |
| POST | `/card-taps` (Escenario 6) | `{ card_uid, vehicle_id, tapped_at?, boarding_signal_id? }` | Sin `boarding_signal_id`: crea una señal nueva sin parada, directo en `boarded`. Con `boarding_signal_id`: reutiliza esa señal (ya declarada en una parada) y la marca `boarded` — así el conteo de demanda baja correctamente en vez de quedar como `expired` |
| POST | `/trips/:id/rating` (Escenario 7) | `{ rating, comment? }` | `:id` es el `boarding_signal_id` que llegó a `boarded` — el contrato no define un recurso `/trips` separado, ver nota en `schema.sql` |
| POST | `/incidents` (Escenario 7) | `{ user_id, route_id, category, description? }` | — |

## Eventos WebSocket (socket.io)
| Evento | Dirección | Payload |
|---|---|---|
| `driver:position` | cliente (conductor) → servidor | `{ vehicle_id, lat, lng }` |
| `vehicle:position` | servidor → todos los clientes | `{ vehicle_id, lat, lng, recorded_at }` |
| `demand:update` | servidor → todos los clientes | `{ stop_id, waiting_count }` |

**Nota de brecha conocida**: el contrato no expone un endpoint para resolver
`vehicle_id → route_id` (por ejemplo al recibir `vehicle:position` en la app).
Para este mockup, `server/src/db/seed.ts` inserta un vehículo por ruta en el
mismo orden del seed, así que `vehicle_id == route_id`. Si se agrega más de
un vehículo por ruta, esta convención deja de bastar y hace falta un
endpoint real (avisar antes de agregarlo, por la regla de "no inventes
rutas... sin avisar" de `CLAUDE.md`).

Usuario demo con tarjeta vinculada (Escenario 6): `card_uid = "DEMO-0001"`.

**Escenario 5 (auto-liberación)**: cuando un `boarding_signal` llega a
`boarded` (por `PATCH` manual o por `/card-taps`), se agenda un timer
(`TRIP_DURATION_MS`, default 15 min) que lo pasa a `alighted` si nadie lo
cambió de estado antes — además de la confirmación manual de descenso, que
sigue disponible vía `PATCH /boarding-signals/:id`. Si necesitas verlo pasar
rápido (para probar, no para presentar), baja la env var: `TRIP_DURATION_MS=3000`.

Ver `dashboard/index.html` para un cliente de ejemplo que consume `/routes`,
`/demand/stops` y `demand:update`.
