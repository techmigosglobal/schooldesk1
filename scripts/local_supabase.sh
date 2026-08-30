#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# This script deliberately exposes a small, local-only command surface.  Do
# not add `link`, `db push`, `db pull`, or `functions deploy` here: production
# promotion is a separate, explicitly approved workflow.
readonly SUPABASE_CLI_VERSION="2.116.0"
readonly LOCAL_PROJECT_ID="schooldesk-local"
readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CONFIG_FILE="$ROOT_DIR/supabase/config.toml"
readonly ENV_FILE="$ROOT_DIR/env.local.json"
readonly FUNCTION_ENV_FILE="$ROOT_DIR/supabase/.env.local"

die() {
  printf '[local-supabase][error] %s\n' "$*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

assert_local_project_config() {
  [[ -f "$CONFIG_FILE" ]] || die "Missing local Supabase config: $CONFIG_FILE"
  grep -Eq "^project_id = \"${LOCAL_PROJECT_ID}\"$" "$CONFIG_FILE" || \
    die "supabase/config.toml must use project_id=${LOCAL_PROJECT_ID}"
}

local_cli() (
  # Always execute the pinned project-local package.  Unset credentials that
  # only matter for hosted Supabase commands; every command below is local.
  cd "$ROOT_DIR"
  exec env -u SUPABASE_ACCESS_TOKEN -u SUPABASE_DB_PASSWORD \
    npx --yes --package="supabase@${SUPABASE_CLI_VERSION}" supabase "$@"
)

ensure_cli() {
  need npx
  assert_local_project_config
  local version
  version="$(local_cli --version)"
  [[ "$version" == "$SUPABASE_CLI_VERSION" ]] || \
    die "Pinned Supabase CLI check failed (expected ${SUPABASE_CLI_VERSION})"
}

ensure_docker() {
  need docker
  docker info >/dev/null 2>&1 || die "Docker is installed but its daemon is unavailable"
}

local_deno() {
  if command -v deno >/dev/null 2>&1; then
    deno "$@"
    return
  fi
  need npx
  npx --yes deno@2.5.6 "$@"
}

start() {
  ensure_docker
  ensure_cli
  # Analytics/logflare are not part of the API security boundary and their
  # optional billing cache can make a clean stack report unhealthy. Excluding
  # them keeps the local database/Auth/Storage/Edge stack deterministic.
  local_cli start --exclude logflare,vector
}

read_status_value() {
  local status_file="$1"
  local key="$2"
  local line value

  line="$(grep -m 1 "^${key}=" "$status_file" || true)"
  [[ -n "$line" ]] || return 1
  value="${line#*=}"
  value="${value%$'\r'}"
  if [[ "$value" == \"*\" ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

assert_local_api_url() {
  case "$1" in
    http://127.0.0.1:* | http://localhost:* | http://[::1]:*) ;;
    *) die "Supabase status returned a non-local API URL; refusing to write runtime config" ;;
  esac
}

assert_single_line() {
  [[ "$2" != *$'\n'* && "$2" != *$'\r'* ]] || die "Invalid local value for $1"
}

write_runtime_env() {
  ensure_cli
  need jq

  local status_file env_tmp function_env_tmp
  local api_url anon_key service_key db_url
  status_file="$(mktemp "${TMPDIR:-/tmp}/schooldesk-local-status.XXXXXX")"
  env_tmp="$(mktemp "$ROOT_DIR/env.local.XXXXXX.json")"
  function_env_tmp="$(mktemp "$ROOT_DIR/supabase/.env.XXXXXX.local")"

  cleanup_runtime_temp() {
    rm -f "$status_file" "$env_tmp" "$function_env_tmp"
  }
  trap cleanup_runtime_temp RETURN

  local_cli status -o env > "$status_file"
  api_url="$(read_status_value "$status_file" API_URL || true)"
  anon_key="$(read_status_value "$status_file" ANON_KEY || read_status_value "$status_file" SUPABASE_ANON_KEY || true)"
  service_key="$(read_status_value "$status_file" SERVICE_ROLE_KEY || read_status_value "$status_file" SUPABASE_SERVICE_ROLE_KEY || true)"
  db_url="$(read_status_value "$status_file" DB_URL || read_status_value "$status_file" POSTGRES_URL || true)"

  [[ -n "$api_url" && -n "$anon_key" && -n "$service_key" ]] || \
    die "Could not read local Supabase credentials from status output"
  assert_local_api_url "$api_url"
  assert_single_line API_URL "$api_url"
  assert_single_line ANON_KEY "$anon_key"
  assert_single_line SERVICE_ROLE_KEY "$service_key"
  assert_single_line DB_URL "$db_url"

  jq -n \
    --arg api_base_url "$api_url/functions/v1/api" \
    --arg supabase_url "$api_url" \
    --arg anon_key "$anon_key" \
    '{
      API_BASE_URL: $api_base_url,
      SUPABASE_URL: $supabase_url,
      SUPABASE_ANON_KEY: $anon_key,
      APP_ENV: "local",
      ENABLE_LOGGING: "true",
      QA_PRINCIPAL_USERNAME: "principal",
      QA_PRINCIPAL_PASSWORD: "Principal@12345",
      QA_ADMIN_USERNAME: "admin",
      QA_ADMIN_PASSWORD: "Admin@12345",
      QA_COORDINATOR_USERNAME: "coordinator",
      QA_COORDINATOR_PASSWORD: "Coordinator@12345",
      QA_TEACHER_USERNAME: "teacher",
      QA_TEACHER_PASSWORD: "Teacher@12345",
      QA_PARENT_USERNAME: "parent",
      QA_PARENT_PASSWORD: "Parent@12345",
      QA_STUDENT_USERNAME: "student",
      QA_STUDENT_PASSWORD: "Student@12345",
      QA_KIOSK_USERNAME: "kiosk",
      QA_KIOSK_PASSWORD: "Kiosk@12345",
      QA_SUPER_ADMIN_USERNAME: "superadmin",
      QA_SUPER_ADMIN_PASSWORD: "SuperAdmin@12345",
      QA_SECOND_SCHOOL_PRINCIPAL_USERNAME: "second-principal",
      QA_SECOND_SCHOOL_PRINCIPAL_PASSWORD: "SecondPrincipal@12345",
      QA_SECOND_SCHOOL_ADMIN_USERNAME: "second-admin",
      QA_SECOND_SCHOOL_ADMIN_PASSWORD: "SecondAdmin@12345",
      QA_SECOND_SCHOOL_COORDINATOR_USERNAME: "second-coordinator",
      QA_SECOND_SCHOOL_COORDINATOR_PASSWORD: "SecondCoordinator@12345",
      QA_SECOND_SCHOOL_TEACHER_USERNAME: "second-teacher",
      QA_SECOND_SCHOOL_TEACHER_PASSWORD: "SecondTeacher@12345",
      QA_SECOND_SCHOOL_PARENT_USERNAME: "second-parent",
      QA_SECOND_SCHOOL_PARENT_PASSWORD: "SecondParent@12345",
      QA_SECOND_SCHOOL_KIOSK_USERNAME: "second-kiosk",
      QA_SECOND_SCHOOL_KIOSK_PASSWORD: "SecondKiosk@12345",
      FIREBASE_API_KEY: "",
      FIREBASE_PROJECT_ID: "",
      FIREBASE_MESSAGING_SENDER_ID: "",
      FIREBASE_ANDROID_APP_ID: "",
      FIREBASE_IOS_APP_ID: "",
      FIREBASE_WEB_APP_ID: "",
      FIREBASE_AUTH_DOMAIN: "",
      FIREBASE_STORAGE_BUCKET: "",
      FIREBASE_MEASUREMENT_ID: "",
      FIREBASE_VAPID_KEY: ""
    }' > "$env_tmp"

  {
    printf 'SUPABASE_URL=%s\n' "$api_url"
    printf 'SUPABASE_ANON_KEY=%s\n' "$anon_key"
    printf 'SUPABASE_SERVICE_ROLE_KEY=%s\n' "$service_key"
    printf 'SUPABASE_DB_URL=%s\n' "$db_url"
    printf 'SCHOOLDESK_LOCAL_CONFIG=%s\n' "$ENV_FILE"
  } > "$function_env_tmp"

  chmod 600 "$env_tmp" "$function_env_tmp"
  mv -f "$env_tmp" "$ENV_FILE"
  mv -f "$function_env_tmp" "$FUNCTION_ENV_FILE"
  trap - RETURN
  rm -f "$status_file"
}

reset_db() {
  start
  # `--local` is intentional: it rejects a linked project as the reset target.
  local_cli db reset --local
  write_runtime_env
}

prepare() {
  reset_db
  cat <<'MSG'

Docker-local Supabase is reset with the synthetic two-school fixture.

Run the Flutter app with:
  flutter run --dart-define-from-file=env.local.json

Serve the local API in another terminal with:
  scripts/local_supabase.sh functions

Run local Edge Function tests with:
  scripts/local_supabase.sh test-functions
MSG
}

serve_functions() {
  start
  write_runtime_env
  local_cli functions serve api --env-file "$FUNCTION_ENV_FILE"
}

wait_for_local_api() {
  local api_base_url="$1"
  local function_pid="$2"
  local log_file="$3"
  local attempt status

  for attempt in $(seq 1 60); do
    status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
      --max-time 2 "$api_base_url/health" || true)"
    [[ "$status" == "200" ]] && return 0
    if ! kill -0 "$function_pid" 2>/dev/null; then
      sed -n '1,240p' "$log_file" >&2 || true
      die "Local Edge Function exited before its health check passed"
    fi
    sleep 0.5
  done

  sed -n '1,240p' "$log_file" >&2 || true
  die "Timed out waiting for the local Edge Function health check"
}

test_functions() {
  need curl
  need jq
  prepare

  local api_base_url log_file function_pid
  local -a test_files
  api_base_url="$(jq -er '.API_BASE_URL' "$ENV_FILE")"
  log_file="$(mktemp "${TMPDIR:-/tmp}/schooldesk-local-api.XXXXXX.log")"
  mapfile -t test_files < <(
    find "$ROOT_DIR/supabase/functions/api" -type f -name '*_test.ts' -print | sort
  )
  ((${#test_files[@]} > 0)) || die "No Edge Function test files were found"

  local_cli functions serve api --env-file "$FUNCTION_ENV_FILE" > "$log_file" 2>&1 &
  function_pid=$!
  cleanup_function_test() {
    kill "$function_pid" 2>/dev/null || true
    wait "$function_pid" 2>/dev/null || true
    rm -f "$log_file"
  }
  trap cleanup_function_test RETURN

  wait_for_local_api "$api_base_url" "$function_pid" "$log_file"
  set -a
  # Generated from local `supabase status`; never source a hosted env file here.
  # shellcheck disable=SC1090
  source "$FUNCTION_ENV_FILE"
  set +a
  (cd "$ROOT_DIR" && local_deno test --no-lock --allow-env --allow-net --allow-read "${test_files[@]}")
}

status() {
  ensure_cli
  local_cli status
}

stop() {
  ensure_cli
  # Never use `--all`; other projects' containers are out of scope.
  local_cli stop --project-id "$LOCAL_PROJECT_ID"
}

case "${1:-help}" in
  prepare) prepare ;;
  start) start ;;
  reset | db-reset) reset_db ;;
  functions | serve-functions) serve_functions ;;
  test-functions) test_functions ;;
  stop) stop ;;
  status) status ;;
  *)
    cat <<'MSG'
Usage: scripts/local_supabase.sh <command>

Local-only commands:
  prepare          Start Docker-local Supabase and reset migrations/seeds
  start            Start this repository's Docker-local Supabase stack
  reset            Reset only the local database and regenerate local runtime config
  functions        Serve the local api Edge Function
  test-functions   Reset locally, serve api, and run Edge Function Deno tests
  stop             Stop only this repository's local Supabase stack
  status           Print Docker-local Supabase status

Hosted Supabase commands are intentionally not available through this script.
MSG
    ;;
esac
