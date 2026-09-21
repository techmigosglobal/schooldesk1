# Known QA Issues and Risks

## Current production disposition — 2026-09-20

- **QA-BLOCK-001:** Migration version drift is resolved. The repository, fresh local Docker history, and production each contain the same 140 version IDs. Thirteen historical name strings still differ, and some original hosted SQL bodies cannot be recovered; these provenance limits and remaining catalog differences are documented in the [migration alignment report](reports/2026-09-21-migration-history-alignment.md). Follow the [migration procedure](../docs/agents/supabase-migrations.md) and inspect the dry-run before future promotion.
- **QA-SEC-002:** The four broad authenticated policies on `school-private-files` were removed in production. Read-only post-deployment verification found zero `school_private_files_authenticated_*` policies. Broader path, expiry, bucket, and object lifecycle checks remain open.
- **QA-APP-001:** Approval-decision audit migration and API changes were promoted and passed local synthetic transaction checks. No isolated production QA identity/record was available, so live authenticated approval history and actual FCM delivery remain unverified. No hosted test records were created.

The issue entries below preserve pre-promotion observations and describe remaining QA scope; where a prior disposition says the change is pending in production, this current section supersedes it.

## QA-OBS-001 — transient local API 502 during security smoke

- **Environment:** Docker-local `schooldesk-local`.
- **Expected:** Coordinator request to unrestricted `/users` returns 403.
- **Observed:** First smoke run returned 502 with “An invalid response was received from the upstream server.”
- **Retest:** The same request returned 403 immediately afterward; the complete second security smoke run passed all 25 checks.
- **Root cause:** Not determined; not reproduced. No source change was made for this observation.
- **Disposition:** Keep as an unreproduced local-runtime observation. Recheck during the next fresh-stack smoke run; do not hide the initial response in the execution report.

## QA-OBS-002 — one local health probe timed out after Storage smoke

- **Environment:** Docker-local `schooldesk-local` after the focused Storage checks.
- **Observed:** A two-second request to `/functions/v1/api/health` returned HTTP 000. Docker services remained running and PostgreSQL was ready; the next request with a ten-second timeout returned HTTP 200.
- **Disposition:** Transient and unreproduced; no source change was made. Recheck during the next local API regression run.

## QA-RISK-001 — low measured Flutter line coverage

- The full coverage run passed 799 tests with one skip, but `coverage/lcov.info` reports 12,891 of 68,882 instrumented lines hit (18.7%).
- Many routes and services are not exercised by this suite. Questionnaire case results remain blocked or Not Run unless their own required evidence exists.
- **Disposition:** Expand targeted automated coverage as the API/RLS and cross-role workflows are executed.

## QA-ENV-001 — no usable browser, emulator, or complete Android native target

- CUA reported no browser provider or browser tabs. The web server and login were exercised with HTTP requests only.
- The configured Pixel 2 AVD cannot start because its Android 30 system image is absent. A physical Moto G85 later completed five role login/dashboard integration cases, but the broader native device suite is incomplete; see QA-ENV-003 and QA-ENV-004.
- iOS build/runtime checks are unavailable on Linux.
- **Disposition:** Backend migrations and the API were promoted on 2026-09-20 after the applicable local/device gates; that promotion does not close the mobile release. Browser, remaining Android native, iOS, and dependent release cases remain Blocked. Gate any future production change on its applicable checks.

## QA-ENV-003 — wireless ADB stalls during APK installation

- **Environment:** Moto G85 5G, Android 16/API 36, wireless ADB; local Docker API health was HTTP 200.
- **Expected:** Install the local QA APK and run the synthetic-role login smoke cases.
- **Observed:** The 173 MiB debug APK built, but installation stalled for 333 seconds and ADB exited `-2`. Flutter reported “No tests ran.” A four-packet host ping received one response at 442 ms (75% loss), and shell requests timed out.
- **Disposition:** This was an initial setup failure, not a product defect. The connection later recovered and the five-role smoke passed. Camera/gallery cancellation, picker callback, share chooser, and print-preview handoffs also passed; broader role lifecycle, FCM delivery, upload/download, and saved PDF checks remain open. The temporary reverse mapping was removed after testing. See [Android device follow-up](reports/2026-09-20-android-device-followup.md).

