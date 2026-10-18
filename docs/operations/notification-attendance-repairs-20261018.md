# Notification and teacher attendance release — 18 October 2026

Released Android **1.0.35+48** with compatible backend repairs on the existing self-hosted VPS. Existing website, chat, payment and attendance work was preserved. No commit or push was performed.

## Changes

- Send Notification has a separate bell/send illustration and contrasting tile accent. Shared container foregrounds, composer tabs, role chips, switches, inputs and disabled states use explicit theme colors.
- Recipient failures have friendly guidance and retry; sending requires a successfully loaded recipient scope. Account/branch changes invalidate recipients, confirmation, history and retry keys; account changes also clear private drafts.
- Principal broadcast authorization reads the active persisted profile and same-organization principal branch membership. Recipients/history remain selected-branch scoped. The outer idempotency cache rechecks this authorization before replay, including the runtime `/api` path prefix; existing ledger paths and request hashes were preserved.
- Student attendance loads an authenticated class context: school date, academic year, permitted bounds and configuration status. Selection remains available during failures; refresh/resume preserves unsaved marks while updating claims/finalization. Fresh context/roster/history reads bypass cached fallback; existing local queued-session merging is retained.
- Initial active class assignments create their first enrollment in the student-write transaction, including API/website writes. No-op saves and transfers do not infer or rewrite historical enrollment. Roster effective dates use the school's timezone.

## Forward migrations and production repair

Only these new SQL files were promoted:

- `20261018060831_principal_branch_broadcast_authorization.sql`
- `20261018060834_initial_student_enrollment_transaction.sql`
- `20261018061104_attendance_roster_school_timezone.sql`

The guarded repair inserted exactly three Madhapur enrollments effective **16 October 2026**, in the previously reviewed class and academic year. It compared student identity, assignment, status, admission date and timestamps, plus the corrected year dates, before writing. Conflicting enrollment or changed assignments abort the transaction. A repeat of the repair alone accepts the exact repaired rows without adding duplicates.

The academic year remains **1 June 2026–30 April 2027**. Before/after audit snapshots confirmed that student records, the year record and existing school attendance were unchanged.

The production installation has no `supabase_migrations.schema_migrations` table. Promotion used its existing self-hosted workflow: exact live function/source baseline comparison, a reviewed package manifest, a fresh backup, three migrations plus repair in one `psql -1` transaction, then four Functions files and a runtime restart. No hosted link, migration-history repair or production `db push` was used. Docker-local migration replay and pinned CLI migration listing passed separately.

## Evidence

Private evidence is under `.local/notification-attendance-20261018/`; the corresponding production audit directory is `/data/schooldesk/repairs/20261018-notification-attendance`. It contains backups, exact source hashes, repair row snapshots, deployment output and authenticated read-check output. These files contain operational/private data and should not be published.

- Flutter full analysis: no issues. Final frozen-source focused suite: **32 tests passed**. Focused behavioral tests cover light/dark and narrow/enlarged controls, failed/loading recipient selection, branch/account changes, transport scope, school-clock initialization, year configuration, refresh recovery, dirty marks, claims and no-store behavior.
- Deno calendar tests and API type checking passed.
- Complete synthetic Docker migration replay and seeds passed. API checks covered principal home/secondary branches, revoked/wrong-role/foreign/inactive authorization, concurrent idempotent retries, scoped history, enrollment creation/activation/transfer preservation, atomic rollback and school-timezone roster boundaries.
- Teacher/co-teacher API checks covered historical/current drafts and submission, exact enrollment identity, competing ownership, finalized registers, malformed/future dates, missing/noncurrent/future/ended year configuration and recovery. The repair passed duplicate-run and changed-assignment rejection tests.
- Existing issue, diary, health/highlight, notification/finance, attendance reopening and chat delivery Docker regressions passed.
- Authenticated production GET checks passed for principal home and authorized secondary branch recipients/history. Both real Madhapur teacher/co-teacher identities received all three enrolled students on the admission date and current school date, plus readable register history. Unauthorized roles and foreign-class/parent context reads were denied.
- Four existing notification timers remained active; the latest processor service result was successful. No production test broadcast or attendance submission was performed.

## APK

Artifact: `artifacts/android/SchoolDesk-1.0.35+48-notification-attendance.apk` (146,063,988 bytes).

SHA-256: `a821dc0e60d55bfa6d9ededb27e60a7f01c23d979f86349fde09613a8389ce42`.

Verified release signature, expected certificate, package `com.techmigos.schooldesk1`, version `1.0.35`/build `48`, production API endpoint, all three stripped native libraries and the frozen source manifest. Device appearance, interaction and actual phone push receipt remain the user's acceptance checks.

## Recovery

Backups include `database-before.dump`, `database-before-promotion.dump` and `functions-before.tar.gz`, protected in the audit directory and copied locally. Restore only the four changed Functions files from the source backup and restart the Functions container for application rollback; the additive schema remains compatible with the prior client. Keep the repaired enrollment rows if attendance has since used them. Any database restoration or reversal requires a separate reviewed recovery operation against current activity; do not blindly delete enrollment or financial/history records.
