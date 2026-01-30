#!/usr/bin/env bash
set -euo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh

say "Building default templates..."
for f in "$VARIABLES_FILE" "$INBOUND_FILE" "$OUTBOUND_FILE" "$ROUTING_FILE" "$LINK_FILE"; do
  if [[ ! -f "$TEMPLATES_DIR/$f" ]]; then
    cp "$DEFAULTS_DIR/$f" "$TEMPLATES_DIR/$f"
    chmod 766 "$TEMPLATES_DIR/$f"
  else
    say "$f already exists"
  fi
done
