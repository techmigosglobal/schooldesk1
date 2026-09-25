#!/usr/bin/env bash
# Upload release signing materials to GitHub Actions environment secrets.
#
# Reads binary files (Apple .p12, .mobileprovision, Android .keystore) and the
# raw passwords / IDs, base64-encodes the binaries, and pushes them via
# `gh secret set --env <env>` to the right environments.  Run this once per
# environment, then again whenever a credential rotates.
#
# Usage:
#   scripts/setup_github_release_secrets.sh android \
#     --keystore /path/to/schooldesk-release.keystore \
#     --store-password '...' \
#     --key-alias '...' \
#     --key-password '...'
#
#   scripts/setup_github_release_secrets.sh ios \
#     --cert /path/to/schooldesk-distribution.p12 \
#     --cert-password '...' \
#     --profile /path/to/schooldesk.mobileprovision \
#     --keychain-password '...' \
#     --team-id '...' \
#     --bundle-id '...'
#
#   scripts/setup_github_release_secrets.sh prod-env \
#     --env-json /path/to/schooldesk-production.env.json
#
# Flags:
#   --repo OWNER/REPO    Override the target repository (defaults to origin).
#   --dry-run            Print the gh commands without running them.
#
# Secrets are never echoed.  Passwords and IDs are written to a temp file with
# mode 0600 and removed on exit.  Binary files are streamed through base64
# without being written to disk.

set -Eeuo pipefail
umask 077

readonly REPO_DEFAULT="techmigosglobal/schooldesk1"

command -v gh    >/dev/null || { printf '[error] gh CLI is required\n' >&2; exit 1; }
command -v base64>/dev/null || { printf '[error] base64 is required\n' >&2; exit 1; }
command -v jq    >/dev/null || { printf '[error] jq is required\n'   >&2; exit 1; }

die()  { printf '[error] %s\n' "$*" >&2; exit 1; }
need() { [[ -n "${1:-}" ]] || die "$2"; }

target_repo="$REPO_DEFAULT"
dry_run=0

env_name=""
keystore_path="" store_password="" key_alias="" key_password=""
cert_path="" cert_password="" profile_path="" keychain_password="" team_id="" bundle_id=""
env_json_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    android|ios|prod-env) env_name="$1"; shift ;;
    --keystore)        keystore_path="$2"; shift 2 ;;
    --store-password)  store_password="$2"; shift 2 ;;
    --key-alias)       key_alias="$2"; shift 2 ;;
    --key-password)    key_password="$2"; shift 2 ;;
    --cert)            cert_path="$2"; shift 2 ;;
    --cert-password)   cert_password="$2"; shift 2 ;;
    --profile)         profile_path="$2"; shift 2 ;;
    --keychain-password) keychain_password="$2"; shift 2 ;;
    --team-id)         team_id="$2"; shift 2 ;;
    --bundle-id)       bundle_id="$2"; shift 2 ;;
    --env-json)        env_json_path="$2"; shift 2 ;;
    --repo)            target_repo="$2"; shift 2 ;;
    --dry-run)         dry_run=1; shift ;;
    -h|--help)
      sed -n '2,/^set -Eeuo pipefail/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

need "$env_name" "Choose one of: android, ios, prod-env"

run_gh() {
  if (( dry_run )); then
    printf '  [dry-run] gh %s\n' "$*"
  else
    gh "$@" >/dev/null
  fi
}

stream_b64() {
  local file="$1"
  [[ -s "$file" ]] || die "File is missing or empty: $file"
  base64 < "$file" | tr -d '\n'
}

printf '[setup-github-release-secrets] repo=%s env=%s\n' "$target_repo" "$env_name"
[[ -n "$(gh auth status 2>&1 | grep 'Logged in')" ]] || die "gh is not authenticated"

case "$env_name" in
  android)
    need "$keystore_path"  "--keystore is required"
    need "$store_password" "--store-password is required"
    need "$key_alias"      "--key-alias is required"
    need "$key_password"   "--key-password is required"
    printf '[setup-github-release-secrets] uploading Android signing material to android-release\n'
    keystore_b64="$(stream_b64 "$keystore_path")"
    printf '%s' "$keystore_b64" | run_gh secret set SCHOOLDESK_ANDROID_KEYSTORE_BASE64 --repo "$target_repo" --env android-release
    run_gh secret set SCHOOLDESK_ANDROID_KEYSTORE_PASSWORD --repo "$target_repo" --env android-release --body "$store_password"
    run_gh secret set SCHOOLDESK_ANDROID_KEY_ALIAS       --repo "$target_repo" --env android-release --body "$key_alias"
    run_gh secret set SCHOOLDESK_ANDROID_KEY_PASSWORD    --repo "$target_repo" --env android-release --body "$key_password"
    printf '[setup-github-release-secrets] Android signing material uploaded.\n'
    ;;

  ios)
    need "$cert_path"          "--cert is required"
    need "$cert_password"      "--cert-password is required"
    need "$profile_path"       "--profile is required"
    need "$keychain_password"  "--keychain-password is required"
    need "$team_id"            "--team-id is required"
    need "$bundle_id"          "--bundle-id is required"
    printf '[setup-github-release-secrets] uploading iOS signing material to ios-release\n'
    cert_b64="$(stream_b64 "$cert_path")"
    profile_b64="$(stream_b64 "$profile_path")"
    printf '%s' "$cert_b64"    | run_gh secret set SCHOOLDESK_IOS_DISTRIBUTION_CERT_BASE64      --repo "$target_repo" --env ios-release
    run_gh secret set SCHOOLDESK_IOS_DISTRIBUTION_CERT_PASSWORD --repo "$target_repo" --env ios-release --body "$cert_password"
    printf '%s' "$profile_b64" | run_gh secret set SCHOOLDESK_IOS_PROVISIONING_PROFILE_BASE64  --repo "$target_repo" --env ios-release
    run_gh secret set SCHOOLDESK_IOS_KEYCHAIN_PASSWORD        --repo "$target_repo" --env ios-release --body "$keychain_password"
    run_gh secret set SCHOOLDESK_IOS_TEAM_ID                  --repo "$target_repo" --env ios-release --body "$team_id"
    run_gh secret set SCHOOLDESK_IOS_BUNDLE_ID                --repo "$target_repo" --env ios-release --body "$bundle_id"
    printf '[setup-github-release-secrets] iOS signing material uploaded.\n'
    ;;

  prod-env)
    need "$env_json_path" "--env-json is required"
    jq -e '.' "$env_json_path" >/dev/null || die "$env_json_path is not valid JSON"
    printf '[setup-github-release-secrets] uploading production env.json to both environments\n'
    env_b64="$(stream_b64 "$env_json_path")"
    printf '%s' "$env_b64" | run_gh secret set SCHOOLDESK_RELEASE_ENV_BASE64 --repo "$target_repo" --env android-release
    printf '%s' "$env_b64" | run_gh secret set SCHOOLDESK_RELEASE_ENV_BASE64 --repo "$target_repo" --env ios-release
    printf '[setup-github-release-secrets] Production env.json uploaded.\n'
    ;;

  *) die "Unknown environment: $env_name (use android | ios | prod-env)" ;;
esac