#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Deploy the SchoolDesk Go backend to the Hostinger Docker Compose VPS safely.

Default mode is dry-run. Nothing is changed on the VPS unless --execute is used.

Usage:
  scripts/deploy-hostinger-backend.sh [options]

Options:
  --config <file>     Load deploy settings from this env file.
                      Default: deploy/hostinger-deploy.env when present.
  --dry-run           Run checks and rsync dry-run only. This is the default.
  --execute           Perform backup, rsync, compose rebuild, and verification.
  --migrate           Temporarily set MIGRATE_ON_START=true during rebuild, then
                      set it back to false and recreate the API container.
  --check-only        Only verify SSH, remote Compose state, migration flag, and
                      public health. No tests, backup, rsync, or rebuild.
  --skip-tests        Skip local go test ./... before deploy/dry-run.
  --yes               Non-interactive execute confirmation.
  --no-login-smoke    Skip optional login smoke even when credentials are set.
  -h, --help          Show this help.

Optional login smoke environment:
  HOSTINGER_SMOKE_LOGIN_USERNAME=principal
  HOSTINGER_SMOKE_LOGIN_PASSWORD='<set-in-current-shell>'

Examples:
  scripts/deploy-hostinger-backend.sh --check-only
  scripts/deploy-hostinger-backend.sh --dry-run
  scripts/deploy-hostinger-backend.sh --execute --yes
  scripts/deploy-hostinger-backend.sh --execute --migrate --yes
USAGE
}

log() {
  printf '[hostinger-deploy] %s\n' "$*"
}

warn() {
  printf '[hostinger-deploy][warn] %s\n' "$*" >&2
}

