#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

XRAY_BIN=/usr/bin/xray
VOLUME=/usr/share/xray
DEFAULTS_DIR=/tmp/xray/templates
TEMPLATES_DIR=$VOLUME/templates
SCRIPTS_DIR=$VOLUME/scripts
CONFIG_FILE=config.json
VARIABLES_FILE=variables.env
SECRETS_FILE=secrets.env
INBOUND_FILE=inbound.json
OUTBOUND_FILE=outbound.json
ROUTING_FILE=routing.json
