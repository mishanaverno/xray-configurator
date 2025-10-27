#!/bin/sh 

rm -f /usr/share/xray/geosite.dat
rm -f /usr/share/xray/geoip.dat
wget -O /usr/share/xray/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat
wget -O /usr/share/xray/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat