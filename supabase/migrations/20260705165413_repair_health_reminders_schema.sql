-- Repair health reminder storage on environments where migration history
-- says the feature exists but the underlying table/columns are missing.

create table if not exists public.health_reminders (
  id uuid primary key default uuid_generate_v4(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  created_by_parent_user_id uuid not null references public.users(id) on delete cascade,
  reminder_date date not null default current_date,
  condition text,
  medication text,
  dosage text,
  reminder_time text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.health_reminders enable row level security;

create index if not exists idx_health_reminders_student_date
  on public.health_reminders(student_id, reminder_date desc, created_at desc);

create index if not exists idx_health_reminders_school_date
  on public.health_reminders(school_id, reminder_date desc, created_at desc);

drop policy if exists "health_reminders_school_select" on public.health_reminders;
create policy "health_reminders_school_select" on public.health_reminders
  for select to authenticated
  using (
    school_id = public.auth_school_id()
    and (
      public.is_admin_or_principal()
      or created_by_parent_user_id = auth.uid()
      or exists (
        select 1
        from public.parent_student_links psl
        where psl.student_id = health_reminders.student_id
          and psl.parent_user_id = auth.uid()
      )
    )
  );

drop policy if exists "health_reminders_parent_insert" on public.health_reminders;
create policy "health_reminders_parent_insert" on public.health_reminders
  for insert to authenticated
  with check (
    school_id = public.auth_school_id()
    and created_by_parent_user_id = auth.uid()
    and exists (
      select 1
      from public.parent_student_links psl
      where psl.school_id = health_reminders.school_id
        and psl.student_id = health_reminders.student_id
        and psl.parent_user_id = auth.uid()
    )
  );

alter table public.notification_logs
  add column if not exists target_role text,
  add column if not exists route text,
  add column if not exists priority text not null default 'medium',
  add column if not exists student_id uuid references public.students(id) on delete set null,
  add column if not exists section_id uuid references public.sections(id) on delete set null,
  add column if not exists teacher_id uuid references public.staff(id) on delete set null;

create index if not exists idx_notification_logs_target_role
  on public.notification_logs(target_role, created_at desc);

create index if not exists idx_notification_logs_entity
  on public.notification_logs(entity_type, entity_id, created_at desc);

with ranked as (
  select
    id,
    row_number() over (
      partition by user_id, entity_type, entity_id
      order by created_at desc, id desc
    ) as rn
  from public.notification_logs
  where user_id is not null
    and entity_type is not null
    and entity_id is not null
)
delete from public.notification_logs logs
using ranked
where logs.id = ranked.id
  and ranked.rn > 1;

create unique index if not exists uniq_notification_logs_entity_recipient
  on public.notification_logs(user_id, entity_type, entity_id);

notify pgrst, 'reload schema';
notify pgrst, 'reload config';
