# Legacy SchoolDesk RPC reconciliation — 2026-09-21

## Decision

All four RPCs are **production-used and retained**. `pg_stat_statements` records service-role execution for each since its statistics reset on 2026-07-01. The currently checked-in code and active Edge Function versions no longer reference them, and the exact external caller could not be identified. Because production traffic is recorded, dropping them is unsafe until that caller is identified and retired.

The new forward migration `20260921043515_reconcile_legacy_schooldesk_rpcs.sql` recreates the production contracts and query bodies, sets an empty `search_path`, qualifies relations and callable catalog functions, pins ownership to `postgres`, revokes execution from `PUBLIC`, `anon`, and `authenticated`, and grants execution to `service_role`. It does not change historical migrations, function signatures, function query logic, or data.

## Production definition and access inventory

Definitions below are verbatim results from production `pg_get_functiondef` before the migration. Each function is owned by `postgres`, is SQL, `SECURITY DEFINER`, `VOLATILE`, `PARALLEL UNSAFE`, and not strict; each had `search_path=public, pg_temp`. The ACL for every function was `{postgres=X/postgres,service_role=X/postgres}`. Effective `EXECUTE`: `anon=false`, `authenticated=false`, `service_role=true`, owner `postgres=true`; no `PUBLIC` grant was present.

| RPC | Identity arguments | Result | Observed production calls since 2026-07-01 |
| --- | --- | --- | ---: |
| `authorize_schooldesk_request` | `p_user_id uuid, p_requested_school_id uuid, p_role_name text` | `TABLE(profile_school_id uuid, is_active boolean, permitted boolean)` | 2,005 as `service_role` + 3 as `postgres` |
| `schooldesk_dashboard_summary` | `p_school_id uuid, p_today_start timestamp with time zone` | `jsonb` | 23 as `service_role` + 3 as `postgres` |
| `schooldesk_parent_fee_balances` | `p_school_id uuid, p_student_ids uuid[]` | `TABLE(student_id uuid, balance numeric)` | 67 as `service_role` + 3 as `postgres` |
| `schooldesk_parent_homework_due` | `p_school_id uuid, p_student_ids uuid[]` | `TABLE(student_id uuid, due_count integer)` | 67 as `service_role` + 3 as `postgres` |

`pg_stat_statements` reports cumulative calls since its reset, not a last-call timestamp or client identity. The counts establish production use during that window; they do not identify whether the caller is still active today.

### `authorize_schooldesk_request`

```sql
CREATE OR REPLACE FUNCTION public.authorize_schooldesk_request(p_user_id uuid, p_requested_school_id uuid, p_role_name text)
 RETURNS TABLE(profile_school_id uuid, is_active boolean, permitted boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  with profile as (
    select id, school_id, is_active
    from public.users
    where id = p_user_id
    limit 1
  ),
  super_admin_scope as (
    select
      home.organization_id as home_organization_id,
      requested.organization_id as requested_organization_id
    from profile
    left join public.schools home on home.id = profile.school_id
    left join public.schools requested on requested.id = p_requested_school_id
  )
  select
    profile.school_id as profile_school_id,
    profile.is_active,
    case
      when profile.id is null or profile.is_active is not true then false
      when p_requested_school_id is null then true
      when lower(coalesce(p_role_name, '')) = 'super_admin' then exists (
        select 1
        from super_admin_scope scope
        where scope.home_organization_id is not null
          and scope.requested_organization_id is not null
          and scope.home_organization_id = scope.requested_organization_id
      )
      when lower(coalesce(p_role_name, '')) = 'coordinator' then
        p_requested_school_id = profile.school_id and exists (
          select 1
          from public.branch_memberships membership
          where membership.user_id = p_user_id
            and membership.school_id = p_requested_school_id
            and membership.is_active = true
        )
      else exists (
        select 1
        from public.branch_memberships membership
        where membership.user_id = p_user_id
          and membership.school_id = p_requested_school_id
          and membership.is_active = true
      )
    end as permitted
  from profile;
$function$
```

### `schooldesk_dashboard_summary`

