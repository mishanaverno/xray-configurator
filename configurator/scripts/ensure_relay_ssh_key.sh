#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh

LOG_FILE="$(mktemp -t xray-relay-ssh-key.XXXXXX)"

fail() {
  say "[ensure_relay_ssh_key.sh] [ERROR] $1"
  cat "$LOG_FILE"
  exit 1
}

trap 'rm -f "$LOG_FILE"' EXIT

if ! source /scripts/env.sh >"$LOG_FILE" 2>&1; then
  fail "Failed to load env.sh"
fi

: "${RELAY_SSH_KEY_FILE:?RELAY_SSH_KEY_FILE is not set}"

if [[ -f "$RELAY_SSH_KEY_FILE" ]]; then
  chown nginx:nginx "$RELAY_SSH_KEY_FILE" 2>>"$LOG_FILE" || fail "Failed to chown relay SSH private key"
  [[ ! -f "$RELAY_SSH_KEY_FILE.pub" ]] || chown nginx:nginx "$RELAY_SSH_KEY_FILE.pub" 2>>"$LOG_FILE" || fail "Failed to chown relay SSH public key"
  chmod 640 "$RELAY_SSH_KEY_FILE" 2>>"$LOG_FILE" || fail "Failed to chmod relay SSH private key"
  [[ ! -f "$RELAY_SSH_KEY_FILE.pub" ]] || chmod 644 "$RELAY_SSH_KEY_FILE.pub" 2>>"$LOG_FILE" || fail "Failed to chmod relay SSH public key"
  say "[ensure_relay_ssh_key.sh] Relay SSH key already exists."
  exit 0
fi

say "[ensure_relay_ssh_key.sh] Generating relay SSH key..."
if ! ssh-keygen -t ed25519 -f "$RELAY_SSH_KEY_FILE" -N "" -C "xray-relay-control" >>"$LOG_FILE" 2>&1; then
  fail "Failed to generate relay SSH key"
fi

chown nginx:nginx "$RELAY_SSH_KEY_FILE" "$RELAY_SSH_KEY_FILE.pub" 2>>"$LOG_FILE" || fail "Failed to chown relay SSH key"
chmod 640 "$RELAY_SSH_KEY_FILE" 2>>"$LOG_FILE" || fail "Failed to chmod relay SSH private key"
chmod 644 "$RELAY_SSH_KEY_FILE.pub" 2>>"$LOG_FILE" || fail "Failed to chmod relay SSH public key"

say "[ensure_relay_ssh_key.sh] Relay SSH key generated."
