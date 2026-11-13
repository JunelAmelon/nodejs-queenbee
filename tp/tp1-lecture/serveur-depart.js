// TP 1 — Lire les mesures sans bloquer la boucle d'événements. Version de départ.
//
//   GET  /ping              déjà écrite : elle joue « l'autre utilisateur »
//   POST /import/bloquant   À ÉCRIRE : lire tout le fichier d'un coup (readFileSync)
//   POST /import/flux       À ÉCRIRE : lire le fichier ligne par ligne (createReadStream + readline)
//
// Lancement, depuis la racine du projet :
//   node tp/tp1-lecture/serveur-depart.js data/mesures-SN-CASA-2026-10-31_30j.ndjson
// Puis, dans un second terminal : node tp/tp1-lecture/sonde.js bloquant (ou flux)

import express from "express";
import { existsSync, readFileSync, createReadStream } from "node:fs";
import { createInterface } from "node:readline";

const FICHIER = process.argv[2] ?? "data/mesures-SN-CASA-2026-10-31.ndjson";

// Le chemin du fichier est relatif au dossier depuis lequel on lance la commande.
if (!existsSync(FICHIER)) {
  console.error(`Fichier introuvable : ${FICHIER}`);
  console.error("Lancez le serveur depuis la racine du projet. Pour générer le fichier de 30 jours :");
  console.error("  node scripts/generate-measures.js SN-CASA 2026-10-31 30");
  process.exit(1);
}

const app = express();

app.get("/ping", (req, res) => {
  res.json({ pong: true });
});

// POST /import/bloquant : tout le fichier est lu et analysé d'un coup.
// Pendant ce temps, la boucle d'événements est occupée : /ping attend.
app.post("/import/bloquant", (req, res) => {
  const debut = performance.now();
  const lignes = readFileSync(FICHIER, "utf8").split("\n").filter((l) => l !== "");
  let somme = 0;
  for (const ligne of lignes) {
    somme += JSON.parse(ligne).weight_kg;
  }
  res.json({
    mesures: lignes.length,
    poids_moyen_kg: Math.round((somme / lignes.length) * 100) / 100,
    duree_ms: Math.round(performance.now() - debut),
  });
});

// POST /import/flux : le fichier est lu ligne par ligne.
// Entre deux morceaux, la boucle d'événements reprend la main : /ping répond.
app.post("/import/flux", async (req, res) => {
  const debut = performance.now();
  let mesures = 0;
  let somme = 0;
  const lignes = createInterface({ input: createReadStream(FICHIER) });
  for await (const ligne of lignes) {
    if (ligne === "") continue;
    somme += JSON.parse(ligne).weight_kg;
    mesures++;
  }
  res.json({
    mesures,
    poids_moyen_kg: Math.round((somme / mesures) * 100) / 100,
    duree_ms: Math.round(performance.now() - debut),
  });
});

app.listen(4000, () => {
  console.log(`Serveur du TP 1 sur http://localhost:4000, fichier : ${FICHIER}`);
});
