-- Deterministic School B fixture for Docker-local tenant-isolation tests.
--
-- This is intentionally a different organization from School A.  Do not add
-- real school records, contacts, or hosted-project data to either local seed.

create extension if not exists pgcrypto;

do $$
declare
  v_organization uuid := '00000000-0000-4000-8000-000000000200';
  v_school uuid := '00000000-0000-4000-8000-000000000201';
  v_year uuid := '00000000-0000-4000-8000-000000000210';
  v_grade uuid := '00000000-0000-4000-8000-000000000220';
  v_room uuid := '00000000-0000-4000-8000-000000000221';
  v_section uuid := '00000000-0000-4000-8000-000000000222';
  v_subject uuid := '00000000-0000-4000-8000-000000000230';
  v_principal_staff uuid := '00000000-0000-4000-8000-000000000240';
  v_admin_staff uuid := '00000000-0000-4000-8000-000000000241';
  v_coordinator_staff uuid := '00000000-0000-4000-8000-000000000242';
  v_teacher_staff uuid := '00000000-0000-4000-8000-000000000243';
  v_student uuid := '00000000-0000-4000-8000-000000000250';
  v_guardian uuid := '00000000-0000-4000-8000-000000000251';
  v_principal_user uuid := '00000000-0000-4000-8000-000000000301';
  v_admin_user uuid := '00000000-0000-4000-8000-000000000302';
  v_coordinator_user uuid := '00000000-0000-4000-8000-000000000303';
  v_teacher_user uuid := '00000000-0000-4000-8000-000000000304';
  v_parent_user uuid := '00000000-0000-4000-8000-000000000305';
  v_kiosk_user uuid := '00000000-0000-4000-8000-000000000306';
