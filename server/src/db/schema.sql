-- Esquema del mockup MaaS Morelia. Inferido del contrato de API en CLAUDE.md
-- (no existía un schema.sql en el repo al momento de escribir este archivo).
-- Escrito en SQLite; portar a Postgres solo cambia AUTOINCREMENT/tipos, no la forma.

CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('passenger', 'driver')),
  card_uid TEXT UNIQUE -- tarjeta de movilidad vinculada (Escenario 6), opcional
);

CREATE TABLE routes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  mode TEXT NOT NULL,
  color_hex TEXT NOT NULL
);

CREATE TABLE stops (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  route_id INTEGER NOT NULL REFERENCES routes(id),
  name TEXT NOT NULL,
  lat REAL NOT NULL,
  lng REAL NOT NULL,
  sequence INTEGER NOT NULL
);

-- Una unidad simulada por ruta, para poder identificar `vehicle_id` en
-- vehicle:position y card-taps sin construir un módulo de flota real.
-- last_lat/last_lng/last_recorded_at guardan la última posición conocida,
-- necesaria para calcular ETA (GET /stops/:id/eta).
CREATE TABLE vehicles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  route_id INTEGER NOT NULL REFERENCES routes(id),
  label TEXT NOT NULL,
  last_lat REAL,
  last_lng REAL,
  last_recorded_at TEXT
);

CREATE TABLE boarding_signals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  stop_id INTEGER REFERENCES stops(id), -- NULL cuando el origen es un tap dentro del vehículo (Escenario 6)
  route_id INTEGER NOT NULL REFERENCES routes(id),
  intent TEXT NOT NULL CHECK (intent IN ('boarding', 'passing')),
  status TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'boarded', 'alighted', 'expired')),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE card_taps (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  card_uid TEXT NOT NULL,
  vehicle_id INTEGER NOT NULL REFERENCES vehicles(id),
  tapped_at TEXT NOT NULL DEFAULT (datetime('now')),
  boarding_signal_id INTEGER REFERENCES boarding_signals(id)
);

-- "Trip" para el mockup = un boarding_signal que llegó a 'boarded'; no existe
-- un recurso /trips separado en el contrato, así que /trips/:id/rating usa
-- ese mismo id (ver nota en server/README.md).
CREATE TABLE ratings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  boarding_signal_id INTEGER NOT NULL REFERENCES boarding_signals(id),
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE incidents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  route_id INTEGER NOT NULL REFERENCES routes(id),
  category TEXT NOT NULL,
  description TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
