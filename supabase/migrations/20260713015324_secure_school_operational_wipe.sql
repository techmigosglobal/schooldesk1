-- Reset only a school's operational records.  Identity, access control,
-- school branding, help content, and audit/error history intentionally remain.
-- The Edge Function is the only caller and uses the service role; no client
-- role may invoke this SECURITY DEFINER function directly.
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
    'audit_logs',
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

  -- Serialise wipes for a school.  This keeps a second click or concurrent
  -- administrator request from interleaving its deletes with this transaction.
  perform pg_advisory_xact_lock(hashtext('school-operational-wipe:' || p_school_id::text));

  -- 1. Gather all public tables that have school_id and are not preserved
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

  -- 2. Multi-pass deletion loop to resolve foreign key constraints dynamically
  -- Run up to 6 passes to delete dependent tables first
  for i in 1..6 loop
    v_pass_deleted_any := false;
    v_has_remaining_tables := false;

    foreach v_table_name in array v_tables_to_delete loop
      -- Skip tables we already successfully deleted/processed
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
        -- Skip for now, try again in next pass once child tables are deleted
        v_has_remaining_tables := true;
      end;
    end loop;

    -- Break early if we made no progress but still have tables remaining to avoid infinite loops
    if not v_pass_deleted_any and v_has_remaining_tables then
      exit;
    end if;
  end loop;

  -- 3. Final pass: run deletes without exception handling so that any remaining unresolved
  -- constraint errors are raised back to the caller for visibility
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
