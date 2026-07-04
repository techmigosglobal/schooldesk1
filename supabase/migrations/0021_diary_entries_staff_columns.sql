-- Add missing columns to diary_entries that are referenced by the backend API
-- The original table only had: id, school_id, section_id, student_id, date, subject, content, created_by, created_at

alter table public.diary_entries
  add column if not exists staff_id     uuid references public.staff(id) on delete set null,
  add column if not exists teacher_id   uuid references public.staff(id) on delete set null,
  add column if not exists entry_date   text,
  add column if not exists entry_type   text,
  add column if not exists type         text,
  add column if not exists class        text,
  add column if not exists title        text,
  add column if not exists homework     text,
  add column if not exists notes        text,
  add column if not exists updated_at   timestamptz not null default now();

-- Index for fast lookup by school + staff
create index if not exists idx_diary_entries_school_staff
  on public.diary_entries(school_id, staff_id, date desc);

create index if not exists idx_diary_entries_school_section
  on public.diary_entries(school_id, section_id, date desc);
