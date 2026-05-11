#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C LC_ALL=C

source /scripts/env.sh
source /scripts/lib.sh

: "${PRESET_DIR:?PRESET_DIR is not set}"
: "${SNI_LIST_FILE:?SNI_LIST_FILE is not set}"

SNI_LIST_PATH="$PRESET_DIR/$SNI_LIST_FILE"

http_ok

if [[ ! -f "$SNI_LIST_PATH" ]]; then
  say "SNI list is empty"
  exit 0
fi

sed '/^[[:space:]]*$/d' "$SNI_LIST_PATH"
