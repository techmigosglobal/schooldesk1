# Regression Checklist — 2026-09-20

## Completed with evidence

- [x] Questionnaire structure: 196 cases, 115 registered routes, controlled metadata verified.
- [x] Supabase Edge Function tests against the local stack.
- [x] Local `/health` and `/ready` responses.
- [x] Role dashboards, finance denial, account-directory restrictions, student/document isolation, disabled public setup, and public rate-limit smoke checks.
- [x] Direct PostgREST School A/School B student-row visibility for Principal, Teacher, and Parent.
- [x] Synthetic teacher leave mutation: API response dates match the persisted `start_date` and `end_date`.
- [x] Teacher leave → Principal approval → Teacher status: approved status, actor, dates, and one notification event/log verified in local database state.
- [x] Synthetic account approval: ID-based user hydration appears in `/account-approvals` and the `/approvals/feed` response contract.
- [x] Docker-local approval audit migration: seven decision-source triggers installed; a service-role approval produced exactly one same-transaction audit row in a rolled-back synthetic check.
- [x] Audit failure handling: missing reviewer caused the decision to remain pending, and Postgres recorded `approval_audit_write_failed`.
- [x] Approval audit API: local Principal read returned HTTP 200; module and `user_id=current` filters were enforced. No previous decisions were present to display.
- [x] Error tracking code path: touched Edge handlers type-check; approval audit failures and first-seen fatal/server failures are configured to create Super Admin notification records and push events, with a per-school rate cap.
- [x] Flutter analysis, full unit/widget suite, coverage run, and focused Approval Center unit/widget regression.
- [x] Very Good Analysis staged lint baseline, Riverpod opt-in analyzer config, and Dependency Validator.
- [x] Local-only storage URL test rerun with generated Docker configuration.
- [x] Web unit tests, typecheck, and production build with local configuration.
- [x] Web HTTP login and role-mismatch probes. These do not count as browser UI evidence.
- [x] Read-only local/cloud migration and catalog reconciliation: 124 common migration IDs, 16 local-only and 12 production-only; all twelve logical timestamp aliases have matching inspected catalog postconditions. Remaining local-only approval/status/Storage changes and retained production-only service RPCs are documented; no history repair was performed. See [reconciliation report](reports/2026-09-20-local-cloud-schema-reconciliation.md).
- [x] Moto G85 Android 16 role login/dashboard integration for Principal, Coordinator, legacy Admin, Teacher, and Parent: 5 passed, 0 failed, using Docker-local synthetic fixtures.
- [x] Moto G85 Android 16 Teacher logout/relogin through the portal drawer: session token and role values cleared; same Teacher returned to the dashboard after login. Other roles remain unverified.
- [x] Android notification permission prompt displayed and `Allow` selected. This does not verify FCM delivery or notification tap routing.
- [x] Moto camera and Android gallery/photo picker intents opened and canceled without capturing/selecting media; app resumed after each handoff.
- [x] Synthetic PDF returned from Android DocumentsUI to Flutter; Android share chooser and Print Spooler preview opened, then were canceled without sharing/printing.

## Still required before release

- [x] Tighten Docker-local `school-private-files` access to the authorized API/signed-URL flow; 21 focused role and tenant checks passed. The hosted project still has the broad policies. Verify signed URL expiry, path traversal, invalid/oversized files, retry behavior, and physical-object cleanup/retention before promotion; then complete remaining API/RLS cases, including branch-header, retry/idempotency, sensitive-table, and audit-mutation coverage.
- [ ] Run the listed teacher/parent/principal cross-role workflows with separate sessions and verify database state, audit events, and recipient views.
- [ ] Rebuild/install the updated local APK and approve/reject synthetic requests on device; confirm each decision appears after refresh and verify notification presentation. Device UI and FCM delivery were not exercised after this change.
- [ ] Approve a production migration sequence that handles the twelve timestamp aliases without replaying them, preserves the four production-only service-role RPCs, and promotes only reviewed local migrations after all release gates pass. Migration history must not be repaired by assumption.
- [ ] Complete browser navigation, responsive, accessibility, logout, and web export checks in a controllable browser.
- [ ] Download and render actual PDFs/exports; verify page layout, values, filenames, fonts, and scope.
- [ ] Complete the remaining Android checks in [DEVICE_VERIFICATION.md](DEVICE_VERIFICATION.md): logout/relogin, permission-denial recovery, in-app upload/download, FCM receive/tap, process/background and offline reconnect, and saved/external PDF rendering and values.
- [ ] Complete isolated production health/smoke checks only after local and applicable Android gates pass.
- [ ] Review the 18.7% line-coverage result and the one transient local API 502 observation.
- [ ] Keep iOS evidence and overall mobile release readiness visibly blocked until a supported iOS environment is available.

## Rollback and data handling

- No production change was made, so no production rollback was needed.
- Local work used only the disposable `schooldesk-local` synthetic two-school fixtures. The two explicitly named QA leave/account rows remain local and contain no real student, payment, or document data.
- Preserve all production financial, audit, identity, and document history. Use the approved local fixture reset for repeat runs.
