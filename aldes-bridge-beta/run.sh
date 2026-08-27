#!/bin/bash
MQTT_PORT=18883
WEB_PORT=8080
BOX_IP=""
MODE=""
HA_MQTT=""
HA_MQTT_DRY_RUN=""

if [ -f /data/options.json ]; then
  val=$(python3 -c "import json,sys; d=json.load(open('/data/options.json')); print(d.get('mqtt_port',''))" 2>/dev/null)
  [ -n "$val" ] && MQTT_PORT=$val
  bip=$(python3 -c "import json,sys; d=json.load(open('/data/options.json')); print(d.get('box_ip',''))" 2>/dev/null)
  [ -n "$bip" ] && BOX_IP=$bip
  md=$(python3 -c "import json,sys; d=json.load(open('/data/options.json')); print(d.get('mode',''))" 2>/dev/null)
  [ -n "$md" ] && MODE=$md
  ha=$(python3 -c "import json,sys; d=json.load(open('/data/options.json')); print(d.get('ha_mqtt_enabled',''))" 2>/dev/null)
  ha_dry=$(python3 -c "import json,sys; d=json.load(open('/data/options.json')); print(d.get('ha_mqtt_dry_run',''))" 2>/dev/null)
  ha_host=$(python3 -c "import json,sys; d=json.load(open('/data/options.json')); print(d.get('ha_mqtt_host',''))" 2>/dev/null)
  ha_port=$(python3 -c "import json,sys; d=json.load(open('/data/options.json')); print(d.get('ha_mqtt_port',''))" 2>/dev/null)
  ha_user=$(python3 -c "import json,sys; d=json.load(open('/data/options.json')); print(d.get('ha_mqtt_user',''))" 2>/dev/null)
  ha_pass=$(python3 -c "import json,sys; d=json.load(open('/data/options.json')); print(d.get('ha_mqtt_password',''))" 2>/dev/null)
  echo "[run.sh] ha_mqtt_enabled='$ha' ha_mqtt_dry_run='$ha_dry' ha_mqtt_host='$ha_host' ha_mqtt_port='$ha_port' ha_mqtt_user='$ha_user'"
  ha_dry_lower=$(echo "$ha_dry" | tr '[:upper:]' '[:lower:]')
  ha_lower=$(echo "$ha" | tr '[:upper:]' '[:lower:]')
  if [ "$ha_lower" = "true" ]; then
    HA_MQTT="--ha-mqtt"
    if [ "$ha_dry_lower" = "false" ]; then
      HA_MQTT_DRY_RUN="--ha-mqtt-no-dry-run"
    else
      HA_MQTT_DRY_RUN="--ha-mqtt-dry-run"
    fi
  fi
fi

echo "[run.sh] options.json contents:"
cat /data/options.json 2>/dev/null || echo "  (file not found)"
echo "[run.sh] MQTT_PORT=$MQTT_PORT, WEB_PORT=$WEB_PORT, BOX_IP=$BOX_IP, HA_MQTT=$HA_MQTT $HA_MQTT_DRY_RUN"

# Diagnostique reseau
echo "[run.sh] --- Network diagnosis ---"
cat /proc/net/tcp 2>/dev/null | head -5 || true
echo "[run.sh] Listening ports:"
cat /proc/net/tcp 2>/dev/null | awk '{print $2}' | grep -v local | while read hex; do
  port=$((16#${hex##*:}))
  [ "$port" -gt 0 ] && echo "  port $port"
done 2>/dev/null || true

# Verifie si iptables/nftables est disponible
echo "[run.sh] Checking iptables..."
which iptables 2>/dev/null && echo "  iptables found" || echo "  iptables NOT found"
iptables -t nat -L PREROUTING -n 2>&1 | head -5 || echo "  iptables nat read FAILED"
nft list ruleset 2>/dev/null | head -5 || echo "  nft not available or no permissions"

# Redirige le port 8883 vers le port MQTT si besoin
# IMPORTANT: on utilise -I (insert) au lieu de -A (append) pour placer
# la regle AVANT la chaine DOCKER qui intercepte tout le trafic local.
if [ "$MQTT_PORT" != "8883" ]; then
  # Supprimer TOUTES les anciennes regles REDIRECT 8883->* (accumulees a chaque restart)
  for chain in PREROUTING OUTPUT; do
    i=0; while [ $i -lt 20 ] && iptables -t nat -D "$chain" -p tcp --dport 8883 -j REDIRECT --to-port 18883 2>/dev/null; do i=$((i+1)); done
    i=0; while [ $i -lt 20 ] && iptables -t nat -D "$chain" -p tcp --dport 8883 -j REDIRECT --to-port 8080 2>/dev/null; do i=$((i+1)); done
    i=0; while [ $i -lt 20 ] && iptables -t nat -D "$chain" -p tcp -s "$BOX_IP" --dport 8883 -j REDIRECT --to-port 18883 2>/dev/null; do i=$((i+1)); done
  done
  echo "[run.sh] iptables: all old 8883 REDIRECT rules cleaned"

  # Ajouter UNIQUEMENT la regle PREROUTING (trafic ENTRANT de la box)
  if [ -n "$BOX_IP" ]; then
    iptables -t nat -I PREROUTING 1 -p tcp -s "$BOX_IP" --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>&1
    echo "[run.sh] iptables PREROUTING: 8883 -> $MQTT_PORT (source: $BOX_IP only)"
  else
    iptables -t nat -I PREROUTING 1 -p tcp --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>&1
    echo "[run.sh] iptables PREROUTING: 8883 -> $MQTT_PORT (all sources)"
  fi
  # PAS de regle OUTPUT : la connexion sortante bridge->Azure ne doit PAS etre redirigee

  echo "[run.sh] --- Verif iptables after apply ---"
  iptables -t nat -L PREROUTING -n -v 2>&1 | head -10 || true
  iptables -t nat -L OUTPUT -n -v 2>&1 | head -10 || true
else
  echo "[run.sh] MQTT port is already 8883, no redirect needed"
fi

echo "[run.sh] Starting FastAPI on port $WEB_PORT, MQTT on port $MQTT_PORT, mode=$MODE"
MODE_ARG=""
if [ -n "$MODE" ]; then
  MODE_ARG="--mode $MODE"
  # Ecrire le mode dans le fichier de persistance pour que le serveur le prenne en compte
  mkdir -p /app/logs
  echo "{\"mode\": \"$MODE\"}" > /app/logs/mode.json
fi
export HA_MQTT_USER="$ha_user"
export HA_MQTT_PASSWORD="$ha_pass"
HA_MQTT_HOST_ARG=""
HA_MQTT_PORT_ARG=""
if [ -n "$ha_host" ]; then
  HA_MQTT_HOST_ARG="--ha-mqtt-host $ha_host"
fi
if [ -n "$ha_port" ] && [ "$ha_port" != "1883" ]; then
  HA_MQTT_PORT_ARG="--ha-mqtt-port $ha_port"
fi
exec python3 -m server.main --mqtt-port "$MQTT_PORT" --web-port "$WEB_PORT" $MODE_ARG $HA_MQTT $HA_MQTT_DRY_RUN $HA_MQTT_HOST_ARG $HA_MQTT_PORT_ARG
