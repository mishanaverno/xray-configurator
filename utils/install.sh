#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

SCRIPT_URL="https://raw.githubusercontent.com/mishanaverno/xray-configurator/main/utils/xr-conf.sh"
SCRIPT_PATH="/$HOME/.local/bin/xr-conf"

echo "Downloading xr-conf utility from GitHub..."

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
source $HOME/.bashrc

rm -f "$SCRIPT_PATH"
curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"
