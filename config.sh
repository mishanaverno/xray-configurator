#!/bin/sh

CONFIG_PATH=$1
rm -f ${CONFIG_PATH}/config.json
cp ${CONFIG_PATH}/config_template.json ${CONFIG_PATH}/config.json
awk -v var="$SERVER_IP" '{gsub(/#SERVER_IP#/, var)}1' ${CONFIG_PATH}/config.json > tmp.txt && mv tmp.txt ${CONFIG_PATH}/config.json
awk -v var="$XRAY_UUID" '{gsub(/#XRAY_UUID#/, var)}1' ${CONFIG_PATH}/config.json > tmp.txt && mv tmp.txt ${CONFIG_PATH}/config.json
awk -v var="$REALITY" '{gsub(/#REALITY#/, var)}1' ${CONFIG_PATH}/config.json > tmp.txt && mv tmp.txt ${CONFIG_PATH}/config.json
awk -v var="$PRIVATE_KEY" '{gsub(/#PRIVATE_KEY#/, var)}1' ${CONFIG_PATH}/config.json > tmp.txt && mv tmp.txt ${CONFIG_PATH}/config.json
awk -v var="$SS_PORT" '{gsub(/#SS_PORT#/, var)}1' ${CONFIG_PATH}/config.json > tmp.txt && mv tmp.txt ${CONFIG_PATH}/config.json
awk -v var="$SS_PASS" '{gsub(/#SS_PASS#/, var)}1' ${CONFIG_PATH}/config.json > tmp.txt && mv tmp.txt ${CONFIG_PATH}/config.json
VLESS_LINK="vless://${XRAY_UUID}@${SERVER_IP}:443/?encryption=none&type=tcp&sni=${REALITY}&fp=chrome&security=reality&alpn=h2&flow=xtls-rprx-vision&pbk=${PUBLIC_KEY}&packetEncoding=xudp#VLESS_VPN"
SS_LINK="ss://2022-blake3-aes-128-gcm:${SS_PASS}${SERVER_IP}:${SS_PORT}#SSOCKS_VPN"

rm -f "${CONFIG_PATH}/links.txt"
echo "$VLESS_LINK" >> "${CONFIG_PATH}/links.txt"
echo "$SS_LINK" >> "${CONFIG_PATH}/links.txt"

