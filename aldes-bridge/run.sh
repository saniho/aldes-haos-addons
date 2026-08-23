#!/bin/bash
MQTT_PORT=18883
WEB_PORT=8080

if [ -f /data/options.json ]; then
  val=$(python3 -c "import json,sys; d=json.load(open('/data/options.json')); print(d.get('mqtt_port',''))" 2>/dev/null)
  [ -n "$val" ] && MQTT_PORT=$val
fi

# Redirige le port 8883 vers le port MQTT si besoin
if [ "$MQTT_PORT" != "8883" ]; then
  iptables -t nat -A PREROUTING -p tcp --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>/dev/null
  ip6tables -t nat -A PREROUTING -p tcp --dport 8883 -j REDIRECT --to-port "$MQTT_PORT" 2>/dev/null
  echo "[run.sh] iptables: 8883 -> $MQTT_PORT"
fi

exec python3 -m server.main --mqtt-port "$MQTT_PORT" --web-port "$WEB_PORT"
