-- Deterministic School A fixture for Docker-local QA only.
--
-- `seed_local_security.sql` adds a distinct School B fixture.  Keep both
-- files synthetic: they are reset-only test data and must never be exported
-- to, or derived from, a hosted project.

create extension if not exists pgcrypto;

do $$
declare
  v_organization uuid := '00000000-0000-4000-8000-000000000000';
  v_school uuid := '00000000-0000-4000-8000-000000000001';
  v_year uuid := '00000000-0000-4000-8000-000000000010';
  v_term uuid := '00000000-0000-4000-8000-000000000011';
  v_grade uuid := '00000000-0000-4000-8000-000000000020';
  v_room uuid := '00000000-0000-4000-8000-000000000021';
  v_section uuid := '00000000-0000-4000-8000-000000000022';
  v_subject uuid := '00000000-0000-4000-8000-000000000030';
  v_teacher_staff uuid := '00000000-0000-4000-8000-000000000040';
  v_admin_staff uuid := '00000000-0000-4000-8000-000000000041';
  v_coordinator_staff uuid := '00000000-0000-4000-8000-000000000042';
  v_principal_staff uuid := '00000000-0000-4000-8000-000000000043';
  v_student uuid := '00000000-0000-4000-8000-000000000050';
  v_guardian uuid := '00000000-0000-4000-8000-000000000051';
  v_principal_user uuid := '00000000-0000-4000-8000-000000000101';
  v_admin_user uuid := '00000000-0000-4000-8000-000000000102';
  v_teacher_user uuid := '00000000-0000-4000-8000-000000000103';
  v_parent_user uuid := '00000000-0000-4000-8000-000000000104';
  v_student_user uuid := '00000000-0000-4000-8000-000000000105';
  v_kiosk_user uuid := '00000000-0000-4000-8000-000000000106';
  v_superadmin_user uuid := '00000000-0000-4000-8000-000000000107';
  v_coordinator_user uuid := '00000000-0000-4000-8000-000000000108';
  v_attendance_session uuid := '00000000-0000-4000-8000-000000000060';
  v_fee_category uuid := '00000000-0000-4000-8000-000000000070';
  v_fee_structure uuid := '00000000-0000-4000-8000-000000000071';
  v_invoice uuid := '00000000-0000-4000-8000-000000000072';
  v_payment_request uuid := '00000000-0000-4000-8000-000000000073';
  v_leave_type uuid := '00000000-0000-4000-8000-000000000080';
  v_conversation uuid := '00000000-0000-4000-8000-000000000090';