## QA-ENV-004 — first native picker run timed out; interactive rerun passed

- **Environment:** Moto G85 5G, Android 16/API 36, Docker-local backend.
- **Observed:** The first unassisted run ended with `did not complete` / `No tests were found` while permission/picker UI was active. On rerun with the notification permission pregranted and active device interaction, the Flutter picker callback returned the synthetic PDF, Android share chooser opened, and Print Spooler preview opened.
- **Disposition:** Native plugin handoff is verified. Authenticated app-form upload/download, external sharing, saved PDF output, and complete report rendering remain unverified; track those in [device verification](DEVICE_VERIFICATION.md).

## QA-BLOCK-001 — historical migration version drift resolved; source provenance limited

**Pre-promotion reconciliation checkpoint — 2026-09-20:** The catalog pass found 124 matching IDs, 16 local-only IDs, and 12 production-only IDs. The four reviewed forward migrations were subsequently promoted under their generated production version IDs. Historical production SQL bodies cannot be reconstructed from the hosted migration table alone. See [local/cloud schema reconciliation](reports/2026-09-20-local-cloud-schema-reconciliation.md) and [production promotion](reports/2026-09-20-production-promotion.md).

**Resolved follow-up — 2026-09-21:** Renamed the 12 local timestamp aliases to their proven production version IDs without changing SQL. Those 140 prior IDs remain aligned; the newly created local migration `20260921043515_reconcile_legacy_schooldesk_rpcs` is the only pending production version. Thirteen historical name strings still differ; nine checked-in marker files intentionally preserve history where the original hosted SQL was unavailable. All four production helper RPCs have recorded service-role calls, so they were preserved and hardened rather than dropped. No production write or history repair was performed. Full evidence is in the [migration alignment report](reports/2026-09-21-migration-history-alignment.md) and [RPC reconciliation report](reports/2026-09-21-legacy-schooldesk-rpc-reconciliation.md).

The inventory below records the pre-reconciliation state and is superseded by the 2026-09-21 resolution.

- Read-only comparison against production project `ouvwogguttybmpgfgctc` found 124 matching migration IDs, 13 local-only IDs, and 12 production-only IDs. Twelve of the local-only files have the same logical migration names as the production-only entries but different timestamp IDs; the extra local ID is `20260920122522_approval_decision_audit_history`.
- Schema inventory found 95 public tables on each side, but they are not at the same level. Local adds the two reviewer columns, two reviewer foreign keys, seven approval-audit triggers, and the audit function. Other differences include five local-only RLS policies, two local-only indexes, a validated production fee-request status constraint versus a `NOT VALID` local constraint, optimized production policy/helper expressions, and a `record_fee_payment` status difference (`pending` is accepted locally but not in production). Production also has four service-role-only helper RPCs absent from this checkout.
- Follow-up catalog review found that the five local-only read policies are covered in production by equivalent owner/school-scoped `ALL` policies. They are redundant policy-name differences, not current read-access gaps, and should not be separately added to production.
- Production now has four reviewed migration entries and API revision 277; no migration-history repair or wholesale `db push` was performed. The timestamp alias mapping remains unresolved because production's original SQL bodies are unavailable.
- **Disposition:** The four earlier reviewed changes are promoted, and the previous migration version drift is resolved. The only current pending migration is `20260921043515_reconcile_legacy_schooldesk_rpcs`; the explicit production dry run listed only this migration. Use the dry-run and review gates in [the repository migration procedure](../docs/agents/supabase-migrations.md). Historical SQL provenance limits remain documented.

## QA-SEC-002 — private-file hosted policy removed; broader workflow coverage open

