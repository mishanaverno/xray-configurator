#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

SCRIPT_URL="https://raw.githubusercontent.com/mishanaverno/xray-configurator/main/xray/xr-conf.sh"
SCRIPT_PATH="/usr/local/bin/xr-conf"

mkdir -p /usr/local/share/xray-conf

echo "[INFO] Downloading xr-conf utility from GitHub..."
rm -f "$SCRIPT_PATH"
curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"
