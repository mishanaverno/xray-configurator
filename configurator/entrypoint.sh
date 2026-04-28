#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

source /scripts/env.sh
source /scripts/lib.sh

if [[ -e "$VOLUME" && ! -d "$VOLUME" ]]; then
    say "[ERROR] $VOLUME exists and is not a directory" >&2
    exit 1
fi

if [[ ! -d "$VOLUME" ]]; then
    say "Initializing $VOLUME dir..."
    mkdir -p "$VOLUME" && chown -R root:xray "$VOLUME" && chmod 2775 "$VOLUME"
else 
    say "$VOLUME already exists."
fi

if [[ -e "$TEMPLATES_DIR" && ! -d "$TEMPLATES_DIR" ]]; then
    say "[ERROR] $TEMPLATES_DIR exists and is not a directory" >&2
    exit 1
fi

if [[ ! -d "$TEMPLATES_DIR" ]]; then
    say "Initializing $TEMPLATES_DIR dir..."
    mkdir -p "$TEMPLATES_DIR" && chmod 2777 "$TEMPLATES_DIR"
else 
    say "$TEMPLATES_DIR already exists."
fi

/scripts/generate_secrets.sh

/scripts/generate_templates.sh

if ! /scripts/update_geodat.sh --plain; then
    say "[WARN] geodat update failed; keeping existing geo files"
fi

umask 002 && spawn-fcgi -s /var/run/fcgiwrap.sock -M 660 -u nginx -g nginx /usr/bin/fcgiwrap

exec nginx -g "daemon off;"
