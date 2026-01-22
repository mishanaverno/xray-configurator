#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

export XRAY_BIN=/usr/bin/xray
export VOLUME=/usr/share/xray
export DEFAULTS_DIR=/tmp/xray/templates
export TEMPLATES_DIR=$VOLUME/templates
export CONFIG_FILE=config.json
export VARIABLES_FILE=variables.env
export SECRETS_FILE=secrets.env
export INBOUND_FILE=inbound.json
export OUTBOUND_FILE=outbound.json
export ROUTING_FILE=routing.json
export LINK_FILE=link.txt
export BOT_ENV=bot.env
