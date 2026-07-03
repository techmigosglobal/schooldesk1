-- Deterministic local QA seed.

create extension if not exists pgcrypto;

do $$
declare
  v_school uuid := '00000000-0000-4000-8000-000000000001';
  v_year uuid := '00000000-0000-4000-8000-000000000010';
  v_term uuid := '00000000-0000-4000-8000-000000000011';
  v_grade uuid := '00000000-0000-4000-8000-000000000020';
  v_room uuid := '00000000-0000-4000-8000-000000000021';
  v_section uuid := '00000000-0000-4000-8000-000000000022';
  v_subject uuid := '00000000-0000-4000-8000-000000000030';
  v_teacher_staff uuid := '00000000-0000-4000-8000-000000000040';
  v_admin_staff uuid := '00000000-0000-4000-8000-000000000041';
  v_student uuid := '00000000-0000-4000-8000-000000000050';
  v_guardian uuid := '00000000-0000-4000-8000-000000000051';
  v_principal_user uuid := '00000000-0000-4000-8000-000000000101';
  v_admin_user uuid := '00000000-0000-4000-8000-000000000102';
  v_teacher_user uuid := '00000000-0000-4000-8000-000000000103';
  v_parent_user uuid := '00000000-0000-4000-8000-000000000104';
  v_student_user uuid := '00000000-0000-4000-8000-000000000105';
  v_kiosk_user uuid := '00000000-0000-4000-8000-000000000106';
  v_attendance_session uuid := '00000000-0000-4000-8000-000000000060';
  v_fee_category uuid := '00000000-0000-4000-8000-000000000070';
  v_fee_structure uuid := '00000000-0000-4000-8000-000000000071';
  v_invoice uuid := '00000000-0000-4000-8000-000000000072';
  v_payment_request uuid := '00000000-0000-4000-8000-000000000073';
  v_leave_type uuid := '00000000-0000-4000-8000-000000000080';
  v_conversation uuid := '00000000-0000-4000-8000-000000000090';
