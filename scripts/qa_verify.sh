#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

dart format --set-exit-if-changed .
flutter analyze
flutter test

if [[ -f env.local.json ]]; then
  flutter test integration_test --dart-define-from-file=env.local.json
  if command -v patrol >/dev/null 2>&1; then
    patrol test --target patrol/role_login_patrol_test.dart --dart-define-from-file=env.local.json
  else
    echo "Skipping Patrol: patrol CLI is not installed." >&2
  fi
else
  echo "Skipping integration and Patrol tests: env.local.json is missing." >&2
fi