- **Environment:** Local Docker `schooldesk-local` after the fix; production catalog read-only query.
- **Historical observation:** Before the local fix, the School A Parent could read and list another same-school user's object through direct Storage access (HTTP 200).
- **Current local result:** Migration `20260920153106_restrict_private_files_to_service_api` removed the four authenticated policies. The focused 21-check smoke denied direct reads/writes/deletes/signing for anonymous, same-school and cross-school users. The Parent could still fetch the linked child's document only through its API-issued signed URL; the School B Principal received HTTP 404 for School A's document list. Cleanup left no synthetic data.
- **Hosted result:** The reviewed Storage migration was promoted. A read-only post-deployment query found zero `school_private_files_authenticated_*` policies on `school-private-files`.
- **Disposition:** The broad hosted policies are removed. `API-011` and `RISK-002` remain Blocked pending the wider expiry/path/bucket matrix, production R2 provider checks, and end-to-end app workflow. See [local private Storage remediation](reports/2026-09-20-local-private-storage-remediation.md) and [production promotion](reports/2026-09-20-production-promotion.md).

## QA-SEC-003 — private document object deletion/retention is unverified

- **Environment:** Docker-local `schooldesk-local`; synthetic private student document.
- **Historical observation:** Direct authenticated Storage DELETE returned HTTP 400 RLS error.
- **Current interpretation:** Direct Storage deletion is denied by design after private objects were restricted to API/service-role access. It is not evidence of a broken authenticated-user Storage delete capability.
- **Remaining question:** The authenticated `DELETE /student-documents/{id}` path deletes the metadata row; physical object cleanup/retention behavior was not tested. Verify the intended retention rule and API cleanup flow before marking the broader `SHARED-013` case Passed.
- **Disposition:** No direct-Storage deletion defect is currently confirmed. Keep `SHARED-013` Blocked for object lifecycle and other untested validation cases. No hosted changes were made.

## QA-ENV-005 — local and production Storage providers differ

- **Observed:** Local Docker `/health` reports `storage=legacy-compatible`; production `/health` reports `storage=r2-configured`.
- **Impact:** The 21-check local private-Storage smoke verifies RLS/API authorization against local Supabase Storage, not the deployed Cloudflare R2 provider or production object lifecycle.
- **Disposition:** The four reviewed migrations are applied in both environments, but Storage runtime behavior is not fully at the same level. Keep production R2 upload/download/delete checks Blocked until an isolated R2 QA bucket/identity is available. Production credentials were not copied into Docker, and no production test object was created.

## QA-ENV-002 — required web build configuration

- A build without deployment configuration stopped with a clear missing-variables error.
- Re-running with explicit loopback API/site values and the synthetic School A ID completed successfully.
- **Disposition:** No product defect. Do not use those local values for hosted deployment.

## QA-APP-001 — Approval Center did not retain decision history

- **Environment:** Docker-local `schooldesk-local`; synthetic two-school fixtures.
- **Root cause:** The Approval Center audit widget was hardcoded to an empty list, and the approval source tables had no decision-history trigger. A completed request left the pending feed while only its current status and reviewer remained.
- **Fix:** Local migration `20260920122522_approval_decision_audit_history` writes approval, rejection, and change-request transitions into tenant-scoped `audit_logs` in the same database transaction. The Approval Center now loads the current actor's recent decisions. Missing audit identity or an audit-write failure aborts the decision and emits `approval_audit_write_failed` to Postgres logs; the client monitoring path escalates that marker to Super Admin notifications.
- **Verification:** Transaction tests passed under `service_role`; a missing reviewer caused rollback. The local API audit endpoint returned HTTP 200 and enforced actor/module scope. The fresh debug APK was installed and launched on the Moto G85, but no role was signed in for Approval Center UI verification. Local synthetic error-alert records were verified and cleaned; actual push delivery remains untested.
- **Disposition:** Approval history migration and API function are promoted. Historical decisions cannot be reconstructed reliably and were not backfilled. Authenticated live approval history and actual FCM delivery remain unverified because no isolated production QA identity was available.
