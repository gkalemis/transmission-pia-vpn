#!/bin/sh
set -eu

rpc_url=http://127.0.0.1:9091/transmission/rpc
port_file=/gluetun/forwarded_port
headers_file=/tmp/transmission-headers
heartbeat_file=/tmp/port-forward-healthy
last_port=

while true; do
  if [ -r "$port_file" ]; then
    port="$(tr -cd '0-9' < "$port_file")"

    if [ -n "$port" ]; then
      curl --silent --show-error \
        --user "$TRANSMISSION_USER:$TRANSMISSION_PASS" \
        --dump-header "$headers_file" \
        --output /dev/null \
        --request POST \
        "$rpc_url" || true

      session_id="$(sed -n 's/^X-Transmission-Session-Id: *//Ip' "$headers_file" | tr -d '\r' | tail -n 1)"

      if [ -n "$session_id" ] && curl --fail --silent --show-error \
        --user "$TRANSMISSION_USER:$TRANSMISSION_PASS" \
        --header "X-Transmission-Session-Id: $session_id" \
        --header 'Content-Type: application/json' \
        --data "{\"method\":\"session-set\",\"arguments\":{\"peer-port\":$port}}" \
        "$rpc_url" >/dev/null; then
        touch "$heartbeat_file"
        if [ "$port" != "$last_port" ]; then
          echo "Transmission peer port updated to $port"
        fi
        last_port="$port"
      fi
    fi
  fi

  sleep 30
done
