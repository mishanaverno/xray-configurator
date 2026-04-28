#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

LOCAL="/usr/local/share/xray"

CONF_NAME="xray-conf"
BOT_NAME="xray-bot"
CONF_IMAGE="mishanaverno/xray-conf:latest"
BOT_IMAGE="mishanaverno/xray-bot:latest"
SNI_LIST_NAME="sni_list"

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

validate_reality_hostname() {
    local reality="$1"

    if [[ "$reality" == *"://"* || "$reality" == *"/"* ]]; then
        echo "XRAY_REALITY must be a hostname, for example google.com" >&2
        exit 1
    fi

    if [[ ! "$reality" =~ ^[A-Za-z0-9.-]+$ ]]; then
        echo "XRAY_REALITY contains unsupported characters" >&2
        exit 1
    fi
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
        fi 
        echo "Initializing bot.env in $LOCAL/bot/bot"
        TOKEN=$(read_nonempty "Enter BOT_TOKEN value: ")
        CHAT=$(read_nonempty "Enter CHAT_ID value: ")
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

set_sni() {
    local reality="${1:-}"
    local vars_file="$LOCAL/conf/templates/variables.env"

    if [[ -z "$reality" ]]; then
        reality=$(read_nonempty "Enter XRAY_REALITY value: ")
    fi

    validate_reality_hostname "$reality"

    mkdir -p "$(dirname "$vars_file")"

    if [[ ! -f "$vars_file" ]]; then
        cat > "$vars_file" <<EOF
XRAY_LOG_LEVEL=warning
XRAY_REALITY=$reality
LINK1_TAG=VLESS_CONF
EOF
        return
    fi

    if grep -q '^XRAY_REALITY=' "$vars_file"; then
        sed -i "s/^XRAY_REALITY=.*/XRAY_REALITY=$reality/" "$vars_file"
    else
        printf '\nXRAY_REALITY=%s\n' "$reality" >> "$vars_file"
    fi
}

local_sni_list() {
    printf '%s/conf/templates/%s\n' "$LOCAL" "$SNI_LIST_NAME"
}

ensure_local_sni_list() {
    local sni_file
    sni_file="$(local_sni_list)"
    mkdir -p "$(dirname "$sni_file")"
    touch "$sni_file"
    printf '%s\n' "$sni_file"
}

add_sni_candidate() {
    local candidate="${1:-}"
    local sni_file

    if [[ -z "$candidate" ]]; then
        candidate=$(read_nonempty "Enter SNI candidate value: ")
    fi

    validate_reality_hostname "$candidate"
    sni_file="$(ensure_local_sni_list)"

    if grep -Fqx "$candidate" "$sni_file"; then
        echo "[xr-conf] SNI candidate already exists: $candidate"
        return
    fi

    printf '%s\n' "$candidate" >> "$sni_file"
    echo "[xr-conf] SNI candidate added: $candidate"
}

list_sni_candidates() {
    local sni_file
    sni_file="$(local_sni_list)"

    if [[ ! -f "$sni_file" ]]; then
        echo "[xr-conf] SNI list does not exist yet: $sni_file"
        return
    fi

    sed '/^[[:space:]]*$/d' "$sni_file"
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
    --set-sni [hostname]
    --add-sni [hostname]
    --list-sni
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
        --set-sni)
            if [[ "${2:-}" == --* ]]; then
                set_sni
                shift
            else
                set_sni "${2:-}"
                shift
                [[ $# -gt 0 ]] && shift
            fi
            ;;
        --add-sni)
            if [[ "${2:-}" == --* ]]; then
                add_sni_candidate
                shift
            else
                add_sni_candidate "${2:-}"
                shift
                [[ $# -gt 0 ]] && shift
            fi
            ;;
        --list-sni)
            list_sni_candidates
            shift
            ;;
        *)
            echo "unknown flag: $1"
            echo "run xr-conf"
            exit 1
            ;;
    esac
done
