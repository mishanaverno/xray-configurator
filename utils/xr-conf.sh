#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

LOCAL="/usr/local/share/xray-conf"

CONF_NAME="xray-conf"
BOT_NAME="xray-bot"
CONF_IMAGE="mishanaverno/xray-conf:latest"
BOT_IMAGE="mishanaverno/xray-bot:latest"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

up_conf() {
    echo "[xr-conf] Starting the conteiner with xray..."
    docker run -d \
    --name $CONF_NAME \
    --network host \
    --restart unless-stopped \
    -v $LOCAL:/usr/share/xray/ \
    $CONF_IMAGE
}

up_bot() {
    echo "[xr-conf] Starting the conteiner with monitoring bot..."
    docker run -d \
    --name $BOT_NAME \
    --network host \
    --restart unless-stopped \
    --env-file $LOCAL/bot.env \
    $BOT_IMAGE
}

down_conf() {
    docker stop $CONF_NAME
    docker rm -f $CONF_NAME
    docker rmi $CONF_IMAGE
}

down_bot() {
    docker stop $BOT_NAME
    docker rm -f $BOT_NAME
    docker rmi $BOT_IMAGE
}

start_xray() {
    echo "[xr-conf] Starting Xray..."
    curl -fsS http://127.0.0.1:8080/start
    health
}

stop_xray() {
    echo "[xr-conf] Stopping Xray..."
    curl -fsS http://127.0.0.1:8080/stop
    health
}

restart() {
    echo "[xr-conf] Restarting Xray..."
    stop
    start
}

update() {
    echo "[xr-conf] Update geo files.."
    docker exec -u 0 $CONF_NAME bash -c "source /scripts/env.sh && /scripts/update_geodat.sh"
    stop
    start
}

links() {
    echo "[xr-conf] Looking for links..."
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
        --up_conf)
            up_conf
            shift
            ;;
        --up_bot)
            up_bot
            shift
            ;;
         --down_conf)
            down_conf
            shift
            ;;
        --down_bot)
            down_bot
            shift
            ;;
        --start_xray)
            start_xray
            shift
            ;;
        --restart_xray)
            restart_xray
            shift
            ;;
        --stop_xray)
            stop_xray
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
