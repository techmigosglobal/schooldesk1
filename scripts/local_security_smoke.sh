#!/usr/bin/env bash
set -Eeuo pipefail

# Direct HTTP RBAC smoke tests for the Docker-local Edge API. The script only
# accepts the generated local env file and refuses any non-loopback endpoint.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
[[ -f env.local.json ]] || { echo "Run scripts/local_supabase.sh prepare first" >&2; exit 1; }

api="$(jq -er '.API_BASE_URL' env.local.json)"
anon="$(jq -er '.SUPABASE_ANON_KEY' env.local.json)"
[[ "$api" == http://127.0.0.1:* || "$api" == http://localhost:* ]] || {
  echo "Refusing non-local API endpoint: $api" >&2
  exit 1
}

fail() { echo "[local-security][FAIL] $*" >&2; exit 1; }
pass() { echo "[local-security][PASS] $*"; }
login_ip="198.18.$((RANDOM % 254)).$((RANDOM % 254))"

login() {
  local username="$1" password="$2"
  curl --max-time 15 --fail-with-body -sS "$api/auth/login" \
    -H "apikey: $anon" -H 'Content-Type: application/json' \
    -H "x-forwarded-for: $login_ip" \
    -d "{\"username\":\"$username\",\"password\":\"$password\"}"
}

principal="$(login principal 'Principal@12345')"
admin="$(login admin 'Admin@12345')"
coordinator="$(login coordinator 'Coordinator@12345')"
teacher="$(login teacher 'Teacher@12345')"
parent="$(login parent 'Parent@12345')"
kiosk="$(login kiosk 'Kiosk@12345')"
superadmin="$(login superadmin 'SuperAdmin@12345')"

for role in principal admin coordinator teacher parent kiosk superadmin; do
  response="$(eval "printf '%s' \"\${$role}\"")"
  [[ "$(jq -r '.success' <<<"$response")" == true ]] || fail "$role login"
done
pass "all local fixture identities authenticate"

token() { jq -er '.data.token' <<<"$1"; }
p_token="$(token "$principal")"
a_token="$(token "$admin")"
c_token="$(token "$coordinator")"
t_token="$(token "$teacher")"
pa_token="$(token "$parent")"
k_token="$(token "$kiosk")"
s_token="$(token "$superadmin")"

request_status() {
  local method="$1" path="$2" bearer="$3" body="${4:-}"
  if [[ -n "$body" ]]; then
    curl --max-time 15 -sS -o /tmp/schooldesk-local-security-response \
      -w '%{http_code}' -X "$method" "$api$path" \
      -H "apikey: $anon" -H "Authorization: Bearer $bearer" \
      -H 'Content-Type: application/json' -d "$body"
  else
    curl --max-time 15 -sS -o /tmp/schooldesk-local-security-response \
      -w '%{http_code}' -X "$method" "$api$path" \
      -H "apikey: $anon" -H "Authorization: Bearer $bearer"
  fi
}

expect_status() {
  local expected="$1" description="$2" method="$3" path="$4" bearer="$5" body="${6:-}"
  local actual
  actual="$(request_status "$method" "$path" "$bearer" "$body")"
  [[ "$actual" == "$expected" ]] || {
    printf '[local-security][FAIL] %s (expected %s, got %s)\n' "$description" "$expected" "$actual" >&2
    sed -n '1,8p' /tmp/schooldesk-local-security-response >&2 || true
    exit 1
  }
  pass "$description"
}

expect_status 200 "principal dashboard" GET /dashboard/principal "$p_token"
expect_status 200 "admin dashboard" GET /dashboard/admin "$a_token"
expect_status 200 "coordinator operations dashboard" GET /dashboard/coordinator "$c_token"
expect_status 200 "teacher scoped dashboard" GET /dashboard/teacher "$t_token"
expect_status 200 "parent family dashboard" GET /dashboard/parent "$pa_token"
expect_status 403 "kiosk cannot use school dashboard" GET /dashboard/kiosk "$k_token"
dashboard_body="$(curl --max-time 15 -sS "$api/dashboard/coordinator" -H "apikey: $anon" -H "Authorization: Bearer $c_token")"
[[ "$(jq -c 'tostring | test("fee|balance|collection"; "i")' <<<"$dashboard_body")" == false ]] || fail "Coordinator dashboard contains finance fields"
pass "Coordinator dashboard excludes finance fields"

expect_status 403 "Coordinator finance denial" GET /fee-invoices "$c_token"
expect_status 200 "Coordinator can read parent accounts for student links" GET "/users?role=Parent&status=active&page=1&page_size=10" "$c_token"
expect_status 403 "Coordinator cannot list unrestricted user accounts" GET "/users?page=1&page_size=10" "$c_token"
role_body='{"first_name":"Attempt","last_name":"Escalation","email":"attempt@school-a.test","account_role":"principal"}'
expect_status 403 "Coordinator cannot appoint Principal" POST /staff "$c_token" "$role_body"
expect_status 403 "Coordinator cannot grant Principal through users" POST /users "$c_token" "$role_body"
expect_status 403 "Parent cannot provision staff" POST /staff "$pa_token" "$role_body"
expect_status 403 "Kiosk cannot read students" GET /students "$k_token"

student_a="00000000-0000-4000-8000-000000000050"
student_b="00000000-0000-4000-8000-000000000250"
guardian_b="00000000-0000-4000-8000-000000000251"
expect_status 200 "Teacher can read assigned student" GET "/students/$student_a" "$t_token"
expect_status 404 "Teacher cannot read another school student" GET "/students/$student_b" "$t_token"
expect_status 200 "Parent can read linked child" GET "/students/$student_a" "$pa_token"
expect_status 404 "Parent cannot read unlinked child" GET "/students/$student_b" "$pa_token"
expect_status 404 "Cross-tenant Principal student ID is not enumerable" GET "/students/$student_b" "$p_token"
expect_status 404 "Parent cannot enumerate another-school guardian" GET "/student-documents?student_id=$student_b" "$pa_token"
expect_status 404 "Parent cannot enumerate another-school document" GET "/student-documents/$guardian_b" "$pa_token"
expect_status 403 "Coordinator cannot read fee structures" GET /fee-structures "$c_token"
expect_status 404 "Public school setup is disabled" POST /schools/setup "" '{}'

rate_ip="203.0.$((RANDOM % 254)).$((RANDOM % 254))"
public_school_id="00000000-0000-4000-8000-000000000001"
last_code=200
for _ in $(seq 1 11); do
  last_code="$(curl --max-time 15 -sS -o /tmp/schooldesk-local-security-response -w '%{http_code}' \
    "$api/website/public?school_id=$public_school_id" -H "apikey: $anon" -H "x-forwarded-for: $rate_ip")"
done
[[ "$last_code" == 429 ]] || fail "public IP rate limit (last status $last_code)"
pass "public IP rate limit returns 429 with database-backed counter"

rm -f /tmp/schooldesk-local-security-response
echo "Local security smoke tests passed."
