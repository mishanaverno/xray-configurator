#!/usr/bin/env sh
set -eu

mkdir -p /data

redis-server \
  --daemonize yes \
  --bind 127.0.0.1 \
  --port 6379 \
  --dir /data \
  --appendonly yes

exec node index.js
