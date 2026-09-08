# CLAUDE.md — Movilidad como Servicio (MaaS) Morelia

## Contexto del proyecto

Plataforma de Movilidad como Servicio (MaaS) para la Zona Metropolitana de Morelia: una app que integra caminata, ciclovía, transporte colectivo (combis/camiones) y, a futuro, teleférico, en una sola experiencia de ruteo multimodal. El diferenciador central: en vez de depender únicamente de GPS oficial en las unidades (hoy parcial), genera una señal de demanda a partir de la intención declarada del propio pasajero ("¿vas a abordar aquí?") y, donde exista, de la tarjeta de movilidad del Morebús/teleférico (el mismo sistema al que las combis se están sumando voluntariamente) — y la agrega en un panel institucional que le sirve al gobierno para decidir dónde se necesitan más o menos unidades.

## Alcance de esta fase: MOCKUP FUNCIONAL, no producción

Este repositorio **no** busca construir el sistema completo (arquitectura con AWS IoT Core, OpenTripPlanner, Aurora Serverless v2, detección de modo por sensores/TensorFlow Lite, etc.). El objetivo de esta fase es un **mockup funcional de los casos de uso clave**, para que el equipo entienda y pueda mostrar cómo se sentiría usar el sistema real — con datos y flujos simulados donde haga falta, priorizando velocidad de desarrollo sobre robustez de producción.

Cuando en este documento se dice "simulado" o "mock": no conectar a un servicio real, usar datos fijos o una implementación mínima que demuestre el comportamiento sin la infraestructura completa. Ante la duda entre "hacerlo bien" y "hacerlo simple", elige simple — siempre se puede avisar en el PR o commit qué se dejó simplificado.

## Escenarios que el mockup debe demostrar

1. **Pasajero ve el mapa y elige modo de transporte** — mapa con rutas fijas (coordenadas reales de Morelia) para caminata, ciclovía, combi/bus **y teleférico** (ya con datos reales en el seed, no solo mencionado), una unidad "en vivo" moviéndose sobre la ruta.
2. **Confirmación de abordaje (el diferenciador del proyecto)** — al tocar una parada en el mapa (sin geofencing real todavía), el pasajero ve el ETA y confirma "voy a abordar" / "solo paso". Esto debe incrementar un contador de demanda visible en el panel institucional.
3. **Conductor simulado moviéndose** — un segundo cliente o script que emite posiciones a lo largo de una ruta fija, para que el pasajero vea la unidad acercarse en tiempo real (WebSocket).
4. **Panel institucional con datos agregados** — vista web separada mostrando el conteo de confirmaciones de abordaje por parada, actualizándose en vivo — la demostración del valor para el gobierno.
5. *(Opcional, si alcanza el tiempo)* Detección de descenso — liberar el estado de "abordado" cuando el pasajero confirma que bajó, o tras un tiempo simulado.
6. *(Opcional, si alcanza el tiempo)* Tap de tarjeta de movilidad simulado — un botón o endpoint que emite un evento falso de "tap" con un `card_uid` ya vinculado a un usuario demo, confirmando el abordaje automáticamente (salta directo a "abordado", sin pasar por "voy a abordar"). Demuestra el mecanismo aunque la integración real con Sedum no exista todavía — ver la nota en "Qué NO construir".
7. *(Opcional, si alcanza el tiempo)* Calificación de conductor y reporte de incidencias al final del viaje — pantalla simple de 1 a 5 estrellas y un botón de "reportar incidencia" con categoría y comentario libre. Para el mockup, basta con atribuir la unidad directamente (ya se conoce desde el Escenario 3) — no hace falta resolverla por proximidad.
8. **Recomendación de ruta con transbordos** — dado un origen y un destino, el backend calcula hasta 3 alternativas de tramos (caminar, bici en línea recta, combi/bus/teleférico, con transbordos) — no solo la mejor opción de una sola ruta. El cliente puede restringir qué modos se permiten (ej. "solo bus y caminata"); sin restricción, el backend ya ofrece variantes ("más rápida", "sin bicicleta", "con menos transbordos"). Regla simple: Dijkstra sobre un grafo de paradas con velocidad fija por modo y penalizaciones fijas de espera/transbordo — sin motor de ruteo real, ver `GET /journeys` en el contrato. Bici tiene un límite de distancia razonable (6 km); más allá, o con distancias cortas del seed sin ese límite, gana casi siempre contra transporte colectivo con transbordo — es el resultado correcto, no un sesgo del motor (ver nota en `server/README.md`).

