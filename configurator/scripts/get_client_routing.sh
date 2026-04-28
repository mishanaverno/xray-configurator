#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh

LOG_FILE="$(mktemp -t xray-client-routing.XXXXXX)"

fail() {
  http_error
  say "$1"
  if [[ -s "$LOG_FILE" ]]; then
    cat "$LOG_FILE"
  fi
  exit 1
}

trap 'rm -f "$LOG_FILE"' EXIT

if ! source /scripts/env.sh >"$LOG_FILE" 2>&1; then
  fail "Failed to load env.sh"
fi

: "${TEMPLATES_DIR:?TEMPLATES_DIR is not set}"
: "${CLIENT_ROUTING_FILE:?CLIENT_ROUTING_FILE is not set}"

CLIENT_ROUTING_PATH="$TEMPLATES_DIR/$CLIENT_ROUTING_FILE"

if [[ ! -f "$CLIENT_ROUTING_PATH" ]]; then
  fail "Missing $CLIENT_ROUTING_PATH"
fi

if ! jq . "$CLIENT_ROUTING_PATH" >"$LOG_FILE" 2>&1; then
  fail "Invalid $CLIENT_ROUTING_FILE"
fi

http_ok
cat "$CLIENT_ROUTING_PATH"
