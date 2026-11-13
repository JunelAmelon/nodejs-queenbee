CREATE TABLE sites (
  id       TEXT PRIMARY KEY,              -- ex. SN-CASA
  name     TEXT NOT NULL,
  country  TEXT NOT NULL
);

CREATE TABLE users (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email            TEXT NOT NULL UNIQUE,
  password_hash    TEXT NOT NULL,
  role             TEXT NOT NULL
                   CHECK (role IN ('apiculteur', 'coordinateur', 'gestionnaire', 'admin')),
  site_id          TEXT REFERENCES sites(id),  -- vide pour gestionnaire et admin
  failed_attempts  INTEGER NOT NULL DEFAULT 0,
  locked_until     TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE hives (
  id          TEXT PRIMARY KEY,           -- ex. SN-CASA-014
  site_id     TEXT NOT NULL REFERENCES sites(id),
  owner_id    UUID REFERENCES users(id),
  ref_lat     DOUBLE PRECISION NOT NULL,
  ref_lon     DOUBLE PRECISION NOT NULL,
  status      TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE measures (
  hive_id                  TEXT NOT NULL REFERENCES hives(id),
  measured_at              TIMESTAMPTZ NOT NULL,
  weight_kg                NUMERIC(5,2),
  temp_internal_c          NUMERIC(4,1),
  temp_external_c          NUMERIC(4,1),
  humidity_pct             SMALLINT,
  acoustic_activity_score  NUMERIC(3,2),
  battery_pct              SMALLINT,
  lat                      DOUBLE PRECISION,
  lon                      DOUBLE PRECISION,
  PRIMARY KEY (hive_id, measured_at)
);

CREATE TABLE inspections (
  id             UUID PRIMARY KEY,        -- généré par l'application mobile
  hive_id        TEXT NOT NULL REFERENCES hives(id),
  author_id      UUID NOT NULL REFERENCES users(id),
  inspected_at   TIMESTAMPTZ NOT NULL,
  queen_present  BOOLEAN,
  colony_status  TEXT NOT NULL
                 CHECK (colony_status IN ('forte', 'normale', 'faible', 'morte')),
  observations   TEXT,
  version        INTEGER NOT NULL DEFAULT 1,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
