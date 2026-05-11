#!/usr/bin/env bash
set -euo pipefail

LANG=C LC_ALL=C

usage() {
  cat >&2 <<'EOF'
Usage:
  presets/backup.sh user@host:port /remote/base/path [local_name]

Examples:
  presets/backup.sh root@203.0.113.10:22 /usr/local/share/xray
  presets/backup.sh democrat@203.0.113.20:1122 /home/democrat/xray democrat_nl

The script downloads:
  /remote/base/path/conf/preset

Default destination:
  presets/backups/<host>-<timestamp>/
EOF
}

fail() {
  printf '[backup-preset] ERROR: %s\n' "$1" >&2
  exit 1
}

quote_sh() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

sanitize_name() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'
}

parse_remote() {
  local spec="$1"

  if [[ "$spec" =~ ^(.+)@(\[[^]]+\]|[^:]+):([0-9]+)$ ]]; then
    remote_user="${BASH_REMATCH[1]}"
    remote_host="${BASH_REMATCH[2]}"
    remote_port="${BASH_REMATCH[3]}"
  elif [[ "$spec" =~ ^(.+)@(\[[^]]+\]|[^:]+)$ ]]; then
    remote_user="${BASH_REMATCH[1]}"
    remote_host="${BASH_REMATCH[2]}"
    remote_port="22"
  else
    fail "remote must look like user@host:port"
  fi

  remote_host="${remote_host#[}"
  remote_host="${remote_host%]}"

  [[ -n "$remote_user" ]] || fail "remote user is empty"
  [[ -n "$remote_host" ]] || fail "remote host is empty"
  [[ "$remote_port" =~ ^[0-9]+$ ]] || fail "remote port must be numeric"
  [[ "$remote_port" -ge 1 && "$remote_port" -le 65535 ]] || fail "remote port is out of range"
}

main() {
  [[ $# -eq 2 || $# -eq 3 ]] || {
    usage
    exit 1
  }

  local remote_spec="$1"
  local remote_base="$2"
  local local_name="${3:-}"
  local script_dir repo_root backup_root backup_dir remote_target quoted_target timestamp safe_host

  parse_remote "$remote_spec"

  [[ -n "$remote_base" ]] || fail "remote base path is empty"
  [[ "$remote_base" = /* ]] || fail "remote base path must be absolute"

  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd -- "$script_dir/.." && pwd)"
  backup_root="$repo_root/presets/backups"
  timestamp="$(date +%Y%m%d%H%M%S)"
  safe_host="$(sanitize_name "$remote_host")"

  if [[ -n "$local_name" ]]; then
    [[ "$local_name" != *"/"* ]] || fail "local_name must not contain slash"
    backup_dir="$backup_root/$local_name-$timestamp"
  else
    backup_dir="$backup_root/$safe_host-$timestamp"
  fi

  remote_target="$remote_base/conf/preset"
  quoted_target="$(quote_sh "$remote_target")"

  mkdir -p "$backup_dir"

  printf '[backup-preset] Backing up %s@%s:%s to %s\n' \
    "$remote_user" "$remote_host" "$remote_target" "$backup_dir"

  if ssh -p "$remote_port" "$remote_user@$remote_host" \
    "test -d $quoted_target && tar -C $quoted_target -cf - ." | tar -C "$backup_dir" -xf -; then
    printf '[backup-preset] Done.\n'
    return
  fi

  rm -rf "$backup_dir"
  fail "failed to download preset from $remote_target"
}

main "$@"
