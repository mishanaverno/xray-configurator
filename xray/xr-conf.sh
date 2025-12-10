#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

NAME="xray-conf"
IMAGE="mishanaverno/xray-conf:latest"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

start() {
    echo "[INFO] Starting the conteiner..."
    docker run -d --name $NAME --network host -v $(pwd)/xray-conf:/usr/share/xray/ $IMAGE
    helth
}

restart() {
    echo "[INFO] Restarting the container..."
    docker exec -u 0 $NAME bash -c "source /scripts/env.sh && /scripts/generate_config.sh"
    stop
    start
}

stop() {
    echo "[INFO] Stopping the service..."
    docker stop $NAME
    helth
    docker rm -f $NAME
}

update() {
    echo "[INFO] Update geo files.."
    docker exec -u 0 $NAME bash -c "source /scripts/env.sh && /scripts/update_geodat.sh"
    stop
    start
}

links() {
    echo "[INFO] Looking for links..."
    docker exec -u 0 $NAME bash -c "source /scripts/env.sh && cat \$VOLUME/\$LINK_FILE"
}

helth() {
    while IFS='|' read -r name container rstatus; do
        if [[ "$name" == "$NAME" ]]; then
            while IFS=' ' read -r status meta; do
                case "$status" in
                    Up)
                        comp="$GREEN ✔ $status$RESET $meta"
                    ;;
                    Stoped)
                        comp="$YELLOW ✖ $status$RESET $meta"
                    ;;
                    *)
                        comp="$RED ✖ $status$RESET $meta"
                    ;;
                esac
            done < <(echo "$rstatus")
            echo -e "$comp"
        fi
    done < <(docker ps -a --format "{{.Names}}|{{.Image}}|{{.Status}}") 
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
    --helth:
        Conteiner health check.
    --links:
        Returns share links generated from link.txt template.
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
        --helth)
            helth
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
