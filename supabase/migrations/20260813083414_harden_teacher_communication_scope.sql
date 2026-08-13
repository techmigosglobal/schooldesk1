-- Teacher scope checks are school/staff scoped on every request. This index
-- avoids repeated broad scans while retaining existing foreign-key indexes
-- for other access patterns.
create index if not exists idx_staff_subjects_school_staff_scope
  on public.staff_subjects (school_id, staff_id, academic_year_id, section_id);
