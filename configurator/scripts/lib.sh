#!/usr/bin/env bash

SCRIPT_NAME="${SCRIPT_NAME:-$(basename "$0")}"

# Печатает сообщение в stdout
# Формат: [script_name] Message
say() {
  local msg="$*"
  printf "[%s] %s\n" "$SCRIPT_NAME" "$msg"
}

http_headers() {
  local status="$1"
  printf "Status: %s\r\n" "$status"
  printf "Content-Type: text/plain; charset=utf-8\r\n\r\n"
}

http_ok() {
  http_headers "200 OK"
}

http_error() {
  http_headers "500 Internal Server Error"
}
