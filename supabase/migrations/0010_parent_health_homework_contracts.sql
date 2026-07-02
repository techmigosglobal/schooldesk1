-- Parent health reminder metadata used by the Flutter health update screen.
alter table public.medical_records
  add column if not exists dosage text,
  add column if not exists reminder_time text,
  add column if not exists notes text,
  add column if not exists is_active boolean not null default true;

create index if not exists idx_medical_records_student_updated
  on public.medical_records(student_id, updated_at desc);

create index if not exists idx_homework_submissions_lookup
  on public.homework_submissions(school_id, homework_id, student_id, created_at desc);
