# Aldes HAOS Add-ons

Add-ons Home Assistant OS pour le [Aldes Bridge](https://github.com/saniho/aldes-bridge).

Ce repo fournit un add-on HAOS qui déploie le bridge MQTT/TLS pour Aldes T.ONE AquaAir
directement sur Home Assistant OS, sans Docker ni SSH.

## Prérequis

- Home Assistant OS (pas HA Core ni HA Container)
- IP fixe configurée sur la HAOS (voir étape 1 ci-dessous)
- Accès admin à la box/routeur pour modifier le DHCP

## Installation

### 1. Configurer l'IP fixe de la HAOS

L'add-on utilise le réseau hôte (`host_network`), donc il écoute sur l'IP de la HAOS.
Il faut d'abord lui assigner une IP fixe.

Trouve l'IP actuelle de ta HAOS :
```
Paramètres → Système → Réseau → Adapter réseau
```

Configure une IP fixe (ex: `192.168.1.90`) :
```
Paramètres → Système → Réseau → Adapter réseau → Configuration IP
→ Méthode : Manuel
→ Adresse IP : 192.168.1.90  (ou l'IP que tu choisis)
→ Passerelle : 192.168.1.254 (IP de ta box/routeur)
→ Masque : 255.255.255.0
```

> **Note :** Dans la suite de ce guide, `<IP_HAOS>` désigne cette IP.
> Remplace-la par ton IP réelle dans toutes les étapes.

### 2. Ajouter le dépôt

> **Attention :** ceci est un dépôt d'**add-ons** (containers), pas HACS.
> Ne pas ajouter dans HACS (qui est pour les intégrations, cards et thèmes).

Dans HAOS :

```
Paramètres → Add-ons → Stores (en bas) → Ajouter un dépôt
→ URL : https://github.com/saniho/aldes-haos-addons
→ Créer
```

### 3. Installer l'add-on Aldes Bridge

```
Paramètres → Add-ons → Chercher "Aldes Bridge" → Installer
```

### 4. Installer l'add-on Dnsmasq (officiel)

```
Paramètres → Add-ons → Chercher "Dnsmasq" → Installer
```

Cet add-on fournit le serveur DNS qui redirige le domaine Aldes vers le bridge.

### 5. Configurer Dnsmasq

Ouvrir l'onglet **Configuration** de l'add-on Dnsmasq et remplacer le contenu par :

```yaml
defaults:
  - 192.168.1.254          # DNS upstream (ta Freebox/box)

hosts:
  - host: aldesiotsuite.azure-devices.net
    ip: <IP_HAOS>           # <-- remplace par l'IP de ta HAOS

log_queries: true
cache_size: 1000
```

> **Important :** `<IP_HAOS>` doit être remplacé par l'IP fixe configurée à l'étape 1.
> Par exemple, si ta HAOS a l'IP `192.168.1.90`, mets `ip: 192.168.1.90`.

Puis **Démarrer** l'add-on et activer le démarrage automatique.

### 6. Configurer le DHCP

Dans l'admin de ta box/routeur :

```
DHCP du réseau local
→ DNS 1 = <IP_HAOS>        # l'IP fixe de ta HAOS
→ DNS 2 = 192.168.1.254    # upstream, backup
→ Appliquer
```

Les appareils qui se connecteront au réseau recevront l'IP de la HAOS comme serveur DNS.

### 7. Vérifier

```bash
# Depuis un PC du réseau (remplace <IP_HAOS> par ton IP)
dig @<IP_HAOS> aldesiotsuite.azure-devices.net +short
# → <IP_HAOS> ✓

dig @<IP_HAOS> github.com +short
# → IP publique normale ✓
```

### 8. Connecter la box Aldes

Redémarre la box Aldes. Elle résoudra `aldesiotsuite.azure-devices.net` vers la HAOS
et se connectera sur le port 8883.

La Web UI est accessible sur `http://<IP_HAOS>:8080`.

## Configuration de l'add-on Aldes Bridge

| Option | Description | Défaut |
|--------|-------------|--------|
| `mode` | Mode de fonctionnement (`bridge`, `proxy`, `listen`, `raw`) | `bridge` |
| `profile` | Profil device Aldes | `tone-aquaair` |
| `history_days` | Rétention de l'historique SQLite (jours) | `90` |
| `box_tz` | Timezone de la box Aldes | `Europe/Paris` |

Le mode peut être changé à tout moment depuis la Web UI.

## Mise à jour

### Add-on Aldes Bridge

Quand une nouvelle version du bridge est publiée sur le repo principal,
mettre à jour le tag dans `aldes-bridge/Dockerfile` :

```dockerfile
FROM ghcr.io/saniho/aldes-bridge:X.Y.Z
```

Pousser sur GitHub, puis dans HAOS :
```
Paramètres → Add-ons → Aldes Bridge → Mettre à jour
```

### Add-on Dnsmasq

Se met à jour depuis le store HAOS normalement.

## Architecture

```
Box Aldes ──MQTT/TLS:8883──→ HAOS (aldes-bridge)
Box Aldes ──DNS:53─────────→ HAOS (dnsmasq) ──→ Box/routeur
Navigateur ──HTTP:8080────→ HAOS (aldes-bridge) → Web UI
```

- **aldes-bridge** : bridge MQTT/TLS + API + Web UI, tourne en `host_network`
  (écoute sur l'IP de la HAOS, ports 8883 et 8080)
- **dnsmasq** : résout `aldesiotsuite.azure-devices.net` vers l'IP de la HAOS,
  relaie le reste vers le DNS upstream

## Fichiers persistants

Les données sont sauvegardées dans `/config/aldes/` (volume HAOS) :

| Fichier | Contenu |
|---------|---------|
| `config.json` | Paramètres (rétention, taille des logs) |
| `telemetry.json` | Dernière télémétrie capturée |
| `history.db` | Base SQLite de l'historique |
| `profile.json` | Profil device sélectionné |
| `consigne.json` | Consignes en attente de confirmation |

## Dépannage

**La Web UI ne répond pas :**
- Vérifier que l'add-on Aldes Bridge est démarré
- `curl http://<IP_HAOS>:8080/api/config`

**La box Aldes ne se connecte pas :**
- Vérifier que dnsmasq tourne : `dig @<IP_HAOS> aldesiotsuite.azure-devices.net`
- Vérifier le DHCP : les appareils doivent recevoir `<IP_HAOS>` comme DNS
- Vérifier les logs de l'add-on Aldes Bridge

**Le DNS de la HAOS ne fonctionne plus :**
- Vérifier que dnsmasq relaye vers l'upstream (`defaults: [192.168.1.254]`)
- Le DNS interne du Supervisor peut entrer en conflit sur le port 53.
  Redémarrer l'add-on dnsmasq résout généralement le problème.
