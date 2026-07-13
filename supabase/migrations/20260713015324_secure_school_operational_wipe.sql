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

  -- Discover school-scoped tables from the live schema instead of keeping a
  -- fragile hand-written list.  Rows without school_id are removed by their
  -- foreign-key cascades from the school-scoped parent records.
  for v_table_name in
    select c.relname
    from pg_catalog.pg_attribute a
    join pg_catalog.pg_class c on c.oid = a.attrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and a.attname = 'school_id'
      and a.attnum > 0
      and not a.attisdropped
      and c.relname <> all (v_preserved_tables)
    order by c.relname
  loop
    execute format('delete from public.%I where school_id = $1', v_table_name)
      using p_school_id;
    get diagnostics v_deleted_rows = row_count;
    v_deleted_total := v_deleted_total + v_deleted_rows;
    v_counts := v_counts || jsonb_build_object(v_table_name, v_deleted_rows);
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
