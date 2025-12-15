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

start() {
    echo "[INFO] Starting the conteiner..."
    docker run -d --name $CONF_NAME --network host -v $LOCAL:/usr/share/xray/ $CONF_IMAGE
    helth
}

restart() {
    echo "[INFO] Restarting the container..."
    docker exec -u 0 $CONF_NAME bash -c "source /scripts/env.sh && /scripts/generate_config.sh"
    stop
    start
}

stop() {
    echo "[INFO] Stopping the service..."
    docker stop $CONF_IMAGE
    helth
    docker rm -f $CONF_NAME
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

clean() {
    docker exec -u 0 $CONF_NAME bash -c "source /scripts/env.sh && cat rm -rf \$VOLUME/"
    stop
    docker rmi $CONF_IMAGE 
}

startbot() {
    docker run -d \
    --name $BOT_NAME \
    --restart unless-stopped \
    --env-file $LOCAL/bot.env \
    -v /usr/local/bin/xr-conf:/usr/bin/xr-conf:ro \
    -v /proc:/host/proc:ro \
    $BOT_IMAGE
}

stopbot() {
    docker stop $BOT_NAME
    docker rm -f $BOT_NAME
}

if [ $# -eq 0 ]; then
    cat <<'EOF'
Usage: xr-conf [--start|--restart|--stop|--update]
    --start:
        Starts container with mounthed volume at ./xray-conf. 
        Create default templates for inbound, outbound, routing in volume.
        Generates config.json from template files.
        Generate link.txt with vless link for vpn clients.
    --restart:
        Regenerates config.json and link.txt.
    --stop:
        Stops container.
    --update:
        Update geo data files.
    --health:
        Conteiner health check.
    --links:
        Returns share links generated from link.txt template.
    --clean:
        Remove local volume files and docker image.
EOF
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
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
        --clean)
            clean
            shift
            ;;
        --startbot)
            startbot
            shift
            ;;
        --stopbot)
            stopbot
            shift
            ;;
        *)
            echo "unknown flag: $1"
            echo "run xr-conf"
            exit 1
            ;;
    esac
done
