#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/env.local.json"
FUNCTION_ENV_FILE="$ROOT_DIR/supabase/.env.local"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    echo "Install it, then rerun this script." >&2
    exit 127
  fi
}

ensure_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    cp "$ROOT_DIR/env.local.example.json" "$ENV_FILE"
    echo "Created env.local.json from env.local.example.json"
  fi
}

write_runtime_env() {
  need supabase
  local status_file
  status_file="$(mktemp)"
  (cd "$ROOT_DIR" && supabase status -o env > "$status_file")

  # shellcheck disable=SC1090
  source "$status_file"
  rm -f "$status_file"

  local api_url="${API_URL:-http://127.0.0.1:54321}"
  local anon_key="${ANON_KEY:-${SUPABASE_ANON_KEY:-}}"
  local service_key="${SERVICE_ROLE_KEY:-${SUPABASE_SERVICE_ROLE_KEY:-}}"
  local db_url="${DB_URL:-${POSTGRES_URL:-}}"

  if [[ -z "$anon_key" || -z "$service_key" ]]; then
    echo "Could not read Supabase local keys from 'supabase status -o env'." >&2
    exit 1
  fi

  cat > "$ENV_FILE" <<JSON
{
  "API_BASE_URL": "$api_url/functions/v1/api",
  "SUPABASE_URL": "$api_url",
  "SUPABASE_ANON_KEY": "$anon_key",
  "APP_ENV": "local",
  "ENABLE_LOGGING": "true",
  "QA_PRINCIPAL_USERNAME": "principal",
  "QA_PRINCIPAL_PASSWORD": "Principal@12345",
  "QA_ADMIN_USERNAME": "admin",
  "QA_ADMIN_PASSWORD": "Admin@12345",
  "QA_TEACHER_USERNAME": "teacher",
  "QA_TEACHER_PASSWORD": "Teacher@12345",
  "QA_PARENT_USERNAME": "parent",
  "QA_PARENT_PASSWORD": "Parent@12345",
  "QA_STUDENT_USERNAME": "student",
  "QA_STUDENT_PASSWORD": "Student@12345",
  "FIREBASE_API_KEY": "",
  "FIREBASE_PROJECT_ID": "",
  "FIREBASE_MESSAGING_SENDER_ID": "",
  "FIREBASE_ANDROID_APP_ID": "",
  "FIREBASE_IOS_APP_ID": "",
  "FIREBASE_WEB_APP_ID": "",
  "FIREBASE_AUTH_DOMAIN": "",
  "FIREBASE_STORAGE_BUCKET": "",
  "FIREBASE_MEASUREMENT_ID": "",
  "FIREBASE_VAPID_KEY": ""
}
JSON

  cat > "$FUNCTION_ENV_FILE" <<ENV
SUPABASE_URL=$api_url
SUPABASE_ANON_KEY=$anon_key
SUPABASE_SERVICE_ROLE_KEY=$service_key
SUPABASE_DB_URL=$db_url
ENV
  chmod 600 "$FUNCTION_ENV_FILE"
}

start() {
  need docker
  need supabase
  (cd "$ROOT_DIR" && supabase start)
}

reset_db() {
  need supabase
  (cd "$ROOT_DIR" && supabase db reset)
}

serve_functions() {
  need supabase
  need deno
  (cd "$ROOT_DIR" && supabase functions serve api --env-file supabase/.env.local)
}

prepare() {
  ensure_env
  start
  write_runtime_env
  reset_db
  cat <<MSG

Local Supabase is ready.

Run the app with:
  flutter run --dart-define-from-file=env.local.json

Serve Edge Functions in a second terminal with:
  scripts/local_supabase.sh functions
MSG
}

case "${1:-help}" in
  prepare) prepare ;;
  start) start ;;
  reset|db-reset) reset_db ;;
  functions|serve-functions) serve_functions ;;
  stop)
    need supabase
    (cd "$ROOT_DIR" && supabase stop)
    ;;
  status)
    need supabase
    (cd "$ROOT_DIR" && supabase status)
    ;;
  *)
    cat <<'MSG'
Usage: scripts/local_supabase.sh <command>

Commands:
  prepare          Create env.local.json, start Supabase, reset DB
  start            Start local Supabase
  reset            Reset DB and run migrations/seed
  functions        Serve the api Edge Function
  stop             Stop local Supabase
  status           Print Supabase status
MSG
    ;;
esac
