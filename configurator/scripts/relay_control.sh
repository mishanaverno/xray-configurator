#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/env.sh
source /scripts/lib.sh

LOG_FILE="$(mktemp -t xray-relay.XXXXXX)"

fail() {
  http_error
  say "Relay command failed"
  say "$1"
  if [[ -s "$LOG_FILE" ]]; then
    cat "$LOG_FILE"
  fi
  exit 1
}

trap 'rm -f "$LOG_FILE"' EXIT

if [[ -f "$TEMPLATES_DIR/$VARIABLES_FILE" ]]; then
  set -a
  . "$TEMPLATES_DIR/$VARIABLES_FILE"
  set +a
fi

action="${RELAY_ACTION:-}"
case "$action" in
  health)
    remote_cmd='curl -fsS http://127.0.0.1:8080/health'
    ;;
  start)
    remote_cmd='curl -fsS http://127.0.0.1:8080/start'
    ;;
  stop)
    remote_cmd='curl -fsS http://127.0.0.1:8080/stop'
    ;;
  restart)
    remote_cmd='curl -fsS http://127.0.0.1:8080/stop; curl -fsS http://127.0.0.1:8080/start'
    ;;
  *)
    fail "Unsupported relay action: $action"
    ;;
esac

relay_host="${XHTTP_RELAY_SSH_HOST:-${XHTTP_RELAY_HOST:-}}"
relay_user="${XHTTP_RELAY_SSH_USER:-root}"
relay_port="${XHTTP_RELAY_SSH_PORT:-22}"
relay_key="${XHTTP_RELAY_SSH_KEY_FILE:-$RELAY_SSH_KEY_FILE}"
relay_known_hosts="${XHTTP_RELAY_SSH_KNOWN_HOSTS_FILE:-$VOLUME/relay_known_hosts}"

[[ -n "$relay_host" ]] || fail "XHTTP_RELAY_SSH_HOST or XHTTP_RELAY_HOST is not set"
[[ -f "$relay_key" ]] || fail "Relay SSH key is missing: $relay_key"

if [[ ! "$relay_port" =~ ^[0-9]+$ ]]; then
  fail "Invalid XHTTP_RELAY_SSH_PORT: $relay_port"
fi

if ! ssh \
  -i "$relay_key" \
  -p "$relay_port" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile="$relay_known_hosts" \
  -o ConnectTimeout=8 \
  "$relay_user@$relay_host" \
  "$remote_cmd" >"$LOG_FILE" 2>&1; then
  fail "ssh $relay_user@$relay_host failed"
fi

http_ok
say "Relay $action complete"
cat "$LOG_FILE"
