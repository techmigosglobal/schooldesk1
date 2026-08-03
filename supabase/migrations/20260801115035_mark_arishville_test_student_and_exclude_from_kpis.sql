-- Keep test accounts in the database for login and QA, but do not include them
-- in operational student totals. Production roster queries can opt in with
-- include_test_accounts=true when the test record is needed.
alter table public.students
  add column if not exists is_test_account boolean not null default false;

create index if not exists idx_students_school_test_account
  on public.students(school_id, is_test_account);

update public.students
set is_test_account = true,
    updated_at = now()
where school_id = 'b3409710-78ac-446d-b8f5-45c58d72a004'
  and student_id_number = '098';
