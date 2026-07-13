#!/usr/bin/env bash

set -euo pipefail

cd "${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"

required_keys=(
  API_BASE_URL
  SUPABASE_URL
  SUPABASE_ANON_KEY
  FIREBASE_API_KEY
  FIREBASE_PROJECT_ID
  FIREBASE_MESSAGING_SENDER_ID
  FIREBASE_IOS_APP_ID
)

for key in "${required_keys[@]}"; do
  if [[ -z "${!key:-}" ]]; then
    echo "Missing required Xcode Cloud environment variable: $key" >&2
    exit 1
  fi
done

flutter_version="${FLUTTER_VERSION:-3.44.0}"
flutter_root="${HOME}/flutter"

if [[ ! -x "$flutter_root/bin/flutter" ]]; then
  git clone \
    --branch "$flutter_version" \
    --depth 1 \
    https://github.com/flutter/flutter.git \
    "$flutter_root"
fi

export PATH="$flutter_root/bin:$PATH"

dart_defines=(
  "--dart-define=API_BASE_URL=$API_BASE_URL"
  "--dart-define=SUPABASE_URL=$SUPABASE_URL"
  "--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
  "--dart-define=FIREBASE_API_KEY=$FIREBASE_API_KEY"
  "--dart-define=FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID"
  "--dart-define=FIREBASE_MESSAGING_SENDER_ID=$FIREBASE_MESSAGING_SENDER_ID"
  "--dart-define=FIREBASE_IOS_APP_ID=$FIREBASE_IOS_APP_ID"
  "--dart-define=FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN:-}"
  "--dart-define=FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET:-}"
  "--dart-define=APP_ENV=production"
  "--dart-define=ENABLE_LOGGING=false"
)

flutter pub get
flutter build ios --config-only --release "${dart_defines[@]}"

if ! grep -q '^DART_DEFINES=' ios/Flutter/Generated.xcconfig; then
  echo "Flutter did not generate the Xcode Cloud release configuration." >&2
  exit 1
fi
