# Local and production schema reconciliation — 2026-09-20

## Scope and safety

- Local database: Docker Supabase project `schooldesk-local`.
- Production database: Supabase project `ouvwogguttybmpgfgctc` (`schooldesk(ArishVille)`).
- Compared migration histories and read-only PostgreSQL catalogs for tables, columns, indexes, constraints, policies, routines, triggers, RLS flags, and selected grants.
- No production migration, function deployment, or migration-history repair was performed. No production records were changed.
- `supabase migration list --linked` could not run because this checkout has no CLI project link. Production catalog reads used the authenticated Supabase read-only SQL connection.

## Migration history

- Local has 140 migration IDs through `20260920153106`; production has 136 through `20260914100223`.
- 124 migration IDs match exactly. There are 16 local-only IDs and 12 production-only IDs.
- Twelve local-only migration files have the same logical migration names as the twelve production-only entries, but their timestamps differ. The original unmatched local migration is `20260920122522_approval_decision_audit_history`.
- Three additional forward-only local migrations now follow the approval audit migration: `20260920152040_reconcile_payment_status_and_local_duplicates`, `20260920152325_align_rls_auth_helpers_with_production`, and `20260920153106_restrict_private_files_to_service_api`.
- The catalog postconditions for the 12 matching-name pairs were checked below. The production migration table stores names and versions, not the original SQL bodies, so exact body equality cannot be certified from history alone. Do not use `migration repair` to mark versions applied.

| Local file version | Production history version | Shared logical name |
| --- | --- | --- |
| `20260828183352` | `20260830134225` | `database_rate_limits` |
| `20260829104820` | `20260830134443` | `enforce_single_parent_per_student` |
| `20260829143718` | `20260830134501` | `repair_telangana_holiday_calendar_2026_27` |
| `20260829144043` | `20260830134507` | `fix_telangana_holiday_calendar_academic_year_range` |
| `20260830103000` | `20260830134516` | `require_canonical_fee_invoice_source` |
| `20260912100000` | `20260913014816` | `api_idempotency_keys` |
| `20260912110000` | `20260913014838` | `r2_storage_migration_tracking` |
| `20260913090000` | `20260914094215` | `paging_fee_summary_and_scope_indexes` |
| `20260913100000` | `20260914094225` | `notification_processing_leases` |
| `20260914070738` | `20260914094232` | `school_feed_destinations_and_media_indexes` |
| `20260914092444` | `20260914094240` | `storage_reference_rewrite_audit` |
| `20260914100133` | `20260914100223` | `revoke_public_fee_dashboard_summary_execute` |

### Matching-name migration effects

- The expected table column signatures, RLS flags, relevant grants, index definitions/validity, constraints, and function definitions/grants for the 12 pairs match across local and production. This includes the rate-limit functions, canonical invoice trigger/function, API idempotency objects, storage migration tracking tables, paging indexes and fee summary RPC, notification lease columns/index/check, feed destination index, and storage rewrite audit objects.
- The Telangana calendar migrations were checked using aggregate matches only. Local has 2 qualifying school-year rows and all 48 expected holiday entries; production has 4 qualifying school-year rows and all 96 expected entries. There are no missing expected entries or old misspelled entries in either environment. No school identifiers were returned.
- The single-parent migration's unique student index matches. Its legacy-row deletion was not independently inspected because that would involve student-link records. The notification lease backfill was not inspected row by row; its columns, index, and validated check match.
- No migration body was rerun in production, and no migration history was repaired. These aliases are documented mappings with matching catalog postconditions, not permission to rewrite migration history.

## Catalog comparison

Both databases have 95 public tables; the broader `public` plus `schooldesk_internal` inventory has 101 tables on each. Table RLS flags and application grants compared equal. The schema still has reviewed differences:

