-- Link teacher-subject assignments directly to class names.
-- In the app, "grade" means the class name (for example Grade 1 / Class 1).

alter table public.staff_subjects
  add column if not exists grade_id uuid references public.grades(id) on delete cascade;

update public.staff_subjects ss
set grade_id = sections.grade_id
from public.sections sections
where ss.grade_id is null
  and ss.section_id = sections.id;

create index if not exists idx_staff_subjects_grade
  on public.staff_subjects(grade_id, academic_year_id);
