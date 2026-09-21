#!/usr/bin/env bash
set -Eeuo pipefail

# Exercise private Supabase Storage using only the disposable Docker project.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 1; }
[[ -f env.local.json ]] || { echo "Run scripts/local_supabase.sh prepare first" >&2; exit 1; }

api="$(jq -er '.API_BASE_URL' env.local.json)"
storage="$(jq -er '.SUPABASE_URL' env.local.json)"
anon="$(jq -er '.SUPABASE_ANON_KEY' env.local.json)"
for endpoint in "$api" "$storage"; do
  [[ "$endpoint" == http://127.0.0.1:* || "$endpoint" == http://localhost:* ]] || {
    echo "Refusing non-local endpoint: $endpoint" >&2
    exit 1
  }
done

bucket="school-private-files"
school_a=""
principal_token=""
teacher_token=""
parent_token=""
school_b_principal_token=""
object_path=""
bad_type_path=""
direct_path=""
upload_title=""
synthetic_file=""
failed=0
http_status=""
http_body=""
login_ip="198.19.$((RANDOM % 254)).$((RANDOM % 254))"

cleanup() {
  local path object_id stored_reference
  [[ -z "$synthetic_file" ]] || rm -f -- "$synthetic_file"
  if [[ -n "$upload_title" ]]; then
    if [[ -z "$object_path" ]]; then
      stored_reference="$(docker exec supabase_db_schooldesk-local psql -U postgres \
        -d postgres -v ON_ERROR_STOP=1 -Atqc \
        "select file_url from public.student_documents where title = '$upload_title' limit 1")" || true
      object_path="${stored_reference#"$bucket/"}"
    fi
    docker exec supabase_db_schooldesk-local psql -U postgres -d postgres \
      -v ON_ERROR_STOP=1 -Atqc \
      "delete from public.student_documents where title = '$upload_title'" \
      >/dev/null 2>&1 || true
  fi
  for path in "$object_path" "$bad_type_path" "$direct_path"; do
    [[ -n "$path" ]] || continue
    object_id="$(docker exec supabase_db_schooldesk-local psql -U postgres \
      -d postgres -v ON_ERROR_STOP=1 -Atqc \
      "select id from storage.objects where bucket_id = '$bucket' and name = '$path'")" || true
    [[ -n "$object_id" ]] || continue
    # Supabase protects direct object-table deletion. This fallback is scoped to
    # the unique synthetic QA path created and checked by this script.
    docker exec supabase_storage_schooldesk-local rm -f -- \
      "/mnt/stub/stub/$bucket/$path/$object_id" >/dev/null 2>&1 || true
    docker exec supabase_db_schooldesk-local psql -U postgres -d postgres \
      -v ON_ERROR_STOP=1 -Atqc \
      "begin; set local storage.allow_delete_query = 'true'; delete from storage.objects where bucket_id = '$bucket' and name = '$path'; commit;" \
      >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

login() {
  local username="$1" password="$2" response
  response="$(curl --silent --show-error --fail-with-body --max-time 20 \
    "$api/auth/login" -H "apikey: $anon" \
    -H "x-forwarded-for: $login_ip" \
    -H 'Content-Type: application/json' \
    --data "$(jq -cn --arg username "$username" --arg password "$password" \
      '{username:$username,password:$password}')")"
  [[ "$(jq -r '.success' <<<"$response")" == true ]] || {
    echo "Fixture login failed for $username" >&2
    exit 1
  }
  printf '%s\n' "$response"
}

http_request() {
  local method="$1" url="$2" token="$3" content_type="${4:-application/json}" body="${5:-}" raw
  local args=(--silent --show-error --max-time 20 -w $'\n%{http_code}' -X "$method" "$url" -H "apikey: $anon")
  [[ -n "$token" ]] && args+=(-H "Authorization: Bearer $token")
  [[ -n "$content_type" ]] && args+=(-H "Content-Type: $content_type")
  [[ -n "$body" ]] && args+=(--data-binary "$body")
  raw="$(curl "${args[@]}")"
  http_status="${raw##*$'\n'}"
  http_body="${raw%$'\n'*}"
}

expect_status() {
  local expected="$1" label="$2"
  if [[ "$http_status" == "$expected" ]]; then
    printf '[local-storage][PASS] %s (HTTP %s)\n' "$label" "$http_status"
  else
    printf '[local-storage][FAIL] %s (expected HTTP %s, got %s)\n' \
      "$label" "$expected" "$http_status" >&2
    failed=1
  fi
}

expect_not_200() {
  local label="$1"
  if [[ "$http_status" != 200 ]]; then
    printf '[local-storage][PASS] %s (HTTP %s)\n' "$label" "$http_status"
  else
    printf '[local-storage][FAIL] %s (unexpected HTTP 200)\n' "$label" >&2
    failed=1
  fi
}

normalize_local_signed_url() {
  local value="$1" location query path
  location="${value%%\?*}"
  query="${value#"$location"}"
  if [[ "$location" == http://* || "$location" == https://* ]]; then
    path="${location#*://}"
    path="/${path#*/}"
  else
    path="$location"
  fi
  printf '%s%s%s' "$storage" "$path" "$query"
}

principal="$(login "$(jq -er '.QA_PRINCIPAL_USERNAME' env.local.json)" \
  "$(jq -er '.QA_PRINCIPAL_PASSWORD' env.local.json)")"
teacher="$(login "$(jq -er '.QA_TEACHER_USERNAME' env.local.json)" \
  "$(jq -er '.QA_TEACHER_PASSWORD' env.local.json)")"
parent="$(login "$(jq -er '.QA_PARENT_USERNAME' env.local.json)" \
  "$(jq -er '.QA_PARENT_PASSWORD' env.local.json)")"
school_b_principal="$(login "$(jq -er '.QA_SECOND_SCHOOL_PRINCIPAL_USERNAME' env.local.json)" \
  "$(jq -er '.QA_SECOND_SCHOOL_PRINCIPAL_PASSWORD' env.local.json)")"

principal_token="$(jq -er '.data.token' <<<"$principal")"
teacher_token="$(jq -er '.data.token' <<<"$teacher")"
parent_token="$(jq -er '.data.token' <<<"$parent")"
school_b_principal_token="$(jq -er '.data.token' <<<"$school_b_principal")"
school_a="$(jq -er '.data.user.school_id' <<<"$teacher")"
[[ "$school_a" == "$(jq -er '.data.user.school_id' <<<"$principal")" && \
   "$school_a" == "$(jq -er '.data.user.school_id' <<<"$parent")" && \
   "$school_a" != "$(jq -er '.data.user.school_id' <<<"$school_b_principal")" ]] || {
  echo "Local fixture roles do not match the expected two-school scope" >&2
  exit 1
}

unique="$(date -u +%Y%m%dT%H%M%SZ)-$$"
student_a="00000000-0000-4000-8000-000000000050"
upload_title="qa-private-storage-$unique"
direct_path="$school_a/qa/direct-private-storage-$unique.csv"
synthetic_file="$(mktemp "${TMPDIR:-/tmp}/schooldesk-private-storage.XXXXXX.csv")"
synthetic_csv=$'qa_case,scope\nlocal-storage-smoke,synthetic-school-a\n'
printf '%s' "$synthetic_csv" > "$synthetic_file"

# The private bucket is reachable through record-authorized API handlers only.
upload_raw="$(curl --silent --show-error --max-time 20 -w $'\n%{http_code}' \
  -X POST "$api/students/$student_a/documents" \
  -H "apikey: $anon" -H "Authorization: Bearer $principal_token" \
  -F "document=@$synthetic_file;type=text/csv" \
  -F 'doc_type=other' -F "title=$upload_title")"
http_status="${upload_raw##*$'\n'}"
http_body="${upload_raw%$'\n'*}"
expect_status 200 "Principal uploads a synthetic student document through the authorized API"
[[ "$http_status" == 200 ]] || exit 1
signed_url="$(jq -er '.data.file_url' <<<"$http_body")"
signed_url="$(normalize_local_signed_url "$signed_url")"
signed_path="${signed_url#"$storage"}"
object_path="${signed_path#"/storage/v1/object/sign/$bucket/"}"
object_path="${object_path%%\?*}"
if [[ -z "$object_path" || "$object_path" == "$signed_path" || \
      "$object_path" == /storage/v1/* ]]; then
  echo "API returned an unexpected private signed URL" >&2
  exit 1
fi
# Edge Functions may generate URLs with Docker's internal hostname. Call the
# same signed path through the published loopback endpoint from this host.
object_url="$storage/storage/v1/object/$bucket/$object_path"

http_request GET "$signed_url" "" ''
expect_status 200 "authorized API signed URL can fetch the private object"

http_request GET "$object_url" "" ''
expect_not_200 "anonymous direct object request is denied"

http_request GET "$storage/storage/v1/object/public/$bucket/$object_path" "" ''
expect_not_200 "private bucket public URL is denied"

http_request GET "$object_url" "$school_b_principal_token" ''
expect_not_200 "other-school Principal cannot read the object directly"

http_request GET "$object_url" "$principal_token" ''
expect_not_200 "same-school Principal cannot bypass API authorization with direct Storage access"

http_request GET "$object_url" "$teacher_token" ''
expect_not_200 "same-school Teacher cannot bypass API authorization with direct Storage access"

http_request GET "$object_url" "$parent_token" ''
expect_not_200 "same-school Parent cannot read a private object directly"

http_request POST "$storage/storage/v1/object/$bucket/$direct_path" \
  "$teacher_token" 'text/csv' "$synthetic_csv"
expect_not_200 "same-school Teacher cannot upload directly to private Storage"

http_request POST "$storage/storage/v1/object/list/$bucket" \
  "$parent_token" 'application/json' \
  "$(jq -cn --arg prefix "$school_a/qa" '{prefix:$prefix,limit:100,offset:0}')"
if [[ "$http_status" == 200 ]] && jq -e --arg name "${object_path##*/}" \
  'any(.[]?; ((.name // "") | endswith($name)))' <<<"$http_body" >/dev/null; then
  printf '[local-storage][FAIL] same-school Parent can list the private object\n' >&2
  failed=1
else
  printf '[local-storage][PASS] same-school Parent cannot list the private object (HTTP %s)\n' "$http_status"
fi

http_request POST "$storage/storage/v1/object/sign/$bucket/$object_path" \
  "$school_b_principal_token" 'application/json' '{"expiresIn":60}'
expect_not_200 "other-school Principal cannot mint a signed URL"

http_request POST "$storage/storage/v1/object/sign/$bucket/$object_path" \
  "$principal_token" 'application/json' '{"expiresIn":60}'
expect_not_200 "same-school Principal must mint private URLs through the authorized API"

object_row_count_before="$(docker exec supabase_db_schooldesk-local psql -U postgres \
  -d postgres -v ON_ERROR_STOP=1 -Atqc \
  "select count(*) from storage.objects where bucket_id = '$bucket' and name = '$object_path'")"
http_request DELETE "$storage/storage/v1/object/$bucket" "$teacher_token" \
  'application/json' "$(jq -cn --arg path "$object_path" '{prefixes:[$path]}')"
delete_status="$http_status"
object_row_count="$(docker exec supabase_db_schooldesk-local psql -U postgres \
  -d postgres -v ON_ERROR_STOP=1 -Atqc \
  "select count(*) from storage.objects where bucket_id = '$bucket' and name = '$object_path'")"
http_request GET "$signed_url" "" ''
if [[ "$http_status" == 200 && "$object_row_count_before" == 1 && \
      "$object_row_count" == 1 && "$http_body" == "$synthetic_csv" ]]; then
  printf '[local-storage][PASS] direct Storage DELETE left the object row and bytes intact (DELETE HTTP %s)\n' \
    "$delete_status"
else
  printf '[local-storage][FAIL] direct Storage DELETE changed or hid the object (DELETE HTTP %s, GET HTTP %s, rows before/after %s/%s)\n' \
    "$delete_status" "$http_status" "$object_row_count_before" "$object_row_count" >&2
  failed=1
fi

http_request GET "$api/students/$student_a" "$parent_token"
expect_status 200 "Parent can read the linked student's restricted API detail"
if jq -e '.data | has("student_documents")' <<<"$http_body" >/dev/null; then
  printf '[local-storage][FAIL] Parent API detail exposed private student documents\n' >&2
  failed=1
else
  printf '[local-storage][PASS] Parent API detail omits private student documents\n'
fi

http_request GET "$api/student-documents?student_id=$student_a" "$parent_token"
expect_status 200 "Parent can list documents for the linked student through the API"
parent_signed_url="$(jq -er --arg title "$upload_title" \
  '.data[] | select(.title == $title) | .file_url' <<<"$http_body" 2>/dev/null || true)"
if [[ -n "$parent_signed_url" ]]; then
  http_request GET "$(normalize_local_signed_url "$parent_signed_url")" "" ''
  expect_status 200 "linked Parent can fetch the child's document with its API-issued signed URL"
else
  printf '[local-storage][FAIL] linked Parent API document list omitted the synthetic document\n' >&2
  failed=1
fi

http_request GET "$api/student-documents?student_id=$student_a" \
  "$school_b_principal_token"
expect_status 404 "other-school Principal cannot list School A student documents through the API"

http_request GET "$api/students/$student_a" "$principal_token"
expect_status 200 "Principal can read full student detail through the API"
if jq -e --arg title "$upload_title" \
  '.data.student_documents | any(.[]?; .title == $title and (.file_url | type == "string" and startswith("http")))' \
  <<<"$http_body" >/dev/null; then
  printf '[local-storage][PASS] Principal API detail returns the authorized document with a signed URL\n'
else
  printf '[local-storage][FAIL] Principal API detail omitted the uploaded document or signed URL\n' >&2
  failed=1
fi

cleanup
object_path=""
bad_type_path=""
printf '\nLocal storage authorization smoke complete.\n'
if (( failed )); then
  exit 1
fi
