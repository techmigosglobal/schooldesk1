# Migration history alignment — 2026-09-21

## Result

The checked-in migration versions, the fresh Docker-local `schooldesk-local` history, and Supabase production now contain the same **140 version IDs**. There are no local-only or production-only versions. The 12 local files that used timestamp aliases were renamed to the already-recorded production versions; their SQL contents were not edited. The four migrations promoted on 2026-09-20 already used matching production versions.

The local Docker database was reset from the repository chain and synthetic two-school seeds. `supabase migration list --local` showed all 140 local files applied to the local database. The authenticated production migration inventory returned the same 140 IDs. No production SQL, migration history, records, or functions were changed during this follow-up. No history repair was used.

## Timestamp mappings applied to repository filenames

| Previous local version | Production version | Migration name |
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

## Historical name and body limits

Thirteen shared version IDs have different migration name strings between repository filenames and production history. Supabase migration tracking uses the version ID. The names are recorded here for clarity; the source files were not renamed or deleted because four baseline names describe different SQL semantics and nine production SQL bodies are unavailable.

| Version | Repository filename name | Production history name |
| --- | --- | --- |
| `0017` | `notification_target_role` | `unified_chat_schema_repair` |
| `0019` | `unified_chat` | `chat_realtime_scope` |
| `0021` | `notification_push_support` | `birthday_alert_cron` |
| `0024` | `notification_processor_cron` | `orphaned_fee_cleanup` |
| `20260812163106` | `remote_applied_schema_marker` | `disable_notification_processor_until_auth_fixed` |
| `20260812163351` | `remote_applied_schema_marker` | `secure_notification_processor_cron_auth` |
| `20260812163435` | `remote_applied_schema_marker` | `enable_notification_processor_cron_after_auth` |
| `20260812164157` | `remote_applied_schema_marker` | `performance_indexes_rls_cleanup` |
| `20260812164846` | `remote_applied_schema_marker` | `harden_rls_helper_search_paths` |
| `20260813043816` | `remote_applied_schema_marker` | `targeted_performance_rls_security_hardening` |
| `20260813044236` | `remote_applied_schema_marker` | `remove_unused_branch_rpc_grant` |
| `20260813075011` | `remote_applied_schema_marker` | `principal_workflow_hardening` |
| `20260813075140` | `remote_applied_schema_marker` | `harden_academic_year_trigger_permissions` |

Do not delete these files or rename a marker to imply unknown SQL. The old reconciliation report remains a record of the earlier version mismatch and is superseded for migration-version status by this report.

## Read-only schema comparison

Compared public schema catalogs after the fresh local reset. Local and production matched for 95 relations, 433 constraints, 325 indexes, 287 RLS policies after normalizing PostgreSQL's nested scalar `SELECT` wrappers, 73 triggers, and 2,423 selected table grants. All 1,149 column definitions matched except the ordinal positions of the seven `staff_subjects` columns; column names and types are the same, and PostgreSQL clients address these by name.

Production has four additional `SECURITY DEFINER` helper RPCs: `authorize_schooldesk_request`, `schooldesk_dashboard_summary`, `schooldesk_parent_fee_balances`, and `schooldesk_parent_homework_due`. Live privilege checks showed `service_role` can execute them while `anon` and `authenticated` cannot. No repository source references these routines. They remain a documented production-only legacy difference and were not removed or copied into the local schema.

This establishes exact migration-version parity and the reviewed catalog parity above. Runtime providers remain different: local Storage is `legacy-compatible`; production Storage is `r2-configured`. The migration history does not make those service configurations identical.

## Future workflow

Use [the repository migration procedure](../../docs/agents/supabase-migrations.md). Current local config remains pinned to `schooldesk-local`; production listing and dry-run are explicit commands.

## RPC reconciliation follow-up — 2026-09-21

The 140 versions shown above remain the shared baseline. Migration `20260921043515_reconcile_legacy_schooldesk_rpcs` was then created and applied only to the local database. Production remains at 140 versions; local is at 141. The explicit production dry run lists only this new migration, with no history repair or production write. The four previously production-only RPC definitions, dependency/traffic investigation, hardening, and local verification are in the [RPC reconciliation report](2026-09-21-legacy-schooldesk-rpc-reconciliation.md).
