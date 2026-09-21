# Production promotion — 2026-09-20

## Scope

- Target: Supabase production project `ouvwogguttybmpgfgctc`, region `ap-south-1`.
- Project was `ACTIVE_HEALTHY` on PostgreSQL 17.6 before promotion.
- No production QA identity, student, payment, approval, or document record was created or changed. Hosted functional approval and FCM checks remain Blocked without isolated QA identities.
- Only four reviewed DDL migrations and the `api` Edge Function were promoted. No migration history was rewritten and no other function was deployed.

## Local gates

- Recreated Docker-local `schooldesk-local` from synthetic two-school fixtures. Fresh reset applied 140 migration files, including the four promoted changes under their final version names.
- Edge Function tests: **26 passed, 0 failed**.
- Local API `/health`: **HTTP 200** after starting the host Edge Function server.
- Role and tenant security smoke: **25 passed**.
- Private Storage smoke: **21 passed**. The corrected direct DELETE probe used the real object path; HTTP 200 left both the Storage row and bytes intact. Cleanup left zero QA document rows and blobs.
- Approval audit transaction smoke inserted one synthetic account approval, moved it through approved and rejected, observed two corresponding `audit_logs` rows, then rolled back.
- Local error-alert smoke posted a synthetic approval-audit failure through `/monitoring/error-events`. It observed one `error_events` row, one Super Admin `notification_logs` row, and one `notification_events` row, then removed all three. This verifies database tracking; it does not verify FCM delivery.
- Flutter analysis passed; Flutter tests: **799 passed, 1 skipped, 0 failed**. `schooldesk-web`: **64 passed**, 250 assertions, typecheck and production build passed with local synthetic configuration. These source/web results were recorded earlier this day; no web source changed in this promotion.
- Moto G85, Android 16: five local role dashboards passed; Teacher logout/relogin passed; camera/gallery cancel paths passed; PDF picker and share chooser passed on the final rerun. Print preview passed in the prior recorded run. Notification permission was allowed. FCM receive/tap, offline reconnect, full app upload/download, saved PDF rendering, and iOS remain unverified.
- After promotion, a regular debug APK (`--dart-define-from-file=env.local.json`) was rebuilt and installed on the Moto G85. It opened the updated landing carousel without an app fatal exception; the notification prompt was allowed. APK SHA-256: `82a2f5727675bb2067f6651dbc09f2f257019ce930c5f0e92cc171d91b70d779`. Screenshot evidence: [Moto G85 startup](evidence/2026-09-20-moto-g85-local-startup.png). This build used ADB reverse to Docker-local Supabase, not production. User role walkthrough and Approval Center UI verification remain open.

## Database migrations

The production project had 136 recorded migrations before promotion. Supabase `apply_migration` assigned these UTC versions; the repository files now use the same versions so these four changes will not replay:

| Production version | Recorded migration name | Repository migration file |
|---|---|---|
| `20260920171339` | `20260920122522_approval_decision_audit_history` | `20260920171339_20260920122522_approval_decision_audit_history.sql` |
| `20260920171403` | `20260920152040_reconcile_payment_status_and_local_duplicates` | `20260920171403_20260920152040_reconcile_payment_status_and_local_duplicates.sql` |
| `20260920171419` | `20260920152325_align_rls_auth_helpers_with_production` | `20260920171419_20260920152325_align_rls_auth_helpers_with_production.sql` |
| `20260920171431` | `20260920153106_restrict_private_files_to_service_api` | `20260920171431_20260920153106_restrict_private_files_to_service_api.sql` |

Production history now has 140 entries. The 12 older timestamp aliases remain; their catalog postconditions matched in the earlier reconciliation, but their original production SQL bodies are unavailable. Do not run a wholesale `supabase db push` until those older aliases have an explicit safe mapping. The four new migrations are version-aligned between the repository, fresh Docker reset, and production.

Verified hosted postconditions:

- Seven enabled approval-decision audit triggers exist; `fee_concessions.reviewed_by` and `event_posts.reviewed_by` exist.
- `record_fee_payment` accepts the legacy `pending` request status; the payment status constraint is validated.
- Redundant local-only read-policy names and the duplicate notification-retention index are absent.
- `school-private-files` has zero `school_private_files_authenticated_*` policies. Access continues through API authorization and service-role Storage operations.
- All four production-only helper RPCs remain present and executable by `service_role` only.

## Edge Function and live smoke

- Deployed only Edge Function `api` to the explicit production ref. New function revision: **277 ACTIVE**; `verify_jwt=false` preserved from revision 276 because the API validates its own user token.
- Production `GET /functions/v1/api/health`: **HTTP 200**, status `ok`, storage `r2-configured`.
- Current local `GET /functions/v1/api/health`: **HTTP 200**, status `ok`, storage `legacy-compatible`. This differs from production's `r2-configured` storage mode. The Docker private-Storage smoke therefore verifies policy/API authorization against local Supabase Storage; it does not exercise the production R2 provider. No production bucket credentials were copied into Docker, and no live object mutation was attempted.
- Production migration inventory shows the four new entries above. No hosted record mutation or authenticated functional smoke was run because no isolated live QA identity/record was available.

## `schooldesk-web` impact

- The web portal is Principal/Coordinator only and sends authenticated requests through its server-side `/api/backend/*` proxy to the same Edge API. It has no Approval Center/audit history screen or private student-document Storage flow. Its current finance payment-request action sends the same `{status: approved|rejected}` payload accepted by the updated API; approval requester response fields remain compatible.
- No web source change was needed for these mobile/backend changes. The existing web suite (64 tests, 250 assertions), typecheck, and build passed earlier with local synthetic configuration; the web source did not change in this promotion.

## Advisors and remaining limits

- Security advisor: eight RLS-enabled service/internal tables have no direct policies (INFO); leaked-password protection remains disabled (WARN), as before. No Auth settings were changed.
- Performance advisor: 136 unindexed foreign keys and 68 unused indexes (INFO). The two new reviewer foreign keys are included in the unindexed-FK notices; add covering indexes in a separate reviewed migration if measured workload warrants it.
- The full questionnaire still reports **166 Blocked, 30 Not Run, 0 Passed, 0 Failed**. Structural validation is not case execution. Browser, live-role, FCM, reconnect, document lifecycle, iOS, and other manual evidence remains open.
- Overall release status stays **BLOCKED**, despite backend promotion. The updated APK cold-started, but role-based manual Approval Center walkthrough, FCM delivery/tap, background/reconnect, and iOS still need evidence.
