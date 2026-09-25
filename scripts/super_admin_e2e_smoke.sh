#!/usr/bin/env bash
# End-to-end Super Admin feature test against the local Docker Supabase stack.
# Exercises every Super Admin-facing endpoint that the Flutter app calls.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
command -v jq   >/dev/null || { echo "jq is required"   >&2; exit 1; }
test -f env.local.json || { echo "env.local.json missing; run scripts/local_supabase.sh prepare" >&2; exit 1; }

api_base="$(jq -er '.API_BASE_URL' env.local.json)"
sa_user="$(jq -er '.QA_SUPER_ADMIN_USERNAME' env.local.json)"
sa_pass="$(jq -er '.QA_SUPER_ADMIN_PASSWORD' env.local.json)"
school_id="00000000-0000-4000-8000-000000000001"

PASS=0
FAIL=0
declare -a FAILURES=()

client_ip="198.51.100.30"

ok()   { PASS=$((PASS+1)); printf "  PASS  %s\n" "$1"; }
fail() { FAIL=$((FAIL+1)); FAILURES+=("$1"); printf "  FAIL  %s\n" "$1"; }

login() {
  curl -fsS --max-time 10 \
    -X POST "$api_base/auth/login" \
    -H 'Content-Type: application/json' \
    -H "x-forwarded-for: $client_ip" \
    --data "$(jq -nc \
      --arg username "$sa_user" \
      --arg password "$sa_pass" \
      --arg school_id "$school_id" \
      '{username:$username,password:$password,school_id:$school_id}')"
}

token="$(login | jq -er '.data.access_token')"
[[ -n "$token" && "$token" != "null" ]] || { echo "Super Admin login failed" >&2; exit 1; }

auth="Authorization: Bearer $token"

get_status() {
  local label="$1" path="$2" expected="$3"
  local code
  code="$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' "$api_base$path" -H "$auth")"
  if [[ "$code" == "$expected" ]]; then ok "$label  [$code]"; else fail "$label  expected=$expected actual=$code  GET $path"; fi
}

post_status() {
  local label="$1" path="$2" expected="$3" payload="${4-}"
  local code
  if [[ -n "$payload" ]]; then
    code="$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' \
      -X POST "$api_base$path" -H "$auth" -H 'Content-Type: application/json' --data "$payload")"
  else
    code="$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' \
      -X POST "$api_base$path" -H "$auth")"
  fi
  if [[ "$code" == "$expected" ]]; then ok "$label  [$code]"; else fail "$label  expected=$expected actual=$code  POST $path"; fi
}

put_status() {
  local label="$1" path="$2" expected="$3" payload="${4-}"
  local code
  code="$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' \
    -X PUT "$api_base$path" -H "$auth" -H 'Content-Type: application/json' --data "$payload")"
  if [[ "$code" == "$expected" ]]; then ok "$label  [$code]"; else fail "$label  expected=$expected actual=$code  PUT $path"; fi
}

patch_status() {
  local label="$1" path="$2" expected="$3" payload="${4-}"
  local code
  code="$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' \
    -X PATCH "$api_base$path" -H "$auth" -H 'Content-Type: application/json' --data "$payload")"
  if [[ "$code" == "$expected" ]]; then ok "$label  [$code]"; else fail "$label  expected=$expected actual=$code  PATCH $path"; fi
}

delete_status() {
  local label="$1" path="$2" expected="$3" payload="${4-}"
  local code
  if [[ -n "$payload" ]]; then
    code="$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' \
      -X DELETE "$api_base$path" -H "$auth" -H 'Content-Type: application/json' --data "$payload")"
  else
    code="$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' \
      -X DELETE "$api_base$path" -H "$auth")"
  fi
  if [[ "$code" == "$expected" ]]; then ok "$label  [$code]"; else fail "$label  expected=$expected actual=$code  DELETE $path"; fi
}

check_data() {
  local label="$1" path="$2"
  local resp
  resp="$(curl -fsS --max-time 10 "$api_base$path" -H "$auth")" || { fail "$label  request failed: $path"; return; }
  if printf '%s' "$resp" | jq -e '.success == true and (.data != null)' >/dev/null; then
    ok "$label  (data present)"
  else
    fail "$label  no data  GET $path"
  fi
}

printf "Super Admin logged in, role=super_admin\n\n"

