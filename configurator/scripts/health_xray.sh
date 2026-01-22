#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh

XRAY_PID_FILE=/tmp/xray.pid
XRAY_PORT=8443

fail() {
  http_error
  say "Xray unhealthy"
  say "$1"
  exit 1
}

# PID file exists?
if [[ ! -f "$XRAY_PID_FILE" ]]; then
  fail "Pid file not found"
fi

XRAY_PID="$(cat "$XRAY_PID_FILE" 2>/dev/null || true)"

if [[ -z "$XRAY_PID" ]]; then
  fail "Pid file is empty"
fi

# Process alive?
if ! kill -0 "$XRAY_PID" 2>/dev/null; then
  fail "Xray process is not running"
fi

# Port listening?
if ! ss -lntp 2>/dev/null | grep -q ":$XRAY_PORT .*pid=$XRAY_PID,"; then
  fail "Xray is not listening on port $XRAY_PORT"
fi

# Healthy
http_ok
say "Xray is healthy"