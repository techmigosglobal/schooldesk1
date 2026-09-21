# Approval audit and alert follow-up — 2026-09-20

## Scope and environment

- Targeted the Docker-local `schooldesk-local` project and synthetic two-school fixtures only.
- No Supabase cloud migration, function deployment, or production smoke check was run.
- The new migration is `20260920122522_approval_decision_audit_history`.

## Root cause

- The Approval Center's Audit Log widget used a constant empty list.
- Approval decisions updated current request rows, but there was no durable decision-history trigger for those source tables. When an item left the pending feed, the screen had no history to show.
- The landing artwork files `assets/images/landing_slide_1.png` through `landing_slide_6.png` have since been replaced with 941 × 1672 px images. Their aspect ratio is 0.5628, about 0.05% from exact 9:16; 1080 × 1920 px is optional, not required. `_ArtworkSlide` still uses `BoxFit.fill`, so keeping the image ratio close to the displayed frame avoids visible distortion.

## Changes

- Added a trigger to `audit_logs` for status decisions on `approval_requests`, `account_approvals`, `leave_applications`, `student_leave_applications`, `fee_concessions`, `parent_payment_requests`, and `event_posts`.
- Each audit row stores school, actor ID/name/role, source row ID/table, previous/new status, optional review note, event type, and timestamp. The SECURITY DEFINER trigger is owned by `postgres`; direct function execution is revoked. Trigger failures emit the marker `approval_audit_write_failed` and abort the associated approval transaction.
- Added reviewer columns for fee-concession and event-post decisions and set them in the Edge handlers.
- Connected the Approval Center widget to `/audit-logs`, with a module filter and `user_id=current`. It now shows entries, a loading state, an empty state, an error state with retry, and a refresh action.
- Existing API error reporting now retains a failed report in memory and retries it with capped backoff. First-seen fatal/server errors and approval-audit failures are recorded in `error_events` and create a tenant-scoped Super Admin notification plus push event. Alerts are deduplicated by error fingerprint and capped at five per school per five minutes.

## Verification evidence

- Applied the migration locally using `supabase migration up --local`; local migration history now includes `20260920122522`.
- A transaction test under `service_role` changed a synthetic pending account approval and observed exactly one matching `audit_logs` row before rolling the transaction back.
- A second transaction omitted the reviewer. The trigger rejected the decision, the request remained pending, and Docker Postgres logged the table, row ID, SQLSTATE, and failure reason under `approval_audit_write_failed`.
- Authenticated a synthetic Principal against the local Edge API. `/audit-logs?module=approvals&user_id=current&page_size=10` returned HTTP 200 and zero rows; all returned rows (none in this fixture) matched the actor and module filters.
- Local API `/health` returned HTTP 200.
- Docker-local Edge Function suite: **26 passed, 0 failed**. Deno type-check passed for touched API handlers. Targeted Dart analysis passed with no issues.

## Limits and remaining checks

- The database transaction probes rolled back, so they left no test approval or audit rows behind. A post-migration decision through the app has not yet been made.
- The installed Moto G85 APK predates these UI changes. Rebuild and reinstall the local APK before manual role approval/rejection walkthroughs.
- Push event creation is implemented and type-checked, but no FCM delivery was exercised; the configured device and hosted messaging setup remain unverified.
- Previously completed decisions cannot be reconstructed reliably from current-status rows, so no historical backfill was performed. New decisions are captured from this migration onward.
- Local/cloud migration histories remain divergent: the current read-only check found 13 local-only and 12 production-only version IDs, with 12 logical-name pairs using different timestamps. Catalog comparison found additional RLS policy/helper and fee-payment RPC differences. Cloud parity and production promotion remain blocked; see [schema reconciliation](2026-09-20-local-cloud-schema-reconciliation.md).
- The installed Flutter landing slides are now 941 × 1672 px and are close enough to 9:16; no resize is required. `schooldesk-web` uses separate photography under `schooldesk-web/public/preschool/` and its desktop hero crops with `object-fit: cover`, so reusing portrait phone slides on the web would need a separate landscape crop or responsive art direction.
- The web Principal/Coordinator portal has no Approval Center module. The shared database migration will persist decisions from any client after promotion, but web history UI and browser error reporting are separate work; the current web error boundary logs to the browser console only. See the schema reconciliation report for the source review.
