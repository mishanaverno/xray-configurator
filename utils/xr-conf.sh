#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

LOCAL="/usr/local/share/xray"

CONF_NAME="xray-conf"
BOT_NAME="xray-bot"
MTPROTO_NAME="mtproto-proxy"
CONF_IMAGE="mishanaverno/xray-conf:latest"
BOT_IMAGE="mishanaverno/xray-bot:latest"
MTPROTO_IMAGE="${MTPROTO_IMAGE:-telegrammessenger/proxy:latest}"
MTPROTO_PORT="${MTPROTO_PORT:-9443}"
SNI_LIST_NAME="sni_list"
RELAY_SSH_KEY_NAME="relay_control_ed25519"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

ensure_dir() {
    local dir="$1"

    if [[ -e "$dir" && ! -d "$dir" ]]; then
        echo "[xr-conf] ERROR: $dir exists and is not a directory" >&2
        exit 1
    fi

    if [[ ! -d "$dir" ]]; then
        echo "[xr-conf] Initializing $dir dir..."
        mkdir -p "$dir"
    fi
}

ensure_local_dirs() {
    ensure_dir "$LOCAL"
    ensure_dir "$LOCAL/conf"
    ensure_dir "$LOCAL/bot"
    ensure_dir "$LOCAL/bot-data"
}

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
    local preset="${1:-reality}"

    if [[ ! "$preset" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "[xr-conf] ERROR: invalid preset: $preset" >&2
        exit 1
    fi

    ensure_local_dirs
    echo "[xr-conf] Starting the conteiner with xray preset: $preset"
    docker pull $CONF_IMAGE
    docker run -d \
    --name $CONF_NAME \
    --network host \
    --restart unless-stopped \
    -e XRAY_PRESET="$preset" \
    -v $LOCAL/conf:/usr/share/xray/ \
    $CONF_IMAGE
}

up_bot() {
    ensure_local_dirs
    if [[ ! -f "$LOCAL/bot/bot.env" ]]; then
        echo "Initializing bot.env in $LOCAL/bot/bot.env"
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
    -v $LOCAL/bot-data:/data \
    $BOT_IMAGE
}

down_conf() {
    docker rm -f $CONF_NAME
}

down_bot() {
    docker rm -f $BOT_NAME
}

up_mtproto() {
    echo "[xr-conf] Starting MTProto proxy on port $MTPROTO_PORT..."
    if command -v ss >/dev/null 2>&1 && ss -ltn "( sport = :$MTPROTO_PORT )" | grep -q ":$MTPROTO_PORT"; then
        echo "[xr-conf] ERROR: port $MTPROTO_PORT is already in use." >&2
        echo "[xr-conf] Try another port: MTPROTO_PORT=9443 xr-conf --up-mtproto" >&2
        return 1
    fi
    docker pull "$MTPROTO_IMAGE" || echo "[xr-conf] Pull failed; trying local image $MTPROTO_IMAGE"
    docker rm -f "$MTPROTO_NAME" >/dev/null 2>&1 || true
    docker run -d \
    --name "$MTPROTO_NAME" \
    --restart unless-stopped \
    -p "$MTPROTO_PORT:443" \
    "$MTPROTO_IMAGE"
    echo "[xr-conf] MTProto proxy started. Use --mtproto-logs to get the Telegram proxy link."
}

down_mtproto() {
    docker rm -f "$MTPROTO_NAME"
}

mtproto_logs() {
    docker logs "$MTPROTO_NAME"
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

relay_ssh_key_path() {
    printf '%s/conf/%s\n' "$LOCAL" "$RELAY_SSH_KEY_NAME"
}

relay_keygen() {
    local key_path
    key_path="$(relay_ssh_key_path)"

    ensure_local_dirs
    if [[ -f "$key_path" ]]; then
        echo "[xr-conf] Relay SSH key already exists: $key_path"
        return
    fi

    ssh-keygen -t ed25519 -f "$key_path" -N "" -C "xray-relay-control"
    chmod 600 "$key_path"
    chmod 644 "$key_path.pub"
    echo "[xr-conf] Relay SSH key generated: $key_path"
}

relay_pubkey() {
    local key_path
    key_path="$(relay_ssh_key_path)"

    if [[ ! -f "$key_path.pub" ]]; then
        echo "[xr-conf] ERROR: relay public key not found. Run: xr-conf --relay-keygen" >&2
        exit 1
    fi

    cat "$key_path.pub"
}

relay_health() {
    curl -s http://127.0.0.1:8080/relay/health
}

relay_start() {
    curl -s http://127.0.0.1:8080/relay/start
}

relay_stop() {
    curl -s http://127.0.0.1:8080/relay/stop
}

relay_restart() {
    curl -s http://127.0.0.1:8080/relay/restart
}

set_sni() {
    local reality="${1:-}"
    local vars_file="$LOCAL/conf/templates/variables.env"
    local response

    if [[ -z "$reality" ]]; then
        reality=$(read_nonempty "Enter XRAY_REALITY value: ")
    fi

    validate_reality_hostname "$reality"

    if response="$(curl -fsS --max-time 4 "http://127.0.0.1:8080/sni/set?sni=$reality" 2>/dev/null)"; then
        printf '%s\n' "$response"
        return
    fi

    echo "[xr-conf] configurator API is unavailable; updating local template file"
    mkdir -p "$(dirname "$vars_file")"

    if [[ ! -f "$vars_file" ]]; then
        cat > "$vars_file" <<EOF
XRAY_LOG_LEVEL=warning
XRAY_REALITY=$reality
XRAY_SHORT_IDS='[""]'
LINK1_TAG=VLESS_CONF
EOF
        return
    fi

    if grep -q '^XRAY_REALITY=' "$vars_file"; then
        tmp="$(mktemp "$vars_file.XXXXXX")"
        awk -v value="XRAY_REALITY=$reality" '
            /^XRAY_REALITY=/ {
                print value
                next
            }
            { print }
        ' "$vars_file" > "$tmp"
        mv -f "$tmp" "$vars_file"
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
    --up-conf [reality|reality_xhttp_relay|xhttp_relay]
    --down-conf
    --up-bot
    --down-bot
    --up-mtproto
    --down-mtproto
    --mtproto-logs
    --start-xray
    --stop-xray
    --restart-xray
    --health-xray
    --links
    --relay-keygen
    --relay-pubkey
    --relay-health
    --relay-start
    --relay-stop
    --relay-restart
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
            if [[ "${2:-}" == --* || -z "${2:-}" ]]; then
                up_conf
                shift
            else
                up_conf "$2"
                shift 2
            fi
            ;;
        --up-bot)
            up_bot
            shift
            ;;
        --up-mtproto)
            up_mtproto
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
        --down-mtproto)
            down_mtproto
            shift
            ;;
        --mtproto-logs)
            mtproto_logs
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
        --relay-keygen)
            relay_keygen
            shift
            ;;
        --relay-pubkey)
            relay_pubkey
            shift
            ;;
        --relay-health)
            relay_health
            shift
            ;;
        --relay-start)
            relay_start
            shift
            ;;
        --relay-stop)
            relay_stop
            shift
            ;;
        --relay-restart)
            relay_restart
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
