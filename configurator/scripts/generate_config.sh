#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

source /scripts/lib.sh

say "Building config.json from templates in $TEMPLATES_DIR ..."
set -a
. "$VOLUME/$SECRETS_FILE"
[ -f "$TEMPLATES_DIR/$VARIABLES_FILE" ] && . "$TEMPLATES_DIR/$VARIABLES_FILE"
set +a

echo "" > "$VOLUME/$CONFIG_FILE"
echo "" > "$VOLUME/$LINK_FILE"

for f in "$INBOUND_FILE" "$OUTBOUND_FILE" "$ROUTING_FILE" "$LINK_FILE"; do
[[ -f "$TEMPLATES_DIR/$f" ]] || { say "[ERROR] missing $TEMPLATES_DIR/$f" >&2; exit 1; }
done

inbounds=$(envsubst < "$TEMPLATES_DIR/$INBOUND_FILE" | jq 'if type=="array" then . else error("inbound.json must be array") end' )
outbounds=$(envsubst < "$TEMPLATES_DIR/$OUTBOUND_FILE" | jq 'if type=="array" then . else error("outbound.json must be array") end' )
routing=$(envsubst < "$TEMPLATES_DIR/$ROUTING_FILE" | jq 'if type=="object" then . else error("routing.json must be object") end' )
echo $(envsubst < "$TEMPLATES_DIR/$LINK_FILE") > "$VOLUME/$LINK_FILE"

jq -n \
--argjson inbounds "$inbounds" \
--argjson outbounds "$outbounds" \
--argjson routing "$routing" \
'{ log:{loglevel:(env.XRAY_LOG_LEVEL // "info")}, inbounds:$inbounds, outbounds:$outbounds, routing:$routing }' \
> "$VOLUME/$CONFIG_FILE.tmp"

jq . "$VOLUME/$CONFIG_FILE.tmp" >/dev/null
mv -f "$VOLUME/$CONFIG_FILE.tmp" "$VOLUME/$CONFIG_FILE"
say "Complete! config.json is ready."
