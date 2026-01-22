#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

source /scripts/lib.sh

say "Updating geo files..."
rm -f $VOLUME/geosite.dat
rm -f $VOLUME/geoip.dat
wget -O $VOLUME/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat
wget -O $VOLUME/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
say "Complete! geo files updated."
