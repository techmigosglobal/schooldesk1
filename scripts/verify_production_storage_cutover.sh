#!/usr/bin/env bash
set -Eeuo pipefail

# Read-only production cutover verifier. It never deploys, changes migrations,
# changes secrets, or deletes storage. Management/database checks are optional
# and only run when the caller supplies protected credentials.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

env_file="${1:-env.supabase.json}"
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
[[ -f "$env_file" ]] || { echo "Missing production env file: $env_file" >&2; exit 1; }

api_base="$(jq -r '.API_BASE_URL // empty' "$env_file")"
anon_key="$(jq -r '.SUPABASE_ANON_KEY // empty' "$env_file")"
project_url="$(jq -r '.SUPABASE_URL // empty' "$env_file")"
[[ "$api_base" == https://* ]] || { echo "API_BASE_URL must use HTTPS" >&2; exit 1; }
[[ -n "$anon_key" ]] || { echo "SUPABASE_ANON_KEY is required for health checks" >&2; exit 1; }

request() {
  local path="$1"
  curl -fsS --max-time 20 \
    -H "apikey: $anon_key" \
    -H "Authorization: Bearer $anon_key" \
    "$api_base/$path"
}

health="$(request health)"
ready="$(request ready)"
jq -e '.success == true and .data.status == "ok" and .data.storage == "r2-configured"' \
  <<<"$health" >/dev/null || { echo "Production health did not confirm R2 configuration" >&2; exit 1; }
jq -e '.success == true and .data.database == "ok" and .data.edge_function == "ok" and .data.storage == "r2-configured"' \
  <<<"$ready" >/dev/null || { echo "Production readiness did not confirm database/Edge/R2 health" >&2; exit 1; }

echo "Hosted health: database, Edge Function, and R2 configuration are healthy."

if [[ -n "${SUPABASE_DB_URL:-}" ]]; then
  command -v supabase >/dev/null 2>&1 || { echo "supabase CLI is required for SUPABASE_DB_URL checks" >&2; exit 1; }
  migration_output="$(mktemp)"
  trap 'rm -f "$migration_output"' EXIT
  supabase migration list --db-url "$SUPABASE_DB_URL" >"$migration_output"
  for migration in \
    20260912110000 \
    20260913090000 \
    20260913100000 \
    20260914070738 \
    20260914092444; do
    if ! rg -q "$migration" "$migration_output"; then
      echo "Hosted migration evidence missing: $migration" >&2
      exit 1
    fi
  done
  echo "Hosted migration list contains the required storage/performance/notification/feed migrations."
else
  echo "Hosted migration history: NOT VERIFIED (set SUPABASE_DB_URL in the protected environment)."
fi

if [[ -n "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  command -v supabase >/dev/null 2>&1 || { echo "supabase CLI is required for function checks" >&2; exit 1; }
  ref="${SUPABASE_PROJECT_REF:-${project_url#https://}}"
  ref="${ref%%.*}"
  supabase functions list --project-ref "$ref" -o json >/dev/null
  echo "Hosted Edge Function listing: accessible."
else
  echo "Hosted Edge Function revision list: NOT VERIFIED (set SUPABASE_ACCESS_TOKEN in the protected environment)."
fi

echo "No deployment, migration, secret, or storage mutation was performed."
