#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh

XRAY_PID_FILE=/tmp/xray.pid

fail() {
  http_error
  say "Xray stop failed"
  say "$1"
  exit 1
}

# PID file exists?
if [[ ! -f "$XRAY_PID_FILE" ]]; then
  http_ok
  say "Xray is not running"
  exit 0
fi

XRAY_PID="$(cat "$XRAY_PID_FILE" 2>/dev/null || true)"

if [[ -z "$XRAY_PID" ]]; then
  http_error
  say "Xray stop failed"
  say "Pid file is empty"
  rm -f "$XRAY_PID_FILE"
  exit 1
fi

# Process alive?
if ! kill -0 "$XRAY_PID" 2>/dev/null; then
  http_ok
  say "Stale pid file found"
  rm -f "$XRAY_PID_FILE"
  exit 0
fi

# Try graceful stop
kill "$XRAY_PID"

# Wait a bit
for _ in {1..10}; do
  if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    rm -f "$XRAY_PID_FILE"
    http_ok
    say "Xray stopped"
    exit 0
  fi
  sleep 0.3
done

# Still alive → hard kill
kill -9 "$XRAY_PID" 2>/dev/null || true
rm -f "$XRAY_PID_FILE"

http_ok
say "Xray stopped forcefully"
