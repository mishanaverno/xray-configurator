#!/bin/sh 

WEB_PATH=$1
cd "${WEB_PATH}" && npm i && node main.js