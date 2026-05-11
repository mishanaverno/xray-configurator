#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

export XRAY_BIN=/usr/bin/xray
export VOLUME=/usr/share/xray
export BUILTIN_PRESET_DIR=/preset
export PRESET_DIR=$VOLUME/preset
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
export SLAVE_SSH_KEY_FILE="${SLAVE_SSH_KEY_FILE:-$VOLUME/slave_control_ed25519}"
