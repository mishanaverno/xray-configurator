install:
bash -c "$(wget -qO- https://raw.githubusercontent.com/mishanaverno/xray-configurator/main/utils/install.sh)" _ /your/path

change SNI:
xr-conf --set-sni example.com
xr-conf --restart-xray

manage SNI candidates:
xr-conf --add-sni example.com
xr-conf --list-sni
Telegram bot:
/add_sni example.com
/sni_list

on Xray start, current XRAY_REALITY is checked with TLS 1.3.
If it fails, Xray tries candidates from:
/usr/local/share/xray/conf/templates/sni_list
