-- Keep local RLS helper definitions aligned with the hardened production
-- versions: stable JWT reads are init-plan friendly and use an explicit path.

create or replace function public.auth_role_name()
returns text
language sql
stable
set search_path = pg_catalog, auth, public
as $$
  select (select auth.jwt()) -> 'app_metadata' ->> 'role_name'
$$;

create or replace function public.auth_school_id()
returns uuid
language sql
stable
set search_path = pg_catalog, auth, public
as $$
  select nullif(
    ((select auth.jwt()) -> 'app_metadata' ->> 'school_id'),
    ''
  )::uuid
$$;

create or replace function public.is_admin_or_principal()
returns boolean
language sql
stable
set search_path = pg_catalog, auth, public
as $$
  select (select public.auth_role_name()) in ('admin', 'principal', 'super_admin')
$$;
