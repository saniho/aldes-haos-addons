FROM ghcr.io/saniho/aldes-bridge:0.4.0

RUN mkdir -p /config/aldes

# Redirige les fichiers persistants vers le volume HAOS (/config)
ENV ALDES_CONFIG_FILE=/config/aldes/config.json
ENV ALDES_TELEMETRY_FILE=/config/aldes/telemetry.json
ENV ALDES_HISTORY_FILE=/config/aldes/history.db
ENV ALDES_PROFILE_FILE=/config/aldes/profile.json
ENV ALDES_CONSIGNE_FILE=/config/aldes/consigne.json

# Note : le mode (mode.json) et le log (events.log.jsonl) sont hardcodés
# dans le code source (pas d'env var). Le mode est initialisé via ALDES_MODE
# et persisté/relu depuis APP_ROOT/logs/mode.json (éphemère dans HAOS, acceptable).
# Le log est non-critique et tournant.
