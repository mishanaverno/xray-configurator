#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

source /scripts/lib.sh
source /scripts/env.sh

say "Building config.json from templates in $PRESET_DIR ..."
set -a
. "$VOLUME/$SECRETS_FILE"
[ -f "$PRESET_DIR/$VARIABLES_FILE" ] && . "$PRESET_DIR/$VARIABLES_FILE"
: "${XRAY_UUID:?XRAY_UUID is not set}"
: "${XRAY_PRIVATE_KEY:?XRAY_PRIVATE_KEY is not set}"
: "${XRAY_PUBLIC_KEY:?XRAY_PUBLIC_KEY is not set}"
: "${XRAY_HOST_IP:?XRAY_HOST_IP is not set}"
: "${XRAY_REALITY:=google.com}"
: "${XRAY_SHORT_IDS:='[""]'}"
set +a
export XRAY_UUID XRAY_PRIVATE_KEY XRAY_PUBLIC_KEY XRAY_HOST_IP XRAY_REALITY XRAY_SHORT_IDS

for f in "$INBOUND_FILE" "$OUTBOUND_FILE" "$ROUTING_FILE"; do
  [[ -f "$PRESET_DIR/$f" ]] || { say "[ERROR] missing $PRESET_DIR/$f" >&2; exit 1; }
done

inbounds=$(envsubst < "$PRESET_DIR/$INBOUND_FILE" | jq 'if type=="array" then . else error("inbound.json must be array") end' )
outbounds=$(envsubst < "$PRESET_DIR/$OUTBOUND_FILE" | jq 'if type=="array" then . else error("outbound.json must be array") end' )
routing=$(envsubst < "$PRESET_DIR/$ROUTING_FILE" | jq 'if type=="object" then . else error("routing.json must be object") end' )
config_tmp="$VOLUME/$CONFIG_FILE.tmp"

if [[ -f "$PRESET_DIR/$LINK_FILE" ]]; then
  link_tmp="$VOLUME/$LINK_FILE.tmp"
  envsubst < "$PRESET_DIR/$LINK_FILE" > "$link_tmp"
else
  link_tmp=""
fi

jq -n \
--argjson inbounds "$inbounds" \
--argjson outbounds "$outbounds" \
--argjson routing "$routing" \
'{ log:{loglevel:(env.XRAY_LOG_LEVEL // "info")}, inbounds:$inbounds, outbounds:$outbounds, routing:$routing }' \
> "$config_tmp"

jq . "$config_tmp" >/dev/null
mv -f "$config_tmp" "$VOLUME/$CONFIG_FILE"
if [[ -n "$link_tmp" ]]; then
  mv -f "$link_tmp" "$VOLUME/$LINK_FILE"
else
  rm -f "$VOLUME/$LINK_FILE"
fi
say "Complete! config.json is ready."
