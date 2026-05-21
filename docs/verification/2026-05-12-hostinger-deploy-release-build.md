# SchoolDesk Hostinger Backend Deploy and Release Build - 2026-05-12

## Scope

- Deploy the latest `school-backend/` source to the Hostinger Docker VPS.
- Keep the rollout safe with preflight, dry-run, remote backup, migration reset, health checks, and login smoke.
- Bump the Flutter app release version and build both Hostinger-target AAB and APK artifacts.

## Backend Deploy Evidence

| Check | Result |
| --- | --- |
| Hostinger preflight | `scripts/deploy-hostinger-backend.sh --check-only --no-login-smoke` passed. |
| Deploy dry-run | `scripts/deploy-hostinger-backend.sh --dry-run --no-login-smoke` passed and showed expected backend source sync. |
| Local backend tests during deploy | `go test ./...` passed from `school-backend/`. |
| Remote backup | Created `/root/schooldesk-backups/deploy-20260512-041610` before source sync/rebuild. |
| Remote migration handling | `MIGRATE_ON_START=true` was enabled only for rebuild, then restored to `MIGRATE_ON_START=false`. |
| Remote health | `https://schooldesk-api.187.127.157.43.nip.io/health` returned HTTP 200 with `{"status":"healthy"}`. |
| Remote login smoke | Principal login smoke returned success with role `Principal`. |
| Remote error scan | Post-deploy `schooldesk-go-api` logs did not show panic/fatal/500 signatures in the checked window. |

## App Build Evidence

| Check | Result |
| --- | --- |
| Version bump | `pubspec.yaml` bumped from `1.0.4+6` to `1.0.5+7`. |
| Flutter analysis | `flutter analyze` passed with no issues. |
| Flutter tests | `flutter test` passed with 201 tests. |
| AAB build | `flutter build appbundle --release --dart-define-from-file=env.hostinger.json` passed. |
| APK build | `flutter build apk --release --dart-define-from-file=env.hostinger.json` passed. |
| Manifest metadata | Package `com.techmigos.schooldesk1`, versionName `1.0.5`, versionCode `7`. |
| Archive integrity | `unzip -t` passed for both copied release artifacts. |

## Release Artifacts

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `build/releases/schooldesk-1.0.5+7-hostinger-release.aab` | 57,189,803 bytes | `3ad3cab4d45b007d260e205ce30ef1f92196448096706dfc54f9a7e5a960269d` |
| `build/releases/schooldesk-1.0.5+7-hostinger-release.apk` | 76,234,216 bytes | `315f16e4f897f6a0b8eef8b08b4db579970f40a2bec47e12325072e953e33be0` |

## Remaining QA Boundary

- Automated, local Docker, emulator role-smoke, VPS health, and release-build checks passed.
- Full guided manual role workflow QA is still pending and should be completed before treating this as final Play Store production certification.
