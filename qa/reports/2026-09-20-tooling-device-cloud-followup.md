# Tooling, cloud parity, and Android follow-up — 2026-09-20

## Scope and result

This follow-up continues the Docker-first QA run. All cloud operations were read-only. No Supabase migration or function was deployed, and no migration file was created or changed by this follow-up.

## Analyzer and dependency tools

- Removed DCM 1.39.2 from `~/.local/bin` and its local package directory, plus the DCM analyzer configuration. DCM's CLI refused to analyze without a license activation key. No DCM installation or configuration remains.
- Added `very_good_analysis`, `riverpod_lint`, and `dependency_validator` as dev dependencies. Project ranges are `^10.0.0`, `^3.1.0`, and `^5.1.0`; the current Dart 3.13.2 lock resolves them to 10.3.0, 3.1.3, and 5.1.0.
- `analysis_options.yaml` includes Very Good Analysis. The first full enablement produced 8,018 informational lint diagnostics in the existing app/pubspec code. Those 54 legacy lint rules are listed as an explicit staged baseline; root `flutter analyze --no-pub` now completes with no issues. Re-enable baseline rules during focused cleanup instead of applying a broad automatic rewrite.
- `analysis_options.riverpod.yaml` enables the Riverpod analyzer plug-in for a Riverpod module. The isolated config check passed. The current app uses `package:provider` and has no Riverpod providers, so this config is opt-in.
- `dart run dependency_validator` passes. It found no source usage for direct dependencies `hotkey_manager`, `json_annotation`, and `url_launcher`; those direct entries were removed, and no imports were found in app/tests.
- `flutter pub get` passed. The full Flutter test suite was rerun afterward: 799 passed, 1 skipped.

## Local and cloud migration history

The local Docker database and checked-in migration files match through `20260914100133_revoke_public_fee_dashboard_summary_execute`. The configured cloud project is **not at the same migration-history level**:

- 124 migration versions match.
- 12 checked-in local versions are missing from cloud: `20260828183352`, `20260829104820`, `20260829143718`, `20260829144043`, `20260830103000`, `20260912100000`, `20260912110000`, `20260913090000`, `20260913100000`, `20260914070738`, `20260914092444`, `20260914100133`.
- 12 cloud-only versions are absent from the checked-in local history: `20260830134225`, `20260830134443`, `20260830134501`, `20260830134507`, `20260830134516`, `20260913014816`, `20260913014838`, `20260914094215`, `20260914094225`, `20260914094232`, `20260914094240`, `20260914100223`.
- `supabase db diff --linked --schema public,auth,storage,extensions,graphql_public,graphql --use-migra` did not finish its shadow-database setup, so it produced no schema diff. Migration-history divergence is confirmed; actual schema parity remains unverified.
- The CLI was linked only long enough to read the remote migration list, then `supabase unlink --yes` removed the project link. The checkout has no active cloud link now.

**Promotion remains blocked.** Do not use `db push`, migration repair, or function deployment to reconcile these histories until the remote-only and local-only changes are inspected and an explicit reconciliation plan is reviewed. There are no new migrations from this analyzer/tool work.

## Android physical attempt

- Device: Moto G85 5G, Android 16/API 36, visible over wireless ADB.
- Docker-local API health: HTTP 200. A temporary ADB reverse mapping targeted only local port 54321.
- `flutter test integration_test/local_role_login_smoke_test.dart --dart-define-from-file=env.local.json --no-pub` built a 173 MiB debug APK, but the install stalled for 333 seconds and ADB exited `-2`. Flutter reported **No tests ran**.
- The host observed 75% packet loss in a four-packet ping to the phone (one reply at 442 ms). Device shell calls and the attempt to remove the reverse mapping timed out. No app login or native behavior was tested.
- This is a test-environment failure, not a pass and not evidence of a product defect. See [device verification](../DEVICE_VERIFICATION.md) and [known issues](../known_issues.md). Clear the reverse mapping with `adb reverse --remove tcp:54321` after reconnecting to the device.

## Current gates

| Gate | Result |
| --- | --- |
| Flutter analysis with staged Very Good baseline | PASS |
| Riverpod opt-in analyzer config load | PASS |
| Dependency Validator | PASS |
| Full Flutter tests after dependency resolution | 799 passed, 1 skipped |
| Docker-local API | HTTP 200 |
| Migration histories at same level | FAIL: 12 local-only and 12 cloud-only |
| Actual cloud schema diff | Unverified: shadow database setup did not complete |
| Android physical login/native checks | BLOCKED: wireless ADB install failed before any test ran |
| Supabase deployment | NOT RUN |
