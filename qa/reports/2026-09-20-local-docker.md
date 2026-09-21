# Local Docker QA Report — 2026-09-20

## Environment

- Workspace commit: `7d38ab5` with uncommitted working-tree changes.
- Host: Ubuntu 26.04.1, Flutter 3.47.2 / Dart 3.13.2, Bun 1.3.10, Next.js 16.2.10.
- Backend: Supabase CLI 2.116.0, Docker project `schooldesk-local`, synthetic School A and School B fixtures, schema through `20260914100133_revoke_public_fee_dashboard_summary_execute`.
- Network/data: local loopback only; `Asia/Kolkata`; no real student, payment, or document data used.
- The test-created synthetic leave and account approval remain in the local database with QA-only reasons.

## Results

| Gate | Result | Evidence |
| --- | --- | --- |
| Questionnaire structure | PASS | `python3 tool/verify_test_questionnaire.py`: 196 cases, 115 routes, metadata/taxonomy checks pass |
| Edge Function tests | PASS | `scripts/local_supabase.sh test-functions`: 26 passed, 0 failed |
| Local API readiness | PASS | `/health` HTTP 200; `/ready` HTTP 200 |
| Role/security smoke | PASS on rerun | `scripts/local_security_smoke.sh`: 25 checks passed; first attempt had one transient 502, documented as QA-OBS-001 |
| Direct RLS tenant probe | PASS for tested rows | Principal, Teacher, Parent each received one School A student row and zero School B rows (HTTP 200) |
| Approval Center leave dates | PASS for tested mutation | Teacher POSTed a synthetic leave for 2026-09-23 through 2026-09-24; feed details and database dates matched |
| Cross-role leave workflow | PASS for tested chain | Principal approved the synthetic request; Teacher then read the approved row; database status, reviewer, dates, one notification event, and one in-app notification log matched |
| Approval Center requester hydration | PASS for tested response | Synthetic account approval returned the linked user in `/account-approvals` and populated requester fields in `/approvals/feed` |
| Flutter static analysis | PASS | `LD_LIBRARY_PATH=/opt/lampp/lib flutter analyze --no-pub`: no issues |
| Flutter unit/widget | PASS | `flutter test --no-pub`: 799 passed, 1 skipped |
| Flutter coverage | PASS with risk | `flutter test --no-pub --coverage`: 799 passed, 1 skipped; 18.7% line coverage |
| Focused Approval Center tests | PASS | Contract and payment widget tests: 4 passed after formatting |
| Local Docker storage contract | PASS | `image_media_url_contract_test.dart` rerun with `--dart-define-from-file=env.local.json`: 7 passed |
| Flutter integration | BLOCKED | No supported target. No physical Android; Pixel 2 AVD missing `android-30/default/x86_64`; Linux/Chrome unsupported by this project |
| Web tests/typecheck | PASS | `bun test`: 64 passed / 250 assertions; `bun run typecheck` passed |
| Web production build | PASS locally | Initial missing-config failure was resolved by supplying explicit loopback API/site and synthetic school ID; no hosted values used |
| Web HTTP auth probes | PASS as HTTP only | Principal login 200, authenticated route 200, Teacher-to-Principal login 403; no browser UI evidence |
| Browser UI | BLOCKED | CUA returned no available browser; HTTP probes are not browser evidence |
| Android physical/native | BLOCKED | No Android device attached; see [device matrix](../DEVICE_VERIFICATION.md) |
| iOS | BLOCKED | No Xcode/iOS runtime on Linux |
| Supabase production promotion | NOT RUN | Gate intentionally held for Android physical checks and remaining release evidence |

## Initial smoke failure

The first security smoke run received HTTP 502 on the coordinator `/users?page=1&page_size=10` denial check. An isolated replay returned the expected 403, then a complete second run passed all 25 checks. The event was not reproduced and no code was changed to suppress it. Track as `QA-OBS-001`.

## Limits

The 196 questionnaire rows describe broad, often composite workflows. Test-suite passes and focused local probes are not substituted for complete per-case evidence. The tracker therefore records **163 Blocked**, **33 Not Run**, and no case-level Passed or Failed result in this cycle. Unverified browser, PDF-download, device, live FCM, performance, production, and complete cross-role workflows remain open.

No Supabase project was deployed, no migration was pushed, and no production smoke check occurred during this report's Docker-local run. A later read-only migration-history comparison and the CLI unlink are recorded in [the follow-up report](2026-09-20-tooling-device-cloud-followup.md).
