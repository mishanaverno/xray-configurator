#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

for f in "$VARIABLES_FILE" "$INBOUND_FILE" "$OUTBOUND_FILE" "$ROUTING_FILE"; do
  if [[ ! -f "$TEMPLATES_DIR/$f" ]]; then
    cp "$DEFAULTS_DIR/$f" "$TEMPLATES_DIR/$f"
  else
    echo "[entrypoint] $f already exists"
  fi
done
