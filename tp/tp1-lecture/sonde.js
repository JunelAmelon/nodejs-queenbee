// TP 1 — Sonde : mesure le pire temps de réponse de /ping pendant un import.
// Elle joue « l'autre utilisateur » : elle envoie un /ping toutes les 10 ms pendant l'import.
//
// Lancement, le serveur du TP tournant dans un autre terminal :
//   node tp/tp1-lecture/sonde.js bloquant
//   node tp/tp1-lecture/sonde.js flux

const BASE = "http://localhost:4000";
const mode = process.argv[2] ?? "bloquant";

if (mode !== "bloquant" && mode !== "flux") {
  console.error("Usage : node tp/tp1-lecture/sonde.js bloquant|flux");
  process.exit(1);
}

// Un premier /ping, non mesuré : il ouvre la connexion, ce qui le rend plus lent que les autres.
await fetch(`${BASE}/ping`);

let pire = 0;
let enCours = true;

// Pendant l'import, envoie des /ping en boucle et garde le temps de réponse le plus long.
const sonde = (async () => {
  while (enCours) {
    const debut = performance.now();
    await fetch(`${BASE}/ping`);
    pire = Math.max(pire, performance.now() - debut);
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
})();

const reponse = await fetch(`${BASE}/import/${mode}`, { method: "POST" });

// En cas d'erreur, Express renvoie une page HTML et non du JSON : on s'arrête avec un message clair.
if (reponse.status === 404) {
  console.error(`La route POST /import/${mode} n'existe pas (encore) sur le serveur.`);
  process.exit(1);
}
if (!reponse.ok) {
  console.error(`L'import a échoué (statut ${reponse.status}) : regardez le message dans le terminal du serveur.`);
  process.exit(1);
}

console.log(`Import ${mode} :`, await reponse.json());

enCours = false;
await sonde;
console.log(`Pire temps de réponse de /ping pendant l'import : ${pire.toFixed(0)} ms`);
