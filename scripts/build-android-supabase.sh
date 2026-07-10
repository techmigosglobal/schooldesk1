#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Build SchoolDesk Android release artifacts attached to the Supabase backend.

Usage:
  scripts/build-android-supabase.sh [apk|aab|abb|all] [--env-file <file>] [extra flutter args...]

Defaults:
  artifact: aab
  env file: env.supabase.json

Examples:
  scripts/build-android-supabase.sh apk
  scripts/build-android-supabase.sh aab
  scripts/build-android-supabase.sh all -- --obfuscate --split-debug-info=build/debug-info
USAGE
}

fail() {
  printf '[android-supabase-build][error] %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[android-supabase-build] %s\n' "$*"
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

artifact="aab"
env_file="$repo_root/env.supabase.json"
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
  and (.API_BASE_URL | type == "string" and test("^https://.+\\.supabase\\.co/functions/v1/api$"))
  and (.SUPABASE_URL | type == "string" and test("^https://.+\\.supabase\\.co$"))
  and (.SUPABASE_ANON_KEY | type == "string" and length > 0)
  and (.APP_ENV == "production")
  and ((.ENABLE_LOGGING | tostring) == "false")
' "$env_file" >/dev/null || fail "$env_file must target the Supabase Edge API with SUPABASE_URL, SUPABASE_ANON_KEY, APP_ENV=production, and ENABLE_LOGGING=false"

# Validate Firebase keys — required for push notifications to work.
# A build with empty Firebase keys produces an APK/AAB where FCM is silently broken.
jq -e '
  type == "object"
  and (.FIREBASE_API_KEY | type == "string" and length > 0)
  and (.FIREBASE_PROJECT_ID | type == "string" and length > 0)
  and (.FIREBASE_MESSAGING_SENDER_ID | type == "string" and length > 0)
  and (.FIREBASE_ANDROID_APP_ID | type == "string" and length > 0)
  and (.FIREBASE_AUTH_DOMAIN | type == "string" and length > 0)
  and (.FIREBASE_STORAGE_BUCKET | type == "string" and length > 0)
' "$env_file" > /dev/null || fail "$env_file is missing one or more required Firebase keys (FIREBASE_API_KEY, FIREBASE_PROJECT_ID, FIREBASE_MESSAGING_SENDER_ID, FIREBASE_ANDROID_APP_ID, FIREBASE_AUTH_DOMAIN, FIREBASE_STORAGE_BUCKET). Push notifications will not work without these."

api_base_url="$(jq -r '.API_BASE_URL' "$env_file")"
supabase_url="$(jq -r '.SUPABASE_URL' "$env_file")"
firebase_project="$(jq -r '.FIREBASE_PROJECT_ID' "$env_file")"
log "Using Supabase backend : $api_base_url"
log "Using Supabase project  : $supabase_url"
log "Using Firebase project  : $firebase_project"

cd "$repo_root"

build_apk() {
  log "Building release APK with Supabase backend defines."
  if ((${#flutter_args[@]})); then
    flutter build apk --release --dart-define-from-file="$env_file" "${flutter_args[@]}"
  else
    flutter build apk --release --dart-define-from-file="$env_file"
  fi
}

build_aab() {
  log "Building release AAB with Supabase backend defines."
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
