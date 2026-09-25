#!/usr/bin/env bash
# End-to-end parent role feature test against the local Docker Supabase stack.
# Exercises every parent-facing endpoint that the Flutter app calls.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
command -v jq   >/dev/null || { echo "jq is required"   >&2; exit 1; }
test -f env.local.json || { echo "env.local.json missing; run scripts/local_supabase.sh prepare" >&2; exit 1; }

api_base="$(jq -er '.API_BASE_URL' env.local.json)"
parent_user="$(jq -er '.QA_PARENT_USERNAME' env.local.json)"
parent_pass="$(jq -er '.QA_PARENT_PASSWORD' env.local.json)"
school_id="00000000-0000-4000-8000-000000000001"

PASS=0
FAIL=0
declare -a FAILURES=()

client_ip="198.51.100.20"

ok()   { PASS=$((PASS+1)); printf "  PASS  %s\n" "$1"; }
fail() { FAIL=$((FAIL+1)); FAILURES+=("$1"); printf "  FAIL  %s\n" "$1"; }

login() {
  curl -fsS --max-time 10 \
    -X POST "$api_base/auth/login" \
    -H 'Content-Type: application/json' \
    -H "x-forwarded-for: $client_ip" \
    --data "$(jq -nc \
      --arg username "$parent_user" \
      --arg password "$parent_pass" \
      --arg school_id "$school_id" \
      '{username:$username,password:$password,school_id:$school_id}')"
}

token="$(login | jq -er '.data.access_token')"
[[ -n "$token" && "$token" != "null" ]] || { echo "Parent login failed" >&2; exit 1; }

auth="Authorization: Bearer $token"
hdr_json=(-H "$auth" -H 'Content-Type: application/json')

# Pull the parent's first linked student once for child-scoped endpoints.
me_students="$(curl -fsS --max-time 10 "$api_base/me/students" -H "$auth")"
student_id="$(printf '%s' "$me_students" | jq -er '.data[0].id // .data.students[0].id // empty')"
student_count="$(printf '%s' "$me_students" | jq -er '.data | if type=="array" then length else (.students|length) end')"
[[ -n "$student_id" ]] || { echo "Could not resolve a parent student id" >&2; exit 1; }
printf "Parent logged in, %s child(ren) linked, primary student=%s\n\n" "$student_count" "$student_id"

# Helper that GETs a path and records pass/fail based on expected status.
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
  local label="$1" path="$2" expected="$3"
  local code
  code="$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' \
    -X DELETE "$api_base$path" -H "$auth")"
  if [[ "$code" == "$expected" ]]; then ok "$label  [$code]"; else fail "$label  expected=$expected actual=$code  DELETE $path"; fi
}

# Helper that checks a JSON envelope response for a non-empty data field.
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

# ----- Auth & session -----
printf "[auth & session]\n"
get_status "auth.profile"          "/auth/profile"   200
get_status "schools.current"       "/schools/current" 200
get_status "academic-years.list"   "/academic-years"  200  # now allowed for parent

# ----- Dashboard / feed -----
printf "\n[dashboard]\n"
check_data "dashboard.parent"        "/dashboard/parent"
check_data "event-posts.home-feed"   "/event-posts/home-feed?page=1&page_size=10"

# ----- My students -----
printf "\n[students]\n"
check_data "me.students"             "/me/students"
get_status "student.detail"          "/students/$student_id" 200

# ----- Fees & payments -----
printf "\n[fees]\n"
check_data "parent.student.fees"     "/parent/students/$student_id/fees"
get_status "fees.payment-requests"   "/fees/payment-requests?student_id=$student_id&page=1&page_size=5" 200
get_status "fees.payment-config"     "/fees/payment-config" 200

# ----- Homework -----
printf "\n[homework]\n"
get_status "homework.feed"           "/homework?page=1&page_size=5&student_id=$student_id" 200

# ----- Student leave applications (parent-scoped) -----
printf "\n[student leave]\n"
get_status "student-leave.list"      "/student-leave/applications?page=1&page_size=5&student_id=$student_id" 200
leave_payload="$(jq -nc \
  --arg sid "$student_id" \
  --arg from "$(date -u -v-1d +%Y-%m-%d 2>/dev/null || date -u -d 'yesterday' +%Y-%m-%d)" \
  --arg to   "$(date -u +%Y-%m-%d)" \
  '{student_id:$sid,from_date:$from,to_date:$to,reason:"E2E parent test - auto submit",leave_type:"sick"}')"
leave_resp="$(curl -fsS --max-time 10 \
  -X POST "$api_base/student-leave/applications" -H "$auth" -H 'Content-Type: application/json' \
  --data "$leave_payload")"
