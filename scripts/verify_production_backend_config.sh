#!/usr/bin/env bash
set -Eeuo pipefail

# This verifier checks configuration contracts only. It must remain safe to
# run in forks and pull requests, so it never requires (or prints) a hosted
# project URL, API key, or other production secret.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

command -v jq >/dev/null 2>&1 || {
  echo "jq is required" >&2
  exit 1
}

example='env.supabase.example.json'
[[ -f "$example" ]] || { echo "Missing $example" >&2; exit 1; }

# The checked-in example is intentionally non-deployable. Keep the production
# mode/logging contract visible while requiring placeholders for every value
# that must come from CI's protected secret store.
jq -e '
  type == "object"
  and .APP_ENV == "production"
  and ((.ENABLE_LOGGING | tostring) == "false")
  and (.API_BASE_URL == "https://YOUR_PROJECT_ID.supabase.co/functions/v1/api")
  and (.SUPABASE_URL == "https://YOUR_PROJECT_ID.supabase.co")
  and (.SUPABASE_ANON_KEY == "YOUR_SUPABASE_ANON_KEY")
' "$example" >/dev/null || {
  echo "$example must retain placeholders plus APP_ENV=production and ENABLE_LOGGING=false" >&2
  exit 1
}

[[ -f codemagic.yaml ]] || { echo "Missing codemagic.yaml" >&2; exit 1; }
required_vars=(
  API_BASE_URL SUPABASE_URL SUPABASE_ANON_KEY
  FIREBASE_API_KEY FIREBASE_PROJECT_ID FIREBASE_MESSAGING_SENDER_ID
  FIREBASE_ANDROID_APP_ID FIREBASE_IOS_APP_ID FIREBASE_AUTH_DOMAIN
  FIREBASE_STORAGE_BUCKET
)
for variable in "${required_vars[@]}"; do
  grep -Fq -- "--dart-define=${variable}=\$${variable}" codemagic.yaml || {
    echo "codemagic.yaml must source ${variable} from the protected CI environment" >&2
    exit 1
  }
done
grep -Fq -- 'groups:' codemagic.yaml || {
  echo "codemagic.yaml must use an encrypted environment group" >&2
  exit 1
}
grep -Fq -- 'schooldesk_prod' codemagic.yaml || {
  echo "codemagic.yaml must reference schooldesk_prod" >&2
  exit 1
}
grep -Fq -- '--dart-define=APP_ENV=production' codemagic.yaml || {
  echo "CI builds must set APP_ENV=production" >&2
  exit 1
}
grep -Fq -- '--dart-define=ENABLE_LOGGING=false' codemagic.yaml || {
  echo "CI builds must disable logging" >&2
  exit 1
}

# No hosted project identity is allowed to become a checked-in production
# input. The real endpoint is supplied through CI secrets at build time.
if rg -n --hidden --glob '!scripts/verify_production_backend_config.sh' \
  'ouvwogguttybmpgfgctc|YOUR_SUPABASE_ANON_KEY' codemagic.yaml scripts; then
  echo "Found a hosted project identity or credential placeholder in CI scripts" >&2
  exit 1
fi

# Keep the final structural check in the release build script itself. Here we
# only require that the script contains the same production invariants; this
# avoids trying to parse shell source as JSON or substituting real secrets.
grep -Fq -- '(.APP_ENV == "production")' scripts/build-android-supabase.sh || {
  echo "Android release build must verify APP_ENV=production" >&2
  exit 1
}
grep -Fq -- '((.ENABLE_LOGGING | tostring) == "false")' scripts/build-android-supabase.sh || {
  echo "Android release build must verify disabled logging" >&2
  exit 1
}

echo "Production configuration contract is structurally protected; values remain CI-secret supplied."
