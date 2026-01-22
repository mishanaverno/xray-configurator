#!/usr/bin/env bash
set -euo pipefail

LANG=C
LC_ALL=C

SCRIPT_URL="https://raw.githubusercontent.com/mishanaverno/xray-configurator/main/utils/xr-conf.sh"
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_PATH="$INSTALL_DIR/xr-conf"

LOCAL_OVERRIDE="${1:-}"

echo "Downloading xr-conf utility from GitHub..."

mkdir -p "$INSTALL_DIR"

tmp="$(mktemp -t xr-conf.XXXXXX)"
trap 'rm -f "$tmp"' EXIT

curl -fsSL "$SCRIPT_URL" -o "$tmp"

if [[ ! -s "$tmp" ]]; then
    echo "Download failed: received empty file" >&2
    exit 1
fi

if [[ -n "$LOCAL_OVERRIDE" ]]; then
    echo "LOCAL overrided to $LOCAL_OVERRIDE"
    esc="$(printf '%s' "$LOCAL_OVERRIDE" | sed -e 's/[\/&\\]/\\&/g')"
    sed -i "0,/^[[:space:]]*LOCAL[[:space:]]*=/{s/^[[:space:]]*LOCAL[[:space:]]*=.*/LOCAL=\"$esc\"/}" "$tmp"
fi

chmod +x "$tmp"
mv "$tmp" "$SCRIPT_PATH"

echo "Installed: $SCRIPT_PATH"

if ! command -v xr-conf >/dev/null 2>&1; then
    echo "Note: '$INSTALL_DIR' is not in PATH for new shells." >&2
    echo "Add this line to your shell config (~/.bashrc or ~/.profile):" >&2
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\"" >&2
fi