leave_ok="$(printf '%s' "$leave_resp" | jq -er '.success')"
leave_id="$(printf '%s' "$leave_resp" | jq -er '.data.id // .data.leave_application_id // .data.application_id // empty')"
if [[ "$leave_ok" == "true" && -n "$leave_id" ]]; then
  ok "student-leave.submit  (id=$leave_id)"
  post_status "student-leave.recall"  "/student-leave/applications/$leave_id/recall" 200
else
  fail "student-leave.submit  (resp=$(printf '%s' "$leave_resp" | head -c 200))"
fi

# ----- Attendance -----
printf "\n[attendance]\n"
get_status "attendance.summary"      "/attendance/summary?student_id=$student_id" 200
get_status "attendance.records"      "/students/$student_id/attendance" 200
get_status "attendance.monthly"       "/attendance/students/$student_id?month=09&year=2026" 200

# ----- Health reminders (CRUD) -----
printf "\n[health reminders]\n"
get_status "health-reminders.list"   "/health-reminders?student_id=$student_id" 200
hr_payload="$(jq -nc \
  --arg sid "$student_id" \
  '{student_id:$sid, title:"E2E parent test", reminder_time:"08:00", dosage:"1 tablet", notes:"auto", is_active:true}')"
hr_create="$(curl -fsS --max-time 10 -X POST "$api_base/health-reminders" -H "$auth" -H 'Content-Type: application/json' --data "$hr_payload")"
hr_id="$(printf '%s' "$hr_create" | jq -er '.data.id // .data.health_reminder_id // empty')"
if [[ -n "$hr_id" ]]; then
  ok "health-reminders.create  (id=$hr_id)"
  patch_status "health-reminders.update" "/health-reminders/$hr_id" 200 \
    '{"notes":"E2E parent test updated","is_active":true}'
  delete_status "health-reminders.delete" "/health-reminders/$hr_id" 200
else
  fail "health-reminders.create  (resp=$(printf '%s' "$hr_create" | head -c 160))"
fi

# ----- Medical records -----
printf "\n[medical records]\n"
get_status "medical-records.list"    "/medical-records?student_id=$student_id" 200
post_status "medical-records.create" "/medical-records" 200 \
  "$(jq -nc --arg sid "$student_id" \
    '{student_id:$sid,blood_group:"O+",allergies:"none",conditions:"none",medications:"none",emergency_contact:"E2E",dosage:"",reminder_time:"",notes:"E2E parent test",is_active:true}')"

# ----- Events / calendar / announcements / notifications -----
printf "\n[events, calendar, announcements, notifications]\n"
get_status "events"                 "/events?page=1&page_size=5" 200
get_status "announcements"          "/announcements?page=1&page_size=5" 200
get_status "notifications"          "/notifications?page=1&page_size=10" 200
get_status "notifications.unread"   "/notifications/unread-count" 200

# ----- Communication (chat) -----
printf "\n[chat / communication]\n"
get_status "chat.contacts"          "/chat/contacts?role=parent&student_id=$student_id" 200
get_status "chat.conversations"     "/chat/conversations?student_id=$student_id&page=1&page_size=5" 200

# ----- Timetable / lesson planners / documents -----
section_id="$(printf '%s' "$me_students" | jq -er '.data[0].current_section_id // .data.students[0].current_section_id // empty')"
printf "\n[timetable, lesson planners, documents]\n"
get_status "timetable.slots"        "/timetable/slots?section_id=$section_id" 200
get_status "lesson-planners.parent" "/lesson-planners/parent" 200
get_status "student-documents"      "/student-documents?student_id=$student_id&page=1&page_size=5" 200

# ----- Parent-only forbidden endpoints (sanity checks) -----
printf "\n[forbidden cross-role checks]\n"
get_status "fees.summary"           "/fees/summary" 403
get_status "users.list"             "/users?page=1&page_size=1" 403
get_status "audit-logs"             "/audit-logs?page_size=1" 403
get_status "access.permissions"     "/access/permissions" 403
post_status "approvals.create"       "/approvals" 403 '{"module":"fees","entity_type":"fee_invoice"}'

# ----- Summary -----
printf "\n"
printf "==========================================\n"
printf "Parent E2E summary: PASS=%d  FAIL=%d\n" "$PASS" "$FAIL"
if (( FAIL > 0 )); then
  printf "Failures:\n"
  for f in "${FAILURES[@]}"; do printf "  - %s\n" "$f"; done
  exit 1
fi
printf "All parent feature checks passed.\n"