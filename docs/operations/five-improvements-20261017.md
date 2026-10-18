# Five SchoolDesk improvements — 17 October 2026

| Task | Result |
| --- | --- |
| 1. Timetable | A 24-hour time picker, padded HH:mm editing/display for leadership, parents and teachers, database-time normalization and existing order/overlap checks. No inference of afternoon from an ambiguous morning value. |
| 2. Notifications | Shared routes use the authenticated role and understand legacy navigation arguments. Inbox reads/read operations use the same authenticated transport. Refreshes coalesce with a follow-up when updates arrive in flight, and stale-account responses are discarded. Categories/unread can load older pages. Opening general/custom items displays the complete message. Test Push is limited to principal and Super Admin in UI and API. The principal’s final home icon opens a role/individual composer, confirmation and audited send history. |
| 3. Fees | Fee updates are not dropped by debounce or null navigation results. Selected-child generation guards reject older results. Proof remains Awaiting verification until recorded approval. A confirmed, reasoned principal payment reversal retains payment history, voids the receipt and recalculates balance. A preexisting ambiguous SQL column bug in the reversal RPC is corrected in a forward migration. |
| 4. Recovery | Refresh progress is distinct from a compact saved-data/refresh-failure status. Attendance retries on resume and reconnection, throttles automatic recovery, forwards force-refresh to all component reads and preserves successful sections on a partial failure. The scrollable content retains a bounded viewport while status is visible. |
| 5. Parent profile | Both Settings profile links are hidden for parents, profile access is excluded from parent route policy, and old/direct routes lead to parent Settings. Change Password and Sign out remain available. Other roles retain Profile. |

## Interfaces

- `GET /notifications/recipients?roles=parent,teacher&search=...&page=1`: principal-only, active school accounts, name/role/id only, 50 rows per page.
- `POST /notifications/broadcasts`: `Idempotency-Key` UUID plus title, message, roles, mode (`all` or `selected`) and user_ids. The database validates the actual active recipient set; all-role selection spans all pages.
- `GET /notifications/broadcasts?page=1`: the principal's saved send history, recipient counts and queued, push-accepted, missing-device, failed and other outcomes. Push acceptance does not mean phone delivery.
- `GET /notifications`: additive category and is_read filters.
- `DELETE /fees/payments/:id`: existing audited reversal endpoint, with a reason in the app. Missing payments return 404 and already-reversed payments return 409.

## Verification

- 21 behavioral unit/widget checks passed: role navigation, inbox subjects, full-message opening/read counts, diagnostic visibility across five roles, composer confirmation, payment refresh/queued refresh, pending proof, recovery status and parent Settings/profile access.
- A separate refresh-race test passed: an update during an older inbox request forces another read and the newest subject wins.
- Synthetic Docker API checks passed role/individual targeting, more than 50 recipients, concurrent idempotency, school boundaries, filtered paging/read state, and forced outbox failure rollback.
- Synthetic finance checks passed full/partial payments, immediate parent retrieval, approved-request reversal, void receipts, duplicate reversal and foreign-school rejection.
- Existing attendance reopening checks passed. The broader local workflow regression also passed parent issue resolution, health delivery/isolation/highlights, saved diary feedback, legacy membership deduplication, historical attendance bounds/finalization and atomic outbox rollback. Original website and attendance changes are preserved.
- Flutter analysis reports no issues. Final release logs record migration replay, backend type checks, source hashes and APK verification.

No test broadcasts or financial transactions are performed against production. Device operation and actual phone push receipt remain user acceptance checks.

## Production promotion and rollback

Use the current self-hosted VPS workflow, not the retired managed project. The two new forward migrations are `20261017062851_principal_custom_notifications.sql` and `20261017063849_payment_reversal_column_scope.sql`. Existing migrations remain immutable.

The deployment consists of communications, fees, the new notification_broadcasts handler and notification-processor. Before promotion, capture a PostgreSQL custom-format dump and complete Functions archive, compare target file hashes, compare the live reversal function and validate that the new table is absent. Apply both migrations atomically, copy only reviewed files, verify their hashes, then restart Functions and perform authenticated read checks.

Backups are retained privately on the VPS under `/data/schooldesk/repairs/20261017-five-improvements/` and locally under ignored `.local/improvements-20261017/`. They must not accompany the APK or be committed.

For application rollback, restore the prior handler versions from the Functions archive. The additive table and corrected reversal RPC can remain. Preserve the custom-notification worker template until any newly queued custom events have drained, or explicitly hold those events during rollback. Existing timers continue unchanged; do not replay historical alert windows. The database dump is a full recovery checkpoint, not a routine rollback command.

The release is version **1.0.33+46**, signed for the existing production application and backend. Artifact signature/configuration evidence is recorded below.

## Production evidence

Both new forward migrations were applied in one transaction using the existing database administrator, after the dump/archive and source/schema baseline checks. The four deployed Functions files match the reviewed local source hashes. The Functions runtime restarted successfully.

Authenticated read checks passed for parent, teacher, coordinator, principal and Super Admin: inbox subjects, unread filters/counts, current school and dated highlights. Principal recipient search and send history returned successfully; the other four roles were denied recipient search and send history. No production broadcast or payment mutation was used.

Production fee/notification realtime triggers and health delivery/withdrawal triggers are enabled. All four existing host timers remain active (processor, birthday morning, birthday afternoon and health). The latest scheduled processor result was success with exit status zero. Phone push delivery remains a separate user acceptance check.

To repeat the synthetic API regressions against the local stack, use `DOCKER_CONTEXT=default python3 scripts/local_notification_finance_smoke.py`, `DOCKER_CONTEXT=default python3 scripts/local_workflow_repairs_smoke.py` and `DOCKER_CONTEXT=default python3 scripts/local_attendance_reopen_smoke.py`. These fixtures are local-only; do not point them at production.

## APK evidence

- Artifact: `artifacts/android/SchoolDesk-1.0.33+46-improvements.apk`, 145,735,618 bytes.
- Package: `com.techmigos.schooldesk1`; version name `1.0.33`, version code `46`.
- APK Signature Scheme v2 verification passed. The signing certificate matches the preceding production release: `80141fa2855069e649008f4f8b7cfc1c31bf66bb4a0a97a7e094765b43c6cb08`.
- The build used the production API and Firebase project; the compiled native library contains `api.arishville.com`. All three packaged native libraries are stripped of DWARF debug sections. Symbols are retained privately for crash diagnosis.
- SHA-256: `7def857f7d0b42e8d64136db22736ac4201b988a6c14a80a5d3c5b37e0cde861`; a checksum sidecar accompanies the APK.
- All 438 Dart/release source files matched the captured handoff manifest after compilation.

No app installation, visual device run or phone push acceptance is claimed. These checks remain with the user, as requested.
