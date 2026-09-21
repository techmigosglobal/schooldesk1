# Local private Storage remediation — 2026-09-20

## Scope and safety

- Local target: Docker Supabase project `schooldesk-local`, using synthetic School A and School B fixtures only.
- Hosted target: production project `ouvwogguttybmpgfgctc`, read-only inspection only.
- No production migration, function deployment, migration-history repair, or record mutation occurred.
- Local API health returned HTTP 200 before the focused run.

## Change

Migration `20260920153106_restrict_private_files_to_service_api.sql` drops the four `authenticated` Storage policies for `school-private-files` (SELECT, INSERT, UPDATE, DELETE). The bucket remains private. Local `storage.objects` now has zero policies for that bucket, so authenticated clients cannot read, list, write, or sign objects directly.

The application stores these files through API handlers using the service role. The student/staff document read handlers authorize school and record scope before returning signed URLs; the focused run verified Principal detail and linked Parent document-list flows. Generic uploads, other document routes, and mutation/lifecycle authorization remain in the wider QA scope. No Flutter code directly accesses `school-private-files`.

## Docker verification

Command: `scripts/local_storage_security_smoke.sh` — **21 checks passed, 0 failed**.

- Principal uploaded a synthetic CSV through the student-document API; an API-issued signed URL fetched it successfully (HTTP 200).
- Anonymous, same-school Principal, Teacher, Parent, and other-school Principal direct reads were denied (HTTP 400). The private public-object URL was denied (HTTP 400).
- Same-school Teacher direct upload and delete were denied (HTTP 400). The existing API-issued signed URL continued to work after the denied delete.
- Same-school Parent Storage listing returned HTTP 200 but did not include the synthetic object. Direct Storage signing by same-school Principal and other-school Principal was denied (HTTP 400).
- Parent detail omitted private documents. A linked Parent could list the child's document through the API and fetch it through the API-issued signed URL (HTTP 200). A School B Principal received HTTP 404 for the School A document list.
- Principal detail returned the uploaded document with a signed URL.
- The run removed its synthetic row and blob. Post-run database checks found zero QA documents and zero QA objects.
- The signed URL returned inside the local Edge Function referenced Docker's internal host. The script fetched the same signed path through the published loopback URL; no signature or policy behavior was changed for the test.

## Hosted comparison

A fresh read-only production query still shows all four `school_private_files_authenticated_*` policies. Production has 136 migrations through `20260914100223`; local has 140 through `20260920153106`. The hosted policy remains school-wide and does not enforce linked-student/record scope. The local fix has not been promoted.

## Remaining checks and gate

- The general `scripts/local_security_smoke.sh` initially received HTTP 429 during repeated fixture logins. After the rate-limit window cleared, a fresh run passed **25/25** after all local reconciliation migrations.
- One two-second API health probe timed out after the focused run. Docker services were still up, PostgreSQL was ready, and an immediate ten-second retry returned HTTP 200; this is recorded as a transient probe in [known issues](../known_issues.md).
- Expiry after the API's configured ten-minute TTL, path traversal, malformed/oversized content, retry behavior, broader private buckets, app-level object cleanup/retention, and physical-device upload/download remain unverified.
- Teacher direct Storage DELETE 400 is expected under the corrected API-only access model and passed as a denial assertion. The authenticated API document-delete lifecycle and physical blob retention still need their own verification.
- Production promotion remains blocked until the remaining local, Android, browser, and hosted readiness gates are resolved. This migration must be included in a later reviewed promotion; nothing was deployed.