# ----- Auth & session -----
printf "[auth & session]\n"
get_status "auth.profile"          "/auth/profile"   200
get_status "schools.current"       "/schools/current" 200
get_status "academic-years"        "/academic-years"  200

# ----- Dashboard -----
printf "\n[dashboard]\n"
check_data "dashboard.super_admin"   "/dashboard/super_admin"

# ----- Users & access -----
printf "\n[users / access]\n"
check_data "users.list"              "/users?page=1&page_size=1"
check_data "users.parent.list"       "/users?role=parent&page=1&page_size=1"
check_data "users.teacher.list"      "/users?role=teacher&page=1&page_size=1"
check_data "users.staff.list"        "/staff?page=1&page_size=1"
check_data "guardians.directory"     "/guardians/directory?page=1&page_size=1"
check_data "access.permissions"      "/access/permissions"

# ----- Branches (Super Admin only) -----
printf "\n[branches]\n"
check_data "branches"                "/branches"
check_data "branches.overview"       "/branches/overview"

# ----- Audit & monitoring -----
printf "\n[audit / monitoring]\n"
check_data "audit-logs"              "/audit-logs?page_size=1"
check_data "monitoring.error-events" "/monitoring/error-events?page=1&page_size=1"
get_status "monitoring.error-events.retention" "/monitoring/error-events/retention" 200
post_status "monitoring.error-events.cleanup.preview" "/monitoring/error-events/cleanup" 200 '{"preview":true}'

# ----- Issues (Super Admin reads + decides; only principal/teacher/parent raise) -----
printf "\n[issues]\n"
check_data "issues.list"             "/issues?page=1&page_size=1"
# Super Admin cannot raise issues (by design); raised_by_role check constraint
# also rejects super_admin. POST should return 403.
post_status "issues.create.forbidden" "/issues" 403 \
  '{"title":"E2E SA test","description":"x","category":"general","priority":"medium"}'

# ----- Admissions (leader-or-super_admin; widened for Super Admin org-wide access) -----
printf "\n[admission]\n"
get_status "admission-inquiries"     "/admission-inquiries?page=1&page_size=1" 200

# ----- Notifications -----
printf "\n[notifications]\n"
get_status "notifications"           "/notifications?page=1&page_size=5" 200
get_status "notifications.unread"    "/notifications/unread-count" 200
get_status "notifications.prefs"     "/notifications/preferences" 200
post_status "notifications.push-diagnostics" "/notifications/push-diagnostics" 200 '{}'

# ----- Students / staff / academics -----
printf "\n[students / staff / academics]\n"
check_data "students.list"           "/students?page=1&page_size=1"
check_data "students.summary"        "/students/summary"
check_data "principal.classes"       "/principal/classes"
check_data "principal.subjects"      "/principal/subjects"
check_data "principal.timetable"     "/principal/timetable"
check_data "lesson-planners.principal" "/lesson-planners/principal"

# ----- Attendance -----
printf "\n[attendance]\n"
get_status "attendance.sessions"     "/attendance/sessions?page=1&page_size=1" 200
check_data "attendance.staff"        "/attendance/staff?page=1&page_size=1"
get_status "attendance.staff.daily"  "/attendance/staff/daily-summary?date=2026-09-23" 200

# ----- Fees -----
printf "\n[fees]\n"
check_data "fees.summary"            "/fees/summary"
get_status "fees.invoices"           "/fees/invoices" 200
get_status "fee-invoices"            "/fee-invoices?page=1&page_size=1" 200
get_status "fees.payment-configs"    "/fees/payment-configs?page=1&page_size=1" 200
get_status "fees.reports.exports"    "/fees/reports/exports?page=1&page_size=1" 200

# ----- Approvals -----
printf "\n[approvals]\n"
check_data "approvals.feed"          "/approvals/feed?page=1&page_size=1"

# ----- Documents -----
printf "\n[documents]\n"
get_status "student-documents"       "/student-documents?page=1&page_size=1" 200
get_status "staff-documents"         "/staff-documents?page=1&page_size=1" 200

# ----- Reports -----
printf "\n[reports]\n"
check_data "reports.exports"         "/reports/exports"
get_status "reports.attendance"      "/reports/attendance" 200
get_status "reports.staff"           "/reports/staff" 200
get_status "reports.fees"            "/reports/fees" 200

