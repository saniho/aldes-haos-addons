#!/usr/bin/env bash
# rebuild.sh — Force le rebuild Docker de l'add-on Aldes Bridge Beta
# Usage: ./rebuild.sh
#
# Prérequis:
#   - HA Supervisor API accessible (depuis la machine HA)
#   - curl installé

set -euo pipefail

ADDON_SLUG="aldes-bridge-beta"
ADDON_DIR="$(cd "$(dirname "$0")" && pwd)/$ADDON_SLUG"
DOCKERFILE="$ADDON_DIR/Dockerfile"
CONFIG_YAML="$ADDON_DIR/config.yaml"
HA_TOKEN="${HA_TOKEN:-}"  # Token long-lived ou via token auth
HA_URL="${HA_URL:-http://supervisor}"

# ── Récupérer la version actuelle ──
CURRENT_VERSION=$(grep '^version:' "$CONFIG_YAML" | sed 's/.*"\(.*\)"/\1/')
echo "Version actuelle: $CURRENT_VERSION"

# ── Extraire le numéro beta et l'incrémenter ──
# Ex: 0.7.0-beta.30 → 0.7.0-beta.31
MAJOR_MINOR=$(echo "$CURRENT_VERSION" | sed -E 's/(beta\.)[0-9]+/\1/')
BETA_NUM=$(echo "$CURRENT_VERSION" | grep -oP 'beta\.\K[0-9]+')
NEW_BETA_NUM=$((BETA_NUM + 1))
NEW_VERSION=$(echo "$CURRENT_VERSION" | sed "s/beta\.[0-9]*/beta.$NEW_BETA_NUM/")
echo "Nouvelle version: $NEW_VERSION"

# ── Mettre à jour config.yaml ──
sed -i "s/^version: \".*\"/version: \"$NEW_VERSION\"/" "$CONFIG_YAML"
echo "✓ config.yaml mis à jour"

# ── Mettre à jour Dockerfile (CACHEBUST + ALDES_ADDON_VERSION) ──
sed -i "s/^ARG CACHEBUST=.*/ARG CACHEBUST=$NEW_VERSION/" "$DOCKERFILE"
sed -i "s/^ENV ALDES_ADDON_VERSION=.*/ENV ALDES_ADDON_VERSION=v$NEW_VERSION/" "$DOCKERFILE"
echo "✓ Dockerfile mis à jour"

# ── Commit & push ──
cd "$ADDON_DIR/.."
git add "$ADDON_SLUG/"
git commit -m "chore(beta): rebuild v$NEW_VERSION — force frontend rebuild"
git push origin main
echo "✓ Pushé sur GitHub"

# ── Rebuild via HA Supervisor API ──
if [ -n "$HA_TOKEN" ]; then
    echo "Rebuild via HA API..."
    curl -s -X POST "$HA_URL/api/hassio/addons/$ADDON_SLUG/rebuild" \
        -H "Authorization: Bearer $HA_TOKEN" \
        -H "Content-Type: application/json" || true
    echo ""
    echo "✓ Demande de rebuild envoyée"
else
    echo ""
    echo "⚠ HA_TOKEN non défini. Pour rebuild automatique:"
    echo "  export HA_TOKEN=votre_token_long_lived"
    echo "  export HA_URL=http://192.168.1.90:8123  # ou http://supervisor depuis HA"
    echo "  ./rebuild.sh"
fi

echo ""
echo "Terminé! L'add-on se rebuild avec la branche feature/ha-auto-discovery."
echo "Après le restart, le toggle 'Envoyer commandes HA vers la box' devrait apparaître."
