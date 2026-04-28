#!/usr/bin/env bash

normalize_hostname() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]'
}

is_valid_hostname() {
  local host="$1"
  [[ -n "$host" && "$host" != *"://"* && "$host" != *"/"* && "$host" =~ ^[A-Za-z0-9.-]+$ ]]
}

