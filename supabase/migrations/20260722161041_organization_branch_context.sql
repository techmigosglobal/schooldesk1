-- Additive multi-branch foundation. Existing schools remain the data boundary.

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  seed_school_id uuid unique references public.schools(id) on delete set null,
  multi_branch_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.organizations enable row level security;

alter table public.schools
  add column if not exists organization_id uuid references public.organizations(id) on delete restrict,
  add column if not exists branch_code text,
  add column if not exists multi_branch_enabled boolean not null default false;
create index if not exists idx_schools_organization on public.schools(organization_id);

-- Give every existing school its own organization first. This is deliberately
-- non-destructive: data remains attached to its existing school_id.
insert into public.organizations (name, seed_school_id)
select concat(name, ' Organization'), id
from public.schools
on conflict (seed_school_id) do nothing;

update public.schools s
set organization_id = o.id
from public.organizations o
where s.organization_id is null
  and o.seed_school_id = s.id;

alter table public.schools alter column organization_id set not null;

create table if not exists public.branch_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  role_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(user_id, school_id)
);
create index if not exists idx_branch_memberships_user on public.branch_memberships(user_id, is_active);
create index if not exists idx_branch_memberships_school on public.branch_memberships(school_id, is_active);
alter table public.branch_memberships enable row level security;

insert into public.branch_memberships (user_id, school_id, role_name)
select id, school_id, role_name from public.users
on conflict (user_id, school_id) do update
set role_name = excluded.role_name,
    is_active = true;

alter table public.users
  add column if not exists must_change_password boolean not null default false,
  add column if not exists password_reset_at timestamptz;

create or replace function public.can_access_branch(target_school_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users u
    where u.id = auth.uid()
      and u.is_active
      and lower(u.role_name) = 'super_admin'
  ) or exists (
    select 1 from public.branch_memberships bm
    where bm.user_id = auth.uid()
      and bm.school_id = target_school_id
      and bm.is_active
  )
$$;
revoke all on function public.can_access_branch(uuid) from public;
grant execute on function public.can_access_branch(uuid) to authenticated;

create or replace function public.sync_principal_branch_memberships()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_organization uuid;
begin
  if lower(new.role_name) not in ('principal', 'super_admin') or not new.is_active then
    return new;
  end if;
  select organization_id into target_organization from public.schools where id = new.school_id;
  if target_organization is null then return new; end if;
  insert into public.branch_memberships (user_id, school_id, role_name)
  select new.id, s.id, new.role_name
  from public.schools s
  where s.organization_id = target_organization
  on conflict (user_id, school_id) do update
  set role_name = excluded.role_name, is_active = true;
  return new;
end;
$$;

create or replace function public.sync_branch_principals()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.branch_memberships (user_id, school_id, role_name)
  select u.id, new.id, u.role_name
  from public.users u
  join public.schools primary_school on primary_school.id = u.school_id
  where primary_school.organization_id = new.organization_id
    and u.is_active
    and lower(u.role_name) in ('principal', 'super_admin')
  on conflict (user_id, school_id) do update
  set role_name = excluded.role_name, is_active = true;
  return new;
end;
$$;

drop trigger if exists trg_principal_branch_memberships on public.users;
create trigger trg_principal_branch_memberships
after insert or update of role_name, is_active, school_id on public.users
for each row execute function public.sync_principal_branch_memberships();

drop trigger if exists trg_branch_principals on public.schools;
create trigger trg_branch_principals
after insert on public.schools
for each row execute function public.sync_branch_principals();

create policy "branch_memberships_self_select" on public.branch_memberships
  for select to authenticated using (user_id = auth.uid());

notify pgrst, 'reload schema';
