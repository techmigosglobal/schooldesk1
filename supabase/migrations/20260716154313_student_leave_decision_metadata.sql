alter table public.student_leave_applications
  add column if not exists rejection_reason text,
  add column if not exists decided_at timestamptz;

comment on column public.student_leave_applications.rejection_reason is
  'Reason supplied by the principal when a student leave request is rejected.';

comment on column public.student_leave_applications.decided_at is
  'Timestamp of the latest principal approval or rejection decision.';
