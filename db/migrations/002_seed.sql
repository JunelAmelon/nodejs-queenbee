-- =====================================================================
-- Jeu de données Queen Bee (module Backend Node.js, M1 Dev)
--
-- Contenu :
--   8 sites (3 pays), 50 utilisateurs de démonstration,
--   400 ruches (50 par site, dont 2 inactives),
--   30 jours de mesures toutes les 15 min (1er au 30 octobre 2026),
--   soit environ 1,15 million de mesures, et 3 inspections par ruche active.
--
-- Le 31 octobre 2026 n'est PAS en base : c'est la journée du fichier
-- de mesures du jour 1 (data/mesures-SN-CASA-2026-10-31.ndjson).
--
-- Comptes de démonstration, tous avec le mot de passe : QueenBee2026!
--   admin@queenbee.test            administrateur
--   gestion@queenbee.test          gestionnaire
--   coord.sn-casa@queenbee.test    coordinateur du site SN-CASA (un par site)
--   api1.sn-casa@queenbee.test     apiculteur, ruches SN-CASA-001 à 010
--   ...                            api1 à api5 sur chacun des 8 sites
--
-- Les mots de passe sont hachés en bcrypt (extension pgcrypto) :
-- l'API les vérifie avec le paquet npm « bcrypt » ou « bcryptjs ».
--
-- Durée du premier démarrage : de 20 secondes à 1 minute.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Rend les valeurs aléatoires reproductibles d'une installation à l'autre
DO $$ BEGIN PERFORM setseed(0.42); END $$;

-- ---------------------------------------------------------------------
-- Données de référence des sites (coordonnées et climat), utilisées
-- uniquement pendant le chargement
-- ---------------------------------------------------------------------
CREATE TEMP TABLE site_ref (
  id          TEXT PRIMARY KEY,
  name        TEXT,
  country     TEXT,
  lat         DOUBLE PRECISION,
  lon         DOUBLE PRECISION,
  temp_base   DOUBLE PRECISION,  -- température extérieure moyenne (°C)
  temp_amp    DOUBLE PRECISION,  -- amplitude jour / nuit (°C)
  hum_base    DOUBLE PRECISION,  -- humidité moyenne (%)
  utc_offset  INTEGER            -- décalage horaire local (h)
);

INSERT INTO site_ref VALUES
  ('SN-CASA', 'Casamance - Ziguinchor',  'Sénégal',       12.5833, -16.2833, 29, 7, 55, 0),
  ('SN-SEDH', 'Casamance - Sédhiou',     'Sénégal',       12.7081, -15.5569, 29, 7, 55, 0),
  ('SN-KOLD', 'Haute-Casamance - Kolda', 'Sénégal',       12.8939, -14.9417, 30, 8, 50, 0),
  ('CI-MAN',  'Man',                     'Côte d''Ivoire', 7.4125,  -7.5539, 25, 5, 82, 0),
  ('CI-DALO', 'Daloa',                   'Côte d''Ivoire', 6.8774,  -6.4502, 26, 5, 80, 0),
  ('CI-AGBO', 'Agboville',               'Côte d''Ivoire', 5.9280,  -4.2130, 27, 5, 84, 0),
  ('CM-BAFO', 'Bafoussam',               'Cameroun',       5.4781,  10.4176, 20, 6, 72, 1),
  ('CM-DSCH', 'Dschang',                 'Cameroun',       5.4500,  10.0500, 19, 6, 75, 1);

INSERT INTO sites (id, name, country)
SELECT id, name, country FROM site_ref;

-- ---------------------------------------------------------------------
-- Utilisateurs : 1 admin, 1 gestionnaire, 8 coordinateurs, 40 apiculteurs
-- ---------------------------------------------------------------------
INSERT INTO users (email, password_hash, role, site_id) VALUES
  ('admin@queenbee.test',   crypt('QueenBee2026!', gen_salt('bf', 10)), 'admin',        NULL),
  ('gestion@queenbee.test', crypt('QueenBee2026!', gen_salt('bf', 10)), 'gestionnaire', NULL);

INSERT INTO users (email, password_hash, role, site_id)
SELECT 'coord.' || lower(s.id) || '@queenbee.test',
       crypt('QueenBee2026!', gen_salt('bf', 10)),
       'coordinateur',
       s.id
FROM site_ref s;

INSERT INTO users (email, password_hash, role, site_id)
SELECT 'api' || k || '.' || lower(s.id) || '@queenbee.test',
       crypt('QueenBee2026!', gen_salt('bf', 10)),
       'apiculteur',
       s.id
FROM site_ref s
CROSS JOIN generate_series(1, 5) AS k;

-- ---------------------------------------------------------------------
-- Ruches : 50 par site, 10 par apiculteur, disposées sur une grille
-- d'environ 2 km autour du site
-- ---------------------------------------------------------------------
INSERT INTO hives (id, site_id, owner_id, ref_lat, ref_lon, status)
SELECT s.id || '-' || lpad(n::text, 3, '0'),
       s.id,
       u.id,
       round((s.lat + (((n - 1) % 10) - 4.5) * 0.002)::numeric, 6)::double precision,
       round((s.lon + (((n - 1) / 10) - 2) * 0.002)::numeric, 6)::double precision,
       CASE WHEN s.id || '-' || lpad(n::text, 3, '0') IN ('CI-AGBO-049', 'CM-DSCH-050')
            THEN 'inactive' ELSE 'active' END
