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

say "Updating geo files..."
rm -f $VOLUME/geosite.dat
rm -f $VOLUME/geoip.dat
wget -O $VOLUME/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat
wget -O $VOLUME/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
chmod 664 $VOLUME/geosite.dat
chmod 664 $VOLUME/geoip.dat
say "Complete! geo files updated."

http_ok
say "Complete! geo files updated."
