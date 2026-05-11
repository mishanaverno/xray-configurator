#!/usr/bin/env bash
set -euo pipefail

LANG=C LC_ALL=C

usage() {
  cat >&2 <<'EOF'
Usage:
  presets/deploy.sh user@host:port /remote/base/path=preset_name

Examples:
  presets/deploy.sh root@203.0.113.10:22 /usr/local/share/xray=reality
  presets/deploy.sh democrat@203.0.113.20:1122 /home/democrat/xray=xhttp_slave

The script uploads local presets/<preset_name>/ to:
  /remote/base/path/conf/preset
EOF
}

fail() {
  printf '[deploy-preset] ERROR: %s\n' "$1" >&2
  exit 1
}

quote_sh() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
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

parse_mapping() {
  local spec="$1"

  [[ "$spec" == *=* ]] || fail "second argument must look like /remote/base/path=preset_name"

  remote_base="${spec%%=*}"
  preset_name="${spec#*=}"

  [[ -n "$remote_base" ]] || fail "remote base path is empty"
  [[ "$remote_base" = /* ]] || fail "remote base path must be absolute"
  [[ -n "$preset_name" ]] || fail "preset name is empty"
  [[ "$preset_name" != *"/"* ]] || fail "preset name must not contain slash"
  [[ "$preset_name" != "." && "$preset_name" != ".." ]] || fail "invalid preset name"
}

main() {
  [[ $# -eq 2 ]] || {
    usage
    exit 1
  }

  local remote_spec="$1"
  local mapping_spec="$2"
  local script_dir repo_root preset_src remote_target remote_tmp quoted_target quoted_tmp

  parse_remote "$remote_spec"
  parse_mapping "$mapping_spec"

  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd -- "$script_dir/.." && pwd)"
  preset_src="$repo_root/presets/$preset_name"

  [[ -d "$preset_src" ]] || fail "preset does not exist: $preset_src"

  remote_target="$remote_base/conf/preset"
  remote_tmp="$remote_base/conf/preset.tmp.$$"
  quoted_target="$(quote_sh "$remote_target")"
  quoted_tmp="$(quote_sh "$remote_tmp")"

  printf '[deploy-preset] Deploying presets/%s to %s@%s:%s\n' \
    "$preset_name" "$remote_user" "$remote_host" "$remote_target"

  ssh -p "$remote_port" "$remote_user@$remote_host" \
    "mkdir -p $(quote_sh "$remote_base/conf") && rm -rf $quoted_tmp && mkdir -p $quoted_tmp"

  tar -C "$preset_src" -cf - . | ssh -p "$remote_port" "$remote_user@$remote_host" \
    "tar -C $quoted_tmp -xf -"

  ssh -p "$remote_port" "$remote_user@$remote_host" \
    "rm -rf $quoted_target && mv $quoted_tmp $quoted_target"

  printf '[deploy-preset] Done.\n'
}

main "$@"
