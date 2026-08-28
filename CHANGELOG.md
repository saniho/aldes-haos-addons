# Changelog

Toutes les versions notables de Aldes Bridge Add-on.

Format basé sur [Keep a Changelog](https://keepachangelog.com/).

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
