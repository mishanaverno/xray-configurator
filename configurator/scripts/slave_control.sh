#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/env.sh
source /scripts/lib.sh

LOG_FILE="$(mktemp -t xray-slave.XXXXXX)"

fail() {
  http_error
  say "slave command failed"
  say "$1"
  if [[ -s "$LOG_FILE" ]]; then
    cat "$LOG_FILE"
  fi
  exit 1
}

trap 'rm -f "$LOG_FILE"' EXIT

role_file="$TEMPLATES_DIR/.role"
role="master"
if [[ -f "$role_file" ]]; then
  role="$(tr -d '[:space:]' < "$role_file")"
fi

if [[ "$role" != "master" ]]; then
  fail "Slave control is allowed only on role=master; current role=${role:-unknown}"
fi

if [[ -f "$TEMPLATES_DIR/$VARIABLES_FILE" ]]; then
  set -a
  . "$TEMPLATES_DIR/$VARIABLES_FILE"
  set +a
fi

action="${SLAVE_ACTION:-}"
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
    fail "Unsupported slave action: $action"
    ;;
esac

slave_host="${SLAVE_SSH_HOST:-${SLAVE_HOST:-}}"
slave_user="${SLAVE_SSH_USER:-root}"
slave_port="${SLAVE_SSH_PORT:-22}"
slave_key="${SLAVE_SSH_KEY_FILE:-$SLAVE_SSH_KEY_FILE}"
slave_known_hosts="${SLAVE_SSH_KNOWN_HOSTS_FILE:-$VOLUME/slave_known_hosts}"

[[ -n "$slave_host" ]] || fail "SLAVE_SSH_HOST or SLAVE_HOST is not set"
[[ -f "$slave_key" ]] || fail "slave SSH key is missing: $slave_key"

if [[ ! "$slave_port" =~ ^[0-9]+$ ]]; then
  fail "Invalid SLAVE_SSH_PORT: $slave_port"
fi

if ! ssh \
  -i "$slave_key" \
  -p "$slave_port" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile="$slave_known_hosts" \
  -o ConnectTimeout=8 \
  "$slave_user@$slave_host" \
  "$remote_cmd" >"$LOG_FILE" 2>&1; then
  fail "ssh $slave_user@$slave_host failed"
fi

http_ok
say "slave $action complete"
cat "$LOG_FILE"
