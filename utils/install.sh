#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

SCRIPT_URL="https://raw.githubusercontent.com/mishanaverno/xray-configurator/main/utils/xr-conf.sh"
SCRIPT_PATH="/usr/local/bin/xr-conf"
LOCAL="/usr/local/share/xray-conf"
BOT_ENV="bot.env"

echo "[INFO] Initilizing $LOCAL..."
mkdir -p $LOCAL
if [[ ! -f "$LOCAL/$BOT_ENV" ]]; then
    echo "[INFO] Initializing $BOT_ENV in $LOCAL"
    cat > "$LOCAL/$BOT_ENV" <<EOF
BOT_TOKEN=
CHAT_ID=
EOF
    chmod 666 "$LOCAL/$BOT_ENV" || true
else 
    echo "[INFO] $BOT_ENV already exists in $LOCAL"
fi

echo "[INFO] Downloading xr-conf utility from GitHub..."
rm -f "$SCRIPT_PATH"
curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"
