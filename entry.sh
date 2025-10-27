#!/bin/sh
rm -f .env
if [ ! -e "/etc/xray/config.json" ]; then
    REALITY="www.amsterdamumc.nl"
    echo "REALITY=${REALITY}" >> .env
    SERVER_IP=$(hostname -i)
    echo "SERVER_IP=${SERVER_IP}" >> .env
    echo "Server IP: ${SERVER_IP}" 
    XRAY_UUID=$(/usr/bin/xray uuid)
    echo "XRAY_UUID=${XRAY_UUID}" >> .env 
    echo "Xray UUID: ${XRAY_UUID}"
    SS_PORT=$(shuf -i 55000-65000 -n 1)
    echo "SS_PORT=${SS_PORT}" >> .env
    echo "Shadow socks port: ${SS_PORT}"
    SS_PASS=$(openssl rand -base64 16)
    echo "SS_PASS=${SS_PASS}" >> .env
    echo "Shadow socks pass: ${SS_PASS}"

    echo "$(/usr/bin/xray x25519)" | while read type fuu key; do
    [[ $type == "Private" ]] && echo "PRIVATE_KEY=${key}" >> .env && echo "Private key: ${key}";
    [[ $type == "Public" ]] && echo "PUBLIC_KEY=${key}" >> .env && echo "Public key: ${key}";
    done 
    sh -ac ". ./.env; ./config.sh /etc/xray" 
fi

cp /etc/xray/links.txt /var/opt/subscribe/links.txt
nohup ./start_web.sh /var/opt/subscribe
./update_geodat.sh
/usr/bin/xray run -c /etc/xray/config.json