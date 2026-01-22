#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh

XRAY_PID_FILE=/tmp/xray.pid
XRAY_LOG=/tmp/xray.log
LOG_FILE="$(mktemp -t xray-gen.XXXXXX)"

fail() {
  http_error
  say "Xray start failed"
  say "$1"
  cat "$LOG_FILE"
  exit 1
}

trap 'rm -f "$LOG_FILE"' EXIT
# env
if ! source /scripts/env.sh >"$LOG_FILE" 2>&1; then
  fail "Failed to load env.sh"
fi

: "${XRAY_BIN:?XRAY_BIN is not set}"
: "${VOLUME:?VOLUME is not set}"
: "${CONFIG_FILE:?CONFIG_FILE is not set}"

CFG_PATH="$VOLUME/$CONFIG_FILE"

# Already running?
if [[ -f "$XRAY_PID_FILE" ]] && kill -0 "$(cat "$XRAY_PID_FILE")" 2>/dev/null; then
  http_ok
  say "Xray already running"
  exit 0
fi

rm -f "$XRAY_PID_FILE"

# generate_config — буферизуем, но не трогаем вывод
if ! /scripts/generate_config.sh >"$LOG_FILE" 2>&1; then
  http_error
  say "Xray start failed"
  say "Generate config failed"
  cat "$LOG_FILE"
  exit 1
fi

# start xray
"$XRAY_BIN" -config "$CFG_PATH" >>"$XRAY_LOG" 2>&1 &
XRAY_PID=$!

sleep 0.5
if ! kill -0 "$XRAY_PID" 2>/dev/null; then
  http_error
  say "Xray start failed"
  say "Xray exited immediately"
  say "Generate config output:"
  cat "$LOG_FILE"
  exit 1
fi

echo "$XRAY_PID" >"$XRAY_PID_FILE"

http_ok
say "Xray started (pid=$XRAY_PID)"
say "Generate config output:"
cat "$LOG_FILE"
