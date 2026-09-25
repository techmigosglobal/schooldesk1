#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# Create Supabase platform restore artifacts without storing credentials.
# Required: SUPABASE_PLATFORM_DB_URL
# Optional: RESTORE_OUTPUT_DIR (default: ignored local directory)

readonly CLI_VERSION="2.116.0"
readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly OUTPUT_DIR="${RESTORE_OUTPUT_DIR:-$ROOT_DIR/.local/platform-restore}"

die() { printf '[platform-restore][error] %s\n' "$*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die "Docker is required by supabase db dump"
command -v npx >/dev/null 2>&1 || die "npx is required"
[[ -n "${SUPABASE_PLATFORM_DB_URL:-}" ]] || die "Set SUPABASE_PLATFORM_DB_URL in protected shell environment"

mkdir -p "$OUTPUT_DIR"
chmod 700 "$OUTPUT_DIR"

cli=(npx --yes --package="supabase@${CLI_VERSION}" supabase)
version="$("${cli[@]}" --version | head -n 1)"
[[ "$version" == "$CLI_VERSION" ]] || die "Expected Supabase CLI ${CLI_VERSION}; got ${version}"

# Do not echo URL or password. CLI requires percent-encoded connection string.
"${cli[@]}" db dump --db-url "$SUPABASE_PLATFORM_DB_URL" \
  --role-only --file "$OUTPUT_DIR/roles.sql"
"${cli[@]}" db dump --db-url "$SUPABASE_PLATFORM_DB_URL" \
  --file "$OUTPUT_DIR/schema.sql"
"${cli[@]}" db dump --db-url "$SUPABASE_PLATFORM_DB_URL" \
  --data-only --use-copy --file "$OUTPUT_DIR/data.sql"

cat > "$OUTPUT_DIR/README.txt" <<'EOF'
SchoolDesk platform restore artifacts

Files:
- roles.sql  Supabase database roles
- schema.sql schema, RLS, functions, triggers, policies
- data.sql   application/auth/storage metadata data

Storage objects are intentionally not included. School post media stays in
Cloudflare R2. Configure R2 secrets on the self-hosted Edge API and keep
STORAGE_WRITE_PROVIDER=r2, STORAGE_READ_ORDER=r2,supabase,
STORAGE_LEGACY_READ=true, STORAGE_LEGACY_WRITE=false during rollback window.

Before restore:
1. Start a fresh self-hosted Supabase stack on Coolify.
2. Use Postgres 17-compatible self-hosted release for this project.
3. Set Supabase URL, JWT/API keys, dashboard password, SMTP, and Edge API
   secrets. Never commit .env or restore SQL files.

Restore only after reviewing dump contents:
psql --single-transaction --variable ON_ERROR_STOP=1 \
  --file roles.sql --file schema.sql \
  --command 'SET session_replication_role = replica' \
  --file data.sql --dbname "$SELF_HOSTED_POSTGRES_URL"

Then verify auth.users, key public tables, extensions, RLS, Edge API health,
Realtime, auth login, and R2 read/write paths. Existing platform JWTs are
invalid after self-hosting; users must sign in again.
EOF

printf 'Restore artifacts written to %s\n' "$OUTPUT_DIR"
printf 'Files: roles.sql schema.sql data.sql README.txt\n'
