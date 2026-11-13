# Base de données et jeu de données Queen Bee

Ce dossier fournit une base PostgreSQL prête à l'emploi pour le module Backend Node.js : le schéma (`migrations/001_schema.sql`) et un jeu de données simulé (`migrations/002_seed.sql`). Le dossier `data/` contient le fichier de mesures du jour 1, produit par `scripts/generate-measures.js`.

Les données sont **simulées** : elles ne proviennent pas de vraies ruches. Elles sont reproductibles, donc identiques sur tous les postes.

## Démarrage

```bash
cp .env.example .env          # puis renseigner un mot de passe dans .env
docker compose up -d
docker compose logs -f db     # attendre « database system is ready to accept connections », puis Ctrl + C
```

Au premier démarrage, PostgreSQL exécute les fichiers de `migrations/` dans l'ordre alphabétique. Le chargement prend de 30 secondes à 1 minute.

**Attention :** ces fichiers ne sont exécutés que si la base est vide. Après une modification du schéma ou des données, il faut tout supprimer et relancer :

```bash
docker compose down -v        # -v supprime le volume, donc toutes les données
docker compose up -d
```

Vérification :

```bash
docker compose exec db psql -U queenbee -d queenbee -c "SELECT (SELECT count(*) FROM sites) AS sites, (SELECT count(*) FROM users) AS users, (SELECT count(*) FROM hives) AS hives, (SELECT count(*) FROM measures) AS measures, (SELECT count(*) FROM inspections) AS inspections;"
```

Résultat attendu : 8 sites, 50 utilisateurs, 400 ruches, 1 146 240 mesures, 1 194 inspections.

## Contenu du jeu de données

### Sites

| Identifiant | Nom | Pays |
| --- | --- | --- |
| `SN-CASA` | Casamance - Ziguinchor | Sénégal |
| `SN-SEDH` | Casamance - Sédhiou | Sénégal |
| `SN-KOLD` | Haute-Casamance - Kolda | Sénégal |
| `CI-MAN` | Man | Côte d'Ivoire |
| `CI-DALO` | Daloa | Côte d'Ivoire |
| `CI-AGBO` | Agboville | Côte d'Ivoire |
| `CM-BAFO` | Bafoussam | Cameroun |
| `CM-DSCH` | Dschang | Cameroun |

### Comptes de démonstration

Tous les comptes ont le mot de passe `QueenBee2026!`. Ce sont des comptes de test, à ne jamais réutiliser ailleurs.