FROM site_ref s
CROSS JOIN generate_series(1, 50) AS n
JOIN users u
  ON u.email = 'api' || ((n - 1) / 10 + 1) || '.' || lower(s.id) || '@queenbee.test';

-- ---------------------------------------------------------------------
-- Mesures : une toutes les 15 minutes, du 1er au 30 octobre 2026 (UTC),
-- pour chaque ruche active. Cycle jour / nuit, légère prise de poids,
-- décharge lente de la batterie, bruit de capteur.
-- ---------------------------------------------------------------------
INSERT INTO measures (hive_id, measured_at, weight_kg, temp_internal_c, temp_external_c,
                      humidity_pct, acoustic_activity_score, battery_pct, lat, lon)
SELECT
  h.id,
  t.ts,
  round((28 + (h.n * 7) % 17 + 0.06 * t.d - 0.35 * a.shape + (random() - 0.5) * 0.15)::numeric, 2),
  round((34.6 + 0.4 * a.cyc + (random() - 0.5) * 0.4)::numeric, 1),
  round((s.temp_base + s.temp_amp * a.cyc + (random() - 0.5))::numeric, 1),
  greatest(5, least(100, round(s.hum_base - 12 * a.cyc + (random() - 0.5) * 6)))::smallint,
  greatest(0, least(1, round((a.shape + (random() - 0.5) * 0.08)::numeric, 2))),
  round(100 - (h.n * 13) % 30 - 0.25 * t.d)::smallint,
  round((h.ref_lat + (random() - 0.5) * 0.00004)::numeric, 6)::double precision,
  round((h.ref_lon + (random() - 0.5) * 0.00004)::numeric, 6)::double precision
FROM (SELECT hives.*, split_part(hives.id, '-', 3)::int AS n
      FROM hives WHERE status = 'active') AS h
JOIN site_ref s ON s.id = h.site_id
CROSS JOIN LATERAL (
  SELECT ts,
         extract(epoch FROM ts - timestamptz '2026-10-01 00:00:00+00') / 86400 AS d,
         (extract(hour FROM ts AT TIME ZONE 'UTC') + extract(minute FROM ts AT TIME ZONE 'UTC') / 60
          + s.utc_offset)::numeric % 24 AS lh
  FROM generate_series(timestamptz '2026-10-01 00:00:00+00',
                       timestamptz '2026-10-30 23:45:00+00',
                       interval '15 minutes') AS ts
) AS t
CROSS JOIN LATERAL (
  SELECT sin(2 * pi() * (t.lh::double precision - 9) / 24) AS cyc,   -- maximum vers 15 h
         CASE WHEN t.lh BETWEEN 6 AND 19
              THEN 0.15 + 0.7 * sin(pi() * (t.lh::double precision - 6) / 13)
              ELSE 0.05 END AS shape                                  -- activité de la colonie
) AS a;

-- ---------------------------------------------------------------------
-- Inspections : 3 par ruche active (vers les 4, 14 et 24 octobre),
-- saisies par l'apiculteur propriétaire, synchronisées avec 0 à 48 h
-- de retard (saisie hors connexion)
-- ---------------------------------------------------------------------
INSERT INTO inspections (id, hive_id, author_id, inspected_at, queen_present,
                         colony_status, observations, created_at, updated_at)
SELECT gen_random_uuid(),
       x.hive_id,
       x.owner_id,
       x.inspected_at,
       CASE WHEN x.colony_status = 'faible' THEN x.r2 < 0.6 ELSE x.r2 < 0.97 END,
       x.colony_status,
       CASE x.colony_status
         WHEN 'forte'   THEN (ARRAY['Cadres de couvain bien remplis', 'Forte activité au trou de vol', 'Réserves de miel abondantes'])[1 + floor(x.r3 * 3)::int]
         WHEN 'normale' THEN (ARRAY['RAS', 'Couvain régulier', 'Activité normale, quelques cellules royales à surveiller'])[1 + floor(x.r3 * 3)::int]
         ELSE                (ARRAY['Peu de couvain', 'Présence de varroas', 'Colonie agressive, réserves faibles'])[1 + floor(x.r3 * 3)::int]
       END,
       x.inspected_at + x.sync_delay,
       x.inspected_at + x.sync_delay
FROM (
  SELECT h.id AS hive_id,
         h.owner_id,
         timestamptz '2026-10-01 08:00:00+00' + (v.day - 1) * interval '1 day'
           + random() * interval '4 hours' AS inspected_at,
         CASE WHEN r.r1 < 0.35 THEN 'forte' WHEN r.r1 < 0.92 THEN 'normale' ELSE 'faible' END AS colony_status,
         r.r2, r.r3,
         random() * interval '48 hours' AS sync_delay
  FROM hives h
  CROSS JOIN (VALUES (4), (14), (24)) AS v(day)
  CROSS JOIN LATERAL (SELECT random() AS r1, random() AS r2, random() AS r3, h.id AS dep) AS r
  WHERE h.status = 'active'
) AS x;

ANALYZE;
