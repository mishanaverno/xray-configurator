#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

NAME="xray-conf"
IMAGE="mishanaverno/xray-conf:latest"

start() {
    echo "[INFO] Starting the conteiner..."
    docker run -d --name $NAME --network host -v $(pwd)/xray-conf:/usr/share/xray/ $IMAGE
    docker logs -f $NAME
}

restart() {
    echo "[INFO] Restarting the container..."
    docker restart $NAME
    docker logs -f $NAME
}

stop() {
    echo "[INFO] Stopping the service..."
    docker rm $NAME
}

update() {
    echo "[INFO] Update geo files.."
    docker exec -u 0 $NAME sh /scripts/update_geodat.sh
    docker logs -f $NAME
}
# Проверка аргументов
if [ $# -eq 0 ]; then
    echo "Использование: $0 [--start|--restart|--stop]"
    exit 1
fi

# Разбор аргументов
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
        *)
            echo "Неизвестный флаг: $1"
            echo "Использование: $0 [--start|--restart|--stop]"
            exit 1
            ;;
    esac
done