```sql
CREATE OR REPLACE FUNCTION public.schooldesk_dashboard_summary(p_school_id uuid, p_today_start timestamp with time zone)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  with active_students as (
    select current_section_id
    from public.students
    where school_id = p_school_id
      and is_test_account = false
      and lower(coalesce(status, '')) = 'active'
  ),
  student_counts as (
    select
      count(*) filter (where current_section_id is not null)::integer
        as active_assigned_students,
      count(*) filter (where current_section_id is null)::integer
        as active_unassigned_students
    from active_students
  ),
  staff_counts as (
    select count(*)::integer as total_staff
    from public.staff
    where school_id = p_school_id
  ),
  section_counts as (
    select count(*)::integer as total_sections
    from public.sections
    where school_id = p_school_id
  ),
  fee_counts as (
    select
      coalesce(sum(balance) filter (where status = 'pending'), 0)::numeric
        as pending_fee_balance,
      coalesce(sum(paid_amount) filter (where status = 'paid'), 0)::numeric
        as total_paid
    from public.fee_invoices
    where school_id = p_school_id
      and status in ('pending', 'paid')
  ),
  leave_counts as (
    select count(*)::integer as pending_leave_requests
    from public.leave_applications
    where school_id = p_school_id
      and status = 'pending'
  ),
  today_attendance_counts as (
    select
      count(attendance.id)::integer as marked,
      count(attendance.id) filter (where attendance.status = 'present')::integer
        as present
    from public.attendance_sessions session
    left join public.student_attendances attendance
      on attendance.session_id = session.id
    where session.school_id = p_school_id
      and session.date = p_today_start::date
  ),
  all_attendance_counts as (
    select count(attendance.id)::integer as attendance_today
    from public.attendance_sessions session
    join public.student_attendances attendance
      on attendance.session_id = session.id
    where session.school_id = p_school_id
  ),
  payment_request_counts as (
    select count(*)::integer as pending_fee_requests
    from public.parent_payment_requests
    where school_id = p_school_id
      and status = 'pending'
  ),
  approval_counts as (
    select count(*)::integer as pending_approvals
    from public.approval_requests
    where school_id = p_school_id
      and status = 'pending'
  )
  select jsonb_build_object(
    'total_students', coalesce(sc.active_assigned_students, 0),
    'active_unassigned_students', coalesce(sc.active_unassigned_students, 0),
    'total_staff', coalesce(st.total_staff, 0),
    'total_sections', coalesce(sec.total_sections, 0),
    'pending_fee_balance', coalesce(fee.pending_fee_balance, 0),
    'total_paid', coalesce(fee.total_paid, 0),
    'total_due', coalesce(fee.pending_fee_balance, 0),
    'pending_leave_requests', coalesce(leave.pending_leave_requests, 0),
    'today_marked', coalesce(today.marked, 0),
    'today_present', coalesce(today.present, 0),
    'attendance_today', coalesce(attendance.attendance_today, 0),
    'pending_fee_requests', coalesce(payments.pending_fee_requests, 0),
    'pending_approvals', coalesce(approvals.pending_approvals, 0)
  )
  from student_counts sc
  cross join staff_counts st
  cross join section_counts sec
  cross join fee_counts fee
  cross join leave_counts leave
  cross join today_attendance_counts today
  cross join all_attendance_counts attendance
  cross join payment_request_counts payments
  cross join approval_counts approvals;
$function$
```

### `schooldesk_parent_fee_balances`

```sql
CREATE OR REPLACE FUNCTION public.schooldesk_parent_fee_balances(p_school_id uuid, p_student_ids uuid[])
 RETURNS TABLE(student_id uuid, balance numeric)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select
    invoice.student_id,
    coalesce(
      sum(
        greatest(
          0,
          coalesce(
            invoice.balance,
            coalesce(invoice.net_amount, 0) - coalesce(invoice.paid_amount, 0)
          )
        )
      ),
      0
    ) as balance
  from public.fee_invoices invoice
  where invoice.school_id = p_school_id
    and invoice.student_id = any(p_student_ids)
    and lower(coalesce(invoice.status, '')) not in ('cancelled', 'canceled', 'void')
  group by invoice.student_id;
$function$
```

### `schooldesk_parent_homework_due`

