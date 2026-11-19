#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ssh_target="${SCHOOLDESK_VPS_SSH_TARGET:-root@82.112.230.198}"
remote_root="${SCHOOLDESK_VPS_FUNCTIONS_ROOT:-/data/schooldesk/functions}"
remote_db_prefix="${SCHOOLDESK_VPS_DB_PREFIX:-supabase-db-}"
remote_edge_prefix="${SCHOOLDESK_VPS_EDGE_PREFIX:-supabase-edge-functions-}"
release_id="$(date -u +%Y%m%dT%H%M%SZ)-${GITHUB_SHA:-local}"
remote_base="/data/schooldesk/repairs/${release_id}-backend"
archive="$(mktemp "${TMPDIR:-/tmp}/schooldesk-functions.XXXXXX.tar.gz")"
trap 'rm -f "$archive"' EXIT
ssh_options=(-o BatchMode=yes -o IdentitiesOnly=yes)
if [[ -n "${SCHOOLDESK_SSH_KEY:-}" ]]; then
  ssh_options+=(-i "$SCHOOLDESK_SSH_KEY")
fi
if [[ -n "${SCHOOLDESK_SSH_KNOWN_HOSTS:-}" ]]; then
  ssh_options+=(-o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$SCHOOLDESK_SSH_KNOWN_HOSTS")
fi

command -v ssh >/dev/null || { printf 'ssh is required\n' >&2; exit 1; }
command -v scp >/dev/null || { printf 'scp is required\n' >&2; exit 1; }
command -v tar >/dev/null || { printf 'tar is required\n' >&2; exit 1; }

tar -C "$repo_root" -czf "$archive" \
  supabase/functions/api \
  supabase/functions/notification-processor \
  supabase/migrations/20261115062654_atomic_parent_payment_request_decisions.sql
archive_sha256="$(sha256sum "$archive" | awk '{print $1}')"

ssh "${ssh_options[@]}" "$ssh_target" "install -d -m 700 '$remote_base/stage'"
scp "${ssh_options[@]}" "$archive" "$ssh_target:$remote_base/stage/functions.tar.gz"

ssh "${ssh_options[@]}" "$ssh_target" "bash -s" \
  -- "$remote_base" "$remote_root" "$remote_db_prefix" "$remote_edge_prefix" "$archive_sha256" <<'REMOTE'
set -Eeuo pipefail
BASE="$1"
ROOT="$2"
DB_PREFIX="$3"
EDGE_PREFIX="$4"
EXPECTED_ARCHIVE_SHA256="$5"
STAGE="$BASE/stage"
DB=$(docker ps --format '{{.Names}}' | awk -v prefix="$DB_PREFIX" 'index($0, prefix) == 1 { print; exit }')
EDGE=$(docker ps --format '{{.Names}}' | awk -v prefix="$EDGE_PREFIX" 'index($0, prefix) == 1 { print; exit }')
test -n "$DB"
test -n "$EDGE"
test "$(sha256sum "$STAGE/functions.tar.gz" | awk '{print $1}')" = "$EXPECTED_ARCHIVE_SHA256"

tar -xzf "$STAGE/functions.tar.gz" -C "$STAGE"
test -f "$STAGE/supabase/functions/api/index.ts"
test -f "$STAGE/supabase/functions/notification-processor/index.ts"

tar -C /data/schooldesk -czf "$BASE/functions-before.tar.gz" functions
docker exec "$DB" pg_dump -U supabase_admin -d postgres -Fc > "$BASE/database-before.dump"
chmod 600 "$BASE/functions-before.tar.gz" "$BASE/database-before.dump"
sha256sum "$BASE/functions-before.tar.gz" "$BASE/database-before.dump" > "$BASE/backup-sha256.txt"

has_decision_function=$(docker exec "$DB" psql -X -U supabase_admin -d postgres -Atqc \
  "select to_regprocedure('public.decide_parent_payment_request(uuid,uuid,text,text,uuid)') is not null")
if [ "$has_decision_function" = t ]; then
  printf 'Payment decision migration already applied, verified by function presence.\n'
else
  docker exec -i "$DB" psql -X -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -1 \
    < "$STAGE/supabase/migrations/20261115062654_atomic_parent_payment_request_decisions.sql" \
    > "$BASE/migration-apply.log"
fi

cp -a "$STAGE/supabase/functions/api/." "$ROOT/api/"
cp -a "$STAGE/supabase/functions/notification-processor/." "$ROOT/notification-processor/"
docker restart "$EDGE" >/dev/null
sleep 5
docker inspect --format '{{.State.Status}}' "$EDGE" | grep -qx running
find "$ROOT/api" "$ROOT/notification-processor" -type f -print0 | sort -z | xargs -0 sha256sum > "$BASE/functions-after.sha256"
printf 'Full SchoolDesk Functions promotion completed at %s\n' "$BASE"
REMOTE
