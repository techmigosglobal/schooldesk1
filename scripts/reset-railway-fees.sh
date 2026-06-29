#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Reset only SchoolDesk Railway fee/payment data.

Default mode is dry-run. It prints table counts and does not modify data.
Students, parents, users, parent-child links, guardians, classes, attendance,
and academics are protected and are not truncated by this script.

Usage:
  DATABASE_URL='postgres://...' scripts/reset-railway-fees.sh [options]

Options:
  --dry-run                     Show fee table counts only. Default.
  --execute                     Backup selected fee tables, then truncate them.
  --confirm RAILWAY_FEE_RESET   Required with --execute.
  --backup-dir <dir>            Backup directory. Default: backups.
  --allow-any-database          Allow non-Railway DATABASE_URL for local testing.
  -h, --help                    Show this help.
USAGE
}

log() {
  printf '[railway-fee-reset] %s\n' "$*"
}

fail() {
  printf '[railway-fee-reset][error] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

mode="dry-run"
confirm=""
backup_dir="backups"
allow_any_database=false

while (($#)); do
  case "$1" in
    --dry-run)
      mode="dry-run"
      ;;
    --execute)
      mode="execute"
      ;;
    --confirm)
      shift
      [[ $# -gt 0 ]] || fail "--confirm requires RAILWAY_FEE_RESET"
      confirm="$1"
      ;;
    --backup-dir)
      shift
      [[ $# -gt 0 ]] || fail "--backup-dir requires a path"
      backup_dir="$1"
      ;;
    --allow-any-database)
      allow_any_database=true
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

database_url="${DATABASE_URL:-}"
[[ -n "$database_url" ]] || fail "DATABASE_URL is required"

if [[ "$allow_any_database" != true ]]; then
  case "$database_url" in
    *railway* | *rlwy.net* | *railway.internal*) ;;
    *)
      fail "DATABASE_URL does not look like Railway. Use --allow-any-database only for local testing."
      ;;
  esac
fi

client_database_url="$database_url"
if command -v psql >/dev/null 2>&1 && command -v pg_dump >/dev/null 2>&1; then
  psql_runner=(psql)
  pg_dump_runner=(pg_dump)
else
  require_cmd docker
  log "psql/pg_dump not found locally; using postgres:16-alpine Docker client."
  client_database_url="${client_database_url//@127.0.0.1:/@host.docker.internal:}"
  client_database_url="${client_database_url//@localhost:/@host.docker.internal:}"
  psql_runner=(docker run --rm -i postgres:16-alpine psql)
  pg_dump_runner=(docker run --rm -i postgres:16-alpine pg_dump)
fi

run_psql() {
  "${psql_runner[@]}" "$client_database_url" "$@"
}

run_pg_dump() {
  "${pg_dump_runner[@]}" "$client_database_url" "$@"
}

fee_tables=(
  fee_receipt_invoice_map
  payment_order_invoice_map
  fee_receipts
  payment_transactions
  payment_webhook_events
  payment_orders
  parent_payment_requests
  payments
  fee_invoice_items
  fee_invoices
  fee_concessions
  fee_installments
  fee_structures
  fee_categories
  school_payment_settings
  scoped_payment_settings
)

protected_tables=(
  students
  users
  parent_student_links
  guardians
  student_guardians
  enrollments
  schools
  grades
  sections
  attendance_sessions
  student_attendances
)

table_csv=""
for table in "${fee_tables[@]}"; do
  if [[ -z "$table_csv" ]]; then
    table_csv="public.$table"
  else
    table_csv="$table_csv, public.$table"
  fi
done

counts_sql="$(
  for table in "${fee_tables[@]}"; do
    printf "SELECT '%s' AS table_name, COUNT(*)::bigint AS rows FROM public.%s;\n" "$table" "$table"
  done
)"

log "Mode: $mode"
log "Fee tables: ${fee_tables[*]}"
log "Protected non-fee tables: ${protected_tables[*]}"

log "Current fee table counts:"
run_psql -v ON_ERROR_STOP=1 -P pager=off -c "$counts_sql"

if [[ "$mode" != "execute" ]]; then
  log "Dry-run only. No data was changed."
  log "To apply: DATABASE_URL='...' scripts/reset-railway-fees.sh --execute --confirm RAILWAY_FEE_RESET"
  exit 0
fi

[[ "$confirm" == "RAILWAY_FEE_RESET" ]] ||
  fail "--execute requires --confirm RAILWAY_FEE_RESET"

timestamp="$(date -u +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
backup_file="$backup_dir/railway-fees-before-reset-$timestamp.sql"

log "Backing up fee tables to $backup_file"
run_pg_dump \
  --clean \
  --if-exists \
  $(printf -- '--table=public.%s ' "${fee_tables[@]}") \
  > "$backup_file"

[[ -s "$backup_file" ]] || fail "Backup file was not created: $backup_file"

log "Truncating only fee/payment tables."
run_psql -v ON_ERROR_STOP=1 <<SQL
BEGIN;
TRUNCATE TABLE $table_csv RESTART IDENTITY CASCADE;
COMMIT;
SQL

log "Post-reset fee table counts:"
run_psql -v ON_ERROR_STOP=1 -P pager=off -c "$counts_sql"

log "Fee reset complete. Backup: $backup_file"