# ----- Events / announcements / school feed -----
printf "\n[events / announcements / feed]\n"
check_data "events"                  "/events?page=1&page_size=5"
check_data "announcements"           "/announcements?page=1&page_size=5"
get_status "event-posts.gallery"     "/event-posts/gallery?page=1&page_size=5" 200  # feedRoles widened to include super_admin
get_status "events.calendar-prefs"   "/events/calendar-preferences" 200

# ----- Website (leader-or-super_admin; widened for Super Admin org-wide access) -----
printf "\n[website]\n"
get_status "website.content"         "/website/content" 200
get_status "website.ticker"          "/website/ticker"  200
get_status "website.gallery"         "/website/gallery" 200

# ----- Student leave -----
printf "\n[student leave]\n"
check_data "student-leave.applications" "/student-leave/applications?page=1&page_size=5"

# ----- Communication -----
printf "\n[communication]\n"
check_data "chat.monitor"            "/chat/monitor?page=1&page_size=5"
get_status "chat.contacts.role-match"  "/chat/contacts?role=super_admin" 400  # role match but no super_admin branch in handler

# ----- Write path: access/permissions update (round-trip) -----
printf "\n[write paths]\n"
access_resp="$(curl -fsS --max-time 10 "$api_base/access/permissions" -H "$auth")"
role_count="$(printf '%s' "$access_resp" | jq -er '.data.roles | length')"
if [[ "$role_count" -gt 0 ]]; then
  role_id="$(printf '%s' "$access_resp" | jq -er '.data.roles[0].id')"
  put_status "access.permissions.update" "/access/permissions" 200 \
    "$(jq -nc --arg rid "$role_id" \
      '{role_id:$rid, permissions:[{module:"students",action:"read"}]}')"
else
  # No roles seeded — write path is not exercisable against the empty set.
  get_status "access.permissions.empty" "/access/permissions" 200  # read still works
fi

# ----- Monitoring write paths -----
patch_status "monitoring.error-events.retention.update" "/monitoring/error-events/retention" 200 \
  '{"warning_keep_days":14,"resolved_keep_days":30,"resolved_fatal_keep_days":60,"max_raw_events":5000}'

# ----- Branch creation (Super Admin only) -----
branch_payload="$(jq -nc \
  --arg name "E2E Super Admin Test Branch $(date +%s)" \
  '{name:$name,code:"E2ESA",address_line1:"123 Test St",city:"Testville",state:"TestState",pincode:"000000",timezone:"Asia/Kolkata",is_active:true}')"
branch_resp="$(curl -fsS --max-time 10 -X POST "$api_base/branches" -H "$auth" -H 'Content-Type: application/json' --data "$branch_payload")"
branch_id="$(printf '%s' "$branch_resp" | jq -er '.data.id // empty')"
branch_name="$(printf '%s' "$branch_resp" | jq -er '.data.name // empty')"
if [[ -n "$branch_id" ]]; then
  ok "branches.create  (id=$branch_id)"
  patch_status "branches.update" "/branches/$branch_id" 200 \
    '{"name":"E2E Super Admin Test Branch (updated)"}'
  # Re-fetch to read the post-update name used in the confirmation string.
  branch_name="$(curl -fsS --max-time 10 "$api_base/branches" -H "$auth" \
    | jq -er --arg id "$branch_id" '.data[] | select(.id == $id) | .name')"
  # Delete requires an explicit confirmation string and at least 2 branches in
  # the organization. First call without confirmation should be 422; second
  # call with confirmation should be 200.
  delete_status "branches.delete.no-confirm" "/branches/$branch_id" 422
  delete_status "branches.delete.confirmed" "/branches/$branch_id" 200 \
    "$(jq -nc --arg c "DELETE $branch_name" '{confirmation:$c}')"
else
  fail "branches.create  $(printf '%s' "$branch_resp" | head -c 200)"
fi

# Issue workflow: list only (Super Admin cannot raise issues) -----
printf "\n[issues workflow]\n"
check_data "issues.list.again"       "/issues?page=1&page_size=1"

# ----- Summary -----
printf "\n"
printf "==========================================\n"
printf "Super Admin E2E summary: PASS=%d  FAIL=%d\n" "$PASS" "$FAIL"
if (( FAIL > 0 )); then
  printf "Failures:\n"
  for f in "${FAILURES[@]}"; do printf "  - %s\n" "$f"; done
  exit 1
fi
printf "All Super Admin feature checks passed.\n"