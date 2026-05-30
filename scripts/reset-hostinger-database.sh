#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Reset the SchoolDesk Hostinger PostgreSQL data safely.

Default mode is dry-run. Nothing is changed unless --execute is used.
The reset keeps a minimal bootstrap by default: one school, roles,
permissions, and the principal login. Operational ERP data is removed.

Usage:
  scripts/reset-hostinger-database.sh [options]

Options:
  --config <file>       Load deploy settings from this env file.
                        Default: deploy/hostinger-deploy.env when present.
  --dry-run             Show the reset plan only. This is the default.
  --execute             Backup, reset PostgreSQL schema, rerun migrations,
                        seed bootstrap login, clear Redis, and clear uploads.
  --yes                 Non-interactive execute confirmation.
  --no-bootstrap        Leave the database fully empty after migrations.
                        Login will not work until a user is created manually.
  -h, --help            Show this help.
USAGE
}

log() {
  printf '[hostinger-reset] %s\n' "$*"
}

fail() {
  printf '[hostinger-reset][error] %s\n' "$*" >&2
  exit 1
}

quote() {
  printf '%q' "$1"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
config_file="${HOSTINGER_DEPLOY_CONFIG:-$repo_root/deploy/hostinger-deploy.env}"
mode="dry-run"
yes=false
bootstrap=true

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
    --yes)
      yes=true
      ;;
    --no-bootstrap)
      bootstrap=false
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

vps_host="${HOSTINGER_SSH_HOST:-46.28.44.198}"
vps_user="${HOSTINGER_SSH_USER:-root}"
ssh_key="${HOSTINGER_SSH_KEY:-$HOME/.ssh/schooldesk_hostinger_vps}"
expected_fingerprint="${HOSTINGER_EXPECTED_ED25519_SHA256:-SHA256:B/u7sYGr6RwyxXuwcoa5cKHlGhkcg1HAqelU6+WEpP4}"
remote_root="${HOSTINGER_REMOTE_ROOT:-/opt/schooldesk-backend}"
compose_file="${HOSTINGER_COMPOSE_FILE:-docker-compose.hostinger-traefik.yml}"
compose_service="${HOSTINGER_COMPOSE_SERVICE:-go-api}"
health_url="${HOSTINGER_API_HEALTH_URL:-https://schooldesk-api.46.28.44.198.nip.io/health}"
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

remote_bash() {
  ssh "${ssh_opts[@]}" "$ssh_target" "bash -se" <<<"$1"
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

require_cmd ssh
require_cmd ssh-keyscan
require_cmd ssh-keygen
require_cmd curl
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
log "Mode: $mode"
log "Bootstrap after reset: $bootstrap"

remote_bash "$(cat <<REMOTE
set -Eeuo pipefail
command -v docker >/dev/null
docker compose version >/dev/null
test -d $(quote "$remote_root")
test -f $(quote "$remote_root/$compose_file")
test -f $(quote "$remote_root/.env")
cd $(quote "$remote_root")
docker compose -f $(quote "$compose_file") ps
REMOTE
)"

if [[ "$mode" != "execute" ]]; then
  log "Dry-run only. Re-run with --execute --yes to reset the VPS database."
  exit 0
fi

if [[ "$yes" != true ]]; then
  printf 'Type RESET to erase operational SchoolDesk data on %s: ' "$ssh_target" >&2
  read -r answer
  [[ "$answer" == "RESET" ]] || fail "Reset cancelled."
fi

backup_dir="$backup_root/reset-$(date -u +%Y%m%d-%H%M%S)"
log "Creating remote backup: $backup_dir"
remote_bash "$(cat <<REMOTE
set -Eeuo pipefail
backup_dir=$(quote "$backup_dir")
remote_root=$(quote "$remote_root")
compose_file=$(quote "$compose_file")
mkdir -p "\$backup_dir"
cd "\$remote_root"
docker compose -f "\$compose_file" ps > "\$backup_dir/docker-compose-ps.txt" || true
cp "\$compose_file" "\$backup_dir/"
cp .env "\$backup_dir/env.backup"
if docker ps --format '{{.Names}}' | grep -qx 'schooldesk-postgres'; then
  docker exec schooldesk-postgres sh -lc 'pg_dump --clean --if-exists -U "\$POSTGRES_USER" "\$POSTGRES_DB"' > "\$backup_dir/postgres-before-reset.sql"
fi
if docker ps --format '{{.Names}}' | grep -qx 'schooldesk-go-api'; then
  docker exec schooldesk-go-api sh -lc 'tar -czf - -C /app uploads 2>/dev/null || true' > "\$backup_dir/uploads-before-reset.tgz"
fi
ls -lh "\$backup_dir"
REMOTE
)"

log "Dropping and recreating public schema."
remote_bash "$(cat <<REMOTE
set -Eeuo pipefail
cd $(quote "$remote_root")
docker exec schooldesk-postgres sh -lc 'psql -v ON_ERROR_STOP=1 -U "\$POSTGRES_USER" -d "\$POSTGRES_DB" \
  -c "DROP SCHEMA IF EXISTS public CASCADE" \
  -c "CREATE SCHEMA public" \
  -c "GRANT ALL ON SCHEMA public TO public"'
REMOTE
)"

log "Running migrations with MIGRATE_ON_START=true."
set_remote_migrate_flag true >/dev/null
remote_bash "$(cat <<REMOTE
set -Eeuo pipefail
cd $(quote "$remote_root")
docker compose -f $(quote "$compose_file") up -d --no-build $(quote "$compose_service")
docker logs --tail=120 schooldesk-go-api
REMOTE
)"
wait_for_health 30 3

if [[ "$bootstrap" == true ]]; then
  log "Seeding minimal bootstrap principal, roles, and permissions only."
  remote_bash "$(cat <<REMOTE
set -Eeuo pipefail
cd $(quote "$remote_root")
docker exec \
  -e SEED_ACADEMIC_YEAR=false \
  -e SEED_ACADEMIC_FIXTURES=false \
  -e SEED_SCHOOL_NAME=SchoolDesk \
  schooldesk-go-api ./seed
REMOTE
)"
fi

log "Clearing Redis cache and uploaded user files."
remote_bash "$(cat <<REMOTE
set -Eeuo pipefail
if docker ps --format '{{.Names}}' | grep -qx 'schooldesk-redis'; then
  docker exec schooldesk-redis sh -lc 'redis-cli -a "\$REDIS_PASSWORD" FLUSHDB >/dev/null'
fi
if docker ps --format '{{.Names}}' | grep -qx 'schooldesk-go-api'; then
  docker exec schooldesk-go-api sh -lc 'find /app/uploads -mindepth 1 -type f -delete && find /app/uploads -mindepth 1 -type d -empty -delete'
fi
REMOTE
)"

log "Restoring MIGRATE_ON_START=false and restarting API."
set_remote_migrate_flag false >/dev/null
remote_bash "$(cat <<REMOTE
set -Eeuo pipefail
cd $(quote "$remote_root")
docker compose -f $(quote "$compose_file") up -d --no-build $(quote "$compose_service")
docker inspect schooldesk-go-api --format '{{range .Config.Env}}{{println .}}{{end}}' | grep '^MIGRATE_ON_START=' || true
docker compose -f $(quote "$compose_file") ps
REMOTE
)"
wait_for_health 30 3

log "Reset completed. Backup: $backup_dir"
