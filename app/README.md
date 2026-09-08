# app/ — Pasajero y conductor (Flutter)

Flutter no está instalado en esta máquina, así que esta carpeta no tiene
código todavía. Quien tenga el SDK debe correr, dentro de esta carpeta:

```
flutter create .
```

Eso genera el proyecto base (incluyendo `android/`, `ios/`, `pubspec.yaml`).
Después, implementar las pantallas de los escenarios de `CLAUDE.md`:

1. Mapa con las 2-3 rutas fijas (`GET /api/routes` del backend en `server/`)
   y selector de modo de transporte.
2. Confirmación de abordaje al tocar una parada — emite `boarding:confirm`
   por WebSocket (`socket_io_client` en pub.dev) al backend.
3. Vista de conductor: modo/pantalla separada que emite `driver:position`
   periódicamente (puede reusar la lógica de `server/src/driver-sim.ts`
   como referencia del payload esperado).

El backend ya expone:
- `GET /api/routes` — rutas y paradas fijas.
- `GET /api/demand` — conteo actual de confirmaciones por parada.
- Eventos WebSocket: `join:ruta`, `driver:position`, `vehicle:position`,
  `boarding:confirm`, `boarding:release`, `demand:update`.

Ver `server/README.md` para correrlo localmente.