begin
  insert into public.organizations (id, name, multi_branch_enabled)
  values (v_organization, 'Local Security Academy A Organization', false)
  on conflict (id) do update set name = excluded.name;

  insert into public.schools (id, organization_id, name, school_type, email, timezone, currency, principal_name)
  values (v_school, v_organization, 'Local Security Academy A', 'preschool', 'principal@school-a.test', 'Asia/Kolkata', 'INR', 'Principal One')
  on conflict (id) do update set name = excluded.name;

  update public.organizations
  set seed_school_id = v_school
  where id = v_organization;

  insert into public.academic_years (id, school_id, year_label, year, start_date, end_date, is_current, status)
  values (v_year, v_school, '2026-2027', '2026', '2026-04-01', '2027-03-31', true, 'active')
  on conflict (id) do update set is_current = true, status = 'active';

  -- Exact Telangana Holiday Calendar 2026-27 from the supplied PDF. Keep
  -- holidays in their own table so they do not create event notifications.
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

  insert into public.terms (id, academic_year_id, term_number, term_name, start_date, end_date, is_current)
  values (v_term, v_year, 1, 'Term 1', '2026-04-01', '2026-09-30', true)
  on conflict (id) do nothing;

  insert into public.grades (id, school_id, grade_number, grade_name)
  values (v_grade, v_school, 1, 'Class 1')
  on conflict (id) do update set grade_name = excluded.grade_name;

  insert into public.rooms (id, school_id, room_number, room_type, capacity, is_active)
  values (v_room, v_school, 'A-101', 'classroom', 30, true)
  on conflict (id) do update set capacity = excluded.capacity;

  insert into public.subjects (id, school_id, subject_name, subject_code, subject_type, subject_color, is_active)
  values (v_subject, v_school, 'English', 'ENG-1', 'core', '#2563EB', true)
  on conflict (id) do update set subject_name = excluded.subject_name;

  insert into public.staff (id, school_id, first_name, last_name, staff_code, email, phone, designation, account_role, is_active)
  values
    (v_teacher_staff, v_school, 'Teacher', 'One', 'TCH-A-001', 'teacher@school-a.test', '0000000003', 'Class Teacher', 'teacher', true),
    (v_admin_staff, v_school, 'Admin', 'One', 'ADM-A-001', 'admin@school-a.test', '0000000002', 'Administrator', 'admin', true),
    (v_coordinator_staff, v_school, 'Coordinator', 'One', 'COO-A-001', 'coordinator@school-a.test', '0000000008', 'Coordinator', 'coordinator', true),
    (v_principal_staff, v_school, 'Principal', 'One', 'PRI-A-001', 'principal@school-a.test', '0000000001', 'Principal', 'principal', true)
  on conflict (id) do update set first_name = excluded.first_name, account_role = excluded.account_role;

  insert into public.sections (id, school_id, grade_id, academic_year_id, section_name, capacity, class_teacher_id, room_id)
  values (v_section, v_school, v_grade, v_year, 'A', 30, v_teacher_staff, v_room)
  on conflict (id) do update set class_teacher_id = excluded.class_teacher_id;

  insert into public.grade_subjects (school_id, academic_year_id, grade_id, section_id, subject_id, periods_per_week, is_mandatory, is_primary)
  values (v_school, v_year, v_grade, v_section, v_subject, 5, true, true)
  on conflict do nothing;

  insert into public.staff_subjects (id, school_id, staff_id, subject_id, grade_id, section_id, academic_year_id, is_primary, periods_per_week)
  values ('00000000-0000-4000-8000-000000000031', v_school, v_teacher_staff, v_subject, v_grade, v_section, v_year, true, 5)
  on conflict (id) do update set staff_id = excluded.staff_id;

  insert into public.students (id, school_id, first_name, last_name, admission_number, student_id_number, date_of_birth, gender, admission_date, current_section_id, status, is_test_account)
  values (v_student, v_school, 'Learner', 'One', 'ADM-A-001', 'STU-A-001', '2020-06-15', 'other', '2026-04-01', v_section, 'active', true)
  on conflict (id) do update set current_section_id = excluded.current_section_id;

  insert into public.enrollments (school_id, student_id, section_id, academic_year_id, roll_number, status)
  values (v_school, v_student, v_section, v_year, '1', 'active')
  on conflict do nothing;

  insert into public.guardians (id, school_id, student_id, full_name, relationship, phone, email, is_primary)
  values (v_guardian, v_school, v_student, 'Guardian One', 'parent', '0000000004', 'parent@school-a.test', true)
  on conflict (id) do update set full_name = excluded.full_name;

  insert into public.student_guardians (student_id, guardian_id)
  values (v_student, v_guardian)
  on conflict do nothing;

  insert into public.medical_records (student_id, blood_group, allergies, conditions, medications, emergency_contact)
  values (v_student, 'O+', 'None', 'None', 'None', '0000000004')
  on conflict do nothing;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  )
  values
    ('00000000-0000-0000-0000-000000000000', v_principal_user, 'authenticated', 'authenticated', 'principal@school-a.test', crypt('Principal@12345', gen_salt('bf')), now(), jsonb_build_object('provider','email','providers',array['email'],'school_id',v_school,'role_name','principal','linked_id',v_principal_staff), '{"name":"Principal One"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_admin_user, 'authenticated', 'authenticated', 'admin@school-a.test', crypt('Admin@12345', gen_salt('bf')), now(), jsonb_build_object('provider','email','providers',array['email'],'school_id',v_school,'role_name','admin','linked_id',v_admin_staff), '{"name":"Admin One"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_teacher_user, 'authenticated', 'authenticated', 'teacher@school-a.test', crypt('Teacher@12345', gen_salt('bf')), now(), jsonb_build_object('provider','email','providers',array['email'],'school_id',v_school,'role_name','teacher','linked_id',v_teacher_staff), '{"name":"Teacher One"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_parent_user, 'authenticated', 'authenticated', 'parent@school-a.test', crypt('Parent@12345', gen_salt('bf')), now(), jsonb_build_object('provider','email','providers',array['email'],'school_id',v_school,'role_name','parent','linked_id',v_guardian), '{"name":"Guardian One"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_student_user, 'authenticated', 'authenticated', 'student@school-a.test', crypt('Student@12345', gen_salt('bf')), now(), jsonb_build_object('provider','email','providers',array['email'],'school_id',v_school,'role_name','student','linked_id',v_student), '{"name":"Learner One"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_kiosk_user, 'authenticated', 'authenticated', 'kiosk@school-a.test', crypt('Kiosk@12345', gen_salt('bf')), now(), jsonb_build_object('provider','email','providers',array['email'],'school_id',v_school,'role_name','kiosk'), '{"name":"Kiosk One"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_superadmin_user, 'authenticated', 'authenticated', 'superadmin@school-a.test', crypt('SuperAdmin@12345', gen_salt('bf')), now(), jsonb_build_object('provider','email','providers',array['email'],'school_id',v_school,'role_name','super_admin'), '{"name":"Local Super Admin"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_coordinator_user, 'authenticated', 'authenticated', 'coordinator@school-a.test', crypt('Coordinator@12345', gen_salt('bf')), now(), jsonb_build_object('provider','email','providers',array['email'],'school_id',v_school,'role_name','coordinator','linked_id',v_coordinator_staff), '{"name":"Coordinator One"}', now(), now(), '', '', '', '')
  on conflict (id) do update
  set encrypted_password = excluded.encrypted_password,
      raw_app_meta_data = excluded.raw_app_meta_data,
      updated_at = now();

  insert into auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  select id, id, id, jsonb_build_object('sub', id, 'email', email), 'email', now(), now(), now()
  from auth.users
  where id in (v_principal_user, v_admin_user, v_teacher_user, v_parent_user, v_student_user, v_kiosk_user, v_superadmin_user, v_coordinator_user)
  on conflict (provider, provider_id) do nothing;

  insert into public.users (id, school_id, username, name, email, phone, role_name, linked_type, linked_id, is_active, is_verified)
  values
    (v_principal_user, v_school, 'principal', 'Principal One', 'principal@school-a.test', '0000000001', 'principal', 'principal', v_principal_staff, true, true),
    (v_admin_user, v_school, 'admin', 'Admin One', 'admin@school-a.test', '0000000002', 'admin', 'staff', v_admin_staff, true, true),
    (v_teacher_user, v_school, 'teacher', 'Teacher One', 'teacher@school-a.test', '0000000003', 'teacher', 'staff', v_teacher_staff, true, true),
    (v_parent_user, v_school, 'parent', 'Guardian One', 'parent@school-a.test', '0000000004', 'parent', 'guardian', v_guardian, true, true),
    (v_student_user, v_school, 'student', 'Learner One', 'student@school-a.test', '0000000005', 'student', 'student', v_student, true, true),
    (v_kiosk_user, v_school, 'kiosk', 'Kiosk One', 'kiosk@school-a.test', '0000000006', 'kiosk', null, null, true, true),
    (v_superadmin_user, v_school, 'superadmin', 'Local Super Admin', 'superadmin@school-a.test', '0000000007', 'super_admin', null, null, true, true),
    (v_coordinator_user, v_school, 'coordinator', 'Coordinator One', 'coordinator@school-a.test', '0000000008', 'coordinator', 'staff', v_coordinator_staff, true, true)
  on conflict (id) do update
  set username = excluded.username,
      role_name = excluded.role_name,
      linked_type = excluded.linked_type,
      linked_id = excluded.linked_id,
      is_active = true,
      is_verified = true;

  insert into public.username_aliases (username, auth_user_id, school_id)
  values
    ('principal', v_principal_user, v_school),
    ('admin', v_admin_user, v_school),
    ('teacher', v_teacher_user, v_school),
    ('parent', v_parent_user, v_school),
    ('student', v_student_user, v_school),
    ('kiosk', v_kiosk_user, v_school),
    ('superadmin', v_superadmin_user, v_school),
    ('coordinator', v_coordinator_user, v_school)
  on conflict (username) do update set auth_user_id = excluded.auth_user_id;

  insert into public.parent_student_links (school_id, parent_user_id, student_id)
  values (v_school, v_parent_user, v_student)
  on conflict (parent_user_id, student_id) do nothing;

  insert into public.attendance_sessions (id, school_id, section_id, academic_year_id, subject_id, staff_id, date, period_number, is_finalized)
  values (v_attendance_session, v_school, v_section, v_year, v_subject, v_teacher_staff, current_date, 1, true)
  on conflict (id) do update set is_finalized = true;

  insert into public.student_attendances (session_id, student_id, status, remarks)
  values (v_attendance_session, v_student, 'present', 'Seed attendance')
  on conflict (session_id, student_id) do update set status = excluded.status;

  insert into public.attendance_summaries (school_id, student_id, academic_year_id, term_id, total_days, present_days, absent_days, late_days, percentage)
  values (v_school, v_student, v_year, v_term, 1, 1, 0, 0, 100)
  on conflict do nothing;

  insert into public.fee_categories (id, school_id, name, description, is_active)
  values (v_fee_category, v_school, 'Tuition', 'Monthly tuition fee', true)
  on conflict (id) do update set name = excluded.name;

  insert into public.fee_structures (id, school_id, academic_year_id, grade_id, section_id, category_id, fee_category_id, amount, due_date, frequency, is_mandatory)
  values (v_fee_structure, v_school, v_year, v_grade, v_section, v_fee_category, v_fee_category, 12000, '2026-07-10', 'monthly', true)
  on conflict (id) do update set amount = excluded.amount;

  -- The fee-structure trigger has already created the canonical invoice for
  -- this student. Reuse that row for the seeded payment request instead of
  -- inserting a second structure-less invoice for the same tuition amount.
  -- That duplicate made a parent who paid ₹12,000 appear to owe another
  -- ₹12,000 in the ledger.
  select id
  into v_invoice
  from public.fee_invoices
  where school_id = v_school
    and student_id = v_student
    and fee_structure_id = v_fee_structure
  order by created_at asc
  limit 1;
  if v_invoice is null then
    perform public.ensure_fee_invoice_for_student_structure(
      v_student,
      v_fee_structure
    );
    select id
    into v_invoice
    from public.fee_invoices
    where school_id = v_school
      and student_id = v_student
      and fee_structure_id = v_fee_structure
    order by created_at asc
    limit 1;
  end if;
  if v_invoice is null then
    raise exception 'seed tuition invoice was not created';
  end if;
  delete from public.fee_invoice_items where invoice_id = v_invoice;
  update public.fee_invoices
  set invoice_number = 'QA-FEE-2026-001',
      invoice_date = current_date,
      due_date = current_date + 10,
      total_amount = 12000,
      net_amount = 12000,
      paid_amount = 0,
      balance = 12000,
      status = 'pending',
      fee_structure_id = v_fee_structure,
      fee_type = 'tuition',
      billing_mode = 'monthly',
      priority = 2,
      monthly_amount = 1200,
      term_amount = 0,
      term_count = 0,
      allowed_month_names = array[
        'June', 'July', 'August', 'September', 'October',
        'November', 'December', 'January', 'February', 'March'
      ]::text[],
      paid_month_names = '{}'::text[],
      updated_at = now()
  where id = v_invoice;

  insert into public.fee_invoice_items (invoice_id, fee_structure_id, category_name, amount)
  values (v_invoice, v_fee_structure, 'Tuition', 12000)
  on conflict do nothing;

  insert into public.parent_payment_requests (id, school_id, parent_user_id, student_id, invoice_id, amount, payment_method, remarks, status, request_reference, selected_months, selected_month_names)
  values (v_payment_request, v_school, v_parent_user, v_student, v_invoice, 12000, 'upi', 'Seed payment request', 'pending', 'QA-PAY-REQ-001', 1, array['July'])
  on conflict (id) do update set status = excluded.status;

  insert into public.school_payment_settings (school_id, accept_online_payment, late_fine_per_day, grace_period_days)
  values (v_school, true, 10, 3)
  on conflict (school_id) do update set accept_online_payment = true;

  insert into public.leave_types (id, school_id, name, max_days, is_paid)
  values (v_leave_type, v_school, 'Casual Leave', 12, true)
  on conflict (id) do nothing;

  insert into public.leave_balances (school_id, staff_id, leave_type_id, academic_year_id, allocated_days, used_days)
  values (v_school, v_teacher_staff, v_leave_type, v_year, 12, 0)
  on conflict do nothing;

  insert into public.student_leave_applications (school_id, student_id, leave_type, start_date, end_date, total_days, reason, status)
  values (v_school, v_student, 'sick', current_date + 2, current_date + 2, 1, 'Seed leave request', 'pending')
  on conflict do nothing;

  insert into public.timetable_slots (school_id, section_id, subject_id, staff_id, room_id, academic_year_id, day_of_week, start_time, end_time, period_number)
  values (v_school, v_section, v_subject, v_teacher_staff, v_room, v_year, 1, '09:00', '09:40', 1)
  on conflict do nothing;

  insert into public.frontend_records (school_id, table_name, record_id, data)
  values (
    v_school,
    'homework',
    'qa-homework-001',
    jsonb_build_object(
      'id','qa-homework-001',
      'title','Read page 10',
      'description','Seed homework for QA',
      'section_id',v_section,
      'academic_year_id',v_year,
      'subject_id',v_subject,
      'staff_id',v_teacher_staff,
      'due_date',(current_date + 1)::text,
      'status','assigned'
    )
  )
  on conflict do nothing;

  insert into public.announcements (school_id, title, body, audience, priority, status, published_at, created_by)
  values (v_school, 'Welcome QA', 'Seed announcement for deterministic tests.', 'all', 'normal', 'published', now(), v_principal_user)
  on conflict do nothing;

  insert into public.notification_logs (school_id, user_id, title, body, type, entity_type, entity_id)
  values (v_school, v_parent_user, 'Fee reminder', 'Seed notification', 'fee', 'fee_invoice', v_invoice::text)
  on conflict do nothing;

  insert into public.events (school_id, academic_year_id, event_title, event_name, event_type, description, audience_type, status, start_date, end_date, created_by)
  values (v_school, v_year, 'QA Orientation', 'QA Orientation', 'meeting', 'Seed calendar event', 'all', 'scheduled', current_date + 7, current_date + 7, v_principal_user)
  on conflict do nothing;

  insert into public.parent_teacher_meetings (school_id, academic_year_id, section_id, teacher_id, student_id, slot_date, slot_time, duration_min, status, created_by)
  values (v_school, v_year, v_section, v_teacher_staff, v_student, current_date + 3, '10:00', 15, 'available', v_teacher_user)
  on conflict do nothing;

  insert into public.message_conversations (id, school_id, title, student_id, participant_ids)
  values (v_conversation, v_school, 'Parent Teacher QA', v_student, jsonb_build_array(v_teacher_user, v_parent_user))
  on conflict (id) do nothing;

  insert into public.messages (school_id, conversation_id, sender_id, body, read_by)
  values (v_school, v_conversation, v_teacher_user, 'Seed chat message', '[]'::jsonb)
  on conflict do nothing;

  -- Baseline role rows for the super_admin access/permissions PUT round-trip.
  -- Synthetic only; never derived from hosted data.
  insert into public.roles (id, school_id, role_name, description, is_system)
  values
    ('00000000-0000-4000-8000-000000000120', v_school, 'principal', 'School principal', true),
    ('00000000-0000-4000-8000-000000000121', v_school, 'teacher', 'Class teacher', true),
    ('00000000-0000-4000-8000-000000000122', v_school, 'parent', 'Parent / guardian', true)
  on conflict (id) do update set role_name = excluded.role_name;

  insert into public.permissions (school_id, role_id, module, action)
  values
    (v_school, '00000000-0000-4000-8000-000000000120', 'students', 'read'),
    (v_school, '00000000-0000-4000-8000-000000000120', 'staff', 'read'),
    (v_school, '00000000-0000-4000-8000-000000000121', 'students', 'read'),
    (v_school, '00000000-0000-4000-8000-000000000122', 'students', 'read')
  on conflict do nothing;
end $$;
