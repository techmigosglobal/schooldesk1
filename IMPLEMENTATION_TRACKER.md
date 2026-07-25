# Monitoring and Realtime implementation tracker

This tracker records implementation work and verification evidence for the
retention and Realtime rollout. It is deliberately not product documentation.

## Acceptance rules

- Existing writes remain secured Edge API operations.
- Realtime carries invalidation signals only; clients refresh through existing
  scoped APIs.
- No open or fatal error event is automatically deleted.
- All manual error cleanup is Super Admin-only, previewed, confirmed, and
  audited.
- Every changed module receives focused automated verification before broad
  Flutter/static checks.

## Tasks

- [x] Map current error reporting, monitoring routes, policies, current table size, and existing chat Realtime implementation.
- [x] Add database schema for error deduplication, bounded payloads, retention settings, daily summaries, scheduled cleanup, and safe Realtime invalidations.
- [x] Add backend retention metrics/settings/preview/confirmed-cleanup APIs with audit records.
- [x] Add Super Admin retention controls and error occurrence display.
- [x] Add client-side report normalization, redaction, and bounded queue behavior.
- [x] Add shared Flutter invalidation subscription service.
- [x] Wire announcements/events/gallery, attendance, fees, dashboards, and foreground notifications to the shared service with API refresh fallback.
- [x] Add contract/regression tests for authorization, limits, cleanup safety, subscriptions, and role/branch isolation.
- [x] Run backend type checks, focused Flutter tests, Flutter analyzer, formatting, and source review.
- [x] Replace the separate demo sandbox entry with shared-credential sign-in, role selection, local normal-role API façade, and role-selector logout.
- [x] Restore the encrypted local demo snapshot after an app restart, while preventing stale production-session restoration from replacing the selected demo role.
- [x] Expand the shared demo into a relational offline fixture store with role-specific school records, local writes, five bundled fictional preschool posts, reset-on-logout, and direct-network guards.
- [x] Add Super Admin-only permanent deletion for individually selected resolved error events, with typed confirmation and audit history.
- [x] Apply the migration, deploy the Edge API, and run authenticated hosted smoke tests against the production project.

## Verification log

- `deno check supabase/functions/api/index.ts` passed.
- `flutter test test/unit/error_retention_realtime_contract_test.dart` passed (5 tests).
- `flutter test test/unit/demo_branch_website_contract_test.dart` passed (3 tests), including standard-field demo sign-in, local-only routing, role-selector logout, and restart restoration wiring.
- Existing chat (16), parent attendance (1), parent-fee role (2), and principal attendance dashboard (1) regression suites passed.
- Focused `flutter analyze` of all changed Flutter surfaces passed with no issues.
- `git diff --check` passed.
- Production release (2026-07-24): migration `20260724163304_error_event_retention_and_realtime_invalidation.sql` applied to `ouvwogguttybmpgfgctc`; `api` deployed and confirmed active at version 218.
- Hosted `/health` and `/ready` both returned success. Authenticated Super Admin retention/event-list requests succeeded; unauthenticated retention access returned 401; the typed-confirmation delete route returned the expected non-mutating 404 for a synthetic UUID.
- Offline demo fixture contract covers Principal, Teacher, and Parent core records, five local media posts, local write persistence, and post-login guards for chat Realtime, push registration, and telemetry.
