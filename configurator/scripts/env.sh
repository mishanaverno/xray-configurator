#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

export XRAY_BIN=/usr/bin/xray
export VOLUME=/usr/share/xray
export PRESETS_DIR=/tmp/xray/presets
export XRAY_PRESET="${XRAY_PRESET:-reality}"
export DEFAULTS_DIR="$PRESETS_DIR/$XRAY_PRESET"
export TEMPLATES_DIR=$VOLUME/templates
export TEMPLATE_PRESET_FILE=.preset
export CONFIG_FILE=config.json
export VARIABLES_FILE=variables.env
export SECRETS_FILE=secrets.env
export INBOUND_FILE=inbound.json
export OUTBOUND_FILE=outbound.json
export ROUTING_FILE=routing.json
export CLIENT_ROUTING_FILE=client_routing.json
export LINK_FILE=link.txt
export SNI_LIST_FILE=sni_list
export SHORT_ID_PARAM=short_id
export BOT_ENV=bot.env
export RELAY_SSH_KEY_FILE="${RELAY_SSH_KEY_FILE:-$VOLUME/relay_control_ed25519}"
