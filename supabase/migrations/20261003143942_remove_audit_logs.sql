-- Remove the audit-log product and its retained data.  Error-event diagnostics,
-- session tracking, payment records, and approval state remain independent.

drop trigger if exists approval_requests_audit_decision on public.approval_requests;
drop trigger if exists account_approvals_audit_decision on public.account_approvals;
drop trigger if exists leave_applications_audit_decision on public.leave_applications;
drop trigger if exists student_leave_applications_audit_decision on public.student_leave_applications;
drop trigger if exists fee_concessions_audit_decision on public.fee_concessions;
drop trigger if exists parent_payment_requests_audit_decision on public.parent_payment_requests;
drop trigger if exists event_posts_audit_decision on public.event_posts;

drop function if exists public.record_approval_decision_audit();

drop table if exists public.audit_logs cascade;

-- Remove Help entries that point users to the retired audit-log screens.
delete from public.help_contents
where question = 'How do I access school-wide audit logs?'
   or action_route in (
     '/principal-audit-logs-screen',
     '/super-admin-audit-logs-screen'
   );

-- The operational wipe function discovers school-owned tables dynamically;
-- keep its preserved-table response truthful now that audit_logs is gone.
create or replace function public.wipe_school_operational_data(
  p_school_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_table_name text;
  v_deleted_rows integer;
  v_deleted_total integer := 0;
  v_counts jsonb := '{}'::jsonb;
  v_preserved_tables constant text[] := array[
    'account_approvals',
    'error_events',
    'help_contents',
    'notification_devices',
    'notification_preferences',
    'notification_subscriptions',
    'permissions',
    'roles',
    'schools',
    'users',
    'username_aliases'
  ];
  v_tables_to_delete text[];
  v_has_remaining_tables boolean;
  v_pass_deleted_any boolean;
begin
  if p_school_id is null then
    raise exception 'A school id is required for a data wipe';
  end if;

  if not exists (select 1 from public.schools where id = p_school_id) then
    raise exception 'The selected school does not exist';
  end if;

  perform pg_advisory_xact_lock(hashtext('school-operational-wipe:' || p_school_id::text));

  select array_agg(c.relname)
    into v_tables_to_delete
  from pg_catalog.pg_attribute a
  join pg_catalog.pg_class c on c.oid = a.attrelid
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r', 'p')
    and a.attname = 'school_id'
    and a.attnum > 0
    and not a.attisdropped
    and c.relname <> all (v_preserved_tables);

  for i in 1..6 loop
    v_pass_deleted_any := false;
    v_has_remaining_tables := false;

    foreach v_table_name in array v_tables_to_delete loop
      if v_counts ? v_table_name then
        continue;
      end if;

      begin
        execute format('delete from public.%I where school_id = $1', v_table_name)
          using p_school_id;
        get diagnostics v_deleted_rows = row_count;
        v_deleted_total := v_deleted_total + v_deleted_rows;
        v_counts := v_counts || jsonb_build_object(v_table_name, v_deleted_rows);
        v_pass_deleted_any := true;
      exception when foreign_key_violation then
        v_has_remaining_tables := true;
      end;
    end loop;

    if not v_pass_deleted_any and v_has_remaining_tables then
      exit;
    end if;
  end loop;

  foreach v_table_name in array v_tables_to_delete loop
    if not (v_counts ? v_table_name) then
      execute format('delete from public.%I where school_id = $1', v_table_name)
        using p_school_id;
      get diagnostics v_deleted_rows = row_count;
      v_deleted_total := v_deleted_total + v_deleted_rows;
      v_counts := v_counts || jsonb_build_object(v_table_name, v_deleted_rows);
    end if;
  end loop;

  return jsonb_build_object(
    'deleted_rows', v_deleted_total,
    'table_counts', v_counts,
    'preserved', v_preserved_tables
  );
end;
$$;

revoke all on function public.wipe_school_operational_data(uuid) from public;
revoke all on function public.wipe_school_operational_data(uuid) from anon;
revoke all on function public.wipe_school_operational_data(uuid) from authenticated;
grant execute on function public.wipe_school_operational_data(uuid) to service_role;
