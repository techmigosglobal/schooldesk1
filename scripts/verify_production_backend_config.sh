#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

prod_api="https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api"
prod_url="https://ouvwogguttybmpgfgctc.supabase.co"

require_contains() {
  local file="$1"
  local text="$2"
  if ! grep -Fq -- "$text" "$file"; then
    echo "Missing expected production backend config in $file: $text" >&2
    exit 1
  fi
}

require_contains env.supabase.example.json "\"API_BASE_URL\": \"$prod_api\""
require_contains env.supabase.example.json "\"SUPABASE_URL\": \"$prod_url\""
require_contains env.supabase.example.json "\"APP_ENV\": \"production\""
require_contains env.supabase.example.json "\"ENABLE_LOGGING\": \"false\""

require_contains codemagic.yaml "API_BASE_URL: $prod_api"
require_contains codemagic.yaml "SUPABASE_URL: $prod_url"
require_contains codemagic.yaml "--dart-define=APP_ENV=production"
require_contains codemagic.yaml "--dart-define=ENABLE_LOGGING=false"

require_contains scripts/build-android-supabase.sh 'test("^https://.+\\.supabase\\.co/functions/v1/api$")'
require_contains scripts/build-android-supabase.sh '(.APP_ENV == "production")'
require_contains scripts/build-android-supabase.sh '((.ENABLE_LOGGING | tostring) == "false")'

echo "Production backend config is pinned to Supabase Edge."
