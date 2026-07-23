#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${1:-$repo_root/env.supabase.json}"
fail() { printf '[android-aab][error] %s\n' "$*" >&2; exit 1; }
[[ -f "$env_file" ]] || fail "Missing production environment file: $env_file"
command -v flutter >/dev/null || fail "Flutter is required"
command -v jq >/dev/null || fail "jq is required"
jq -e '(.API_BASE_URL | test("^https://.+\\.supabase\\.co/functions/v1/api$")) and (.APP_ENV == "production") and (.FIREBASE_ANDROID_APP_ID | length > 0)' "$env_file" >/dev/null || fail "Environment must target production Supabase and include Firebase Android settings"
cd "$repo_root"
current_version="$(awk '/^version:/{print $2; exit}' pubspec.yaml)"
read -r -p "Current version is $current_version. Bump it before AAB build? [y/N] " bump
if [[ "$bump" =~ ^[Yy]$ ]]; then
  read -r -p "Choose patch, minor, major, or build [patch]: " kind
  kind="${kind:-patch}"
  python3 - "$kind" <<'PY'
import re, sys
path = 'pubspec.yaml'; kind = sys.argv[1]; text = open(path).read()
match = re.search(r'^version: (\d+)\.(\d+)\.(\d+)\+(\d+)$', text, re.M)
if not match: raise SystemExit('pubspec.yaml version must be X.Y.Z+N')
major, minor, patch, build = map(int, match.groups())
if kind == 'major': major, minor, patch = major + 1, 0, 0
elif kind == 'minor': minor, patch = minor + 1, 0
elif kind == 'patch': patch += 1
elif kind != 'build': raise SystemExit('choose patch, minor, major, or build')
updated = f'{major}.{minor}.{patch}+{build + 1}'
open(path, 'w').write(text[:match.start(0)] + f'version: {updated}' + text[match.end(0):])
print(updated)
PY
fi
flutter pub get
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info/android/aab --dart-define-from-file="$env_file"
artifact=build/app/outputs/bundle/release/app-release.aab
[[ -f "$artifact" ]] || fail "AAB was not created"
shasum -a 256 "$artifact"
printf 'AAB: %s\nSymbols: %s\n' "$artifact" build/debug-info/android/aab