fail() {
  printf '[hostinger-deploy][error] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

quote() {
  printf '%q' "$1"
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
backend_dir="$repo_root/school-backend"

config_file="${HOSTINGER_DEPLOY_CONFIG:-$repo_root/deploy/hostinger-deploy.env}"
mode="dry-run"
run_migrations=false
check_only=false
skip_tests=false
yes=false
login_smoke=true

args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[$i]}" in
    --config)
      i=$((i + 1))
      [[ $i -lt ${#args[@]} ]] || fail "--config requires a file path"
      config_file="${args[$i]}"
      ;;
  esac
done

if [[ -f "$config_file" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "$config_file"
  set +a
fi

while (($#)); do
  case "$1" in
    --config)
      shift
      [[ $# -gt 0 ]] || fail "--config requires a file path"
      config_file="$1"
      ;;
    --dry-run)
      mode="dry-run"
      ;;
    --execute)
      mode="execute"
      ;;
    --migrate)
      run_migrations=true
      ;;
    --check-only)
      check_only=true
      ;;
    --skip-tests)
      skip_tests=true
      ;;
    --yes)
      yes=true
      ;;
    --no-login-smoke)
      login_smoke=false
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
  shift
done

vps_host="${HOSTINGER_SSH_HOST:-187.127.157.43}"
vps_user="${HOSTINGER_SSH_USER:-root}"
ssh_key="${HOSTINGER_SSH_KEY:-$HOME/.ssh/schooldesk_hostinger_vps}"
expected_fingerprint="${HOSTINGER_EXPECTED_ED25519_SHA256:-SHA256:ZqqHqq502eUL+j3N5ccdlfVD7nxPUBkGchftOj40atA}"
remote_root="${HOSTINGER_REMOTE_ROOT:-/opt/schooldesk_V1}"
compose_file="${HOSTINGER_COMPOSE_FILE:-docker-compose.hostinger-traefik.yml}"
compose_service="${HOSTINGER_COMPOSE_SERVICE:-go-api}"
compose_extra_services="${HOSTINGER_COMPOSE_EXTRA_SERVICES:-}"
compose_profiles="${HOSTINGER_COMPOSE_PROFILES:-}"
health_url="${HOSTINGER_API_HEALTH_URL:-https://schooldesk-api.187.127.157.43.nip.io/health}"
login_url="${HOSTINGER_API_LOGIN_URL:-https://schooldesk-api.187.127.157.43.nip.io/api/v1/auth/login}"
backup_root="${HOSTINGER_BACKUP_ROOT:-/root/schooldesk-backups}"
known_hosts_file="${HOSTINGER_KNOWN_HOSTS_FILE:-$HOME/.ssh/known_hosts}"
ssh_target="${vps_user}@${vps_host}"

ssh_opts=(
  -i "$ssh_key"
  -o BatchMode=yes
  -o ConnectTimeout=10
  -o StrictHostKeyChecking=yes
  -o UserKnownHostsFile="$known_hosts_file"
)

remote() {
  ssh "${ssh_opts[@]}" "$ssh_target" "$@"
}

remote_bash() {
  ssh "${ssh_opts[@]}" "$ssh_target" "bash -se" <<<"$1"
}

wait_for_health() {
  local attempts="${1:-30}"
  local delay="${2:-3}"
  local body

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if body="$(curl -fsS "$health_url" 2>/dev/null)"; then
      log "Health check passed: $body"
      return 0
    fi
    sleep "$delay"
  done

  fail "Health check failed after $attempts attempts: $health_url"
}

run_login_smoke() {
  if [[ "$login_smoke" != true ]]; then
    log "Login smoke skipped by --no-login-smoke."
    return 0
  fi

  if [[ -z "${HOSTINGER_SMOKE_LOGIN_USERNAME:-}" || -z "${HOSTINGER_SMOKE_LOGIN_PASSWORD:-}" ]]; then
    log "Login smoke skipped; HOSTINGER_SMOKE_LOGIN_USERNAME/PASSWORD are not both set."
    return 0
  fi

  local payload response body status
  payload="$(jq -cn \
    --arg username "$HOSTINGER_SMOKE_LOGIN_USERNAME" \
    --arg password "$HOSTINGER_SMOKE_LOGIN_PASSWORD" \
    '{username:$username,password:$password}')"

  response="$(curl -fsS -w $'\nHTTP:%{http_code}' \
    -H 'Content-Type: application/json' \
    -d "$payload" \
    "$login_url")"
  body="${response%$'\n'HTTP:*}"
  status="${response##*$'\n'HTTP:}"

  [[ "$status" == "200" ]] || fail "Login smoke returned HTTP $status"
  jq -e '.success == true and .data.user.username != null' >/dev/null <<<"$body" ||
    fail "Login smoke response did not contain success=true and user.username"
  log "Login smoke passed for username: $HOSTINGER_SMOKE_LOGIN_USERNAME"
}

set_remote_migrate_flag() {
  local value="$1"
  remote_bash "$(cat <<REMOTE
set -Eeuo pipefail
cd $(quote "$remote_root")
if grep -q '^MIGRATE_ON_START=' .env; then
  sed -i 's/^MIGRATE_ON_START=.*/MIGRATE_ON_START=$value/' .env
else
  printf '\\nMIGRATE_ON_START=$value\\n' >> .env
fi
grep '^MIGRATE_ON_START=' .env
REMOTE
)"
}

restore_migrate_false() {
  if [[ "${migration_flag_touched:-false}" == true && "$mode" == "execute" ]]; then
    warn "Restoring MIGRATE_ON_START=false on remote .env before exit."
    set_remote_migrate_flag false >/dev/null || true
  fi
}

trap restore_migrate_false EXIT

require_cmd ssh
require_cmd ssh-keyscan
require_cmd ssh-keygen
require_cmd rsync
require_cmd curl
require_cmd jq
if [[ "$skip_tests" != true && "$check_only" != true ]]; then
  require_cmd go
fi

