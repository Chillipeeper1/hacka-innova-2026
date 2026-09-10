# server/ — Backend del mockup MaaS Morelia

```
npm install
npm run dev          # levanta el servidor en http://localhost:3001
npm run simulate      # en otra terminal: teletransporta la unidad parada a parada cada 3s (rápido para probar el evento)
npm run demo-drive    # alternativa para presentar: recorrido continuo a velocidad comprimida (SPEED_KMH=600), con parada real en cada stop (DWELL_MS=5000, ventana para pagar)
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
| GET | `/stops/:id/eta` (Escenario 2) | — | `{ stop_id, route_id, vehicle_id, distance_km, eta_minutes }`; ambos `null` si el vehículo de esa ruta aún no emitió ninguna posición. ETA = distancia en línea recta / `DEMO_VEHICLE_SPEED_KMH` (`lib/speeds.ts`), la velocidad del conductor simulado — no la del modo, para que el número cuadre con la unidad que se ve avanzar |
| POST | `/card-taps` (Escenario 6) | `{ card_uid, vehicle_id, tapped_at?, boarding_signal_id? }` | Sin `boarding_signal_id`: crea una señal nueva sin parada, directo en `boarded`. Con `boarding_signal_id`: reutiliza esa señal (ya declarada en una parada) y la marca `boarded` — así el conteo de demanda baja correctamente en vez de quedar como `expired` |
| POST | `/trips/:id/rating` (Escenario 7) | `{ rating, comment? }` | `:id` es el `boarding_signal_id` que llegó a `boarded` — el contrato no define un recurso `/trips` separado, ver nota en `schema.sql` |
| POST | `/incidents` (Escenario 7) | `{ user_id, route_id, category, description? }` | — |
| GET | `/journeys` (Escenario 8) | query: `origin_lat, origin_lng, destination_lat, destination_lng, modes?` | Recomendación de ruta con transbordos, hasta 3 alternativas — ver detalle abajo |

### Trazado por calles (`geometry`, `shape`, `/walk-path`)

Cada `leg` puede traer `geometry`: la polilinea real por calles, como pares
`[lat, lng]`. La anade `src/lib/roadGeometry.ts` **despues** de planear,
pidiendosela a OSRM (`OSRM_URL`, por omision `https://router.project-osrm.org`).

Separacion deliberada: elegir que tomar y dibujar por donde va son dos
preguntas distintas. El motor sigue decidiendo con haversine — hacerlo con
ruteo real seria una peticion por cada par de paradas del grafo — y esto
solo traza el viaje ya decidido: unos pocos tramos, una peticion por tramo,
cacheadas en memoria. Por eso `distance_km` y `eta_minutes` **no** miden la
polilinea: son la linea recta a velocidad fija con la que se eligio.

- Los tramos de transporte van con las paradas intermedias de su ruta como
  waypoints, para que la linea pase por donde la unidad para de verdad y no
  por el atajo mas corto entre las dos puntas.
- El teleferico no lleva trazado: va por el aire, y ahi la recta es correcta.
  Los tramos de longitud cero (conexiones origen-parada) tampoco.
- Si OSRM no contesta, los tramos salen sin `geometry` y el cliente dibuja la
  recta de siempre. Tras un fallo se deja de insistir 60 s (`BACKOFF_MS`), asi
  una demo sin internet no paga el timeout en cada tramo de cada peticion.

Las otras dos superficies donde se dibuja una ruta usan el mismo motor:

- `GET /routes` anade `shape` a cada ruta: su trazado completo por calles,
  pasando por todas sus paradas. Es lo que dibujan las pantallas del viaje en
  camion, que antes unian paradas con rectas. Se precalienta al arrancar
  (`warmRouteShapes`), de una peticion en una, porque el servidor publico
  limita rafagas y un fallo cortaba el trazado de todas las rutas a la vez.
- `GET /walk-path?from_lat&from_lng&to_lat&to_lng&via?` da un trazado a pie por
  calles. `via` son puntos intermedios (`lat,lng` separados por `;`) por los
  que el camino tiene que pasar: los vertices de un rodeo que ya esquiva una
  zona marcada, los extremos de una ciclovia. Sin ellos, ajustar a calles
  deshace el desvio que el cliente costo calcular. Devuelve `{ "path": [] }`
  cuando no hay trazado, nunca un error. Lo usan el tramo a pie hasta la parada
  (flujo de camion) y los modos de bici y caminata, que trazan en el cliente.

El servidor publico de OSRM **solo tiene el perfil de coche** — responde lo
mismo a `foot`, `bike` y `driving`—, asi que los tramos a pie y en bici
siguen calles de coche. Con un OSRM propio y perfiles reales, basta apuntar
`OSRM_URL` a el.

### `GET /journeys` — filtro de modos y alternativas

`modes` (opcional, coma-separado): lista de modos **permitidos** —
`bike`, `combi`, `bus`, `teleferico` (ver `KNOWN_JOURNEY_MODES` en
`journeyPlanner.ts`). Caminar siempre está disponible, no se puede excluir
— es la conexión mínima, no una elección real. Un valor desconocido → 400.

