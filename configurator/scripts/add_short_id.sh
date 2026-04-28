#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/env.sh
source /scripts/lib.sh

: "${TEMPLATES_DIR:?TEMPLATES_DIR is not set}"
: "${VARIABLES_FILE:?VARIABLES_FILE is not set}"

VARIABLES_PATH="$TEMPLATES_DIR/$VARIABLES_FILE"

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

short_id="$(get_query_param "${SHORT_ID_PARAM:-short_id}" || true)"

if [[ ! "$short_id" =~ ^[0-9a-fA-F]{2,16}$ || $(( ${#short_id} % 2 )) -ne 0 ]]; then
  fail "Invalid short id"
fi

short_id="$(printf '%s' "$short_id" | tr '[:upper:]' '[:lower:]')"
mkdir -p "$TEMPLATES_DIR"
touch "$VARIABLES_PATH"

current_value="$(awk -F= '$1 == "XRAY_SHORT_IDS" {print substr($0, index($0, "=") + 1); exit}' "$VARIABLES_PATH")"
if [[ -z "$current_value" ]]; then
  current_value='[""]'
fi

current_value="${current_value%\'}"
current_value="${current_value#\'}"
current_value="${current_value%\"}"
current_value="${current_value#\"}"

if ! updated_value="$(jq -cn --argjson current "$current_value" --arg short_id "$short_id" '$current + [$short_id] | map(select(. != "")) | unique')" ; then
  fail "Invalid XRAY_SHORT_IDS value"
fi

tmp="$(mktemp "$VARIABLES_PATH.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

if grep -q '^XRAY_SHORT_IDS=' "$VARIABLES_PATH"; then
  awk -v value="XRAY_SHORT_IDS='$updated_value'" '
    BEGIN { replaced = 0 }
    /^XRAY_SHORT_IDS=/ {
      print value
      replaced = 1
      next
    }
    { print }
    END {
      if (!replaced) {
        print value
      }
    }
  ' "$VARIABLES_PATH" > "$tmp"
else
  cp "$VARIABLES_PATH" "$tmp"
  printf '\nXRAY_SHORT_IDS=%s\n' "'$updated_value'" >> "$tmp"
fi

mv -f "$tmp" "$VARIABLES_PATH"
chmod 666 "$VARIABLES_PATH"

http_ok
say "Short id added: $short_id"
