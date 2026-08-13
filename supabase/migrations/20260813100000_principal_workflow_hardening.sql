-- Principal workflow hardening: academic-year invariants and teacher daily claims.

create or replace function public.guard_academic_year_invariants()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    if exists (
      select 1
      from public.academic_years existing
      where existing.school_id = new.school_id
        and lower(trim(existing.year_label)) = lower(trim(new.year_label))
        and existing.id <> new.id
    ) then
      raise exception using
        errcode = '23505',
        message = 'academic year label already exists for this school';
    end if;
  elsif new.school_id is distinct from old.school_id or
      new.year_label is distinct from old.year_label then
    if exists (
    select 1
    from public.academic_years existing
    where existing.school_id = new.school_id
      and lower(trim(existing.year_label)) = lower(trim(new.year_label))
      and existing.id <> new.id
    ) then
      raise exception using
        errcode = '23505',
        message = 'academic year label already exists for this school';
    end if;
  end if;

  if new.is_current then
    update public.academic_years
    set is_current = false,
        updated_at = now()
    where school_id = new.school_id
      and id <> new.id
      and is_current = true;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_academic_year_invariants
on public.academic_years;
create trigger trg_guard_academic_year_invariants
before insert or update of school_id, year_label, is_current
on public.academic_years
for each row execute function public.guard_academic_year_invariants();

create unique index if not exists uq_academic_years_school_label_ci
  on public.academic_years(school_id, lower(trim(year_label)));
create unique index if not exists uq_academic_years_one_current_per_school
  on public.academic_years(school_id)
  where is_current = true;

create table if not exists public.class_daily_operation_claims (
  id uuid primary key default uuid_generate_v4(),
  school_id uuid not null references public.schools(id) on delete cascade,
  academic_year_id uuid not null references public.academic_years(id) on delete cascade,
  section_id uuid not null references public.sections(id) on delete cascade,
  operation text not null check (operation in ('attendance', 'homework')),
  operation_date date not null,
  claimed_by_staff_id uuid not null references public.staff(id) on delete restrict,
  status text not null default 'claimed' check (status in ('claimed', 'reopened')),
  claimed_at timestamptz not null default now(),
  reopened_at timestamptz,
  reopened_by uuid references public.users(id) on delete set null,
  reopen_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, academic_year_id, section_id, operation, operation_date)
);

create index if not exists idx_daily_claims_section_date
  on public.class_daily_operation_claims(school_id, section_id, operation_date);
create index if not exists idx_daily_claims_staff
  on public.class_daily_operation_claims(school_id, claimed_by_staff_id);

alter table public.class_daily_operation_claims enable row level security;
drop policy if exists class_daily_claims_service_role on public.class_daily_operation_claims;
create policy class_daily_claims_service_role
on public.class_daily_operation_claims
for all to service_role
using (true)
with check (true);

drop trigger if exists trg_class_daily_operation_claims_updated_at
on public.class_daily_operation_claims;
create trigger trg_class_daily_operation_claims_updated_at
before update on public.class_daily_operation_claims
for each row execute function public.set_updated_at();
