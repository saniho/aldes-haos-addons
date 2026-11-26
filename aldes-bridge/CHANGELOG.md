# Changelog

Toutes les versions notables de Aldes Bridge Add-on.

Format basé sur [Keep a Changelog](https://keepachangelog.com/).

## [0.22.0] — 2026-11-26

Stable de [0.22.0-beta1](../aldes-bridge-beta/CHANGELOG.md) : support des VMC double flux et pilotage de l'UI par le profil device.

### Ajouté
- **Profil VMC InspirAIR Home S** (`profiles/inspirair-home-s.yaml`, `type: vmc`) : pour un profil de type `vmc`, la discovery HA publie un select « Mode » (Daily / Holidays / Guest / Boost / Air Prog, codes `changeMode` V→Z) et les sensors du profil, à la place des entités climate / water_heater du T.ONE. Les champs bruts non documentés sont exposés en `entity_category: diagnostic` ; les unités des sensors sont déduites des valeurs observées (PR #63).
- **Mode Holidays (W)** : envoie la fenêtre UTC attendue par la machine (`ha_discovery.holiday_duration_hours`, 24 h par défaut) — sans elle, la machine ignore la commande.
- `AGENTS.md` décrit maintenant l'équipement selon le `type` du profil (`pac` ou `vmc`).
- **Modes rapides pilotés par le profil** : les boutons rapides du panneau « infos aldes » sont générés depuis `ui.quick_modes` (`field` + `label`) au lieu d'être codés en dur — la VMC affiche un groupe « Ventilation », la PAC conserve Climatisation / Chauffage / ECS. Les sections « Temp. principale » et « Eau chaude (ECS) » respectent `ui.show_thermostats` et `ui.show_hot_water`.
- **Tableau de bord adapté au profil** : les sections Extérieur, Présence et Eau chaude respectent `ui.show_people` / `ui.show_hot_water`, la section « Capteurs » liste les capteurs non-diagnostic du profil (`ha_discovery.entities.sensors`) avec leurs valeurs (`—` si absentes), et la tuile « Compresseur » n'apparaît que si `health.mfac` existe. Les libellés de modes viennent du profil.
- **Onglet santé utile en VMC** : `health.cards` dans le profil génère des cartes génériques dont les libellés et unités sont lus dans `ha_discovery.entities.sensors` — InspirAIR Home S déclare « Qualité d'air » (CO2, PM2.5, COV) et « État de l'installation » (compteur filtre, RSSI). Sans `health.cards`, le rendu PAC historique est conservé. `health_keys` pilote l'extraction des clés de santé : déclaré vide pour la VMC, il empêche des valeurs PAC persistées (`mfac`, `defr`…) de survivre à un changement de profil, y compris après redémarrage.
- **Tests e2e du profil VMC** : scénarios Playwright couvrant le basculement tone ↔ VMC, les modes rapides et l'onglet santé (`web/e2e/features/profil-vmc.feature`).

### Corrigé
- **Dry-run ignoré à l'exécution** : `state.config` (défaut `ha_mqtt_dry_run: False`) écrasait le dry-run résolu au démarrage — les commandes HA partaient vers la box même avec `HA_MQTT_DRY_RUN=true`. Le client lit désormais `self.dry_run`, que le toggle des réglages met à jour.
- **Topic de commande HA** : les commandes partaient sur `devices/aldes_bridge/messages/devicebound` au lieu du `client_id` de la box connectée (`devices/<client_id>/...`).
- **Profil par défaut** : il dépendait de l'ordre alphabétique des fichiers — ajouter un profil changeait le profil des installations existantes. Le défaut est maintenant `tone-aquaair`.
- **Identifiants MQTT Supervisor** : la réponse de `services/mqtt` contenait `username`/`password`, ignorés jusqu'ici. Ils sont maintenant utilisés, un broker configuré explicitement restant prioritaire.
- **Session jamais redescendue** : `shutdown()` fermait le fd depuis un autre thread pendant une lecture SSL, qui restait bloquée jusqu'au timeout keepalive. `shutdown(SHUT_RDWR)` réveille le lecteur et c'est le thread propriétaire qui ferme le socket.
- **TLS 1.3 et relais** : proxy/listen lisaient et écrivaient le même `SSLSocket` depuis deux threads — en TLS 1.3, les messages post-handshake faisaient perdre des écritures (le CONNECT relayé n'arrivait pas au pair). Le TLS est plafonné à 1.2, négocié déjà par Azure IoT Hub.
- **Champs `telemetry` codés en dur** : tous les noms déclarés dans le bloc `telemetry` d'un profil sont maintenant lus via `device_profile.telemetry_field` / `telemetry_key_for` au lieu d'être codés en dur — `air_mode_field`, `water_mode_field`, `hot_water_field`, `people_field`, `vacation_start_field` / `vacation_end_field`, `zone_temp_prefix`, `zone_setpoint_prefix`, `zone_count`, et les entrées inversées `modemid` / `productid` / `dt` (issue #76). Les topics MQTT HA (`aldes/state/sensor/NED`, `…/MT0`, `aldes/state/people`, `aldes/state/vacation_*`) restent stables : seul le champ lu depuis la télémétrie suit le profil, donc un profil qui renomme un champ n'a plus besoin de toucher au code.
- **Codes de mode résolus en dur** : `air_mode_code` / `water_mode_code` sont désormais les seuls points de résolution (profil puis repli). Appelés depuis le mapping télémétrie, la discovery HA et le client HA, ils ne peuvent plus diverger d'un appel à l'autre.

### Changé
- **Libellés d'historique résolus côté backend** : `GET /api/history/keys` renvoie `label` et `family` (correspondance exacte `history_labels`, motifs regex `{0}` / `{1}`, puis nom du capteur du profil, repli « Divers / non documenté ») ainsi que `family_order`. Le module front `web/src/historyLabels.ts` — un doublon des 72 clés et 8 motifs du YAML, dont seul le backend pouvait être mis à jour — est supprimé ; un profil sans `history_labels` (InspirAIR Home S) affiche enfin des libellés lisibles dans l'onglet historique.

## [0.21.0] — 2026-11-01

### Ajouté
- **Backend** : 3 nouveaux capteurs HA — « Consommation ECS », « Consommation Chauffage H » et « Consommation Climatisation » (`state_class: total_increasing`, unité kWh), alimentés par les compteurs `CoE*` / `CoH*` / `CoC*` de la télémétrie Aldes (issue #78)
- **Backend** : persistance des totaux d'énergie (`--energy-file` / `ALDES_ENERGY_FILE`, défaut `logs/energy_totals.json`), sur le même modèle que `mode_file` / `consigne_file`
- **Backend** : **reseeding depuis les messages retenus du broker** — à chaque démarrage, le bridge s'abonne à `aldes/state/energy/+`, lit les 3 valeurs retenues de ses propres capteurs (Mosquitto a la persistance activée) et s'en sert de plancher pour reconstruire l'offset si `energy_totals.json` a été perdu (réinstallation de l'add-on, restauration d'un backup ancien). La publication des compteurs reste bloquée tant que le reseed n'est pas terminé (3/3 retenus, ou délai de 5 s écoulé)
- **Backend** : **soupape de reset usine** — si les 12 compteurs d'une famille tombent à zéro sur 3 télémesures consécutives, l'offset est purgé et le capteur repart de la somme brute (un rollover de mois ne vide qu'un seul slot)

### Corrigé
- **Backend** : fausses remises à zéro des 3 capteurs énergie — un payload Aldes partiel publiait un sous-total plus bas que le précédent et HA l'interprétait comme un reset du compteur. Le bridge ne publie désormais que si les **12 compteurs** de la famille sont présents
- **Backend** : compteurs `Co*` en **fenêtre glissante 12 mois** — au 1er du mois, le slot du mois entrant remplace celui sortant et la somme brute baisse. Le total est désormais **un total à vie** : la valeur du mois sortant est capitalisée dans un offset persistant, ce qui le rend monotone par construction et survivant aux redémarrages (issue #78)

### Changé
- **Découverte MQTT** : `CoC` affiché en **« Consommation Climatisation »** (et non « Consommation Chauffage C ») avec l'icône `mdi:snowflake` — `CoC` mesure la **climatisation**, pas le chauffage. L'`entity_id` existant (`sensor.aldes_t_one_consommation_chauffage_c`) est conservé, seul le nom affiché change

### Migration
- Si l'add-on est réinstallé **sans** Mosquitto, le reseed lit les messages retenus et aucune intervention n'est nécessaire.
- Si **les deux** sont réinstallés (double wipe), le reseed n'a rien à lire : démarrer, attendre la première remontée, puis **réinitialiser les 3 statistiques** dans Outils développeur → Statistiques. Reset avant la chute = le fantôme est recompté.
- Depuis, les totaux sont monotones par construction, plus aucune remise à zéro.

## [0.20.0] — 2026-10-21

### Corrigé
- **Backend** : résolution du preset ambigu « Confort » depuis HA — le label existe à la fois pour le chauffage (B) et la climatisation (F) ; la recherche se fait désormais dans la famille du mode HVAC courant (`heat` → B, `cool` → F) au lieu de toujours résoudre en F (issue #67)

### Changé
- **Backend** : les `preset_modes` publiés sur l'entité climate HA sont filtrés selon la famille active (issue #67) — mode `cool` (F-I) → presets clim uniquement (`Off, Confort, Boost, Programme C, Programme D`), mode `heat` (B-E) → presets chauffage uniquement (`Off, Confort, Éco, Programme A, Programme B`), mode `off` (A) → union des deux. La discovery est republiée automatiquement à chaque changement de mode

## [0.19.4] — 2026-10-20

### Corrigé
- **Backend** : entité HA « Nombre de personnes » — `state/people` publie le nombre réel (2–6) au lieu de l'index `NpiH` brut (0–4), et la commande reçue de HA est reconvertie en index (`valeur − 2`, clamp 0–4) avant `changePeople` (issue #66)

### Changé
- **Backend** : découverte MQTT `number` `aldes_people` bornée `min: 2` / `max: 6` — les automations HA qui lisaient la plage 0–4 sont à ajuster

## [0.19.3] — 2026-10-20

### Corrigé
- **Frontend** : `Defr` traité comme un état (via `f_state`) et non comme une alerte dans le panneau Santé
- **Backend** : cohérence des versions — tests vérifiant que backend, UI et config add-on portent la même version, préfixe `v` unique dans la bannière de démarrage

### Ajouté
- **Tests** : scénarios e2e du mode alignés sur la barre de statut post-redesign, et nouveau scénario `defr-state.feature`

## [0.19.2] — 2026-10-19

### Corrigé
- **Backend** : bornes `min_temp` / `max_temp` des entités climate HA inversées entre chauffage et climatisation (#64) — en mode chauffage, les bornes clim (FMiST/FMaST) étaient appliquées et inversement, ce qui bloquait la consigne sous 22 °C depuis Home Assistant
- **Backend** : détection du mode air dans `_get_min_max` — l'indice numérique UAM (0..8) était comparé à une lettre, rendant la détection climatisation toujours fausse ; conversion numérique → code lettre (A..I) ajoutée, et détection étendue aux codes G/H/I (Boost, Programmes C/D)
- **Backend** : remplacement de `app.extra` par `app.state` dans l'API FastAPI — corrige un crash au démarrage (`AttributeError: 'FastAPI' object has no attribute 'extra'`)

## [0.19.0] — 2026-09-25

### Changé
- **Addon** : migration vers `addon_config:rw` — données persistées dans un dossier isolé par addon (`/addon_configs/aldes-bridge/`), inclus automatiquement dans les backups HA
- **Addon** : ajout de `homeassistant_config:rw` en montage temporaire pour la migration automatique des données depuis l'ancien emplacement
- **Addon** : migration automatique au premier démarrage — les fichiers telemetry, history, config, profile et consignes sont copiés depuis `/homeassistant/aldes/` vers `/config/aldes/`

### Corrigé
- **Addon** : retrait du champ `codenotary` (champ déprécié ignoré)
- **Addon** : retrait de l'architecture `armv7` (plus supportée par HA Supervisor)

## [0.18.5] — 2026-09-25

### Corrigé
- **Addon** : retour à `map: config:rw` — le montage `homeassistant_config` est ignoré silencieusement par les versions anciennes du Superviseur, causant une perte de données (telemetry, history, config) au redémarrage

## [0.18.4] — 2026-09-25

### Corrigé
- **Addon** : remplacement `map: config` par `map: homeassistant_config` (option dépréciée HA Supervisor)
- **Addon** : retrait de l'architecture `armv7` (plus supportée par HA Supervisor)
- **Addon** : suppression du champ `codenotary` (champ déprécié ignoré)

## [0.18.0] — 2026-09-20

### Ajouté
- **Frontend** : contrôle de présence (NpiH) avec boutons +/- dans le dashboard
- **Backend** : commande `changePeople` (MQTT auto-discovery + handler HA)
- **Backend** : topic `set/people` ajouté à la souscription MQTT

### Changé
- Versions 0.18.1 à 0.18.3 : rebuilds successifs (pas de changements fonctionnels)

## [0.16.0] — 2026-09-17

### Ajouté
- **Panneau Santé** : 8 capteurs de températures avancées (TAin, TAHU, TAHL, TEHG, TEHL, TEHU, TUeH, THGa) avec nouvelle carte "Températures avancées"

### Corrigé
- **Backend** : filtrage des valeurs sentinelles (≤ -40 °C) dans `store_telemetry()`, `_extract_health()` et au chargement de `telemetry.json` — exclut les capteurs non connectés

## [0.15.0] — 2026-09-16

### Ajouté
- **Backend** : sensors HA MQTT pour les températures de zones (MT0-MT9) — un sensor par zone active, regroupé sous le device "PAC Aldes"
- **Backend** : toggle `ha_zone_sensors` dans les settings pour activer/désactiver l'exposition des températures de zones en tant que sensors HA
- **Frontend** : toggle "Exposer temperatures zones en sensors HA" dans le panneau Configuration

### Corrigé
- **Backend** : détection des zones actives exclut les zones avec température ET consigne à 0 — évite les sensors/climats fantômes
- **Backend** : nettoyage forcé de toutes les zones 0-9 inactives à chaque cycle discovery — élimine les entités phantom après mise à jour

## [0.14.5] — 2026-09-16

### Ajouté
- **Backend** : nettoyage automatique des consignes après 2 rejets — évite les consignes bloquées indéfiniment en `confirmed: false`
- **Backend** : compteur `attempts` dans la structure `_consignes` pour tracer le nombre de tentatives avant désactivation
- **Frontend** : affichage du compteur de tentatives (ex: `demandé 22.0 °C (tentative 1/2)`) dans le panneau températures
- **Frontend** : champ `attempts` ajouté au type `consigne inline`

## [0.14.0] — 2026-09-10

### Ajouté
- **Debug** : panel de recherche de messages bruts (onglet "Messages bruts")
- **Debug** : exploration des valeurs de champ avec timestamps (onglet "Valeurs du champ")
- **Debug** : table `raw_messages` en SQLite pour stocker les payloads MQTT
- **Debug** : endpoints `/api/history/search` et `/api/history/field`
- **Debug** : rétention configurable (1-90 jours, défaut 7) via ConfigPanel
- **Backend** : tracking des messages HA (télémétrie bridge→ha, commandes ha→box)

### Changé
- **Backend** : source/destination corrigés pour le mode proxy

## [0.13.7] — 2026-09-10

### Corrigé
- **Backend** : vitesse ventilateur (RVeI) divisée par 10 pour afficher la valeur réelle en tr/min (panneau santé + sensor HA)

## [0.13.6] — 2026-09-08

### Ajouté
- **Backend** : persistance séparée des données santé (PreH, Text, RVeI, MfAc...) dans `telemetry.json` sous la clé `"health"` — affichage du panneau santé immédiat au redémarrage

### Corrigé
- **Backend** : PreH (pression haute) divisé par 100 pour affichage en bar (73 → 0.73 bar)
- **Backend** : compatibilité ascendante avec les anciens `telemetry.json` (pas de clé `"health"`)

## [0.13.5] — 2026-09-08

### Ajouté
- **UI** : section « Ventilation » dans TempsPanel — RPM ventilateur (RVeI) et débits d'air (Dno, Dma, Dint, DLN, DPLe, DmCO) en m³/h
- **Backend** : extraction des clés ventilation depuis la télémétrie courante
- **HA MQTT** : capteurs ventilation (fan RPM, airflow nominal/max/medium/night/full/max CO2) en auto-discovery

### Corrigé
- **Backend** : arrêt propre du container (exit 137) — handler SIGTERM + timeout_graceful_shutdown uvicorn

## [0.13.3] — 2026-09-08

### Ajouté
- **UI** : onglet "Santé" — diagnostic compresseur, pressions circuit, alertes
- **UI** : température extérieure (Text) et vitesse ventilateur (RVeI)
- **Backend** : clés santé extraites depuis la télémétrie (PreH, dHi, dLo, HPC, MfAc, MfEc, Defr, UAM, Text, RVeI)

### Corrigé
- **UI** : alerte Defr masquée quand compresseur arrêt (MfAc = 0)
- **UI** : comparaisons Defr/UAM robustifiées avec Number()

## [0.12.7] — 2026-09-02

### Changé
- Bridge : `ha_mqtt_dry_run` passe à `False` par défaut — les commandes HA sont envoyées à la box

## [0.12.6] — 2026-09-02

### Retiré
- Option `ha_mqtt_dry_run` de l'addon (le bridge garde son comportement par défaut)

## [0.12.5] — 2026-09-02

### Ajouté
- **HA Discovery** : entité `binary_sensor` pour la protection anti-légionelles (`AntiL`) — `device_class: safety`

## [0.12.3] — 2026-09-02

### Ajouté
- **Infra** : endpoint `/healthz` pour liveness/readiness probes Kubernetes et docker-compose
- **Infra** : endpoint `/api/health` retourne status, uptime, mqtt_connected, box_connected

## [0.12.2] — 2026-09-02

### Corrigé
- **HA Discovery** : supprimé `device_class: water` du capteur Niveau ECS (incompatible avec l'unité `%` — HA rejetait la config discovery)

## [0.12.1] — 2026-09-01

### Corrigé
- Merge de la branche `feature/water-heater-ha` sur `main` — les entités ECS sont maintenant disponibles sur la version stable

## [0.12.0] — 2026-09-01

### Ajouté
- **HA Discovery** : entité `water_heater` pour le ballon d'eau chaude (remplacement du `select ecs_mode`)
  - Opérations : Off (L) / On (M) / Boost (N)
  - Labels lus depuis le profil device (`tone-aquaair`)
- **HA Discovery** : capteurs ECS — Niveau ECS (`NED` %), Ballon Bas (`TBBa` °C), Ballon Haut (`TBHa` °C)
- **Tests** : 9 tests unitaires ajoutés pour la validation ECS (164/164 passent)

### Corrigé
- **HA Discovery** : les valeurs ECS (`NED`, `TBBa`, `TBHa`) sont publiées au démarrage depuis `telemetry.json`

## [0.9.0] — 2026-08-30

### Ajouté
- **Diagnostic** : check certificat TLS (expiration, warn < 30 jours)
- **Diagnostic** : latence réseau Azure (RTT TCP en ms)
- **Diagnostic** : santé processus backend (uptime + mémoire RSS)
- **Diagnostic** : consignes en attente de confirmation (warn > 5min, perdu > 30min)

## [0.8.6] — 2026-08-30

### Corrigé
- **Tests** : remplacement de `random.randint()` par `socket.bind(port 0)` pour éliminer les conflits de port entre tests (fix #9)

## [0.8.5] — 2026-08-29

### Corrigé
- **HA Discovery** : élimination du flicker "Inconnu" des entités climate (nettoyage ciblé)
- **HA Discovery** : persistance des zones actives dans `logs/zones.json` pour nettoyage au redemarrage

### Ajouté
- Argument CLI `--zones-file` pour la persistance des zones actives

## [0.8.4] — 2026-08-29

### Corrigé
- **HA Discovery** : précision des températures à 0.1°C
- **HA Discovery** : `temp_step` lu depuis le profil PAC
- **HA Discovery** : presets air et eau chaude chargés depuis le profil Aldes (noms français)
- **MQTT** : variable `HA_MQTT_DRY_RUN` prise en compte effective

## [0.8.3] — 2026-08-29

### Corrigé
- **HA Discovery** : zones correctement nommées "Zone N" dans HA
- **HA Discovery** : températures affichées avec une décimale

## [0.8.2] — 2026-08-29

### Corrigé
- **HA Discovery** : index des zones corrigé (Zone 2 bridge = Zone 2 HA)

## [0.8.0] — 2026-08-28

### Ajouté
- Auto-discovery MQTT Home Assistant : les entités climate, sensors, ECS et vacances
  apparaissent automatiquement dans HA sans configuration manuelle
- Toggle "Envoyer commandes HA vers la box" dans l'UI Config (dry-run live)
- Détection automatique du broker MQTT via l'API Supervisor
- Multi-zone climate avec min/max dynamiques par mode
- Publication immédiate de la consigne demandée sur le topic state (pas de rétrogradation HA)

### Corrigé
- Format JSON-RPC pour les commandes Aldes (`{"id":1,"jsonrpc":"2.0","method":...,"params":[...]}`)
- Topic MQTT corrigé : `devices/<id>/messages/devicebound` (pas `device/`)
- `logging.basicConfig()` pour afficher les messages INFO
- Crash silencieux des threads MQTT capturé et loggé

### Changé
- Le panneau Diagnostic affiche le statut MQTT HA (connecté/séché/désactivé)
- Les versions backend, frontend et add-on sont synchronisées

## [0.7.0] — 2026-08-XX

### Ajouté
- Profils device YAML (tone-aquaair)
- Tests E2E avec Playwright
- Déploiement Kubernetes (guide K3s)

### Corrigé
- Port MQTT utilisé dans le diagnostic (#3)
- Expiration des sessions MQTT silencieuses (#4)
- Profils AIR corrigés (#2)

## [0.6.0] — 2026-08-XX

### Ajouté
- Web UI React avec onglets flux/températures
- API HTTP + SSE
- Mode bridge et proxy
- iptables automatiques pour redirection 8883 → 18883
- DNS over HTTPS (DoH) pour contourner dnsmasq en mode proxy
