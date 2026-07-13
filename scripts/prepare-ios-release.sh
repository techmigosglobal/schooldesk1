#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${1:-$repo_root/env.supabase.json}"

if [[ ! -f "$env_file" ]]; then
  echo "Missing iOS release environment file: $env_file" >&2
  echo "Create it from env.supabase.example.json and keep it out of Git." >&2
  exit 1
fi

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
  value="$(plutil -extract "$key" raw -expect string "$env_file" 2>/dev/null || true)"
  if [[ -z "$value" ]]; then
    echo "Missing required release value $key in $env_file" >&2
    exit 1
  fi
done

cd "$repo_root"
flutter pub get
flutter build ios \
  --config-only \
  --release \
  --dart-define-from-file="$env_file"

# Flutter regenerates the Swift package with an iOS 13 declaration, while the
# release dependencies require iOS 15. Keep the generated package aligned with
# the deployment target before Xcode resolves the Release package graph.
sh "$repo_root/scripts/fix_spm_deployment_target.sh"

if ! grep -q '^DART_DEFINES=' ios/Flutter/Generated.xcconfig; then
  echo "Flutter did not generate the iOS release Dart defines." >&2
  exit 1
fi

echo "iOS Release configuration prepared."
echo "Open ios/Runner.xcworkspace, select Any iOS Device, then Product > Archive."
