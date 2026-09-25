-- Keep guardian forms and attendance-session summaries aligned with the API.
-- Existing financial and attendance history remains intact.

alter table public.guardians
  add column if not exists annual_income numeric(14, 2),
  add column if not exists can_pickup boolean not null default false;

alter table public.attendance_sessions
  add column if not exists total_students integer not null default 0,
  add column if not exists present_count integer not null default 0;

-- Rebuild counts from stored attendance and the current active roster. Existing
-- sessions predate these fields, so never report fewer students than were
-- already marked present in the session.
update public.attendance_sessions session
set total_students = greatest(
      coalesce((
        select count(*)
        from public.students student
        where student.school_id = session.school_id
          and student.current_section_id = session.section_id
          and lower(trim(coalesce(student.status, ''))) = 'active'
      ), 0),
      coalesce((
        select count(*)
        from public.student_attendances attendance
        where attendance.session_id = session.id
      ), 0)
    ),
    present_count = coalesce((
      select count(*)
      from public.student_attendances attendance
      where attendance.session_id = session.id
        and lower(trim(attendance.status)) in ('present', 'p')
    ), 0);

notify pgrst, 'reload schema';