No construyas nada fuera de estos escenarios sin preguntar primero — es fácil derivar hacia "hacerlo completo" y perder el punto del mockup.

## Stack para este mockup (simplificado a propósito)

| Componente | Para este mockup | NO usar todavía (es la versión de producción) |
|---|---|---|
| App móvil | Flutter | — |
| Mapas | `flutter_map` con tiles de OpenStreetMap, o Google Maps Flutter plugin con API key gratuita | MapLibre + tiles propios auto-hospedados |
| Backend | Node.js + TypeScript, Express o Fastify, con `socket.io` para posiciones en vivo | NestJS completo, AWS IoT Core, MQTT |
| Base de datos | PostgreSQL local vía Docker, o incluso SQLite | Aurora Serverless v2, PostGIS completo |
| Rutas / ruteo | 2-3 rutas fijas capturadas a mano (array de coordenadas), sin motor de ruteo real | OpenTripPlanner, OSRM |
| Detección de modo de transporte | Confirmación manual del usuario (botón) | HAR con TensorFlow Lite, sensores |
| Panel institucional | Página web simple (React, o incluso HTML+JS) leyendo del mismo backend | Panel con autenticación institucional completa |
| Infraestructura | Todo corre local, `docker compose up` | AWS completo |

## Contrato de API y eventos (para consistencia entre app y servidor)

### REST
- `GET /routes` — lista de rutas con sus paradas (`id, name, mode, color_hex, stops: [{id, name, lat, lng, sequence}]`)
- `POST /users` — crea un usuario demo (`name, role`)
- `POST /boarding-signals` — confirma intención (`user_id, stop_id, route_id, intent`, y opcionalmente `destination_stop_id, destination_lat, destination_lng` — destino declarado por el pasajero antes de abordar) → crea el registro en estado `waiting`
- `PATCH /boarding-signals/:id` — actualiza estado (`status: 'boarded' | 'alighted' | 'expired'`)
- `GET /demand/stops` — conteo agregado de `waiting` por parada, para el panel institucional
- `GET /stops/:id/eta` *(Escenario 2, agregado por el backend)* — ETA simple (`distance_km, eta_minutes`, ambos `null` si el vehículo de esa ruta aún no reportó posición); regla fija `distancia en línea recta / 15 km/h`, no sobre el trazado real de la ruta
- `POST /card-taps` *(Escenario 6)* — simula un tap (`card_uid, vehicle_id, tapped_at`, y opcionalmente `boarding_signal_id` para marcar como `boarded` una señal ya declarada en una parada, en vez de crear una nueva sin parada asociada)
- `POST /trips/:id/rating` *(Escenario 7)* — calificación (`rating 1-5, comment?`)
- `POST /incidents` *(Escenario 7)* — reporte (`user_id, route_id, category, description`)
- `GET /journeys` *(Escenario 8, agregado por el backend)* — recomendación de ruta con transbordos; query params `origin_lat, origin_lng, destination_lat, destination_lng` y opcionalmente `modes` (coma-separado: `bike,combi,bus,teleferico` — lista de modos *permitidos*; caminar siempre está disponible y no se filtra) → `{ alternatives: [...] }`. Sin `modes`, hasta 3 alternativas etiquetadas (`"Más rápida"`, `"Sin bicicleta"`, `"Con menos transbordos"`), sin duplicados; con `modes`, una sola (`"Tu selección"`) respetando esa restricción. Cada alternativa trae `legs` (cada `leg`: `mode`, `route_id/route_name` si aplica, `from/to`, `distance_km/eta_minutes`), `total_distance_km` y `total_eta_minutes`. Siempre hay al menos una alternativa (el peor caso es caminar todo el trayecto)

### WebSocket (`socket.io`)
- `vehicle:position` — el servidor emite `{vehicle_id, lat, lng, recorded_at}` cada vez que el conductor simulado avanza
- `demand:update` — el servidor emite `{stop_id, waiting_count}` cada vez que cambia una confirmación, para que el panel institucional y la app se actualicen sin refrescar

