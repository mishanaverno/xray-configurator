#!/usr/bin/env bash
set -euo pipefail

LANG=C LC_ALL=C

source /scripts/env.sh
source /scripts/lib.sh
source /scripts/sni_lib.sh

CHECK_ONLY=false
if [[ "${1:-}" == "--check-only" ]]; then
  CHECK_ONLY=true
fi

: "${TEMPLATES_DIR:?TEMPLATES_DIR is not set}"
: "${VARIABLES_FILE:?VARIABLES_FILE is not set}"
: "${SNI_LIST_FILE:?SNI_LIST_FILE is not set}"

VARIABLES_PATH="$TEMPLATES_DIR/$VARIABLES_FILE"
SNI_LIST_PATH="$TEMPLATES_DIR/$SNI_LIST_FILE"

tls_ok() {
  local host="$1"
  timeout 6 openssl s_client -tls1_3 -servername "$host" -connect "$host:443" </dev/null >/dev/null 2>&1
}

set_reality() {
  local host="$1"

  if grep -q '^XRAY_REALITY=' "$VARIABLES_PATH"; then
    sed -i "s/^XRAY_REALITY=.*/XRAY_REALITY=$host/" "$VARIABLES_PATH"
  else
    printf '\nXRAY_REALITY=%s\n' "$host" >> "$VARIABLES_PATH"
  fi
}

current_reality() {
  if [[ -f "$VARIABLES_PATH" ]]; then
    awk -F= '$1 == "XRAY_REALITY" {print $2; exit}' "$VARIABLES_PATH"
  fi
}

reality="$(normalize_hostname "$(current_reality)")"

if is_valid_hostname "$reality" && tls_ok "$reality"; then
  say "XRAY_REALITY is healthy: $reality"
  exit 0
fi

if [[ -n "$reality" ]]; then
  say "XRAY_REALITY check failed: $reality"
else
  say "XRAY_REALITY is empty or missing"
fi

if [[ "$CHECK_ONLY" == "true" ]]; then
  exit 1
fi

if [[ ! -f "$SNI_LIST_PATH" ]]; then
  say "[ERROR] missing $SNI_LIST_PATH"
  exit 1
fi

while IFS= read -r candidate; do
  candidate="${candidate%%#*}"
  candidate="$(normalize_hostname "$candidate")"
  [[ -z "$candidate" ]] && continue

  if ! is_valid_hostname "$candidate"; then
    say "Skipping invalid SNI candidate: $candidate"
    continue
  fi

  if [[ "$candidate" == "$reality" ]]; then
    continue
  fi

  if tls_ok "$candidate"; then
    set_reality "$candidate"
    say "XRAY_REALITY replaced with healthy SNI: $candidate"
    exit 0
  fi

  say "SNI candidate failed TLS check: $candidate"
done < "$SNI_LIST_PATH"

say "[ERROR] no healthy SNI candidate found in $SNI_LIST_PATH"
exit 1
