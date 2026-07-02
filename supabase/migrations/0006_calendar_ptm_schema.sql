-- ============================================================
-- Migration 0006: Calendar events and PTM availability
-- ============================================================

create table public.events (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  academic_year_id uuid not null references public.academic_years(id) on delete cascade,
  event_title      text not null,
  event_name       text,
  event_type       text not null default 'event',
  description      text,
  venue            text,
  location         text,
  audience_type    text not null default 'all',
  status           text not null default 'scheduled',
  is_holiday       boolean not null default false,
  start_date       date,
  end_date         date,
  start_time       text,
  end_time         text,
  event_date       timestamptz,
  start_datetime   timestamptz,
  end_datetime     timestamptz,
  created_by       uuid references public.users(id) on delete set null,
  updated_by       uuid references public.users(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index idx_events_school_dates on public.events(
  school_id,
  academic_year_id,
  start_date,
  start_datetime
);
alter table public.events enable row level security;

create table public.parent_teacher_meetings (
  id                       uuid primary key default uuid_generate_v4(),
  school_id                uuid not null references public.schools(id) on delete cascade,
  academic_year_id         uuid references public.academic_years(id) on delete set null,
  event_id                 uuid references public.events(id) on delete set null,
  section_id               uuid references public.sections(id) on delete set null,
  teacher_id               uuid references public.staff(id) on delete set null,
  guardian_id              uuid references public.guardians(id) on delete set null,
  student_id               uuid references public.students(id) on delete set null,
  booked_by_parent_user_id uuid references public.users(id) on delete set null,
  slot_date                date not null,
  slot_time                text not null,
  duration_min             int not null default 15,
  status                   text not null default 'available',
  notes                    text,
  created_by               uuid references public.users(id) on delete set null,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);
create index idx_ptm_school_slot on public.parent_teacher_meetings(
  school_id,
  slot_date,
  slot_time
);
alter table public.parent_teacher_meetings enable row level security;

create policy "events_school_select" on public.events
  for select to authenticated using (school_id = public.auth_school_id());
create policy "events_school_insert" on public.events
  for insert to authenticated with check (school_id = public.auth_school_id());
create policy "events_school_update" on public.events
  for update to authenticated
  using (school_id = public.auth_school_id())
  with check (school_id = public.auth_school_id());
create policy "events_school_delete" on public.events
  for delete to authenticated using (school_id = public.auth_school_id());

create policy "parent_teacher_meetings_school_select" on public.parent_teacher_meetings
  for select to authenticated using (school_id = public.auth_school_id());
create policy "parent_teacher_meetings_school_insert" on public.parent_teacher_meetings
  for insert to authenticated with check (school_id = public.auth_school_id());
create policy "parent_teacher_meetings_school_update" on public.parent_teacher_meetings
  for update to authenticated
  using (school_id = public.auth_school_id())
  with check (school_id = public.auth_school_id());
create policy "parent_teacher_meetings_school_delete" on public.parent_teacher_meetings
  for delete to authenticated using (school_id = public.auth_school_id());