- **Approval audit, local only:** `event_posts.reviewed_by` and `fee_concessions.reviewed_by`, their foreign keys, `record_approval_decision_audit()`, seven decision triggers, and `audit_logs_approval_actor_recent_idx`. These are the expected contents of the new local approval-audit migration.
- **Notification index:** Production has `idx_notification_events_created` on `created_at`; local also had an identical extra index named `idx_notification_events_retention`. The local reconciliation migration removed the duplicate; no production index change is needed.
- **Fee-request validation:** Both environments now have the same allowed status check and it is validated. The local reconciliation migration validated it after a pre-migration aggregate check found no invalid statuses; production was already validated.
- **RLS policies:** Both environments now have 287 public policies. The five extra local read policies were redundant with existing owner/school-scoped `ALL` policies and were removed locally; no production policy change was needed. All 287 matching policy definitions compare equal after normalizing scalar `SELECT` wrappers around `auth.uid()`, `auth_school_id()`, `auth_role_name()`, and `is_admin_or_principal()`.
- **RLS helper functions:** The three local helper definitions now match production exactly by catalog definition hash and `search_path=pg_catalog, auth, public`. The production scalar wrappers are retained as query-plan optimization; the policy predicates remain semantically aligned.
- **Fee payment behavior:** Production `record_fee_payment` rejects a request in `pending` status; local accepts `pending` as well as `pending_verification`, `resubmitted`, and `submitted`. A normalized function-definition comparison found this status guard is the only body difference. The local reconciliation migration restores the repository's explicit legacy compatibility contract. Production remains unchanged until a later promotion.
- **RPC inventory:** Production has four additional `SECURITY DEFINER` helpers, executable by `service_role` only: `authorize_schooldesk_request`, `schooldesk_dashboard_summary`, `schooldesk_parent_fee_balances`, and `schooldesk_parent_homework_due`. No local source or stored routine body references them. Keep these as retained cloud legacy routines; the reconciliation migrations do not drop them.
- **Approval triggers:** The seven local-only approval triggers are required for the audit fix and are not present in production until the migration is promoted.
- **Private Storage:** Local migration `20260920153106_restrict_private_files_to_service_api` removes the four authenticated policies from `storage.objects` for `school-private-files`. The application uses API/service-role operations, with student/staff document readers checking record scope before returning signed URLs. The focused Docker run passed 21 checks: direct reads, writes, deletes, and signing were denied; Principal and linked Parent API flows returned valid signed URLs; and a cross-school API request returned 404. Production still has the four school-wide authenticated policies, confirmed by a fresh read-only query; this migration remains a required production delta.

## Security observation

Supabase's table inventory flagged `public.finance_document_sequences` because RLS is disabled in production. It is also disabled locally. The full read-only grant inventory shows only `service_role` has table privileges; `anon` and `authenticated` have none. This means the advisor's public-access warning is not borne out by current grants, though RLS remains disabled as a defense-in-depth gap. No change was applied. Do not enable RLS without defining the intended service/API access policy.

## Promotion gate and reconciliation plan

1. The 12 timestamp aliases have matching catalog postconditions and are mapped above; do not rewrite production migration history because the applied SQL bodies are unavailable for exact comparison.
2. The three local reconciliation migrations are applied to Docker only. Catalog checks confirmed the validated constraint, legacy `pending` guard, removal of the duplicate index/policies, production-matching auth helper hashes/paths, and zero authenticated policies for the private-file bucket.
3. The approval audit remains local only. Review its forward migration and verify it on a fresh Docker reset before any hosted release request; only 710 MB was free at the latest check with the root filesystem at 100%, so do not reset until capacity is safe.
4. Keep the four service-role-only production RPCs intact. Revisit their retirement only with an explicit dependency audit.
5. The former same-school private Storage direct-read issue is fixed and verified in Docker only; production still has the broad policies. Keep promotion blocked until this migration is reviewed alongside the remaining local, Android, browser, and hosted gates.

**Status:** The matching migration pairs and identified duplicate policy/index differences are reconciled or classified. Production still differs by the local-only approval audit, fee-status compatibility update, private Storage policy hardening, and retained production-only service RPCs. All three reconciliation migrations applied to Docker. The auth-helper catalog hashes match production, and the synthetic Principal/Teacher JWT helper smoke passed. The focused private Storage smoke passed 21 checks; the general post-migration API security smoke later passed 25/25 after its initial fixture-login 429s cleared. Production promotion remains blocked.
