# hacka-innova-2026
Hackathon innovation fest 2026 — MaaS Morelia (mockup funcional)

## Dónde empezar

- **`CLAUDE.md`** — alcance del mockup: qué escenarios hay que demostrar y qué queda fuera de esta fase.
- **`documento-base-maas-morelia.md`** — plan completo de producto/arquitectura/negocio (versión de producción, no lo que se construye aquí).
- **`server/`** — backend (Node + TypeScript + Express + socket.io + SQLite en memoria). Ver `server/README.md` para la tabla de endpoints REST, eventos WebSocket y cómo correrlo. **Ya está listo y probado** — es la base sobre la que arma el frontend.
- **`app/`** — app de pasajero/conductor (Flutter). Ver `app/README.md` — el proyecto Flutter todavía no está inicializado (`flutter create .` pendiente), pero el contrato de API contra el que debe hablar ya está definido en `server/README.md`.
- **`dashboard/index.html`** — panel institucional. Es solo una referencia de cómo consumir la API (tabla simple, sin build tools) — no es el entregable final de UI.
