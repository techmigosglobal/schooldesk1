create table if not exists public.school_calendar_preferences (
  school_id uuid primary key references public.schools(id) on delete cascade,
  hide_generated_holidays boolean not null default false,
  updated_by uuid references public.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.school_calendar_preferences enable row level security;

create policy "school_calendar_preferences_school_select"
  on public.school_calendar_preferences for select to authenticated
  using (school_id = public.auth_school_id());

create policy "school_calendar_preferences_school_write"
  on public.school_calendar_preferences for all to authenticated
  using (school_id = public.auth_school_id())
  with check (school_id = public.auth_school_id());
