#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh

LOG_FILE="$(mktemp -t xray-gen.XXXXXX)"

fail() {
  http_error
  say "Request filed"
  say "$1"
  cat "$LOG_FILE"
  exit 1
}

trap 'rm -f "$LOG_FILE"' EXIT
# env
if ! source /scripts/env.sh >"$LOG_FILE" 2>&1; then
  fail "Failed to load env.sh"
fi

: "${LINK_FILE:?LINK_FILE is not set}"

LINK_PATH="$VOLUME/$LINK_FILE"

http_ok
cat "$LINK_PATH"
