-- Align student attendance rows with the Supabase API handler and Flutter UI.
-- The runtime upsert writes marked_at and read paths expose marked_at as the
-- visible attendance timestamp.

alter table public.student_attendances
  add column if not exists marked_at timestamptz;

update public.student_attendances
set marked_at = coalesce(marked_at, updated_at, created_at)
where marked_at is null;

create index if not exists idx_student_attendances_marked_at
  on public.student_attendances(marked_at);

notify pgrst, 'reload schema';
