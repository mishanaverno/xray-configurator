#!/usr/bin/env bash
set -euo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh

if [[ ! -f "$VOLUME/$SECRETS_FILE" ]]; then
  say "Generating fresh UUID and x25519..."
  data=$("$XRAY_BIN" x25519 | tr -d $'\r')
  priv=$(printf '%s\n' "$data" | awk -F': *' 'tolower($1) ~ /private[[:space:]]*key/ || $1 == "PrivateKey" {gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}')
  pass=$(printf '%s\n' "$data" | awk -F': *' 'tolower($1) ~ /public[[:space:]]*key/ || $1 == "Password" {gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}')
  uuid="$("$XRAY_BIN" uuid | tr -d $'\r' | head -n1)"
  host_ip=$(hostname -i | awk '{print $1}')

  if [[ -z "$priv" || -z "$pass" || -z "$uuid" ]]; then
    say "[ERROR] failed to parse xray secrets" >&2
    printf '%s\n' "$data" >&2
    exit 1
  fi

  say "Server accessible at: $host_ip:<port>"
  say "Secrets generated: UUID=$uuid PUB_KEY=$pass"

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
