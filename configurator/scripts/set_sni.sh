#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/env.sh
source /scripts/lib.sh
source /scripts/sni_lib.sh

: "${TEMPLATES_DIR:?TEMPLATES_DIR is not set}"
: "${VARIABLES_FILE:?VARIABLES_FILE is not set}"
: "${SNI_LIST_FILE:?SNI_LIST_FILE is not set}"

VARIABLES_PATH="$TEMPLATES_DIR/$VARIABLES_FILE"
SNI_LIST_PATH="$TEMPLATES_DIR/$SNI_LIST_FILE"

fail() {
  http_error
  say "$1"
  exit 1
}

decode_query_value() {
  local value="$1"
  printf '%b' "${value//%/\\x}"
}

get_query_param() {
  local name="$1"
  local pair key value

  IFS='&' read -ra pairs <<< "${QUERY_STRING:-}"
  for pair in "${pairs[@]}"; do
    key="${pair%%=*}"
    value="${pair#*=}"
    if [[ "$key" == "$name" ]]; then
      decode_query_value "${value//+/ }"
      return 0
    fi
  done

  return 1
}

reality="$(get_query_param sni || true)"
reality="$(normalize_hostname "$reality")"

if ! is_valid_hostname "$reality"; then
  fail "Invalid SNI hostname"
fi

mkdir -p "$TEMPLATES_DIR"
touch "$VARIABLES_PATH"

tmp="$(mktemp "$VARIABLES_PATH.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

if grep -q '^XRAY_REALITY=' "$VARIABLES_PATH"; then
  awk -v value="XRAY_REALITY=$reality" '
    /^XRAY_REALITY=/ {
      print value
      next
    }
    { print }
  ' "$VARIABLES_PATH" > "$tmp"
else
  cp "$VARIABLES_PATH" "$tmp"
  printf '\nXRAY_REALITY=%s\n' "$reality" >> "$tmp"
fi

mv -f "$tmp" "$VARIABLES_PATH"
chmod 666 "$VARIABLES_PATH"

if [[ -f "$SNI_LIST_PATH" ]]; then
  sni_tmp="$(mktemp "$SNI_LIST_PATH.XXXXXX")"
  trap 'rm -f "$tmp" "$sni_tmp"' EXIT
  awk -v reality="$reality" '
    {
      line = $0
      sub(/#.*/, "", line)
      gsub(/[[:space:]]/, "", line)
      if (tolower(line) == reality) {
        next
      }
      print
    }
  ' "$SNI_LIST_PATH" > "$sni_tmp"
  mv -f "$sni_tmp" "$SNI_LIST_PATH"
  chmod 666 "$SNI_LIST_PATH"
fi

http_ok
say "XRAY_REALITY set to: $reality"
