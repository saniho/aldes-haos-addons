# Changelog

Toutes les versions notables de Aldes Bridge Add-on.

Format basé sur [Keep a Changelog](https://keepachangelog.com/).

## [0.22.0-beta1] — 2026-11-04

### Ajouté
- **Profil VMC InspirAIR Home S** (`profiles/inspirair-home-s.yaml`, `type: vmc`) : pour un profil de type `vmc`, la discovery HA publie un select « Mode » (Daily / Holidays / Guest / Boost / Air Prog, codes `changeMode` V→Z) et les sensors du profil, à la place des entités climate / water_heater du T.ONE. Les champs bruts non documentés sont exposés en `entity_category: diagnostic` ; les unités des sensors sont déduites des valeurs observées (PR #63).
- **Mode Holidays (W)** : envoie la fenêtre UTC attendue par la machine (`ha_discovery.holiday_duration_hours`, 24 h par défaut) — sans elle, la machine ignore la commande.
- `AGENTS.md` décrit maintenant l'équipement selon le `type` du profil (`pac` ou `vmc`).

### Corrigé
- **Dry-run ignoré à l'exécution** : `state.config` (défaut `ha_mqtt_dry_run: False`) écrasait le dry-run résolu au démarrage — les commandes HA partaient vers la box même avec `HA_MQTT_DRY_RUN=true`. Le client lit désormais `self.dry_run`, que le toggle des réglages met à jour.
- **Topic de commande HA** : les commandes partaient sur `devices/aldes_bridge/messages/devicebound` au lieu du `client_id` de la box connectée (`devices/<client_id>/...`).
- **Profil par défaut** : il dépendait de l'ordre alphabétique des fichiers — ajouter un profil changeait le profil des installations existantes. Le défaut est maintenant `tone-aquaair`.
- **Identifiants MQTT Supervisor** : la réponse de `services/mqtt` contenait `username`/`password`, ignorés jusqu'ici. Ils sont maintenant utilisés, un broker configuré explicitement restant prioritaire.
- **Session jamais redescendue** : `shutdown()` fermait le fd depuis un autre thread pendant une lecture SSL, qui restait bloquée jusqu'au timeout keepalive. `shutdown(SHUT_RDWR)` réveille le lecteur et c'est le thread propriétaire qui ferme le socket.
- **TLS 1.3 et relais** : proxy/listen lisaient et écrivaient le même `SSLSocket` depuis deux threads — en TLS 1.3, les messages post-handshake faisaient perdre des écritures (le CONNECT relayé n'arrivait pas au pair). Le TLS est plafonné à 1.2, négocié déjà par Azure IoT Hub.
- **Champs `telemetry` codés en dur** : tous les noms déclarés dans le bloc `telemetry` d'un profil sont maintenant lus via `device_profile.telemetry_field` / `telemetry_key_for` au lieu d'être codés en dur — `air_mode_field`, `water_mode_field`, `hot_water_field`, `people_field`, `vacation_start_field` / `vacation_end_field`, `zone_temp_prefix`, `zone_setpoint_prefix`, `zone_count`, et les entrées inversées `modemid` / `productid` / `dt` (issue #76). Les topics MQTT HA (`aldes/state/sensor/NED`, `…/MT0`, `aldes/state/people`, `aldes/state/vacation_*`) restent stables : seul le champ lu depuis la télémétrie suit le profil, donc un profil qui renomme un champ n'a plus besoin de toucher au code.

## [0.21.0-beta7] — 2026-11-01

### Ajouté
- **Reseed depuis le broker MQTT** : à chaque démarrage, le bridge s'abonne à `aldes/state/energy/+` et lit les 3 messages **retenus** de ses propres capteurs (les publications se font avec `retain=True`, et le Mosquitto de l'add-on a la persistance activée). Ces valeurs servent de **plancher** pour reconstruire l'offset : si `energy_totals.json` a été perdu (réinstallation de l'add-on, restauration d'un backup ancien), le total repart de la dernière valeur vue par HA au lieu de retomber à la somme brute. La publication des compteurs reste bloquée tant que le reseed n'est pas terminé (3/3 retenus, ou délai de 5 s écoulé) — sinon on publierait une somme basse avant d'avoir lu le plancher.
- **Soupape de reset usine** : si la PAC Aldes est remise à zéro (les 12 compteurs d'une famille tombent à zéro sur 3 télémesures consécutives), l'offset est purgé et le capteur repart de la somme brute. Sans cela, un reset usine laisserait un offset fantôme qui figerait le total à vie.

### Connu
- **Double wipe résiduel** : si l'add-on Aldes **et** le Mosquitto sont réinstallés ensemble (perte des retenues), le reseed n'a rien à lire et on retombe sur la somme brute — une remise à zéro manuelle dans Outils développeur → Statistiques reste nécessaire dans ce cas de figure. C'est le seul scénario non couvert ; il est documenté plutôt que traité par une dépendance à l'API HA.

## [0.21.0-beta6] — 2026-11-01

### Corrigé
- **Découverte MQTT** : renommage du capteur `CoC` en **« Consommation Climatisation »** (au lieu de « Consommation Chauffage C ») — `CoC` mesure la **climatisation**, pas le chauffage — et icône `mdi:snowflake` au lieu de `mdi:fire` (issue #78, section Divers). L'`entity_id` existant (`sensor.aldes_t_one_consommation_chauffage_c`) est conservé, seul le nom affiché change

## [0.21.0-beta5] — 2026-11-01

### Corrigé
- **Backend** : compteurs `Co*` en **fenêtre glissante 12 mois** — au 1er du mois, le slot du mois entrant remplace celui sortant, ce qui fait **baisser** la somme brute. Le garde-fou monotone bloquait alors la publication (capteur figé pendant des semaines), et un redémarrage publiait la somme basse → HA comptait une remise à zéro fantôme. Le total est désormais **un total à vie** : la valeur du mois sortant est capitalisée dans un offset persistant (`logs/energy_totals.json`), ce qui le rend monotone par construction et survivant aux redémarrages (issue #78)

### Ajouté
- **Backend** : persistance des totaux d'energie (`--energy-file` / `ALDES_ENERGY_FILE`, défaut `logs/energy_totals.json`), sur le même modèle que `mode_file` / `consigne_file`

### Migration
- Le rollover du 01/11/2026 est **déjà passé** : au premier démarrage, sans état connu, le bridge publie la somme brute post-rollover (817→716, 414→396). Deux façons de gérer cette chute unique :
  1. **Éviter la chute** — déposer `energy_totals.json` (dans l'add-on : `/config/aldes/energy_totals.json`, hôte : `/addon_configs/<slug>/aldes/`) **avant** de démarrer, avec les offsets du mois sortant :
     ```json
     {"energy_heating_h": {"slots": null, "offset": 102.0}, "energy_ecs": {"slots": null, "offset": 18.0}, "energy_heating_c": {"slots": null, "offset": 0.0}}
     ```
     Résultat : 818 / 414 / 428, sans saut. À noter : ce dossier n'est **pas** celui de la config HA — File Editor / Studio Code n'y voient pas ce fichier, il faut le Terminal (`/app_configs/<slug>/aldes/` ou `/addon_configs/<slug>/aldes/`).
  2. **Accepter la chute** — démarrer sans fichier, puis **réinitialiser les 3 statistiques** dans Outils développeur → Statistiques **après** la première remontée (quand les capteurs affichent la somme basse). Reset avant la chute = le fantôme est recompté. Depuis, les totaux sont monotones par construction, plus aucune remise à zéro.

## [0.21.0-beta4] — 2026-10-22

### Corrigé
- **Backend** : fausses remises à zéro des 3 capteurs énergie kWh — un payload Aldes partiel (sous-ensemble des compteurs `CoE/CoC/CoH`) publiait un **sous-total** plus bas que le précédent ; HA (`state_class: total_increasing`) l'interprétait comme un reset du compteur et ajoutait la valeur aux statistiques (jusqu'à ×4 le total réel après 2 redémarrages). Le bridge n'publie désormais que si les **12 compteurs** de la famille sont présents dans le payload, et ignore tout total inférieur au dernier publié

## [0.21.0-beta2] — 2026-10-22

### Changé
- **Build** : le Dockerfile beta clone la branche `feature/energy-sensors` (les capteurs énergie ne sont pas encore sur `main`)

## [0.21.0-beta1] — 2026-10-22

### Ajouté
- **Backend** : 3 capteurs énergie kWh en auto-discovery HA (issue #62) — `Consommation ECS`, `Consommation Chauffage C`, `Consommation Chauffage H` avec `device_class: energy` et `state_class: total_increasing`
- **Backend** : agrégation des compteurs par zone (`CoE1..12`, `CoC1..12`, `CoH1..12`) en totaux publiés sur `aldes/state/energy/*`

## [0.20.0-beta1] — 2026-10-21

### Corrigé
- **Backend** : résolution du preset ambigu « Confort » depuis HA — le label existe à la fois pour le chauffage (B) et la climatisation (F) ; la recherche se fait désormais dans la famille du mode HVAC courant (`heat` → B, `cool` → F) au lieu de toujours résoudre en F (issue #67)

### Changé
- **Backend** : les `preset_modes` publiés sur l'entité climate HA sont filtrés selon la famille active (issue #67) — mode `cool` (F-I) → presets clim uniquement (`Off, Confort, Boost, Programme C, Programme D`), mode `heat` (B-E) → presets chauffage uniquement (`Off, Confort, Éco, Programme A, Programme B`), mode `off` (A) → union des deux. La discovery est republiée automatiquement à chaque changement de mode

## [0.19.4-beta1] — 2026-10-20

### Corrigé
- **Backend** : entité HA « Nombre de personnes » — `state/people` publie désormais le nombre réel (2–6) au lieu de l'index `NpiH` brut (0–4), et la commande reçue de HA est reconvertie en index (`valeur − 2`, clamp 0–4) avant `changePeople` (issue #66)

### Changé
- **Backend** : découverte MQTT `number` `aldes_people` bornée `min: 2` / `max: 6` — les automations HA qui lisaient la plage 0–4 sont à ajuster

## [0.19.2-beta2] — 2026-10-19

### Corrigé
- **Backend** : remplacement de `app.extra` par `app.state` dans l'API FastAPI — `app.extra` n'existe pas dans les versions de Starlette embarquées dans l'image Docker de l'addon, ce qui provoquait un crash au démarrage (`AttributeError: 'FastAPI' object has no attribute 'extra'`)

## [0.19.2-beta1] — 2026-10-18

### Corrigé
- **Backend** : bornes `min_temp` / `max_temp` des entités climate HA inversées entre chauffage et climatisation (issue #64) — en mode chauffage, les bornes clim (FMiST/FMaST) étaient appliquées et inversement, ce qui bloquait la consigne sous 22 °C depuis Home Assistant
- **Backend** : détection du mode air dans `_get_min_max` — l'indice numérique UAM (0..8) était comparé à une lettre, rendant la détection climatisation toujours fausse ; conversion numérique → code lettre (A..I) ajoutée, et détection étendue aux codes G/H/I (Boost, Programmes C/D)

## [0.19.3-beta2] — 2026-10-19

### Corrigé
- **Tests E2E** : 3 scénarios des modes (basculement, annulation, transitions) alignés sur la barre de statut après le redesign du dashboard — libellé « Mode : » retiré de la `StatusBar` ; ajout d'un `data-testid="status-mode"` et assertions ciblées sur ce testid, suite E2E complète au vert (22/22)

## [0.19.3-beta1] — 2026-10-19

### Corrigé
- **Build** : `dist/version.json` n'est plus réécrit avec la clé `version` (le build Vite écrit déjà la clé `ui`) — le menu burger n'affichait plus « UI vdev »
- **Logs** : la bannière de démarrage affiche un seul préfixe `v` par version (`Add-on vv0.19.1-beta1`) et résout la version UI réelle
- **Frontend** : `Defr` est l'état du dégivrage (0/1) et non un défaut — la bannière d'alerte du dashboard ne se déclenche plus que sur `HPC` et le panneau santé affiche `Inactif` / `Actif` / `Inconnu` au lieu de `ALERTE` (#60)

### Changé
- **Version** : format de version beta unique `0.19.1-beta1` (le backend affichait `0.19.1.beta1` et l'UI `0.19.1-beta.1`)
- **Frontend** : libellé `Defr` → « Dégivrage (état) » dans le profil device et l'historique
- **Docs** : sémantique `Defr` et bannière d'alerte du dashboard documentées
- **Build** : la beta est construite depuis la branche `fix/defr-state` (elle pointait encore sur `fix/ha-min-max-modes`, déjà mergée)

## [0.18.0-beta1] — 2026-09-20

### Ajouté
- **Frontend** : contrôle de présence (NpiH) avec boutons +/- dans le dashboard
- **Backend** : commande `changePeople` (MQTT auto-discovery + handler HA)
- **Backend** : topic `set/people` ajouté à la souscription MQTT

## [0.16.0-beta3] — 2026-09-17

### Corrigé
- **Backend** : filtrage des valeurs sentinelles (≤ -40 °C) dans `_extract_health()` et au chargement de `telemetry.json` — corrige l'affichage de -40 °C dans le panneau Santé

## [0.16.0-beta2] — 2026-09-17

### Corrigé
- **Backend** : filtrage des valeurs sentinelles (≤ -40 °C) des capteurs de températures avancées — évite d'afficher des valeurs absurdement basses pour des capteurs non connectés

## [0.16.0-beta1] — 2026-09-16

### Ajouté
- **Backend** : températures avancées (TAin, TAHU, TAHL, TEHG, TEHL, TEHU, TUeH, THGa) ajoutées aux données health persistées
- **Frontend** : carte "Températures avancées" dans le panneau santé — grille avec 8 capteurs de l'échangeur de chaleur

## [0.15.0-beta3] — 2026-09-16

### Corrigé
- **Backend** : forcer le nettoyage de toutes les zones 0-9 inactives à chaque cycle discovery (climats + sensors) — élimine les entités phantom qui persistent après une mise à jour

## [0.15.0-beta2] — 2026-09-16

### Corrigé
- **Backend** : exclusion des zones avec température ET consigne à 0 de la détection des zones actives — évite les sensors fantômes

## [0.15.0-beta1] — 2026-09-16

### Ajouté
- **Backend** : sensors HA MQTT pour les températures de zones (MT0-MT9) — un sensor par zone active, regroupé sous le device "PAC Aldes"
- **Backend** : toggle `ha_zone_sensors` dans les settings pour activer/désactiver l'exposition des températures de zones en tant que sensors HA
- **Frontend** : toggle "Exposer temperatures zones en sensors HA" dans le panneau Configuration

## [0.14.5] — 2026-09-16

### Ajouté
- **Backend** : nettoyage automatique des consignes après 2 rejets — évite les consignes bloquées indéfiniment en `confirmed: false`
- **Backend** : compteur `attempts` dans la structure `_consignes` pour tracer le nombre de tentatives avant désactivation
- **Frontend** : affichage du compteur de tentatives (ex: `demandé 22.0 °C (tentative 1/2)`) dans le panneau températures
- **Frontend** : champ `attempts` ajouté au type `consigne inline`

## [0.14.2-beta2] — 2026-09-10

### Ajouté
- **Backend** : nettoyage automatique des consignes en attente après 2 tentatives non concordantes de la PAC — évite les consignes bloquées indéfiniment en `confirmed: false`
- **Backend** : compteur `attempts` dans la structure `_consignes` pour tracer le nombre de tentatives avant désactivation
- **Frontend** : affichage du compteur de tentatives (ex: `demandé 22.0 °C (tentative 1/2)`) dans le panneau températures
- **Frontend** : événement SSE `rejected` pour informer l'utilisateur du rejet d'une consigne

## [0.13.7-beta2] — 2026-09-10

### Corrigé
- **Backend** : vitesse ventilateur (RVeI) divisée par 10 pour afficher la valeur réale en tr/min (panneau santé + sensor HA)

## [0.13.6-beta2] — 2026-09-08

### Ajouté
- **Backend** : persistance séparée des données santé (PreH, Text, RVeI, MfAc...) dans `telemetry.json` sous la clé `"health"` — garantit l'affichage du panneau santé au redémarrage

### Corrigé
- **Backend** : compatibilité ascendante avec les anciens `telemetry.json` (pas de clé `"health"`)

## [0.12.3] — 2026-09-02

### Ajouté
- **Infra** : endpoint `/healthz` pour liveness/readiness probes Kubernetes et docker-compose
- **Infra** : endpoint `/api/health` retourne status, uptime, mqtt_connected, box_connected

## [0.13.4-beta2] — 2026-09-08

### Corrigé
- **Bridge** : gestion du SIGTERM pour un arrêt propre du container (exit code 137 corrigé)

## [0.13.5-beta1] — 2026-09-08

### Ajouté
- **UI** : section "Ventilation" dans TempsPanel — RPM ventilateur (RVeI) et débits d'air (Dno, Dma, Dint, DLN, DPLe, DmCO)
- **Backend** : extraction des clés ventilation depuis la télémétrie courante
- **HA MQTT** : capteurs ventilation (fan RPM, airflow nominal/max/medium/night/full/max CO2) en auto-discovery

### Corrigé
- **Backend** : arrêt propre du container (exit 137) — handler SIGTERM + timeout_graceful_shutdown uvicorn

## [0.13.2-beta7] — 2026-09-08

### Corrigé
- **UI** : alerte Defr masquée quand compresseur arrêt (MfAc = 0) — fix définitif

## [0.13.2-beta6] — 2026-09-08

### Ajouté
- **UI** : température extérieure (Text) et vitesse ventilateur (RVeI) dans le panneau santé

## [0.13.2-beta5] — 2026-09-08

### Corrigé
- **UI** : comparaisons Defr/UAM robustifiées avec Number()

## [0.13.2-beta4] — 2026-09-08

### Corrigé
- **UI** : afficher "N/A (clim off)" pour Defr quand UAM = 0

## [0.13.2-beta3] — 2026-09-08

### Corrigé
- **UI** : suppression variable level non utilisée (TS6133)

## [0.13.2-beta2] — 2026-09-03

### Changé
- Bump version beta2 (Dockerfile pointe sur branche feature/health-panel)

## [0.13.2-beta1] — 2026-09-03

### Ajouté
- **UI** : nouvel onglet "Santé" dans la barre principale
- **UI** : panneau état compresseur (MfAc) — marche/arrêt
- **UI** : panneau pressions circuit (PreH, dHi, dLo)
- **UI** : panneau alertes haute pression (HPC) et défaut circuit froid (Defr)
- **Backend** : endpoint `/api/config` retourne `health` avec les 7 clés santé
- **Backend** : extraction des clés santé depuis la télémétrie courante

## [0.12.3] — 2026-09-02

### Ajouté
- **Infra** : endpoint `/healthz` pour liveness/readiness probes Kubernetes et docker-compose
- **Infra** : endpoint `/api/health` retourne status, uptime, mqtt_connected, box_connected

## [0.11.0] — 2026-08-31

### Changé
- Refactor majeur mergé sur main : split monolithes, deduplication, composition
- Modes air séparés Climatisation / Chauffage (sans doublons hors Off)
- ECS : Off, On, Boost
- UI : boutons séparés Climatisation / Chauffage
- Dockerfile clone maintenant la branche main

## [0.10.1-beta.4] — 2026-08-31

### Changé
- Modes air séparés climatisation / chauffage
- Labels ECS : Off, On, Boost

## [0.10.1-beta.1] — 2026-08-30

### Changé
- Refactor majeur du backend : scission des fichiers monolithiques (`api.py` 746L → `routers/` 8 modules, `ha_discovery.py` 1082L → `ha/` 4 modules)
- Déduplication du code (~200L supprimées) : `safe_float()`, `parse_json_payload()`, `get_state()`/`get_engine()` partagés
- Suppression du shim backward-compat `ha_discovery.py`
- `ListenHandler` : composition via injection de stratégie au lieu de l'héritage
- `run_diagnostic()` scindé en 15 fonctions par check
- `main()` allégé avec `_setup_ha_client()` extrait
- Branche : `feature/refactor-ha-api-appstate`

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
