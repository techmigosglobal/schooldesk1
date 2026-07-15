-- Deletes all school-scoped data except the school profile/branding and one or
-- more retained login identities (principal and Super Admin). The Edge
-- Function provides verified ids from both public.users and Auth app_metadata.
create or replace function public.wipe_school_data(
  p_school_id uuid,
  p_retained_user_ids uuid[]
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
  v_retained_user_ids uuid[];
  v_preserved_tables constant text[] := array[
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

  perform pg_advisory_xact_lock(hashtext('school-full-wipe:' || p_school_id::text));

  select coalesce(array_agg(distinct u.id), '{}'::uuid[])
    into v_retained_user_ids
  from public.users u
  where u.school_id = p_school_id
    and (
      lower(u.role_name) in ('principal', 'super_admin')
      or u.id = any(coalesce(p_retained_user_ids, '{}'::uuid[]))
    );

  if cardinality(v_retained_user_ids) = 0 then
    raise exception 'Wipe blocked: this school has no principal login to preserve';
  end if;

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

  delete from public.username_aliases
    where school_id = p_school_id
      and auth_user_id <> all(v_retained_user_ids);
  get diagnostics v_deleted_rows = row_count;
  v_deleted_total := v_deleted_total + v_deleted_rows;
  v_counts := v_counts || jsonb_build_object('username_aliases', v_deleted_rows);

  delete from public.users
    where school_id = p_school_id
      and id <> all(v_retained_user_ids);
  get diagnostics v_deleted_rows = row_count;
  v_deleted_total := v_deleted_total + v_deleted_rows;
  v_counts := v_counts || jsonb_build_object('users', v_deleted_rows);

  return jsonb_build_object(
    'deleted_rows', v_deleted_total,
    'table_counts', v_counts,
    'retained_login_accounts', cardinality(v_retained_user_ids)
  );
end;
$$;

revoke all on function public.wipe_school_data(uuid, uuid[]) from public;
revoke all on function public.wipe_school_data(uuid, uuid[]) from anon;
revoke all on function public.wipe_school_data(uuid, uuid[]) from authenticated;
grant execute on function public.wipe_school_data(uuid, uuid[]) to service_role;