| Adresse | Rôle | Périmètre |
| --- | --- | --- |
| `admin@queenbee.test` | admin | Tout |
| `gestion@queenbee.test` | gestionnaire | Tous les sites |
| `coord.sn-casa@queenbee.test` | coordinateur | Le site `SN-CASA` (un coordinateur par site, même schéma d'adresse) |
| `api1.sn-casa@queenbee.test` à `api5.sn-casa@queenbee.test` | apiculteur | Ses 10 ruches (cinq apiculteurs par site) |

Les mots de passe sont hachés en bcrypt (coût 10). L'API les vérifie avec le paquet npm `bcrypt` ou `bcryptjs`.

### Ruches

50 ruches par site, soit 400 au total, numérotées de `001` à `050` (par exemple `SN-CASA-014`). Chaque apiculteur en possède 10 : `api1` les ruches 001 à 010, `api2` les ruches 011 à 020, et ainsi de suite. Deux ruches sont inactives et n'ont ni mesures ni inspections : `CI-AGBO-049` et `CM-DSCH-050`.

### Mesures

Une mesure toutes les 15 minutes pour chaque ruche active, du 1er octobre 2026 à 0 h au 30 octobre 2026 à 23 h 45 (UTC) : 398 ruches × 30 jours × 96 mesures par jour = 1 146 240 mesures.

Le **31 octobre 2026 n'est volontairement pas en base** : c'est la journée du fichier `data/mesures-SN-CASA-2026-10-31.ndjson`, que l'API doit insérer elle-même.

### Inspections

Trois inspections par ruche active, vers le 4, le 14 et le 24 octobre, saisies par l'apiculteur propriétaire. Environ 35 % de colonies « forte », 57 % « normale » et 8 % « faible ». Le champ `created_at` est postérieur de 0 à 48 h à `inspected_at` : l'inspection a été saisie hors connexion, puis synchronisée plus tard.

## Dictionnaire de données

### `sites`

| Colonne | Type | Description |
| --- | --- | --- |
| `id` | TEXT, clé primaire | Code du site : pays et lieu, par exemple `SN-CASA` |
| `name` | TEXT | Nom du site |
| `country` | TEXT | Pays |

### `users`

| Colonne | Type | Description |
| --- | --- | --- |
| `id` | UUID, clé primaire | Généré par la base |
| `email` | TEXT, unique | Identifiant de connexion |
| `password_hash` | TEXT | Empreinte bcrypt, jamais le mot de passe en clair |
| `role` | TEXT | `apiculteur`, `coordinateur`, `gestionnaire` ou `admin` |
| `site_id` | TEXT, vers `sites` | Site de rattachement ; vide pour gestionnaire et admin, qui voient tous les sites |
| `failed_attempts` | INTEGER | Nombre d'échecs de connexion consécutifs |
| `locked_until` | TIMESTAMPTZ | Fin du blocage du compte après 5 échecs (UC-T01) ; vide si le compte n'est pas bloqué |
| `created_at` | TIMESTAMPTZ | Date de création |

### `hives`

| Colonne | Type | Description |
| --- | --- | --- |
| `id` | TEXT, clé primaire | Code du site suivi d'un numéro, par exemple `SN-CASA-014` |
| `site_id` | TEXT, vers `sites` | Site de la ruche |
| `owner_id` | UUID, vers `users` | Apiculteur propriétaire |
| `ref_lat`, `ref_lon` | DOUBLE PRECISION | Position GPS de référence |
| `status` | TEXT | `active` ou `inactive` |
| `created_at` | TIMESTAMPTZ | Date de création |

### `measures`

| Colonne | Type | Description |
| --- | --- | --- |
| `hive_id` | TEXT, vers `hives` | Ruche mesurée |
| `measured_at` | TIMESTAMPTZ | Instant de la mesure |
| `weight_kg` | NUMERIC(5,2) | Poids de la ruche (kg) |
| `temp_internal_c` | NUMERIC(4,1) | Température du couvain (°C) |
| `temp_external_c` | NUMERIC(4,1) | Température extérieure (°C) |
| `humidity_pct` | SMALLINT | Humidité (%) |
| `acoustic_activity_score` | NUMERIC(3,2) | Activité de la colonie, de 0 à 1 |
| `battery_pct` | SMALLINT | Charge de la batterie du capteur (%) |
| `lat`, `lon` | DOUBLE PRECISION | Position GPS transmise avec la mesure |

Clé primaire : (`hive_id`, `measured_at`).

### `inspections`

| Colonne | Type | Description |
| --- | --- | --- |
| `id` | UUID, clé primaire | Généré par l'application mobile, sans valeur par défaut en base |
| `hive_id` | TEXT, vers `hives` | Ruche inspectée |
| `author_id` | UUID, vers `users` | Auteur de l'inspection |
| `inspected_at` | TIMESTAMPTZ | Moment de l'inspection sur le terrain |
| `queen_present` | BOOLEAN | Présence de la reine observée |
| `colony_status` | TEXT | `forte`, `normale`, `faible` ou `morte` |
| `observations` | TEXT | Notes libres |
| `version` | INTEGER | Incrémenté à chaque modification, pour détecter les conflits |
| `created_at` | TIMESTAMPTZ | Arrivée sur le serveur (synchronisation) |
| `updated_at` | TIMESTAMPTZ | Dernière modification sur le serveur |

## Choix de conception

- **La clé des mesures est (`hive_id`, `measured_at`)** plutôt qu'un identifiant auto-incrémenté. Après une coupure, une passerelle peut renvoyer des mesures déjà reçues : avec cette clé, la base refuse elle-même les doublons (`INSERT … ON CONFLICT DO NOTHING`). Elle sert aussi à lire l'historique d'une ruche par date.
- **L'identifiant d'une inspection est un UUID généré par l'application mobile.** L'apiculteur crée l'inspection sans réseau : l'application a besoin d'un identifiant immédiatement. Si la synchronisation est rejouée, le serveur reconnaît l'inspection déjà reçue au lieu de créer un doublon.
- **Le champ `version`** permet de détecter deux modifications concurrentes de la même inspection (UC-A01).
- **Le contrôle d'accès repose sur trois champs** : `users.role` (le type d'utilisateur), `users.site_id` comparé à `hives.site_id` (le coordinateur ne voit que son site) et `hives.owner_id` (l'apiculteur ne voit que ses ruches).
- **Chaque mesure contient une position**, en plus de la position de référence de la ruche, pour détecter un déplacement anormal comme un vol (UC-CY04). Le calcul géospatial relève de la spécialité Data.
- **Des contraintes `CHECK`** limitent les rôles, les statuts de ruche et les états de colonie à une liste fermée.
- **Le modèle est volontairement minimal.** Coopératives, récoltes, alertes, capteurs et photos (§ 7.1 du cahier des charges) ne sont pas représentés : ils relèvent de la conception de chaque groupe.

## Fichiers de mesures

`data/mesures-SN-CASA-2026-10-31.ndjson` contient 4 800 mesures : les 50 ruches du site `SN-CASA`, toutes les 15 minutes, pendant la journée du 31 octobre 2026. C'est ce qu'une passerelle renvoie après une journée de coupure (§ 6.4 et 8.1 du cahier des charges).

Le format est **NDJSON** : une trame JSON par ligne, au format du § 6.5.

```json
{"hive_id":"SN-CASA-001","site_id":"SN-CASA","timestamp":"2026-10-31T00:00:00Z","position_lat":12.574304,"position_lon":-16.287302,"weight_kg":36.84,"temp_internal_c":34.4,"temp_external_c":23.7,"humidity_pct":64,"acoustic_activity_score":0.03,"battery_pct":80}
```

Ce format se lit ligne par ligne, sans charger tout le fichier en mémoire : c'est ce qui permet de le traiter en flux.

Pour générer d'autres fichiers :

```bash
node scripts/generate-measures.js                          # SN-CASA, 31 octobre, 1 jour (4 800 lignes)
node scripts/generate-measures.js CI-MAN 2026-10-31 1      # un autre site
node scripts/generate-measures.js SN-CASA 2026-10-31 30    # 30 jours (144 000 lignes, environ 37 Mo)
```

Les fichiers de plusieurs jours sont lourds et se régénèrent à volonté : ils sont exclus du dépôt (`data/*_30j.ndjson` dans `.gitignore`).

## Comment les données sont simulées

Le script SQL et le script JavaScript appliquent les mêmes formules : les fichiers générés prolongent donc les mesures de la base. Les valeurs aléatoires utilisent une graine fixe, ce qui rend le résultat identique à chaque génération.

Notations : `h` est l'heure locale du site (de 0 à 24), `d` le nombre de jours écoulés depuis le 1er octobre 2026, `n` le numéro de la ruche (1 à 50).

| Valeur | Ce qui est simulé |
| --- | --- |
| Cycle jour / nuit | `sin(2π(h − 9) / 24)` varie de −1 à 1 : maximum vers 15 h, minimum vers 3 h |
| Activité de la colonie | Entre 6 h et 19 h, une courbe en cloche de 0,15 à 0,85 avec un pic vers 12 h 30 ; la nuit, 0,05 |
| Poids | Un poids de départ propre à chaque ruche (28 à 44 kg), une prise de 60 g par jour, une baisse en journée quand les butineuses sortent, un bruit de ± 75 g |
| Température intérieure | Autour de 34,6 °C, car les abeilles régulent le couvain entre 34 et 35 °C (§ 5.3) |
| Température extérieure | La température moyenne du site, plus ou moins l'amplitude jour / nuit de son climat |
| Humidité | L'humidité moyenne du site, plus élevée la nuit |
| Score acoustique | L'activité de la colonie, avec un léger bruit |
| Batterie | Une charge de départ entre 71 et 100 %, qui perd 0,25 point par jour |
| Position | La position de référence, avec un bruit d'environ 2 m (précision GPS) |

Les données ne contiennent **aucune anomalie** : ni essaimage, ni chute de poids brutale, ni vol de ruche. Leur simulation relève du simulateur du projet Queen Bee (§ 6.6 du cahier des charges), et leur détection des spécialités Data et Cyber.
