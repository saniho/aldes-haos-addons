# Changelog

Toutes les versions notables de Aldes Bridge Add-on.

Format basé sur [Keep a Changelog](https://keepachangelog.com/).

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
