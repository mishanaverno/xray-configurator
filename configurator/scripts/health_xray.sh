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
if command -v timeout >/dev/null 2>&1; then
  timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/$XRAY_PORT" >/dev/null 2>&1 \
    || fail "Xray port $XRAY_PORT is not reachable on 127.0.0.1"
else
  # без timeout (может потенциально зависнуть в экзотических случаях)
  ( echo >/dev/tcp/127.0.0.1/$XRAY_PORT ) >/dev/null 2>&1 \
    || fail "Xray port $XRAY_PORT is not reachable on 127.0.0.1"
fi

# Healthy
http_ok
say "Xray is healthy"