# Queen Bee — API

API de suivi de ruches (poids, température, humidité, inspections).

## Membres du groupe

- Khady
- Junel
- Amale

## Lancer le serveur

```bash
npm install
npm run dev          # node --watch src/server.js
# ou avec un fichier .env :
node --env-file=.env src/server.js
```

## TP 1 — Lire les mesures sans bloquer

Mesures relevées pendant un import, avec la sonde (`/ping` toutes les 10 ms) :

| Fichier  | Lecture   | Durée de l'import (ms) | Pire temps de /ping (ms) |
|----------|-----------|------------------------|--------------------------|
| 1 jour   | bloquante | 22                     | 21                       |
| 1 jour   | en flux   | 37                     | 5                        |
| 30 jours | bloquante | 518                    | 507                      |
| 30 jours | en flux   | 481                    | 23                       |

### Réponses aux questions

1. **Pourquoi `/ping` attend-il pendant l'import bloquant ?**
   `readFileSync` et les `JSON.parse` successifs s'exécutent entièrement dans le
   thread unique de Node.js : la boucle d'événements est occupée pendant tout
   l'import et ne peut traiter aucune autre requête. Les `/ping` s'empilent et
   ne sont servis qu'à la fin.

2. **La lecture en flux est-elle plus rapide ?**
   Non, elle est même parfois un peu plus lente (481 ms contre 518 ms pour
   l'import : durées proches). Son avantage est ailleurs : entre deux morceaux
   du fichier, la boucle d'événements reprend la main, donc les autres requêtes
   restent servies (pire `/ping` : 23 ms contre 507 ms). Elle consomme aussi
   beaucoup moins de mémoire, car le fichier n'est jamais chargé en entier.

3. **Pourquoi l'effet est-il presque invisible avec le fichier d'une journée ?**
   Le fichier ne fait que 4 800 lignes (~1,2 Mo) : l'import bloquant ne prend
   que ~22 ms, donc `/ping` n'attend que très peu. Le problème ne devient
   visible qu'avec un gros fichier, où le blocage dure une fraction de seconde
   voire plusieurs secondes.