```sql
CREATE OR REPLACE FUNCTION public.schooldesk_parent_homework_due(p_school_id uuid, p_student_ids uuid[])
 RETURNS TABLE(student_id uuid, due_count integer)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  with student_scope as (
    select id as student_id, current_section_id
    from public.students
    where school_id = p_school_id
      and id = any(p_student_ids)
      and lower(coalesce(status, '')) = 'active'
  ),
  homework_rows as (
    select
      coalesce(
        nullif(data->>'homework_id', ''),
        nullif(data->>'id', ''),
        record_id::text,
        id::text
      ) as homework_key,
      coalesce(nullif(data->>'student_id', ''), '') as target_student_id,
      coalesce(nullif(data->>'section_id', ''), '') as target_section_id
    from public.frontend_records
    where school_id = p_school_id
      and table_name = 'homework'
  ),
  latest_submissions as (
    select distinct on (submission.homework_id::text, submission.student_id)
      submission.homework_id::text as homework_key,
      submission.student_id,
      lower(coalesce(submission.status, '')) as status
    from public.homework_submissions submission
    where submission.school_id = p_school_id
      and submission.student_id = any(p_student_ids)
    order by submission.homework_id::text, submission.student_id,
      submission.updated_at desc nulls last,
      submission.created_at desc nulls last
  ),
  matched_homework as (
    select scope.student_id, homework.homework_key
    from student_scope scope
    join homework_rows homework
      on homework.target_student_id = scope.student_id::text
      or (
        homework.target_student_id = ''
        and homework.target_section_id <> ''
        and homework.target_section_id = scope.current_section_id::text
      )
    left join latest_submissions latest
      on latest.homework_key = homework.homework_key
      and latest.student_id = scope.student_id
    where coalesce(latest.status, '') not in ('submitted', 'reviewed')
  )
  select matched_homework.student_id, count(*)::integer as due_count
  from matched_homework
  group by matched_homework.student_id;
$function$
```

## Dependency and usage checks

- Repository-wide text search found no application-code references; only the two prior QA/reconciliation reports mention these names.
- The active production `api` Edge Function is version 277 and `notification-processor` is version 47. All deployed files for both functions were searched; neither calls these RPCs.
- Production `pg_depend` reported no stored-object dependencies; no trigger uses them; no other stored function source references them; no `cron.job` command mentions them.
- `pg_stat_statements` did record the service-role calls listed above. Those calls are why the functions are retained even though the current source inventory does not identify the caller.

**Decision per RPC:** preserve and harden all four as production-used. None is classified as safe to drop. Follow-up still needed to identify the external/older service-role caller and establish a recent last-use window before any future removal proposal.

## Verification after migration

- `npx --yes --package=supabase@2.116.0 supabase db reset --local`: passed; all 141 migrations applied from scratch and both synthetic seed files loaded.
- `supabase migration list --local`: 141 local migrations applied. Production history remains at 140. The previous 140 version IDs are exactly shared; only `20260921043515` is local-only and expected pending promotion.
- Local catalog privilege checks: for all four functions, owner `postgres`, `SECURITY DEFINER=true`, `search_path=""`, `PUBLIC` has no execute grant, and effective privileges are anon=false, authenticated=false, service_role=true.
- Direct execution probes: all 8 calls (four functions as each of `anon` and `authenticated`) failed with permission denied. Service-role execution smoke checks passed for all four.
- Synthetic two-school checks passed: active-profile authorization, dashboard JSON shape for both schools, own-school fee/homework query execution, rejection of another school's student IDs by both parent helpers, and denial of a cross-school teacher authorization.
- Before/after function-body comparison: normalized body hashes match production for all four; normalization removes only explicit `pg_catalog.` qualifiers and whitespace differences.
- Local vs production catalog comparison: equal counts and signatures/digests for 95 public relations, 433 constraints, 325 indexes, 287 policy identities, 73 triggers, 1,758 selected grants to `anon`/`authenticated`/`service_role`, 1,149 semantic column definitions excluding ordinal, and all 43 public routine signatures. The only database catalog difference observed in this pass is the intended empty `search_path` on these four local definitions pending production promotion.
- `staff_subjects` retains the accepted column-order difference: production order places `grade_id` last; local order places it fifth. No table rebuild was performed.
- `supabase db advisors --local --type all`: 19 performance warnings, all `auth_rls_initplan` policy notices; zero advisor findings named these four RPCs and no security finding was reported for them.
- `supabase db push --dry-run --skip-vault --project-ref ouvwogguttybmpgfgctc`: passed as a dry run and listed exactly `20260921043515_reconcile_legacy_schooldesk_rpcs.sql`. It did not push the migration or update Vault.
- No real production push, migration repair, data change, or Storage configuration change was performed.

## Remaining risks and accepted differences

- The RPC caller is unknown. Although calls occurred as `service_role` during the `pg_stat_statements` window, the current active Edge Function sources and repository do not identify the client, and statistics do not expose a last-call timestamp. Keep the RPCs until the owner is identified.
- Production still has the original `search_path=public, pg_temp` definitions until the one pending migration is explicitly promoted. The dry run is ready for review; it was not applied.
- Seven `staff_subjects` columns retain the accepted ordinal difference. Local Storage remains `legacy-compatible` and production Storage remains `r2-configured`.
- Production's four existing service-only helper RPCs (`schooldesk_parent_fee_balances`, `schooldesk_parent_homework_due`, `schooldesk_dashboard_summary`, and `authorize_schooldesk_request`) remain active until that authorized migration is applied; no behavior or response contract changes are included here.
