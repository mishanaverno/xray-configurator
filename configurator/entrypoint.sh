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
    mkdir -p "$VOLUME"
else 
    say "$VOLUME already exists."
fi

chown -R nginx:nginx "$VOLUME"
chmod 2775 "$VOLUME"

if [[ -e "$TEMPLATES_DIR" && ! -d "$TEMPLATES_DIR" ]]; then
    say "[ERROR] $TEMPLATES_DIR exists and is not a directory" >&2
    exit 1
fi

if [[ ! -d "$TEMPLATES_DIR" ]]; then
    say "Initializing $TEMPLATES_DIR dir..."
    mkdir -p "$TEMPLATES_DIR"
else 
    say "$TEMPLATES_DIR already exists."
fi

chown -R nginx:nginx "$TEMPLATES_DIR"
chmod 2775 "$TEMPLATES_DIR"

/scripts/generate_secrets.sh

/scripts/generate_templates.sh

if [[ -f "$TEMPLATES_DIR/$VARIABLES_FILE" ]] && grep -Eq '^SLAVE_(SSH_HOST|HOST)=' "$TEMPLATES_DIR/$VARIABLES_FILE"; then
    /scripts/ensure_slave_ssh_key.sh
fi

chown -R nginx:nginx "$TEMPLATES_DIR"
chmod 2775 "$TEMPLATES_DIR"

NGINX_CONFIG="/tmp/xray/nginx/reality.conf"
if [[ ! -f "$NGINX_CONFIG" ]]; then
    say "[ERROR] nginx config does not exist: $NGINX_CONFIG" >&2
    exit 1
fi

if [[ -f "$TEMPLATES_DIR/$VARIABLES_FILE" ]]; then
    set -a
    . "$TEMPLATES_DIR/$VARIABLES_FILE"
    set +a
fi

say "Using nginx config: reality"
cp "$NGINX_CONFIG" /etc/nginx/nginx.conf

umask 002 && spawn-fcgi -s /var/run/fcgiwrap.sock -M 660 -u nginx -g nginx /usr/bin/fcgiwrap

(
    if ! /scripts/update_geodat.sh --plain; then
        say "[WARN] geodat update failed; keeping existing geo files"
    fi
) &

exec nginx -g "daemon off;"