[[ -d "$backend_dir" ]] || fail "Backend directory not found: $backend_dir"
[[ -f "$backend_dir/main.go" ]] || fail "Backend entrypoint not found: $backend_dir/main.go"
compose_source="$repo_root/$compose_file"
[[ -f "$compose_source" ]] || fail "Compose source not found: $compose_source"
[[ -f "$ssh_key" ]] || fail "SSH key not found: $ssh_key"

if [[ -n "$expected_fingerprint" ]]; then
  log "Checking VPS ED25519 fingerprint before SSH."
  host_key_scan="$(ssh-keyscan -T 5 -t ed25519 "$vps_host" 2>/dev/null || true)"
  actual_fingerprint="$(ssh-keygen -lf - 2>/dev/null <<<"$host_key_scan" | awk '{print $2; exit}')"
  [[ -n "$actual_fingerprint" ]] || fail "Could not read ED25519 host fingerprint for $vps_host"
  [[ "$actual_fingerprint" == "$expected_fingerprint" ]] ||
    fail "Host fingerprint mismatch. Expected $expected_fingerprint, got $actual_fingerprint"
  mkdir -p "$(dirname "$known_hosts_file")"
  touch "$known_hosts_file"
  chmod 600 "$known_hosts_file"
  if ! ssh-keygen -F "$vps_host" -f "$known_hosts_file" >/dev/null 2>&1; then
    printf '%s\n' "$host_key_scan" >> "$known_hosts_file"
  fi
fi

log "Remote target: $ssh_target:$remote_root"
log "Compose file: $compose_file"
log "Service: $compose_service"
if [[ -n "$compose_extra_services" ]]; then
  log "Extra services: $compose_extra_services"
fi
if [[ -n "$compose_profiles" ]]; then
  log "Compose profiles: $compose_profiles"
fi
log "Mode: $mode"

if [[ "$skip_tests" != true && "$check_only" != true ]]; then
  log "Running local backend tests before deployment."
  (cd "$backend_dir" && go test ./...)
fi

log "Checking remote Docker Compose environment."
remote_bash "$(cat <<REMOTE
set -Eeuo pipefail
command -v docker >/dev/null
docker compose version >/dev/null
test -d $(quote "$remote_root")
test -f $(quote "$remote_root/$compose_file")
test -f $(quote "$remote_root/.env")
cd $(quote "$remote_root")
docker compose -f $(quote "$compose_file") ps
echo CURRENT_MIGRATE_FLAG
grep '^MIGRATE_ON_START=' .env || true
REMOTE
)"

remote_migrate_value="$(
  remote "cd $(quote "$remote_root") && grep '^MIGRATE_ON_START=' .env 2>/dev/null | tail -n1 | cut -d= -f2-" || true
)"
if [[ "$mode" == "execute" && "$run_migrations" != true && "$remote_migrate_value" == "true" ]]; then
  fail "Remote .env has MIGRATE_ON_START=true. Run with --migrate or set it back to false before deploying."
fi

wait_for_health 10 2

if [[ "$check_only" == true ]]; then
  run_login_smoke
  log "Check-only completed without changing the VPS."
  exit 0
fi

rsync_excludes=(
  --exclude='.git/'
  --exclude='.env'
  --exclude='.gocache/'
  --exclude='.DS_Store'
  --exclude='school.db'
  --exclude='test-report/'
  --exclude='tmp/'
  --exclude='uploads/'
)
rsync_rsh="$(printf '%q ' ssh "${ssh_opts[@]}")"
rsync_target="$ssh_target:$remote_root/school-backend/"
rsync_args=(-az --delete --itemize-changes "${rsync_excludes[@]}" -e "$rsync_rsh" "$backend_dir/" "$rsync_target")
compose_rsync_args=(-az --itemize-changes -e "$rsync_rsh" "$compose_source" "$ssh_target:$remote_root/$compose_file")

