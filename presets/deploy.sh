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

permission_hint() {
  cat >&2 <<EOF
[deploy-preset] Could not write to remote preset directory without sudo.
[deploy-preset] Fix permissions once on the server, then run deploy again:

  sudo mkdir -p $(quote_sh "$remote_target")
  sudo chmod -R a+rwX $(quote_sh "$remote_target")

EOF
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
  local script_dir repo_root preset_src remote_target remote_archive
  local quoted_target quoted_archive

  parse_remote "$remote_spec"
  parse_mapping "$mapping_spec"

  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd -- "$script_dir/.." && pwd)"
  preset_src="$repo_root/presets/$preset_name"

  [[ -d "$preset_src" ]] || fail "preset does not exist: $preset_src"

  remote_target="$remote_base/conf/preset"
  remote_archive="/tmp/xray-preset.$preset_name.$$.tar"
  quoted_target="$(quote_sh "$remote_target")"
  quoted_archive="$(quote_sh "$remote_archive")"

  printf '[deploy-preset] Deploying presets/%s to %s@%s:%s\n' \
    "$preset_name" "$remote_user" "$remote_host" "$remote_target"

  tar -C "$preset_src" -cf - . | ssh -p "$remote_port" "$remote_user@$remote_host" \
    "cat > $quoted_archive"

  if ! ssh -p "$remote_port" "$remote_user@$remote_host" \
    "set -e; mkdir -p $quoted_target; find $quoted_target -mindepth 1 -maxdepth 1 -exec rm -rf {} +; tar --no-overwrite-dir -C $quoted_target -xf $quoted_archive; rm -f $quoted_archive"; then
    ssh -p "$remote_port" "$remote_user@$remote_host" "rm -f $quoted_archive" >/dev/null 2>&1 || true
    permission_hint
    exit 1
  fi

  printf '[deploy-preset] Installed.\n'
  printf '[deploy-preset] Remote files:\n'
  ssh -p "$remote_port" "$remote_user@$remote_host" \
    "find $quoted_target -maxdepth 1 -type f -printf '%f\n' | sort"

  printf '[deploy-preset] Restarting remote Xray...\n'
  ssh -p "$remote_port" "$remote_user@$remote_host" \
    "curl -fsS --max-time 120 http://127.0.0.1:8080/restart || { curl -fsS --max-time 30 http://127.0.0.1:8080/stop; curl -fsS --max-time 120 http://127.0.0.1:8080/start; }"

  printf '[deploy-preset] Done.\n'
}

main "$@"
