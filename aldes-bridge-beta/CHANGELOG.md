# Changelog

Toutes les versions notables de Aldes Bridge Add-on.

Format basé sur [Keep a Changelog](https://keepachangelog.com/).

## [0.12.3] — 2026-09-02

### Ajouté
- **Infra** : endpoint `/healthz` pour liveness/readiness probes Kubernetes et docker-compose
- **Infra** : endpoint `/api/health` retourne status, uptime, mqtt_connected, box_connected

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
