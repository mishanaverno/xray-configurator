#!/usr/bin/env bash
set -euo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh

say "Building default templates..."

if [[ ! "$XRAY_PRESET" =~ ^[A-Za-z0-9_-]+$ ]]; then
  say "[ERROR] invalid XRAY_PRESET: $XRAY_PRESET" >&2
  exit 1
fi

if [[ ! -d "$DEFAULTS_DIR" ]]; then
  say "[ERROR] preset does not exist: $XRAY_PRESET" >&2
  say "[ERROR] available presets:" >&2
  for preset_dir in "$PRESETS_DIR"/*; do
    [[ -d "$preset_dir" ]] && say "  $(basename "$preset_dir")" >&2
  done
  exit 1
fi

current_preset=""
if [[ -f "$TEMPLATES_DIR/$TEMPLATE_PRESET_FILE" ]]; then
  current_preset="$(cat "$TEMPLATES_DIR/$TEMPLATE_PRESET_FILE")"
fi

required_files=("$VARIABLES_FILE" "$INBOUND_FILE" "$OUTBOUND_FILE" "$ROUTING_FILE")
optional_files=("$CLIENT_ROUTING_FILE" "$LINK_FILE" "$SNI_LIST_FILE")

has_existing_templates=false
for f in "${required_files[@]}" "${optional_files[@]}"; do
  [[ -f "$TEMPLATES_DIR/$f" ]] && has_existing_templates=true
done

if [[ -n "$current_preset" && "$current_preset" != "$XRAY_PRESET" ]] || [[ -z "$current_preset" && "$XRAY_PRESET" != "reality" && "$has_existing_templates" == "true" ]]; then
  backup_dir="$VOLUME/templates.backup.$(date +%Y%m%d%H%M%S)"
  say "Applying preset: ${current_preset:-legacy} -> $XRAY_PRESET. Backing up templates to $backup_dir"
  mv "$TEMPLATES_DIR" "$backup_dir"
  mkdir -p "$TEMPLATES_DIR"
fi

for f in "${required_files[@]}"; do
  if [[ ! -f "$DEFAULTS_DIR/$f" ]]; then
    say "[ERROR] preset $XRAY_PRESET is missing required template: $f" >&2
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

printf '%s\n' "$XRAY_PRESET" > "$TEMPLATES_DIR/$TEMPLATE_PRESET_FILE"
chmod 666 "$TEMPLATES_DIR/$TEMPLATE_PRESET_FILE"
