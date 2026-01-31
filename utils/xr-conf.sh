#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

LOCAL="/usr/local/share/xray"

CONF_NAME="xray-conf"
BOT_NAME="xray-bot"
CONF_IMAGE="mishanaverno/xray-conf:latest"
BOT_IMAGE="mishanaverno/xray-bot:latest"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

if [[ ! -f "$LOCAL" ]]; then
    echo "Initializing $LOCAL dir..."
    mkdir -p "$LOCAL"
else 
    echo "$LOCAL already exists."
fi

read_nonempty() {
  local prompt="$1" v
  while true; do
    read -rp "$prompt" v
    [ -n "$v" ] && { printf '%s' "$v"; return; }
    echo "Значение не может быть пустым."
  done
}

up_conf() {
    echo "[xr-conf] Starting the conteiner with xray..."
    docker pull $CONF_IMAGE
    docker run -d \
    --name $CONF_NAME \
    --network host \
    --restart unless-stopped \
    -v $LOCAL/conf:/usr/share/xray/ \
    $CONF_IMAGE
}

up_bot() {
    if [[ ! -f "$LOCAL/bot/bot.env" ]]; then
        if [[ ! -f "$LOCAL/bot" ]]; then
            echo "Initializing $LOCAL/bot dir..."
            mkdir -p "$LOCAL/bot"
            TOKEN=$(read_nonempty "Enter BOT_TOKEN value: ")
            CHAT=$(read_nonempty "Enter CHAT_ID value: ")
            
        else 
            echo "$LOCAL/bot already exists."
        fi
        echo "Initializing bot.env in $LOCAL/bot/bot"
        cat > "$LOCAL/bot/bot.env" <<EOF
BOT_TOKEN=$TOKEN
CHAT_ID=$CHAT
EOF
    else 
        echo "[xr-conf] bot.env already exists in $LOCAL/bot/bot.env"
    fi
    echo "[xr-conf] Starting the conteiner with monitoring bot..."
    docker pull $BOT_IMAGE
    docker run -d \
    --name $BOT_NAME \
    --network host \
    --restart unless-stopped \
    --env-file $LOCAL/bot/bot.env \
    $BOT_IMAGE
}

down_conf() {
    docker rm -f $CONF_NAME
}

down_bot() {
    docker rm -f $BOT_NAME
}

start_xray() {
    echo "[xr-conf] Starting Xray..."
    curl -s http://127.0.0.1:8080/start
    health_xray
}

stop_xray() {
    echo "[xr-conf] Stopping Xray..."
    curl -s http://127.0.0.1:8080/stop
    health_xray
}

health_xray() {
    echo "[xr-conf] CHecking Xray..."
    curl -s http://127.0.0.1:8080/health
}

restart_xray() {
    echo "[xr-conf] Restarting Xray..."
    stop_xray
    start_xray
}

update() {
    echo "[xr-conf] Update geo files.."
    curl -s http://127.0.0.1:8080/update
    restart_xray
}

links() {
    echo "[xr-conf] Looking for links..."
    curl -s http://127.0.0.1:8080/links
}


if [ $# -eq 0 ]; then
    cat <<'EOF'
Usage: xr-conf []
    --up-conf
    --down-conf
    --up-bot
    --down-bot
    --start-xray
    --stop-xray
    --restart-xray
    --health-xray
    --links
    --update-geo
EOF
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --up-conf)
            up_conf
            shift
            ;;
        --up-bot)
            up_bot
            shift
            ;;
         --down-conf)
            down_conf
            shift
            ;;
        --down-bot)
            down_bot
            shift
            ;;
        --start-xray)
            start_xray
            shift
            ;;
        --restart-xray)
            restart_xray
            shift
            ;;
        --stop-xray)
            stop_xray
            shift
            ;;
        --update-geo)
            update
            shift
            ;;
        --health-xray)
            health_xray
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
