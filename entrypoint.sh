#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

. /scripts/env.sh

mkdir -p "$TEMPLATES_DIR"

. /scripts/generate_secrets.sh

. /scripts/generate_templates.sh

. /scripts/generate_config.sh

. /scripts/update_geodat.sh

exec "$XRAY_BIN" -config "$VOLUME/$CONFIG_FILE"