#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/lib.sh

LOG_FILE="$(mktemp -t xray-xhttp-tls.XXXXXX)"

fail() {
  say "[ensure_xhttp_tls.sh] [ERROR] $1"
  cat "$LOG_FILE"
  exit 1
}

trap 'rm -f "$LOG_FILE"' EXIT

if ! source /scripts/env.sh >"$LOG_FILE" 2>&1; then
  fail "Failed to load env.sh"
fi

: "${XHTTP_HOST:?XHTTP_HOST is not set}"
: "${XHTTP_TLS_CERT_FILE:?XHTTP_TLS_CERT_FILE is not set}"
: "${XHTTP_TLS_KEY_FILE:?XHTTP_TLS_KEY_FILE is not set}"

if [[ -s "$XHTTP_TLS_CERT_FILE" && -s "$XHTTP_TLS_KEY_FILE" ]]; then
  say "[ensure_xhttp_tls.sh] TLS certificate already exists."
  exit 0
fi

cert_dir="$(dirname "$XHTTP_TLS_CERT_FILE")"
key_dir="$(dirname "$XHTTP_TLS_KEY_FILE")"
mkdir -p "$cert_dir" "$key_dir" 2>>"$LOG_FILE" || fail "Failed to create certificate directories"

san_type="DNS"
if [[ "$XHTTP_HOST" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ || "$XHTTP_HOST" == *:* ]]; then
  san_type="IP"
fi

say "[ensure_xhttp_tls.sh] Generating self-signed TLS certificate for $XHTTP_HOST..."
if ! openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 3650 \
  -keyout "$XHTTP_TLS_KEY_FILE" \
  -out "$XHTTP_TLS_CERT_FILE" \
  -subj "/CN=$XHTTP_HOST" \
  -addext "subjectAltName=$san_type:$XHTTP_HOST" \
  >>"$LOG_FILE" 2>&1; then
  fail "Failed to generate TLS certificate"
fi

chmod 664 "$XHTTP_TLS_CERT_FILE" 2>>"$LOG_FILE" || fail "Failed to chmod certificate"
chmod 660 "$XHTTP_TLS_KEY_FILE" 2>>"$LOG_FILE" || fail "Failed to chmod private key"

say "[ensure_xhttp_tls.sh] TLS certificate generated."
