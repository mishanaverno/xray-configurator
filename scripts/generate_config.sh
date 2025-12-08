#!/usr/bin/env bash
set -euo pipefail
LANG=C LC_ALL=C

set -a
. "$TEMPLATES_DIR/$SECRETS_FILE"
[ -f "$TEMPLATES_DIR/$VARIABLES_FILE" ] && . "$TEMPLATES_DIR/$VARIABLES_FILE"
set +a

rm "$VOLUME/$CONFIG_FILE";

echo "[entrypoint] Building config.json from templates in $TEMPLATES_DIR ..."
for f in "$INBOUND_FILE" "$OUTBOUND_FILE" "$ROUTING_FILE"; do
[[ -f "$TEMPLATES_DIR/$f" ]] || { echo "[ERROR] missing $TEMPLATES_DIR/$f" >&2; exit 1; }
done

inbounds=$(envsubst < "$TEMPLATES_DIR/$INBOUND_FILE"  | jq 'if type=="array" then . else error("inbound.json must be array") end' )
outbounds=$(envsubst < "$TEMPLATES_DIR/$OUTBOUND_FILE" | jq 'if type=="array" then . else error("outbound.json must be array") end' )
routing=$(envsubst < "$TEMPLATES_DIR/$ROUTING_FILE"  | jq 'if type=="object" then . else error("routing.json must be object") end' )

jq -n \
--argjson inbounds "$inbounds" \
--argjson outbounds "$outbounds" \
--argjson routing "$routing" \
'{ log:{loglevel:(env.XRAY_LOG_LEVEL // "info")}, inbounds:$inbounds, outbounds:$outbounds, routing:$routing }' \
> "$VOLUME/$CONFIG_FILE.tmp"

jq . "$VOLUME/$CONFIG_FILE.tmp" >/dev/null
mv -f "$VOLUME/$CONFIG_FILE.tmp" "$VOLUME/$CONFIG_FILE"
