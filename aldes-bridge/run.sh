#!/bin/bash
MQTT_PORT=18883
WEB_PORT=8080

if [ -f /data/options.json ]; then
  val=$(python3 -c "import json,sys; d=json.load(open('/data/options.json')); print(d.get('mqtt_port',''))" 2>/dev/null)
  [ -n "$val" ] && MQTT_PORT=$val
fi

exec python3 -m server.main --mqtt-port "$MQTT_PORT" --web-port "$WEB_PORT"
