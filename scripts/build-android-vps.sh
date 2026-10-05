#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Build a SchoolDesk Android release artifact against the Hostinger VPS backend.

Usage:
  scripts/build-android-vps.sh [apk|aab|all] [extra flutter args...]

The VPS Supabase anon key is read from the configured Coolify Supabase Kong
container over SSH and is kept only in a temporary, shredded build file.
Override SCHOOLDESK_VPS_SSH_TARGET or provide SCHOOLDESK_VPS_ANON_KEY in CI.
USAGE
}

fail() {
  printf '[android-vps-build][error] %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[android-vps-build] %s\n' "$*"
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
base_env="${SCHOOLDESK_BASE_ENV_FILE:-$repo_root/env.supabase.json}"
ssh_target="${SCHOOLDESK_VPS_SSH_TARGET:-root@82.112.230.198}"
artifact="aab"

if (($# > 0)); then
  case "$1" in
    apk | aab | all)
      artifact="$1"
      shift
      ;;
    --help | -h)
      usage
      exit 0
      ;;
  esac
fi

[[ -f "$base_env" ]] || fail "Missing base environment file: $base_env"
command -v jq >/dev/null 2>&1 || fail "Missing required command: jq"
command -v curl >/dev/null 2>&1 || fail "Missing required command: curl"

if [[ -n "${SCHOOLDESK_VPS_ANON_KEY:-}" ]]; then
  anon_key="$SCHOOLDESK_VPS_ANON_KEY"
else
  command -v ssh >/dev/null 2>&1 || fail "Missing required command: ssh"
  anon_key="$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$ssh_target" 'bash -s' <<'REMOTE'
set -Eeuo pipefail
container="$(docker ps --format '{{.Names}}' | grep '^supabase-kong-' | head -n 1)"
test -n "$container"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$container" |
  awk -F= '$1 == "SUPABASE_ANON_KEY" { sub(/^[^=]*=/, ""); print; exit }'
REMOTE
)"
fi

anon_key="${anon_key//$'\r'/}"
[[ "$anon_key" == eyJ*.*.* ]] ||
  fail "The VPS anon key is not a JWT; refusing to build with a non-VPS key"

temp_env="$(mktemp "${TMPDIR:-/tmp}/schooldesk-vps-env.XXXXXX.json")"
trap 'shred -u -- "$temp_env" 2>/dev/null || true' EXIT

jq --arg supabase 'https://api.arishville.com' \
  --arg api 'https://api.arishville.com/functions/v1/api' \
  --arg anon "$anon_key" \
  '.SUPABASE_URL=$supabase |
   .API_BASE_URL=$api |
   .SUPABASE_ANON_KEY=$anon' \
  "$base_env" > "$temp_env"

health_status="$(curl --silent --show-error --output /dev/null \
  --write-out '%{http_code}' --max-time 15 \
  -H "apikey: ${anon_key}" \
  -H "Authorization: Bearer ${anon_key}" \
  'https://api.arishville.com/functions/v1/api/health')"
[[ "$health_status" == "200" ]] ||
  fail "VPS health preflight returned HTTP $health_status"

log "Verified VPS backend health: https://api.arishville.com/functions/v1/api/health"
log "Building $artifact with the VPS Supabase URL and anon key"
"$repo_root/scripts/build-android-supabase.sh" "$artifact" \
  --env-file "$temp_env" "$@"
