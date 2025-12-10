#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

echo "[generate_templates] Building default templates"
for f in "$VARIABLES_FILE" "$INBOUND_FILE" "$OUTBOUND_FILE" "$ROUTING_FILE" "$LINK_FILE"; do
  if [[ ! -f "$TEMPLATES_DIR/$f" ]]; then
    cp "$DEFAULTS_DIR/$f" "$TEMPLATES_DIR/$f"
  else
    echo "[generate_templates] $f already exists"
  fi
done
