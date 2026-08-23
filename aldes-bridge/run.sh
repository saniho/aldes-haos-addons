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

# Redirige le port 8883 vers le port MQTT si besoin
if [ "$MQTT_PORT" != "8883" ]; then
  if [ -n "$BOX_IP" ]; then
    iptables -t nat -A PREROUTING -p tcp -s "$BOX_IP" --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>/dev/null
    ip6tables -t nat -A PREROUTING -p tcp -s "$BOX_IP" --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>/dev/null
    echo "[run.sh] iptables PREROUTING: 8883 -> $MQTT_PORT (source: $BOX_IP only)"
  else
    iptables -t nat -A PREROUTING -p tcp --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>/dev/null
    ip6tables -t nat -A PREROUTING -p tcp --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>/dev/null
    echo "[run.sh] iptables PREROUTING: 8883 -> $MQTT_PORT (all sources)"
  fi
  # PREROUTING ne catche pas le trafic depuis la HAOS elle-meme.
  # Ajoute aussi OUTPUT pour que le redirect fonctionne si la box
  # est sur le meme sous-reseau (trafic "local" vu par le noyau).
  if [ -n "$BOX_IP" ]; then
    iptables -t nat -A OUTPUT -p tcp -s "$BOX_IP" --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>/dev/null
  else
    iptables -t nat -A OUTPUT -p tcp --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>/dev/null
  fi
  echo "[run.sh] iptables OUTPUT: 8883 -> $MQTT_PORT (local traffic)"
fi

echo "[run.sh] Starting FastAPI on port $WEB_PORT, MQTT on port $MQTT_PORT"
exec python3 -m server.main --mqtt-port "$MQTT_PORT" --web-port "$WEB_PORT"
