#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh

LOG_FILE="$(mktemp -t xray-geodat.XXXXXX)"
GEOSITE_TMP=""
GEOIP_TMP=""
PLAIN_OUTPUT=false

if [[ "${1:-}" == "--plain" ]]; then
  PLAIN_OUTPUT=true
fi

fail() {
  if [[ "$PLAIN_OUTPUT" != "true" ]]; then
    http_error
  fi
  say "Request failed"
  say "$1"
  cat "$LOG_FILE"
  exit 1
}

cleanup() {
  rm -f "$LOG_FILE"
  [[ -z "$GEOSITE_TMP" ]] || rm -f "$GEOSITE_TMP"
  [[ -z "$GEOIP_TMP" ]] || rm -f "$GEOIP_TMP"
}

trap cleanup EXIT
# env
if ! source /scripts/env.sh >"$LOG_FILE" 2>&1; then
  fail "Failed to load env.sh"
fi

: "${VOLUME:?VOLUME is not set}"

if ! GEOSITE_TMP="$(mktemp "$VOLUME/geosite.dat.XXXXXX" 2>>"$LOG_FILE")"; then
  fail "Failed to create temporary geosite.dat"
fi

if ! GEOIP_TMP="$(mktemp "$VOLUME/geoip.dat.XXXXXX" 2>>"$LOG_FILE")"; then
  fail "Failed to create temporary geoip.dat"
fi

if ! wget -O "$GEOSITE_TMP" https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat >>"$LOG_FILE" 2>&1; then
  fail "Failed to download geosite.dat"
fi

if ! wget -O "$GEOIP_TMP" https://github.com/v2fly/geoip/releases/latest/download/geoip.dat >>"$LOG_FILE" 2>&1; then
  fail "Failed to download geoip.dat"
fi

chmod 664 "$GEOSITE_TMP" "$GEOIP_TMP"
mv -f "$GEOSITE_TMP" "$VOLUME/geosite.dat"
GEOSITE_TMP=""
mv -f "$GEOIP_TMP" "$VOLUME/geoip.dat"
GEOIP_TMP=""

if [[ "$PLAIN_OUTPUT" != "true" ]]; then
  http_ok
fi
say "Complete! geo files updated."
