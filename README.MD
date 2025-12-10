install:
bash -c "$(wget -qO- https://raw.githubusercontent.com/mishanaverno/xray-configurator/main/xray/install.sh)"

start xray:
    xr-conf --start

stop xray:
    xr-conf --stop

restart xray:
    xr-conf --restart

update geo files:
    xr-conf --update
