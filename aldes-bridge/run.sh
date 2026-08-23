#!/bin/bash
MQTT_PORT=18883
WEB_PORT=8080
BOX_IP=""

if [ -f /data/options.json ]; then
  val=$(python3 -c "import json,sys; d=json.load(open('/data/options.json')); print(d.get('mqtt_port',''))" 2>/dev/null)
  [ -n "$val" ] && MQTT_PORT=$val
  bip=$(python3 -c "import json,sys; d=json.load(open('/data/options.json')); print(d.get('box_ip',''))" 2>/dev/null)
  [ -n "$bip" ] && BOX_IP=$bip
fi

echo "[run.sh] MQTT_PORT=$MQTT_PORT, WEB_PORT=$WEB_PORT, BOX_IP=$BOX_IP"

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
# la règle AVANT la chaîne DOCKER qui intercepte tout le trafic local.
if [ "$MQTT_PORT" != "8883" ]; then
  if [ -n "$BOX_IP" ]; then
    iptables -t nat -I PREROUTING 1 -p tcp -s "$BOX_IP" --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>&1
    ip6tables -t nat -I PREROUTING 1 -p tcp -s "$BOX_IP" --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>&1
    echo "[run.sh] iptables PREROUTING: 8883 -> $MQTT_PORT (source: $BOX_IP only)"
  else
    iptables -t nat -I PREROUTING 1 -p tcp --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>&1
    ip6tables -t nat -I PREROUTING 1 -p tcp --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>&1
    echo "[run.sh] iptables PREROUTING: 8883 -> $MQTT_PORT (all sources)"
  fi
  if [ -n "$BOX_IP" ]; then
    iptables -t nat -I OUTPUT 1 -p tcp -s "$BOX_IP" --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>&1
  else
    iptables -t nat -I OUTPUT 1 -p tcp --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>&1
  fi
  echo "[run.sh] iptables OUTPUT: 8883 -> $MQTT_PORT (local traffic)"

  echo "[run.sh] --- Verif iptables after apply ---"
  iptables -t nat -L PREROUTING -n -v 2>&1 | head -10 || true
else
  echo "[run.sh] MQTT port is already 8883, no redirect needed"
fi

echo "[run.sh] Starting FastAPI on port $WEB_PORT, MQTT on port $MQTT_PORT"
exec python3 -m server.main --mqtt-port "$MQTT_PORT" --web-port "$WEB_PORT"