begin
  insert into public.organizations (id, name, multi_branch_enabled)
  values (v_organization, 'Local Security Academy B Organization', false)
  on conflict (id) do update set name = excluded.name;

  insert into public.schools (
    id, organization_id, name, school_type, email, timezone, currency,
    principal_name
  )
  values (
    v_school, v_organization, 'Local Security Academy B', 'preschool',
    'principal@school-b.test', 'Asia/Kolkata', 'INR', 'Principal Two'
  )
  on conflict (id) do update set name = excluded.name;

  update public.organizations
  set seed_school_id = v_school
  where id = v_organization;

  insert into public.academic_years (
    id, school_id, year_label, year, start_date, end_date, is_current, status
  )
  values (
    v_year, v_school, '2026-2027', '2026', '2026-04-01', '2027-03-31', true,
    'active'
  )
  on conflict (id) do update set is_current = true, status = 'active';

  -- Keep School B on the same exact Telangana Holiday Calendar 2026-27
  -- fixture so cross-tenant calendar reads can be tested locally.
  insert into public.holidays (
    school_id, academic_year_id, holiday_name, from_date, to_date, type
  )
  select
    v_school, v_year, holiday.holiday_name, holiday.from_date,
    holiday.to_date, holiday.type
  from (values
    ('Muharram (Ashoora)', date '2026-06-26', date '2026-06-26', 'telangana'),
    ('Bonalu', date '2026-08-10', date '2026-08-10', 'telangana'),
    ('Independence Day', date '2026-08-15', date '2026-08-15', 'telangana'),
    ('Varamahalakshmi Vratha', date '2026-08-21', date '2026-08-21', 'telangana'),
    ('Rakhi', date '2026-08-28', date '2026-08-28', 'telangana'),
    ('Krishna Jayanthi', date '2026-09-04', date '2026-09-04', 'telangana'),
    ('Vinayaka Chavithi', date '2026-09-14', date '2026-09-14', 'telangana'),
    ('Vinayaka Nimarjanam', date '2026-09-25', date '2026-09-25', 'telangana'),
    ('Mahatma Gandhi Jayanti', date '2026-10-02', date '2026-10-02', 'telangana'),
    ('Dussehra Holidays', date '2026-10-10', date '2026-10-21', 'telangana'),
    ('Deepawali Holidays', date '2026-11-06', date '2026-11-08', 'telangana'),
    ('Gurunanak Jayanthi', date '2026-11-24', date '2026-11-24', 'telangana'),
    ('Christmas & New Year Holidays', date '2026-12-25', date '2027-01-01', 'telangana'),
    ('Bhogi / Makara Sankranti Holidays', date '2027-01-14', date '2027-01-16', 'telangana'),
    ('Republic Day', date '2027-01-26', date '2027-01-26', 'telangana'),
    ('Vasant Panchami', date '2027-02-11', date '2027-02-11', 'telangana'),
    ('Maha Shivaratri', date '2027-03-06', date '2027-03-06', 'telangana'),
    ('Ramzan Id (Tentative Date)', date '2027-03-10', date '2027-03-10', 'telangana'),
    ('Holi', date '2027-03-22', date '2027-03-22', 'telangana'),
    ('Good Friday', date '2027-03-26', date '2027-03-26', 'telangana'),
    ('Gudi Padwa', date '2027-04-07', date '2027-04-07', 'telangana'),
    ('Ambedkar Jayanthi', date '2027-04-14', date '2027-04-14', 'telangana'),
    ('Rama Navami', date '2027-04-15', date '2027-04-15', 'telangana'),
    ('Mahaveer Jayanthi', date '2027-04-19', date '2027-04-19', 'telangana')
  ) as holiday(holiday_name, from_date, to_date, type)
  where not exists (
    select 1 from public.holidays existing
    where existing.school_id = v_school
      and existing.academic_year_id = v_year
      and existing.holiday_name = holiday.holiday_name
      and existing.from_date = holiday.from_date
      and existing.to_date = holiday.to_date
  );

  insert into public.grades (id, school_id, grade_number, grade_name)
  values (v_grade, v_school, 1, 'Class 1')
  on conflict (id) do update set grade_name = excluded.grade_name;

  insert into public.rooms (
    id, school_id, room_number, room_type, capacity, is_active
  )
  values (v_room, v_school, 'B-101', 'classroom', 30, true)
  on conflict (id) do update set capacity = excluded.capacity;

  insert into public.subjects (
    id, school_id, subject_name, subject_code, subject_type, subject_color,
    is_active
  )
  values (v_subject, v_school, 'Language', 'LANG-B-1', 'core', '#7C3AED', true)
  on conflict (id) do update set subject_name = excluded.subject_name;

  insert into public.staff (
    id, school_id, first_name, last_name, staff_code, email, phone,
    designation, account_role, is_active
  )
  values
    (v_principal_staff, v_school, 'Principal', 'Two', 'PRI-B-001', 'principal@school-b.test', '0000000101', 'Principal', 'principal', true),
    (v_admin_staff, v_school, 'Admin', 'Two', 'ADM-B-001', 'admin@school-b.test', '0000000102', 'Administrator', 'admin', true),
    (v_coordinator_staff, v_school, 'Coordinator', 'Two', 'COO-B-001', 'coordinator@school-b.test', '0000000103', 'Coordinator', 'coordinator', true),
    (v_teacher_staff, v_school, 'Teacher', 'Two', 'TCH-B-001', 'teacher@school-b.test', '0000000104', 'Class Teacher', 'teacher', true)
  on conflict (id) do update
  set first_name = excluded.first_name,
      account_role = excluded.account_role,
      is_active = true;

  insert into public.sections (
    id, school_id, grade_id, academic_year_id, section_name, capacity,
    class_teacher_id, room_id
  )
  values (v_section, v_school, v_grade, v_year, 'B', 30, v_teacher_staff, v_room)
  on conflict (id) do update set class_teacher_id = excluded.class_teacher_id;

  insert into public.grade_subjects (
    school_id, academic_year_id, grade_id, section_id, subject_id,
    periods_per_week, is_mandatory, is_primary
  )
  values (v_school, v_year, v_grade, v_section, v_subject, 5, true, true)
  on conflict do nothing;

  insert into public.staff_subjects (
    id, school_id, staff_id, subject_id, grade_id, section_id,
    academic_year_id, is_primary, periods_per_week
  )
  values (
    '00000000-0000-4000-8000-000000000231', v_school, v_teacher_staff,
    v_subject, v_grade, v_section, v_year, true, 5
  )
  on conflict (id) do update set staff_id = excluded.staff_id;

  insert into public.students (
    id, school_id, first_name, last_name, admission_number, student_id_number,
    date_of_birth, gender, admission_date, current_section_id, status,
    is_test_account
  )
  values (
    v_student, v_school, 'Learner', 'Two', 'ADM-B-001', 'STU-B-001',
    '2020-07-16', 'other', '2026-04-01', v_section, 'active', true
  )
  on conflict (id) do update
  set current_section_id = excluded.current_section_id,
      is_test_account = true;

  insert into public.enrollments (
    school_id, student_id, section_id, academic_year_id, roll_number, status
  )
  values (v_school, v_student, v_section, v_year, '1', 'active')
  on conflict do nothing;

  insert into public.guardians (
    id, school_id, student_id, full_name, relationship, phone, email,
    is_primary
  )
  values (
    v_guardian, v_school, v_student, 'Guardian Two', 'parent', '0000000105',
    'parent@school-b.test', true
  )
  on conflict (id) do update set full_name = excluded.full_name;

  insert into public.student_guardians (student_id, guardian_id)
  values (v_student, v_guardian)
  on conflict do nothing;

  insert into public.medical_records (
    student_id, blood_group, allergies, conditions, medications,
    emergency_contact
  )
  values (v_student, 'A+', 'None', 'None', 'None', '0000000105')
  on conflict do nothing;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  )
  values
    ('00000000-0000-0000-0000-000000000000', v_principal_user, 'authenticated', 'authenticated', 'principal@school-b.test', crypt('SecondPrincipal@12345', gen_salt('bf')), now(), jsonb_build_object('provider', 'email', 'providers', array['email'], 'school_id', v_school, 'role_name', 'principal', 'linked_id', v_principal_staff), '{"name":"Principal Two"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_admin_user, 'authenticated', 'authenticated', 'admin@school-b.test', crypt('SecondAdmin@12345', gen_salt('bf')), now(), jsonb_build_object('provider', 'email', 'providers', array['email'], 'school_id', v_school, 'role_name', 'admin', 'linked_id', v_admin_staff), '{"name":"Admin Two"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_coordinator_user, 'authenticated', 'authenticated', 'coordinator@school-b.test', crypt('SecondCoordinator@12345', gen_salt('bf')), now(), jsonb_build_object('provider', 'email', 'providers', array['email'], 'school_id', v_school, 'role_name', 'coordinator', 'linked_id', v_coordinator_staff), '{"name":"Coordinator Two"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_teacher_user, 'authenticated', 'authenticated', 'teacher@school-b.test', crypt('SecondTeacher@12345', gen_salt('bf')), now(), jsonb_build_object('provider', 'email', 'providers', array['email'], 'school_id', v_school, 'role_name', 'teacher', 'linked_id', v_teacher_staff), '{"name":"Teacher Two"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_parent_user, 'authenticated', 'authenticated', 'parent@school-b.test', crypt('SecondParent@12345', gen_salt('bf')), now(), jsonb_build_object('provider', 'email', 'providers', array['email'], 'school_id', v_school, 'role_name', 'parent', 'linked_id', v_guardian), '{"name":"Guardian Two"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_kiosk_user, 'authenticated', 'authenticated', 'kiosk@school-b.test', crypt('SecondKiosk@12345', gen_salt('bf')), now(), jsonb_build_object('provider', 'email', 'providers', array['email'], 'school_id', v_school, 'role_name', 'kiosk'), '{"name":"Kiosk Two"}', now(), now(), '', '', '', '')
  on conflict (id) do update
  set encrypted_password = excluded.encrypted_password,
      raw_app_meta_data = excluded.raw_app_meta_data,
      updated_at = now();

  insert into auth.identities (
    id, provider_id, user_id, identity_data, provider, last_sign_in_at,
    created_at, updated_at
  )
  select
    id, id, id, jsonb_build_object('sub', id, 'email', email), 'email', now(),
    now(), now()
  from auth.users
  where id in (
    v_principal_user, v_admin_user, v_coordinator_user, v_teacher_user,
    v_parent_user, v_kiosk_user
  )
  on conflict (provider, provider_id) do nothing;

  insert into public.users (
    id, school_id, username, name, email, phone, role_name, linked_type,
    linked_id, is_active, is_verified
  )
  values
    (v_principal_user, v_school, 'second-principal', 'Principal Two', 'principal@school-b.test', '0000000101', 'principal', 'principal', v_principal_staff, true, true),
    (v_admin_user, v_school, 'second-admin', 'Admin Two', 'admin@school-b.test', '0000000102', 'admin', 'staff', v_admin_staff, true, true),
    (v_coordinator_user, v_school, 'second-coordinator', 'Coordinator Two', 'coordinator@school-b.test', '0000000103', 'coordinator', 'staff', v_coordinator_staff, true, true),
    (v_teacher_user, v_school, 'second-teacher', 'Teacher Two', 'teacher@school-b.test', '0000000104', 'teacher', 'staff', v_teacher_staff, true, true),
    (v_parent_user, v_school, 'second-parent', 'Guardian Two', 'parent@school-b.test', '0000000105', 'parent', 'guardian', v_guardian, true, true),
    (v_kiosk_user, v_school, 'second-kiosk', 'Kiosk Two', 'kiosk@school-b.test', '0000000106', 'kiosk', null, null, true, true)
  on conflict (id) do update
  set username = excluded.username,
      role_name = excluded.role_name,
      linked_type = excluded.linked_type,
      linked_id = excluded.linked_id,
      is_active = true,
      is_verified = true;

  insert into public.username_aliases (username, auth_user_id, school_id)
  values
    ('second-principal', v_principal_user, v_school),
    ('second-admin', v_admin_user, v_school),
    ('second-coordinator', v_coordinator_user, v_school),
    ('second-teacher', v_teacher_user, v_school),
    ('second-parent', v_parent_user, v_school),
    ('second-kiosk', v_kiosk_user, v_school)
  on conflict (username) do update set auth_user_id = excluded.auth_user_id;

  insert into public.parent_student_links (school_id, parent_user_id, student_id)
  values (v_school, v_parent_user, v_student)
  on conflict (parent_user_id, student_id) do nothing;
end $$;