begin
  insert into public.schools (id, name, school_type, email, timezone, currency, principal_name)
  values (v_school, 'SchoolDesk Local Academy', 'preschool', 'principal@schooldesk.local', 'Asia/Kolkata', 'INR', 'School Principal')
  on conflict (id) do update set name = excluded.name;

  insert into public.academic_years (id, school_id, year_label, year, start_date, end_date, is_current, status)
  values (v_year, v_school, '2026-2027', '2026', '2026-04-01', '2027-03-31', true, 'active')
  on conflict (id) do update set is_current = true, status = 'active';

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
    (v_teacher_staff, v_school, 'Tara', 'Teacher', 'TCH-001', 'teacher@schooldesk.local', '9000000003', 'Class Teacher', 'teacher', true),
    (v_admin_staff, v_school, 'Anita', 'Admin', 'ADM-001', 'admin@schooldesk.local', '9000000002', 'Administrator', 'admin', true)
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

  insert into public.students (id, school_id, first_name, last_name, admission_number, student_code, date_of_birth, gender, admission_date, current_section_id, status)
  values (v_student, v_school, 'Sam', 'Student', 'ADM-001', 'STU-001', '2020-06-15', 'other', '2026-04-01', v_section, 'active')
  on conflict (id) do update set current_section_id = excluded.current_section_id;

  insert into public.enrollments (school_id, student_id, section_id, academic_year_id, roll_number, status)
  values (v_school, v_student, v_section, v_year, '1', 'active')
  on conflict do nothing;

  insert into public.guardians (id, school_id, student_id, full_name, relationship, phone, email, is_primary)
  values (v_guardian, v_school, v_student, 'Priya Parent', 'parent', '9000000004', 'parent@schooldesk.local', true)
  on conflict (id) do update set full_name = excluded.full_name;

  insert into public.student_guardians (student_id, guardian_id)
  values (v_student, v_guardian)
  on conflict do nothing;

  insert into public.medical_records (student_id, blood_group, allergies, conditions, medications, emergency_contact)
  values (v_student, 'O+', 'None', 'None', 'None', '9000000004')
  on conflict do nothing;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  )
  values
    ('00000000-0000-0000-0000-000000000000', v_principal_user, 'authenticated', 'authenticated', 'principal@schooldesk.local', crypt('Principal@12345', gen_salt('bf')), now(), jsonb_build_object('provider','email','providers',array['email'],'school_id',v_school,'role_name','principal'), '{"name":"School Principal"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_admin_user, 'authenticated', 'authenticated', 'admin@schooldesk.local', crypt('Admin@12345', gen_salt('bf')), now(), jsonb_build_object('provider','email','providers',array['email'],'school_id',v_school,'role_name','admin'), '{"name":"School Admin"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_teacher_user, 'authenticated', 'authenticated', 'teacher@schooldesk.local', crypt('Teacher@12345', gen_salt('bf')), now(), jsonb_build_object('provider','email','providers',array['email'],'school_id',v_school,'role_name','teacher'), '{"name":"Tara Teacher"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_parent_user, 'authenticated', 'authenticated', 'parent@schooldesk.local', crypt('Parent@12345', gen_salt('bf')), now(), jsonb_build_object('provider','email','providers',array['email'],'school_id',v_school,'role_name','parent'), '{"name":"Priya Parent"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_student_user, 'authenticated', 'authenticated', 'student@schooldesk.local', crypt('Student@12345', gen_salt('bf')), now(), jsonb_build_object('provider','email','providers',array['email'],'school_id',v_school,'role_name','student'), '{"name":"Sam Student"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_kiosk_user, 'authenticated', 'authenticated', 'kiosk@schooldesk.local', crypt('Kiosk@12345', gen_salt('bf')), now(), jsonb_build_object('provider','email','providers',array['email'],'school_id',v_school,'role_name','kiosk'), '{"name":"Attendance Kiosk"}', now(), now(), '', '', '', '')
  on conflict (id) do update
  set encrypted_password = excluded.encrypted_password,
      raw_app_meta_data = excluded.raw_app_meta_data,
      updated_at = now();

  insert into auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  select id, id, id, jsonb_build_object('sub', id, 'email', email), 'email', now(), now(), now()
  from auth.users
  where id in (v_principal_user, v_admin_user, v_teacher_user, v_parent_user, v_student_user, v_kiosk_user)
  on conflict (provider, provider_id) do nothing;

  insert into public.users (id, school_id, username, name, email, phone, role_name, linked_type, linked_id, is_active, is_verified)
  values
    (v_principal_user, v_school, 'principal', 'School Principal', 'principal@schooldesk.local', '9000000001', 'principal', 'staff', null, true, true),
    (v_admin_user, v_school, 'admin', 'School Admin', 'admin@schooldesk.local', '9000000002', 'admin', 'staff', v_admin_staff, true, true),
    (v_teacher_user, v_school, 'teacher', 'Tara Teacher', 'teacher@schooldesk.local', '9000000003', 'teacher', 'staff', v_teacher_staff, true, true),
    (v_parent_user, v_school, 'parent', 'Priya Parent', 'parent@schooldesk.local', '9000000004', 'parent', 'guardian', v_guardian, true, true),
    (v_student_user, v_school, 'student', 'Sam Student', 'student@schooldesk.local', '9000000005', 'student', 'student', v_student, true, true),
    (v_kiosk_user, v_school, 'kiosk', 'Attendance Kiosk', 'kiosk@schooldesk.local', '9000000006', 'kiosk', null, null, true, true)
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
    ('kiosk', v_kiosk_user, v_school)
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

  insert into public.fee_invoices (id, school_id, student_id, academic_year_id, invoice_number, invoice_date, due_date, total_amount, net_amount, paid_amount, balance, status)
  values (v_invoice, v_school, v_student, v_year, 'QA-FEE-2026-001', current_date, current_date + 10, 12000, 12000, 0, 12000, 'pending')
  on conflict (id) do update set balance = excluded.balance, status = excluded.status;

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
end $$;
