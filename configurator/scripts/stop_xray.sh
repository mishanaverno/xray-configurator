#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

XRAY_PID_FILE=/var/run/xray.pid

if [[ ! -f "$XRAY_PID_FILE" ]]; then
  echo "[stop_xray] Xray is not running"
  exit 0
fi

XRAY_PID=$(cat "$XRAY_PID_FILE")
if kill -0 "$XRAY_PID" 2>/dev/null; then
  echo "[stop_xray] Stopping Xray..."
  kill "$XRAY_PID"
else
  echo "[stop_xray] Stale PID file found"
fi

rm -f "$XRAY_PID_FILE"