No inventes rutas ni nombres de eventos distintos a estos sin avisar — es lo que mantiene la app, el servidor y el panel hablando el mismo idioma mientras se construyen en paralelo.

## Identidad visual

La identidad vigente es la del Figma "HACKA" (marca "MTAPP"), ya implementada en `app/lib/theme.dart` — **no** la paleta teal/ámbar/navy que se usó en el pitch del jurado; se decidió conscientemente quedarse con la del proyecto en vez de rehacer la app para igualar el pitch.

- CTA principal: `#E244AE` (magenta), variante presionada `#C42890`
- Acento de titulares: `#CAFF94` (lima)
- Enlaces de acción: `#56AC00` (verde)
- Texto secundario: `#8A8A8A`
- Tipografías: Coolvetica, Nura, Satoshi y League Spartan (archivos `.ttf`/`.otf` pendientes de agregar a `app/assets/fonts/`; mientras tanto cae a la tipografía del sistema).

Si en algún momento se actualiza el pitch o material de marketing, debe alinearse a esta paleta — no al revés.

## Estructura de carpetas sugerida

```
maas-morelia-mockup/
├── app/                  # Flutter — pasajero y conductor como modo/pantalla separada
├── server/
│   └── src/
│       ├── routes/       # Endpoints REST
│       ├── sockets/      # Eventos WebSocket: posición, confirmación de abordaje
│       ├── data/         # Rutas y paradas fijas (mock, coordenadas reales de Morelia)
│       └── db/           # Esquema y acceso a Postgres/SQLite
├── dashboard/            # Panel institucional (web simple)
└── CLAUDE.md
```

## Convenciones

- TypeScript en modo estricto en el backend.
- Identificadores de código en inglés (convención estándar); textos de interfaz en español — el producto es para usuarios en Morelia.
- Commits pequeños y descriptivos. No hace falta CI/CD para este mockup.

## Qué NO construir en esta fase

- Autenticación robusta (un nombre o sesión simple basta).
- Cualquier integración de pago.
- Modelos de IA/ML entrenados — cualquier "predicción" mostrada puede ser un valor fijo o una regla simple (ej. ETA = distancia restante / velocidad promedio fija).
- Infraestructura en AWS.
- La integración real con el sistema de cobro de Sedum/Morebús (requiere un acuerdo de datos externo que hoy no existe) — el Escenario 6, si se construye, usa un evento de tap completamente simulado, nunca una conexión real.
- La inferencia de unidad por proximidad calculada en el dispositivo (solo aplica en producción cuando el mecanismo de abordaje no determina el vehículo directamente) — en el Escenario 7 el vehículo ya se conoce sin necesidad de inferirlo.

## Datos semilla

`seed-routes.json` (en `server/src/data/`) trae 4 rutas ancladas en puntos reales y conocidos de Morelia: combi (Catedral, Fuente de las Tarascas, Acueducto), bus (Catedral, Bosque Cuauhtémoc), teleférico (Bosque Cuauhtémoc — mismo punto que el bus, para que haya un transbordo real de fábrica — y Central de Autobuses), y una combi larga de salida a Charo (~9 km desde Catedral, para poder probar el motor de recomendación a distancias reales, no solo dentro del clúster céntrico). Son aproximados, no paradas/estaciones verificadas en campo ni las estaciones reales anunciadas por Sedum — ajústenlos con Google Maps/OSM o recorrido físico antes de ir más allá del mockup. El `card_uid` de ejemplo del Escenario 6 (`"DEMO-0001"`) vinculado a un usuario de prueba basta — no se necesita un formato real de tarjeta.

## Referencia

El plan completo de producto, arquitectura y modelo de negocio para la versión de producción vive en `documento-base-maas-morelia.md` (colócalo en la raíz del repo junto a este archivo). El esquema de base de datos del mockup ya está definido en `schema.sql` (colócalo en `server/src/db/`) — úsalo tal cual, no lo rediseñes desde cero. Este mockup es una versión deliberadamente reducida de la Fase 1 descrita ahí — el objetivo es iterar rápido y validar la experiencia antes de invertir en la infraestructura completa.
