#!/usr/bin/env bash
set -euo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh

say "Building default templates..."

if [[ ! -d "$DEFAULTS_DIR" ]]; then
    say "[ERROR] default template does not exist: $DEFAULTS_DIR" >&2
  exit 1
fi

required_files=("$VARIABLES_FILE" "$INBOUND_FILE" "$OUTBOUND_FILE" "$ROUTING_FILE")
optional_files=("$CLIENT_ROUTING_FILE" "$LINK_FILE" "$SNI_LIST_FILE" ".preset" ".role")

for f in "${required_files[@]}"; do
  if [[ ! -f "$DEFAULTS_DIR/$f" ]]; then
    say "[ERROR] default template is missing required file: $f" >&2
    exit 1
  fi

  if [[ ! -f "$TEMPLATES_DIR/$f" ]]; then
    cp "$DEFAULTS_DIR/$f" "$TEMPLATES_DIR/$f"
    chmod 666 "$TEMPLATES_DIR/$f"
  else
    say "$f already exists"
  fi
done

for f in "${optional_files[@]}"; do
  if [[ -f "$DEFAULTS_DIR/$f" ]]; then
    if [[ ! -f "$TEMPLATES_DIR/$f" ]]; then
      cp "$DEFAULTS_DIR/$f" "$TEMPLATES_DIR/$f"
      chmod 666 "$TEMPLATES_DIR/$f"
    else
      say "$f already exists"
    fi
  fi
done
