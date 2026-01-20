#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

source /scripts/env.sh

mkdir -p "$TEMPLATES_DIR"

/scripts/generate_secrets.sh

/scripts/generate_templates.sh

/scripts/update_geodat.sh

spawn-fcgi -s /var/run/fcgiwrap.sock /usr/bin/fcgiwrap

exec nginx -g "daemon off;"
