#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh
source /scripts/env.sh

XRAY_PID_FILE=/tmp/xray.pid
LOG_FILE="$(mktemp -t xray-health.XXXXXX)"

fail() {
  http_error
  say "Xray unhealthy"
  say "$1"
  if [[ -s "$LOG_FILE" ]]; then
    cat "$LOG_FILE"
  fi
  exit 1
}

trap 'rm -f "$LOG_FILE"' EXIT

if [[ -f "$TEMPLATES_DIR/$VARIABLES_FILE" ]]; then
  set -a
  . "$TEMPLATES_DIR/$VARIABLES_FILE"
  set +a
fi

if [[ "$XRAY_PRESET" == "xhttp_relay" ]]; then
  XRAY_PORT=1050
else
  XRAY_PORT=8443
fi

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

if [[ "$XRAY_PRESET" == reality* ]]; then
  if ! /scripts/ensure_reality.sh --check-only >"$LOG_FILE" 2>&1; then
    fail "XRAY_REALITY TLS check failed"
  fi
else
  say "Skipping Reality/SNI check for preset: $XRAY_PRESET" >"$LOG_FILE"
fi

# Healthy
http_ok
say "Xray is healthy"
cat "$LOG_FILE"
