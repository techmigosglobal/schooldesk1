#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Run deterministic local review checks for SchoolDesk.

This is the local fallback reviewer when CodeRabbit is unavailable or stalled.
It checks formatting, diff hygiene, common secret leaks, focused Flutter
contracts, Dart analyzer, and Go backend tests.

Usage:
  scripts/local-code-review.sh [options]

Options:
  --with-docker-smoke     Also run scripts/verify-local-docker-api.sh.
  --skip-flutter          Skip Flutter tests/analyzer.
  --skip-go               Skip Go backend tests.
  -h, --help              Show this help.
USAGE
}

log() {
  printf '[local-review] %s\n' "$*"
}

fail() {
  printf '[local-review][error] %s\n' "$*" >&2
  exit 1
}

run() {
  log "$*"
  "$@"
}

with_docker_smoke=false
skip_flutter=false
skip_go=false

while (($#)); do
  case "$1" in
    --with-docker-smoke)
      with_docker_smoke=true
      ;;
    --skip-flutter)
      skip_flutter=true
      ;;
    --skip-go)
      skip_go=true
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

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

run git diff --check

log "Checking uncommitted diff for obvious secret material."
if git diff -- . \
  ':!pubspec.lock' \
  ':!school-backend/go.sum' \
  ':!scripts/local-code-review.sh' \
  ':!scripts/reset-railway-fees.sh' \
  ':!test/unit/railway_fee_reset_and_review_contract_test.dart' \
  | rg -n 'DATABASE_URL|PGPASSWORD|RAILWAY_TOKEN|PRIVATE KEY|SECRET_KEY|FIREBASE_SERVICE_ACCOUNT_JSON'; then
  fail "Potential secret found in git diff. Review before continuing."
fi

if [[ "$skip_flutter" != true ]]; then
  run dart format --set-exit-if-changed \
    lib/features/attendance/presentation/screens/parent_attendance_screen/parent_attendance_screen.dart \
    test/unit/attendance_workflow_contract_test.dart \
    test/unit/railway_fee_reset_and_review_contract_test.dart

  run flutter test test/unit/attendance_workflow_contract_test.dart
  run flutter test test/unit/railway_fee_reset_and_review_contract_test.dart
  run dart analyze \
    lib/features/attendance/presentation/screens/parent_attendance_screen/parent_attendance_screen.dart \
    test/unit/attendance_workflow_contract_test.dart \
    test/unit/railway_fee_reset_and_review_contract_test.dart
fi

if [[ "$skip_go" != true ]]; then
  (
    cd school-backend
    run go test ./internal/handlers ./cmd/local-api-verify
  )
fi

if [[ "$with_docker_smoke" == true ]]; then
  run scripts/verify-local-docker-api.sh
fi

log "Local review checks completed."
