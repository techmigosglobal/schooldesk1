#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${1:-$repo_root/env.supabase.json}"

fail() { printf '[ios-wireless-archive][error] %s\n' "$*" >&2; exit 1; }
[[ -f "$env_file" ]] || fail "Missing production environment file: $env_file"
command -v xcrun >/dev/null || fail "Xcode command-line tools are required"
command -v flutter >/dev/null || fail "Flutter is required"
command -v jq >/dev/null || fail "jq is required"
jq -e '(.API_BASE_URL | test("^https://.+\\.supabase\\.co/functions/v1/api$")) and (.APP_ENV == "production") and (.FIREBASE_IOS_APP_ID | length > 0)' "$env_file" >/dev/null || fail "Environment must target production Supabase and include Firebase iOS settings"

cd "$repo_root"
current_version="$(awk '/^version:/{print $2; exit}' pubspec.yaml)"
read -r -p "Current version is $current_version. Bump it before build? [y/N] " bump
if [[ "$bump" =~ ^[Yy]$ ]]; then
  read -r -p "Choose patch, minor, major, or build [patch]: " kind
  kind="${kind:-patch}"
  python3 - "$kind" <<'PY'
import re, sys
path = 'pubspec.yaml'; kind = sys.argv[1]
text = open(path).read(); match = re.search(r'^version: (\d+)\.(\d+)\.(\d+)\+(\d+)$', text, re.M)
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
flutter build ios --debug --dart-define-from-file="$env_file"
devices=()
while IFS= read -r device; do
  [[ -n "$device" ]] && devices+=("$device")
done < <(xcrun devicectl list devices | awk '/available/{print $NF}')
(( ${#devices[@]} > 0 )) || fail "No paired, available physical iOS devices found in Xcode"
printf 'Available device identifiers:\n%s\n' "${devices[*]}"
read -r -p "Wireless device identifier to install on: " device_id
[[ -n "$device_id" ]] || fail "A device identifier is required"
xcrun devicectl device install app --device "$device_id" build/ios/iphoneos/Runner.app

read -r -p "Create signed Release archive and open Xcode Organizer? [y/N] " archive
if [[ "$archive" =~ ^[Yy]$ ]]; then
  flutter build ios --config-only --release --dart-define-from-file="$env_file"
  sh "$repo_root/scripts/fix_spm_deployment_target.sh"
  archive_path="$repo_root/build/ios/archive/Runner.xcarchive"
  xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -destination 'generic/platform=iOS' -archivePath "$archive_path" archive
  open "$archive_path"
fi
