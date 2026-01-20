#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

CONF_NAME="xray-conf"
BOT_NAME="xray-bot"
CONF_IMAGE="mishanaverno/xray-conf:latest"
BOT_IMAGE="mishanaverno/xray-bot:latest"
LOCAL="/usr/local/share/xray-conf"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

install() {
    echo "[INFO] Starting the conteiner with xray..."
    docker run -d \
    --name $CONF_NAME \
    --network host \
    --restart unless-stopped \
    -v $LOCAL:/usr/share/xray/ \
    $CONF_IMAGE

    echo "[INFO] Starting the conteiner with monitoring bot..."
    docker run -d \
    --name $BOT_NAME \
    --network host \
    --restart unless-stopped \
    --env-file $LOCAL/bot.env \
    $BOT_IMAGE
}

uninstall() {
    docker stop $CONF_NAME
    docker rm -f $CONF_NAME
    docker rmi $CONF_IMAGE

    docker stop $BOT_NAME
    docker rm -f $BOT_NAME
    docker rmi $BOT_IMAGE
}

start() {
    echo "[INFO] Starting Xray..."
    curl -fsS http://127.0.0.1:8080/start >/dev/null
    health
}

restart() {
    echo "[INFO] Restarting Xray..."
    stop
    start
}

stop() {
    echo "[INFO] Stopping Xray..."
    curl -fsS http://127.0.0.1:8080/stop >/dev/null || true
    health
}

update() {
    echo "[INFO] Update geo files.."
    docker exec -u 0 $CONF_NAME bash -c "source /scripts/env.sh && /scripts/update_geodat.sh"
    stop
    start
}

links() {
    echo "[INFO] Looking for links..."
    docker exec -u 0 $CONF_NAME bash -c "source /scripts/env.sh && cat \$VOLUME/\$LINK_FILE"
}

health() {
    while IFS='|' read -r name container status; do
        if [[ "$name" == "$CONF_NAME" ]]; then
            echo -e "$status"
        fi
    done < <(docker ps -a --format "{{.Names}}|{{.Image}}|{{.Status}}") 
}


if [ $# -eq 0 ]; then
    cat <<'EOF'
Usage: xr-conf []
    --install:
        Starts containers with xray and monitoring bot
    --start:
        Starts xray
    --restart:
        Regenerates config.json and link.txt.
        Restarts xray
    --stop:
        Stops xray.
    --update:
        Update geo data files.
    --health:
        Health check.
    --links:
        Returns share links generated from link.txt template.
EOF
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install)
            install
            shift
            ;;
        --uninstall))
            uninstall
            shift
            ;;
        --start)
            start
            shift
            ;;
        --restart)
            restart
            shift
            ;;
        --stop)
            stop
            shift
            ;;
        --update)
            update
            shift
            ;;
        --health)
            health
            shift
            ;;
        --links)
            links
            shift
            ;;
        *)
            echo "unknown flag: $1"
            echo "run xr-conf"
            exit 1
            ;;
    esac
done
