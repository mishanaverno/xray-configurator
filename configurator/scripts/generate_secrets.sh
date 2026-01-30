#!/usr/bin/env bash
set -euo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh

if [[ ! -f "$VOLUME/$SECRETS_FILE" ]]; then
  say "Generating fresh UUID and x25519..."
  data=$("$XRAY_BIN" x25519 | tr -d $'\r')
  priv=$(echo "$data" | awk -F': ' '/^PrivateKey:/ {gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2}')
  pass=$(echo "$data" | awk -F': ' '/^Password:/   {gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2}')
  uuid="$("$XRAY_BIN" uuid | tr -d $'\r' | head -n1)"
  host_ip=$(hostname -i | awk '{print $1}')
  say "Server accessible at: $host_ip:<port>"
  say "Secrets generated: UUID=$uuid PUB_KEY=$pass PRIV_KEY=$priv"

  cat > "$VOLUME/$SECRETS_FILE" <<EOF
XRAY_UUID=$uuid
XRAY_PRIVATE_KEY=$priv
XRAY_PUBLIC_KEY=$pass
XRAY_HOST_IP=$host_ip
EOF
  chmod 664 "$VOLUME/$SECRETS_FILE"
else
  say "secrets.env already exists"
fi
