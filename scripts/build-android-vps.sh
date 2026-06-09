#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Build SchoolDesk Android release artifacts attached to the Hostinger VPS backend.

Usage:
  scripts/build-android-vps.sh [apk|aab|abb|all] [--env-file <file>] [extra flutter args...]

Defaults:
  artifact: aab
  env file: env.hostinger.json

Examples:
  scripts/build-android-vps.sh apk
  scripts/build-android-vps.sh aab
  scripts/build-android-vps.sh all -- --obfuscate --split-debug-info=build/debug-info
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

artifact="aab"
env_file="$repo_root/env.hostinger.json"
flutter_args=()

while (($#)); do
  case "$1" in
    apk | aab | abb | all)
      artifact="$1"
      ;;
    --env-file)
      shift
      [[ $# -gt 0 ]] || fail "--env-file requires a path"
      env_file="$1"
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    --)
      shift
      flutter_args+=("$@")
      break
      ;;
    *)
      flutter_args+=("$1")
      ;;
  esac
  shift
done

if [[ "$artifact" == "abb" ]]; then
  artifact="aab"
fi

[[ -f "$env_file" ]] || fail "Missing env file: $env_file"
command -v jq >/dev/null 2>&1 || fail "Missing required command: jq"
command -v flutter >/dev/null 2>&1 || fail "Missing required command: flutter"

jq -e '
  type == "object"
  and (.API_BASE_URL | type == "string" and startswith("https://"))
  and (.APP_ENV == "production")
  and ((.ENABLE_LOGGING | tostring) == "false")
' "$env_file" >/dev/null || fail "$env_file must contain a production HTTPS API_BASE_URL and ENABLE_LOGGING=false"

api_base_url="$(jq -r '.API_BASE_URL' "$env_file")"
log "Using VPS backend: $api_base_url"

cd "$repo_root"

build_apk() {
  log "Building release APK with Hostinger backend defines."
  if ((${#flutter_args[@]})); then
    flutter build apk --release --dart-define-from-file="$env_file" "${flutter_args[@]}"
  else
    flutter build apk --release --dart-define-from-file="$env_file"
  fi
}

build_aab() {
  log "Building release AAB with Hostinger backend defines."
  if ((${#flutter_args[@]})); then
    flutter build appbundle --release --dart-define-from-file="$env_file" "${flutter_args[@]}"
  else
    flutter build appbundle --release --dart-define-from-file="$env_file"
  fi
}

case "$artifact" in
  apk)
    build_apk
    ;;
  aab)
    build_aab
    ;;
  all)
    build_apk
    build_aab
    ;;
  *)
    fail "Unknown artifact: $artifact"
    ;;
esac
