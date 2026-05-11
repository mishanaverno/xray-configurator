#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh

LOG_FILE="$(mktemp -t xray-restart.XXXXXX)"

fail() {
  http_error
  say "Xray restart failed"
  say "$1"
  cat "$LOG_FILE"
  exit 1
}

trap 'rm -f "$LOG_FILE"' EXIT

if ! curl -fsS --max-time 20 http://127.0.0.1:8080/stop >"$LOG_FILE" 2>&1; then
  fail "Stop request failed"
fi

if ! curl -fsS --max-time 90 http://127.0.0.1:8080/start >>"$LOG_FILE" 2>&1; then
  fail "Start request failed"
fi

http_ok
say "Xray restarted"
cat "$LOG_FILE"