if [[ "$mode" != "execute" ]]; then
  log "Running rsync dry-run. No files will be changed."
  rsync --dry-run "${compose_rsync_args[@]}"
  rsync --dry-run "${rsync_args[@]}"
  log "Dry-run completed. Re-run with --execute to deploy."
  exit 0
fi

if [[ "$yes" != true ]]; then
  printf 'Type DEPLOY to update %s:%s: ' "$ssh_target" "$remote_root" >&2
  read -r answer
  [[ "$answer" == "DEPLOY" ]] || fail "Deployment cancelled."
fi

backup_dir="$backup_root/deploy-$(date -u +%Y%m%d-%H%M%S)"
log "Creating remote backup: $backup_dir"
remote_bash "$(cat <<REMOTE
set -Eeuo pipefail
backup_dir=$(quote "$backup_dir")
remote_root=$(quote "$remote_root")
compose_file=$(quote "$compose_file")
mkdir -p "\$backup_dir"
cd "\$remote_root"
docker compose -f "\$compose_file" ps > "\$backup_dir/docker-compose-ps.txt" || true
docker ps > "\$backup_dir/docker-ps.txt" || true
cp "\$compose_file" "\$backup_dir/"
cp .env "\$backup_dir/env.backup"
tar \
  --exclude='school-backend/.git' \
  --exclude='school-backend/.gocache' \
  --exclude='school-backend/tmp' \
  --exclude='school-backend/test-report' \
  --exclude='school-backend/uploads' \
  -czf "\$backup_dir/school-backend-source.tgz" \
  school-backend
if docker ps --format '{{.Names}}' | grep -qx 'schooldesk-postgres'; then
  docker exec schooldesk-postgres sh -lc 'pg_dump --clean --if-exists -U "\$POSTGRES_USER" "\$POSTGRES_DB"' > "\$backup_dir/postgres.sql"
fi
ls -lh "\$backup_dir"
REMOTE
)"

log "Syncing backend source to VPS."
rsync "${compose_rsync_args[@]}"
rsync "${rsync_args[@]}"

if [[ "$run_migrations" == true ]]; then
  log "Enabling MIGRATE_ON_START=true for this rebuild only."
  migration_flag_touched=true
  set_remote_migrate_flag true
fi

compose_services=("$compose_service")
if [[ -n "$compose_extra_services" ]]; then
  # shellcheck disable=SC2206
  extra_services=( $compose_extra_services )
  compose_services+=("${extra_services[@]}")
fi
compose_services_remote="$(printf ' %q' "${compose_services[@]}")"
profile_export=""
if [[ -n "$compose_profiles" ]]; then
  profile_export="export COMPOSE_PROFILES=$(quote "$compose_profiles")"
fi

log "Rebuilding and restarting services:${compose_services_remote}."
remote_bash "$(cat <<REMOTE
set -Eeuo pipefail
$profile_export
cd $(quote "$remote_root")
docker compose -f $(quote "$compose_file") up -d --build$compose_services_remote
docker compose -f $(quote "$compose_file") ps
docker logs --tail=120 schooldesk-go-api
if docker ps --format '{{.Names}}' | grep -qx 'schooldesk-notification-worker'; then
  docker logs --tail=80 schooldesk-notification-worker
fi
REMOTE
)"

wait_for_health 30 3

if [[ "$run_migrations" == true ]]; then
  log "Disabling MIGRATE_ON_START and recreating API container without rebuild."
  set_remote_migrate_flag false
  remote_bash "$(cat <<REMOTE
set -Eeuo pipefail
$profile_export
cd $(quote "$remote_root")
docker compose -f $(quote "$compose_file") up -d --no-build $(quote "$compose_service")
docker inspect schooldesk-go-api --format '{{range .Config.Env}}{{println .}}{{end}}' | grep '^MIGRATE_ON_START=' || true
docker compose -f $(quote "$compose_file") ps
REMOTE
)"
  wait_for_health 30 3
fi

run_login_smoke
log "Deployment completed. Backup: $backup_dir"
