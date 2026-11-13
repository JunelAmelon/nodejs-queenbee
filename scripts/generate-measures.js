// Génère un fichier de mesures Queen Bee au format du § 6.5 du cahier des charges,
// une trame JSON par ligne (NDJSON), comme une passerelle qui renvoie ses mesures
// après une coupure : toutes les ruches actives d'un site, une mesure toutes les 15 min.
//
// Usage : node scripts/generate-measures.js [site] [date de début] [nombre de jours]
//   node scripts/generate-measures.js                          -> SN-CASA, 2026-10-31, 1 jour (4 800 lignes)
//   node scripts/generate-measures.js SN-CASA 2026-10-31 30    -> 30 jours (144 000 lignes)
//
// Les valeurs suivent les mêmes formules que db/migrations/002_seed.sql :
// les mesures prolongent donc celles de la base (qui s'arrête au 30 octobre 2026).

import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const SITES = {
  'SN-CASA': { lat: 12.5833, lon: -16.2833, tempBase: 29, tempAmp: 7, humBase: 55, utcOffset: 0 },
  'SN-SEDH': { lat: 12.7081, lon: -15.5569, tempBase: 29, tempAmp: 7, humBase: 55, utcOffset: 0 },
  'SN-KOLD': { lat: 12.8939, lon: -14.9417, tempBase: 30, tempAmp: 8, humBase: 50, utcOffset: 0 },
  'CI-MAN':  { lat: 7.4125,  lon: -7.5539,  tempBase: 25, tempAmp: 5, humBase: 82, utcOffset: 0 },
  'CI-DALO': { lat: 6.8774,  lon: -6.4502,  tempBase: 26, tempAmp: 5, humBase: 80, utcOffset: 0 },
  'CI-AGBO': { lat: 5.9280,  lon: -4.2130,  tempBase: 27, tempAmp: 5, humBase: 84, utcOffset: 0 },
  'CM-BAFO': { lat: 5.4781,  lon: 10.4176,  tempBase: 20, tempAmp: 6, humBase: 72, utcOffset: 1 },
  'CM-DSCH': { lat: 5.4500,  lon: 10.0500,  tempBase: 19, tempAmp: 6, humBase: 75, utcOffset: 1 },
};
const INACTIVE = new Set(['CI-AGBO-049', 'CM-DSCH-050']);
const SEED_START = Date.parse('2026-10-01T00:00:00Z');
const STEP_MS = 15 * 60 * 1000;

const [siteId = 'SN-CASA', startDate = '2026-10-31', daysArg = '1'] = process.argv.slice(2);
const site = SITES[siteId];
const days = Number(daysArg);
if (!site || Number.isNaN(Date.parse(startDate)) || !(days > 0)) {
  console.error(`Usage : node scripts/generate-measures.js [${Object.keys(SITES).join('|')}] [AAAA-MM-JJ] [jours]`);
  process.exit(1);
}

// Générateur pseudo-aléatoire à graine fixe : le fichier est identique à chaque exécution
let state = 42;
function random() {
  state = (state + 0x6d2b79f5) | 0;
  let t = Math.imul(state ^ (state >>> 15), 1 | state);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const round = (x, digits) => Number(x.toFixed(digits));
const clamp = (x, min, max) => Math.min(max, Math.max(min, x));

const hives = [];
for (let n = 1; n <= 50; n++) {
  const id = `${siteId}-${String(n).padStart(3, '0')}`;
  if (INACTIVE.has(id)) continue;
  hives.push({
    id,
    n,
    refLat: round(site.lat + (((n - 1) % 10) - 4.5) * 0.002, 6),
    refLon: round(site.lon + (Math.floor((n - 1) / 10) - 2) * 0.002, 6),
  });
}

const start = Date.parse(`${startDate}T00:00:00Z`);
const end = start + days * 24 * 60 * 60 * 1000;
const lines = [];

for (let ts = start; ts < end; ts += STEP_MS) {
  const date = new Date(ts);
  const d = (ts - SEED_START) / 86_400_000;
  const lh = (date.getUTCHours() + date.getUTCMinutes() / 60 + site.utcOffset) % 24;
  const cyc = Math.sin((2 * Math.PI * (lh - 9)) / 24);                               // maximum vers 15 h
  const shape = lh >= 6 && lh <= 19 ? 0.15 + 0.7 * Math.sin((Math.PI * (lh - 6)) / 13) : 0.05; // activité

  for (const h of hives) {
    lines.push(JSON.stringify({
      hive_id: h.id,
      site_id: siteId,
      timestamp: date.toISOString().replace('.000Z', 'Z'),
      position_lat: round(h.refLat + (random() - 0.5) * 0.00004, 6),
      position_lon: round(h.refLon + (random() - 0.5) * 0.00004, 6),
      weight_kg: round(28 + ((h.n * 7) % 17) + 0.06 * d - 0.35 * shape + (random() - 0.5) * 0.15, 2),
      temp_internal_c: round(34.6 + 0.4 * cyc + (random() - 0.5) * 0.4, 1),
      temp_external_c: round(site.tempBase + site.tempAmp * cyc + (random() - 0.5), 1),
      humidity_pct: clamp(Math.round(site.humBase - 12 * cyc + (random() - 0.5) * 6), 5, 100),
      acoustic_activity_score: round(clamp(shape + (random() - 0.5) * 0.08, 0, 1), 2),
      battery_pct: Math.round(100 - ((h.n * 13) % 30) - 0.25 * d),
    }));
  }
}

const dir = join(import.meta.dirname, '..', 'data');
mkdirSync(dir, { recursive: true });
const suffix = days === 1 ? startDate : `${startDate}_${days}j`;
const file = join(dir, `mesures-${siteId}-${suffix}.ndjson`);
writeFileSync(file, lines.join('\n') + '\n');
console.log(`${lines.length} mesures écrites dans ${file}`);