- **Sin `modes`**: la respuesta trae hasta 3 alternativas etiquetadas —
  `"Más rápida"` (todos los modos), `"Sin bicicleta"` y
  `"Con menos transbordos"` (penalización de transbordo elevada a 15 min) —
  descartando cualquiera que resulte idéntica a otra ya incluida.
- **Con `modes`**: respeta esa elección tal cual y devuelve una sola
  alternativa (`"Tu selección"`), sin generar variantes derivadas — el
  cliente ya decidió la restricción. Además **garantiza que el viaje use al
  menos uno de los modos pedidos**: quien declara "acepto combi" está
  preguntando cómo llegar en combi, y devolverle la caminata completa porque
  sale antes no responde esa pregunta — y no genera ninguna señal de
  abordaje, que es el punto del proyecto. Única excepción: si con lo pedido
  no existe ningún viaje posible (p. ej. `modes=bike` a 9 km, fuera de
  `MAX_BIKE_DISTANCE_KM`), se cae al camino más rápido en vez de contestar
  "no hay viaje". Implementación: Dijkstra sobre el grafo duplicado en dos
  capas — "aún no aborda" y "ya abordó"—, donde una arista de un modo pedido
  sube de capa y el destino solo cuenta en la segunda; así el resultado es el
  **mejor de los viajes que sí abordan**, no el mejor a secas descartado
  después.

  Efecto secundario a tener presente: en trayectos muy cortos el viaje
  forzado puede salir peor que caminar (destino a 150 m → aborda, se pasa y
  regresa a pie). Es deliberado; si molesta en la demo, la salida sería
  devolver también una alternativa `"Caminando"` cuando gane por mucho.

```json
{
  "alternatives": [
    {
      "label": "Más rápida",
      "legs": [
        { "mode": "bike", "route_id": null, "route_name": null,
          "from": { "stop_id": null, "name": null, "lat": 19.7008, "lng": -101.1844 },
          "to":   { "stop_id": null, "name": null, "lat": 19.687, "lng": -101.162 },
          "distance_km": 2.803, "eta_minutes": 11.2 }
      ],
      "total_distance_km": 2.803,
      "total_eta_minutes": 11.2
    },
    {
      "label": "Sin bicicleta",
      "legs": [
        { "mode": "walk", "...": "..." },
        { "mode": "bus", "route_id": 2, "route_name": "Ruta Centro - Bosque", "...": "..." },
        { "mode": "walk", "...": "transbordo, 3 min de penalización" },
        { "mode": "teleferico", "route_id": 3, "route_name": "Teleférico Bosque - Central", "...": "..." }
      ],
      "total_distance_km": 2.929,
      "total_eta_minutes": 19.1
    }
  ]
}
```

Motor en `server/src/lib/journeyPlanner.ts`: Dijkstra sobre un grafo completo
(origen, destino y cada parada), con aristas de caminata (`WALK_SPEED_KMH`,
4.5 km/h) y de bici (`BIKE_SPEED_KMH`, 15 km/h, línea recta — no replica el
trazado de ciclovías de `app/lib/data/bike_network.dart`) entre origen,
destino y cada parada; de viaje por ruta (velocidad según `speedForMode`,
más 3 min de espera de abordaje); y de transbordo a pie entre paradas de
rutas distintas (caminata + 3 min de penalización, o 15 min en la
alternativa "Con menos transbordos"). Siempre devuelve al menos una
alternativa — el peor caso es caminar todo el trayecto directo, así que
nunca hay "sin ruta posible".

**Límite de distancia para bici** (`MAX_BIKE_DISTANCE_KM = 6`): más allá,
bici deja de ofrecerse — sin este límite, como combi/bus comparten la
misma velocidad que la bici pero cargan espera de abordaje, la bici nunca
perdería sin importar la distancia (ver hallazgo abajo). El límite se
valida sobre la bici **total** de cada alternativa, no por tramo: el motor
prueba primero con bici disponible y, si el camino más corto encadena dos
tramos de bici que juntos superan el límite (relevando a través de una
parada usada solo como punto de paso), recalcula esa alternativa sin bici
en vez de dejar pasar el relevo.

**Hallazgo real, no un bug**: con distancias cortas (< 6 km, como el
clúster céntrico del seed), la bici gana casi cualquier comparación contra
transporte colectivo con transbordo — los tiempos fijos de espera/transbordo
(3 min cada uno) pesan mucho sobre trayectos tan cortos, y combi/bus ni
siquiera tienen ventaja de velocidad sobre la bici (comparten 15 km/h). El
motor no está sesgado a favor del transporte colectivo: recomienda lo que
de verdad es más rápido. La ruta larga del seed (`Ruta Salida a Charo`,
~9 km, id 4) sirve para demostrar el caso donde el transbordo sí compite —
ahí la bici queda fuera por el límite de distancia.

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
