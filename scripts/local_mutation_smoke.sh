#!/usr/bin/env bash
set -Eeuo pipefail

# Local-only authenticated mutation smoke. This deliberately covers the
# methods used by the Flutter profile/settings surfaces; document POST and
# Storage DELETE authorization remain covered by local_storage_security_smoke.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
[[ -f env.local.json ]] || {
  echo "Run scripts/local_supabase.sh prepare first" >&2
  exit 1
}

api="$(jq -er '.API_BASE_URL' env.local.json)"
[[ "$api" == http://127.0.0.1:* || "$api" == http://localhost:* ]] || {
  echo "Refusing non-local API endpoint: $api" >&2
  exit 1
}

username="$(jq -er '.QA_PRINCIPAL_USERNAME' env.local.json)"
password="$(jq -er '.QA_PRINCIPAL_PASSWORD' env.local.json)"
client_ip="198.18.$((RANDOM % 254)).$((RANDOM % 254))"
login_response="$(curl -fsS --max-time 15 -X POST "$api/auth/login" \
  -H 'Content-Type: application/json' \
  -H "x-forwarded-for: $client_ip" \
  --data "$(jq -nc --arg username "$username" --arg password "$password" \
    '{username:$username,password:$password}')")"
token="$(jq -er '.data.access_token // .data.token' <<<"$login_response")"

expect_status() {
  local expected="$1" description="$2" method="$3" path="$4" body="${5:-}"
  local response_file code
  response_file="$(mktemp "${TMPDIR:-/tmp}/schooldesk-mutation.XXXXXX")"
  if [[ -n "$body" ]]; then
    code="$(curl -sS --max-time 15 -o "$response_file" -w '%{http_code}' \
      -X "$method" "$api$path" \
      -H "Authorization: Bearer $token" \
      -H 'Content-Type: application/json' \
      --data "$body")"
  else
    code="$(curl -sS --max-time 15 -o "$response_file" -w '%{http_code}' \
      -X "$method" "$api$path" \
      -H "Authorization: Bearer $token")"
  fi
  if [[ "$code" != "$expected" ]]; then
    printf '[local-mutation][FAIL] %s (expected %s, got %s)\n' \
      "$description" "$expected" "$code" >&2
    jq -c '{error,message}' "$response_file" >&2 2>/dev/null || true
    rm -f "$response_file"
    exit 1
  fi
  printf '[local-mutation][PASS] %s (HTTP %s)\n' "$description" "$code"
  rm -f "$response_file"
}

expect_status 200 "read current profile" GET /auth/profile
expect_status 200 "PATCH profile name and phone" PATCH /auth/profile \
  '{"name":"API Validation Principal","phone":"+919999999999"}'
expect_status 200 "read updated profile" GET /auth/profile
expect_status 200 "read notification preferences" GET /notifications/preferences
expect_status 200 "PUT notification preferences" PUT /notifications/preferences \
  '{"enable_push":true,"general_alerts":true}'

echo 'PASS: local authenticated mutation smoke'
