# Projet Queen Bee — API v0 (Jour 1)

Ce dépôt contient l'API v0 du projet **Queen Bee**, développée sous Node.js et Express, permettant la gestion de ruches, de mesures de capteurs et d'inspections terrain, organisée en architecture en couches.

## Équipe et répartition des tâches

Travail réalisé en groupe :
* **Junel** — **TP 1** : Expérimentation sur la boucle d'événements Node.js (comparaison lecture bloquante vs lecture en flux).
* **Jennifer** — **TP 2** : Mise en place des premières routes HTTP en mémoire, journalisation des requêtes et création de la collection de tests.
* **Amale** — **TP 3** : Rédaction du contrat d'API (`docs/api.md`), implémentation des routes de mesures/inspections et standardisation des erreurs au format RFC 9457.
* **Khady** — **TP 4** : Refactorisation en architecture en couches (Routeur, Contrôleurs, Services, Repositories), validation des plages physiques et tests unitaires (`node:test`).

---

## Installation et démarrage

### 1. Prérequis et base de données
1. Copier `.env.example` en `.env` et renseigner le mot de passe de la base.
2. Démarrer PostgreSQL avec Docker :
   ```bash
   docker compose up -d
   ```

### 2. Lancer l'API v0
1. Installer les dépendances :
   ```bash
   npm install
   ```
2. Démarrer le serveur en mode développement :
   ```bash
   npm run dev
   ```
3. Lancer les tests unitaires :
   ```bash
   npm test
   ```

---


## TP 1 Lire les mesures sans bloquer

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

### TP 2 — Premières routes en mémoire (Jennifer)
* **Routes implémentées :**
  * `GET /health` : vérification de l'état du serveur (`200 OK`).
  * `GET /api/hives` : récupération de la liste des ruches avec support du filtre optionnel `?site_id=`.
  * `GET /api/hives/:id` : récupération d'une ruche par identifiant (`200` ou `404`).
  * `POST /api/hives/:id/measures` : ajout d'une mesure de capteur en mémoire en conservant son `timestamp` d'origine (`201 Created`, `400` ou `404`).
* **Journalisation & Tests :** Configuration du middleware de logs HTTP (`morgan`) et création/export de la collection Postman couvrant les cas nominaux et les cas d'erreur.

---

### TP 3 — Contrat d’API et gestion des erreurs (Amale)

---

### TP 4 — Architecture en couches et tests unitaires (Khady)


## Livrables et architecture du projet

* **`docs/api.md`** : Contrat détaillé des routes HTTP (paramètres, corps attendus, codes de statut et exemples RFC 9457).
* **`docs/`** : Collection de requêtes Postman/Bruno exportée couvrant les cas nominaux et les cas d'erreur.
* **`src/`** : Code source de l'API organisé en couches strictes (`routes/`, `controllers/`, `services/`, `repositories/memory/`, `middlewares/`, `utils/`).
* **`test/`** : Suite de tests unitaires vérifiant les règles métier et les plages physiques des capteurs.
```

