-- ============================================================
-- Migration 0012: Teacher Attendance Runtime Alignment
-- Aligns Supabase attendance rows with the Flutter teacher workflow.
-- ============================================================

alter table public.attendance_sessions
  add column if not exists status text not null default 'draft',
  add column if not exists submitted_at timestamptz,
  add column if not exists reopened_at timestamptz,
  add column if not exists reopened_by uuid references public.users(id) on delete set null,
  add column if not exists reopen_reason text,
  add column if not exists correction_reason text,
  add column if not exists correction_asked_at timestamptz,
  add column if not exists corrected_at timestamptz;

update public.attendance_sessions
set status = case when is_finalized then 'submitted' else status end
where status is null or status = 'draft';

alter table public.student_attendances
  add column if not exists enrollment_id uuid references public.enrollments(id) on delete set null,
  add column if not exists reason text;

update public.student_attendances
set reason = remarks
where reason is null and remarks is not null;

create index if not exists idx_student_attendances_enrollment
  on public.student_attendances(enrollment_id);

create index if not exists idx_attendance_sessions_staff_date
  on public.attendance_sessions(staff_id, date);
