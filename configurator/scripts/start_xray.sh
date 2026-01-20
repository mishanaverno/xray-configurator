#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

XRAY_PID_FILE=/var/run/xray.pid

source /scripts/env.sh

if [[ -f "$XRAY_PID_FILE" ]] && kill -0 "$(cat "$XRAY_PID_FILE")" 2>/dev/null; then
  echo "[start_xray] Xray already running"
  exit 0
fi

rm -f "$XRAY_PID_FILE"
mkdir -p "$(dirname "$XRAY_PID_FILE")"

/scripts/generate_config.sh

echo "[start_xray] Starting Xray..."
"$XRAY_BIN" -config "$VOLUME/$CONFIG_FILE" >/var/log/xray.log 2>&1 &
echo $! > "$XRAY_PID_FILE"
