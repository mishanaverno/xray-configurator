#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh

LOG_FILE="$(mktemp -t xray-slave-ssh-key.XXXXXX)"

fail() {
  say "[ensure_slave_ssh_key.sh] [ERROR] $1"
  cat "$LOG_FILE"
  exit 1
}

trap 'rm -f "$LOG_FILE"' EXIT

if ! source /scripts/env.sh >"$LOG_FILE" 2>&1; then
  fail "Failed to load env.sh"
fi

: "${SLAVE_SSH_KEY_FILE:?SLAVE_SSH_KEY_FILE is not set}"

if [[ -f "$SLAVE_SSH_KEY_FILE" ]]; then
  chown nginx:nginx "$SLAVE_SSH_KEY_FILE" 2>>"$LOG_FILE" || fail "Failed to chown slave SSH private key"
  [[ ! -f "$SLAVE_SSH_KEY_FILE.pub" ]] || chown nginx:nginx "$SLAVE_SSH_KEY_FILE.pub" 2>>"$LOG_FILE" || fail "Failed to chown slave SSH public key"
  chmod 600 "$SLAVE_SSH_KEY_FILE" 2>>"$LOG_FILE" || fail "Failed to chmod slave SSH private key"
  [[ ! -f "$SLAVE_SSH_KEY_FILE.pub" ]] || chmod 644 "$SLAVE_SSH_KEY_FILE.pub" 2>>"$LOG_FILE" || fail "Failed to chmod slave SSH public key"
  say "[ensure_slave_ssh_key.sh] slave SSH key already exists."
  exit 0
fi

say "[ensure_slave_ssh_key.sh] Generating slave SSH key..."
if ! ssh-keygen -t ed25519 -f "$SLAVE_SSH_KEY_FILE" -N "" -C "xray-slave-control" >>"$LOG_FILE" 2>&1; then
  fail "Failed to generate slave SSH key"
fi

chown nginx:nginx "$SLAVE_SSH_KEY_FILE" "$SLAVE_SSH_KEY_FILE.pub" 2>>"$LOG_FILE" || fail "Failed to chown slave SSH key"
chmod 600 "$SLAVE_SSH_KEY_FILE" 2>>"$LOG_FILE" || fail "Failed to chmod slave SSH private key"
chmod 644 "$SLAVE_SSH_KEY_FILE.pub" 2>>"$LOG_FILE" || fail "Failed to chmod slave SSH public key"

say "[ensure_slave_ssh_key.sh] slave SSH key generated."
