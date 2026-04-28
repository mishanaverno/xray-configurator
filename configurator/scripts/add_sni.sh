#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/env.sh
source /scripts/lib.sh
source /scripts/sni_lib.sh

: "${TEMPLATES_DIR:?TEMPLATES_DIR is not set}"
: "${SNI_LIST_FILE:?SNI_LIST_FILE is not set}"

SNI_LIST_PATH="$TEMPLATES_DIR/$SNI_LIST_FILE"

fail() {
  http_error
  say "$1"
  exit 1
}

query="${QUERY_STRING:-}"
candidate="${query#sni=}"
candidate="$(printf '%s' "$candidate" | sed 's/%2E/./g; s/%2e/./g; s/%2D/-/g; s/%2d/-/g')"
candidate="$(normalize_hostname "$candidate")"

if ! is_valid_hostname "$candidate"; then
  fail "Invalid SNI hostname"
fi

mkdir -p "$TEMPLATES_DIR"
touch "$SNI_LIST_PATH"

if grep -Fqx "$candidate" "$SNI_LIST_PATH"; then
  http_ok
  say "SNI candidate already exists: $candidate"
  exit 0
fi

printf '%s\n' "$candidate" >> "$SNI_LIST_PATH"
chmod 666 "$SNI_LIST_PATH"

http_ok
say "SNI candidate added: $candidate"
