-- ============================================================
-- Migration 0005: Row Level Security Policies
-- School-scoped: all data tables access controlled by
-- app_metadata.school_id from the Supabase JWT
-- ============================================================

-- Helper: extract school_id from JWT app_metadata (set by Edge Function on login)
create or replace function public.auth_school_id()
returns uuid language sql stable as $$
  select nullif(
    (auth.jwt() -> 'app_metadata' ->> 'school_id'),
    ''
  )::uuid
$$;

-- Helper: extract role from JWT app_metadata
create or replace function public.auth_role_name()
returns text language sql stable as $$
  select auth.jwt() -> 'app_metadata' ->> 'role_name'
$$;

-- Helper: is the current user a principal or admin?
create or replace function public.is_admin_or_principal()
returns boolean language sql stable as $$
  select public.auth_role_name() in ('admin', 'principal', 'super_admin')
$$;

-- ─── schools ───────────────────────────────────────────────────
create policy "school_select" on public.schools
  for select to authenticated
  using (id = public.auth_school_id());

create policy "school_update" on public.schools
  for update to authenticated
  using (id = public.auth_school_id() and public.is_admin_or_principal())
  with check (id = public.auth_school_id() and public.is_admin_or_principal());

-- ─── academic_years ────────────────────────────────────────────
create policy "academic_years_select" on public.academic_years
  for select to authenticated using (school_id = public.auth_school_id());

create policy "academic_years_insert" on public.academic_years
  for insert to authenticated
  with check (school_id = public.auth_school_id() and public.is_admin_or_principal());

create policy "academic_years_update" on public.academic_years
  for update to authenticated
  using (school_id = public.auth_school_id() and public.is_admin_or_principal())
  with check (school_id = public.auth_school_id());

create policy "academic_years_delete" on public.academic_years
  for delete to authenticated
  using (school_id = public.auth_school_id() and public.is_admin_or_principal());

-- ─── Macro: school-scoped RLS for most read/write tables ───────
-- Tables where authenticated users of the same school can read
-- and admin/principal can write.
do $$
declare
  t text;
begin
  foreach t in array array[
    'holidays','working_day_configs','departments','subjects',
    'grades','rooms','sections','grade_subjects',
    'roles','permissions',
    'staff','staff_subjects','staff_documents',
    'students','guardians',
    'student_documents','enrollments','transfer_records',
    'attendance_sessions','staff_attendances',
    'attendance_summaries','substitutions',
    'fee_categories','fee_structures',
    'fee_invoices','fee_concessions','parent_payment_requests',
    'school_payment_settings',
    'leave_types','leave_balances','leave_applications','student_leave_applications',
    'timetable_slots','timetable_templates',
    'announcements','event_posts','diary_entries','lesson_planners',
    'message_conversations','messages',
    'notification_logs',
    'homework_submissions',
    'approval_requests','account_approvals',
    'uploaded_files','frontend_records','bulk_import_jobs','error_events',
    'audit_logs'
  ] loop
    execute format(
      'create policy "%I_school_select" on public.%I
       for select to authenticated using (school_id = public.auth_school_id())',
      t, t
    );
    execute format(
      'create policy "%I_school_insert" on public.%I
       for insert to authenticated with check (school_id = public.auth_school_id())',
      t, t
    );
    execute format(
      'create policy "%I_school_update" on public.%I
       for update to authenticated
       using (school_id = public.auth_school_id())
       with check (school_id = public.auth_school_id())',
      t, t
    );
    execute format(
      'create policy "%I_school_delete" on public.%I
       for delete to authenticated using (school_id = public.auth_school_id())',
      t, t
    );
  end loop;
end;
$$;

-- ─── terms: scope through academic_years ──────────────────────
create policy "terms_school_select" on public.terms
  for select to authenticated
  using (
    exists (
      select 1
      from public.academic_years academic_year
      where academic_year.id = terms.academic_year_id
        and academic_year.school_id = public.auth_school_id()
    )
  );

create policy "terms_school_insert" on public.terms
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.academic_years academic_year
      where academic_year.id = terms.academic_year_id
        and academic_year.school_id = public.auth_school_id()
    )
    and public.is_admin_or_principal()
  );

create policy "terms_school_update" on public.terms
  for update to authenticated
  using (
    exists (
      select 1
      from public.academic_years academic_year
      where academic_year.id = terms.academic_year_id
        and academic_year.school_id = public.auth_school_id()
    )
  )
  with check (
    exists (
      select 1
      from public.academic_years academic_year
      where academic_year.id = terms.academic_year_id
        and academic_year.school_id = public.auth_school_id()
    )
  );

create policy "terms_school_delete" on public.terms
  for delete to authenticated
  using (
    exists (
      select 1
      from public.academic_years academic_year
      where academic_year.id = terms.academic_year_id
        and academic_year.school_id = public.auth_school_id()
    )
    and public.is_admin_or_principal()
  );

-- ─── Child tables without school_id ───────────────────────────
create policy "staff_qualifications_school_select" on public.staff_qualifications
  for select to authenticated
  using (
    exists (
      select 1 from public.staff
      where staff.id = staff_qualifications.staff_id
        and staff.school_id = public.auth_school_id()
    )
  );

create policy "staff_qualifications_school_insert" on public.staff_qualifications
  for insert to authenticated
  with check (
    exists (
      select 1 from public.staff
      where staff.id = staff_qualifications.staff_id
        and staff.school_id = public.auth_school_id()
    )
  );

create policy "staff_qualifications_school_update" on public.staff_qualifications
  for update to authenticated
  using (
    exists (
      select 1 from public.staff
      where staff.id = staff_qualifications.staff_id
        and staff.school_id = public.auth_school_id()
    )
  )
  with check (
    exists (
      select 1 from public.staff
      where staff.id = staff_qualifications.staff_id
        and staff.school_id = public.auth_school_id()
    )
  );

create policy "staff_qualifications_school_delete" on public.staff_qualifications
  for delete to authenticated
  using (
    exists (
      select 1 from public.staff
      where staff.id = staff_qualifications.staff_id
        and staff.school_id = public.auth_school_id()
    )
  );

create policy "student_guardians_school_select" on public.student_guardians
  for select to authenticated
  using (
    exists (
      select 1 from public.students
      where students.id = student_guardians.student_id
        and students.school_id = public.auth_school_id()
    )
  );

create policy "student_guardians_school_insert" on public.student_guardians
  for insert to authenticated
  with check (
    exists (
      select 1 from public.students
      where students.id = student_guardians.student_id
        and students.school_id = public.auth_school_id()
    )
  );

create policy "student_guardians_school_update" on public.student_guardians
  for update to authenticated
  using (
    exists (
      select 1 from public.students
      where students.id = student_guardians.student_id
        and students.school_id = public.auth_school_id()
    )
  )
  with check (
    exists (
      select 1 from public.students
      where students.id = student_guardians.student_id
        and students.school_id = public.auth_school_id()
    )
  );

create policy "student_guardians_school_delete" on public.student_guardians
  for delete to authenticated
  using (
    exists (
      select 1 from public.students
      where students.id = student_guardians.student_id
        and students.school_id = public.auth_school_id()
    )
  );

create policy "medical_records_school_select" on public.medical_records
  for select to authenticated
  using (
    exists (
      select 1 from public.students
      where students.id = medical_records.student_id
        and students.school_id = public.auth_school_id()
    )
  );

create policy "medical_records_school_insert" on public.medical_records
  for insert to authenticated
  with check (
    exists (
      select 1 from public.students
      where students.id = medical_records.student_id
        and students.school_id = public.auth_school_id()
    )
  );

create policy "medical_records_school_update" on public.medical_records
  for update to authenticated
  using (
    exists (
      select 1 from public.students
      where students.id = medical_records.student_id
        and students.school_id = public.auth_school_id()
    )
  )
  with check (
    exists (
      select 1 from public.students
      where students.id = medical_records.student_id
        and students.school_id = public.auth_school_id()
    )
  );

create policy "medical_records_school_delete" on public.medical_records
  for delete to authenticated
  using (
    exists (
      select 1 from public.students
      where students.id = medical_records.student_id
        and students.school_id = public.auth_school_id()
    )
  );

create policy "student_attendances_school_select" on public.student_attendances
  for select to authenticated
  using (
    exists (
      select 1
      from public.attendance_sessions
      where attendance_sessions.id = student_attendances.session_id
        and attendance_sessions.school_id = public.auth_school_id()
    )
  );

create policy "student_attendances_school_insert" on public.student_attendances
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.attendance_sessions
      where attendance_sessions.id = student_attendances.session_id
        and attendance_sessions.school_id = public.auth_school_id()
    )
  );

create policy "student_attendances_school_update" on public.student_attendances
  for update to authenticated
  using (
    exists (
      select 1
      from public.attendance_sessions
      where attendance_sessions.id = student_attendances.session_id
        and attendance_sessions.school_id = public.auth_school_id()
    )
  )
  with check (
    exists (
      select 1
      from public.attendance_sessions
      where attendance_sessions.id = student_attendances.session_id
        and attendance_sessions.school_id = public.auth_school_id()
    )
  );

create policy "student_attendances_school_delete" on public.student_attendances
  for delete to authenticated
  using (
    exists (
      select 1
      from public.attendance_sessions
      where attendance_sessions.id = student_attendances.session_id
        and attendance_sessions.school_id = public.auth_school_id()
    )
  );

create policy "fee_installments_school_select" on public.fee_installments
  for select to authenticated
  using (
    exists (
      select 1 from public.fee_structures
      where fee_structures.id = fee_installments.fee_structure_id
        and fee_structures.school_id = public.auth_school_id()
    )
  );

create policy "fee_installments_school_insert" on public.fee_installments
  for insert to authenticated
  with check (
    exists (
      select 1 from public.fee_structures
      where fee_structures.id = fee_installments.fee_structure_id
        and fee_structures.school_id = public.auth_school_id()
    )
  );

create policy "fee_installments_school_update" on public.fee_installments
  for update to authenticated
  using (
    exists (
      select 1 from public.fee_structures
      where fee_structures.id = fee_installments.fee_structure_id
        and fee_structures.school_id = public.auth_school_id()
    )
  )
  with check (
    exists (
      select 1 from public.fee_structures
      where fee_structures.id = fee_installments.fee_structure_id
        and fee_structures.school_id = public.auth_school_id()
    )
  );

create policy "fee_installments_school_delete" on public.fee_installments
  for delete to authenticated
  using (
    exists (
      select 1 from public.fee_structures
      where fee_structures.id = fee_installments.fee_structure_id
        and fee_structures.school_id = public.auth_school_id()
    )
  );

create policy "fee_invoice_items_school_select" on public.fee_invoice_items
  for select to authenticated
  using (
    exists (
      select 1 from public.fee_invoices
      where fee_invoices.id = fee_invoice_items.invoice_id
        and fee_invoices.school_id = public.auth_school_id()
    )
  );

create policy "fee_invoice_items_school_insert" on public.fee_invoice_items
  for insert to authenticated
  with check (
    exists (
      select 1 from public.fee_invoices
      where fee_invoices.id = fee_invoice_items.invoice_id
        and fee_invoices.school_id = public.auth_school_id()
    )
  );

create policy "fee_invoice_items_school_update" on public.fee_invoice_items
  for update to authenticated
  using (
    exists (
      select 1 from public.fee_invoices
      where fee_invoices.id = fee_invoice_items.invoice_id
        and fee_invoices.school_id = public.auth_school_id()
    )
  )
  with check (
    exists (
      select 1 from public.fee_invoices
      where fee_invoices.id = fee_invoice_items.invoice_id
        and fee_invoices.school_id = public.auth_school_id()
    )
  );

create policy "fee_invoice_items_school_delete" on public.fee_invoice_items
  for delete to authenticated
  using (
    exists (
      select 1 from public.fee_invoices
      where fee_invoices.id = fee_invoice_items.invoice_id
        and fee_invoices.school_id = public.auth_school_id()
    )
  );

create policy "fee_receipts_school_select" on public.fee_receipts
  for select to authenticated
  using (
    exists (
      select 1
      from public.payments
      where payments.id = fee_receipts.payment_id
        and payments.school_id = public.auth_school_id()
    )
  );

create policy "fee_receipts_school_insert" on public.fee_receipts
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.payments
      where payments.id = fee_receipts.payment_id
        and payments.school_id = public.auth_school_id()
    )
  );

create policy "fee_receipts_school_update" on public.fee_receipts
  for update to authenticated
  using (
    exists (
      select 1
      from public.payments
      where payments.id = fee_receipts.payment_id
        and payments.school_id = public.auth_school_id()
    )
  )
  with check (
    exists (
      select 1
      from public.payments
      where payments.id = fee_receipts.payment_id
        and payments.school_id = public.auth_school_id()
    )
  );

create policy "fee_receipts_school_delete" on public.fee_receipts
  for delete to authenticated
  using (
    exists (
      select 1
      from public.payments
      where payments.id = fee_receipts.payment_id
        and payments.school_id = public.auth_school_id()
    )
  );

create policy "notification_device_tokens_select" on public.notification_device_tokens
  for select to authenticated
  using (user_id = auth.uid());

create policy "notification_device_tokens_insert" on public.notification_device_tokens
  for insert to authenticated
  with check (user_id = auth.uid());

create policy "notification_device_tokens_update" on public.notification_device_tokens
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "notification_device_tokens_delete" on public.notification_device_tokens
  for delete to authenticated
  using (user_id = auth.uid());

-- ─── users: each user can read their own row + same school ──────
create policy "users_school_select" on public.users
  for select to authenticated using (school_id = public.auth_school_id());

create policy "users_school_insert" on public.users
  for insert to authenticated
  with check (school_id = public.auth_school_id() and public.is_admin_or_principal());

create policy "users_school_update" on public.users
  for update to authenticated
  using (school_id = public.auth_school_id())
  with check (school_id = public.auth_school_id());

create policy "users_school_delete" on public.users
  for delete to authenticated
  using (school_id = public.auth_school_id() and public.is_admin_or_principal());

-- ─── username_aliases: service-role writes, Edge Fn reads via service client
-- anon cannot read; authenticated can look up their own
create policy "username_aliases_select" on public.username_aliases
  for select to authenticated using (school_id = public.auth_school_id());

-- ─── parent_student_links: parent can see their own, admin sees all ──
create policy "parent_student_links_select" on public.parent_student_links
  for select to authenticated
  using (
    school_id = public.auth_school_id()
    and (
      public.is_admin_or_principal()
      or parent_user_id = auth.uid()
    )
  );

create policy "parent_student_links_insert" on public.parent_student_links
  for insert to authenticated
  with check (school_id = public.auth_school_id() and public.is_admin_or_principal());

create policy "parent_student_links_delete" on public.parent_student_links
  for delete to authenticated
  using (school_id = public.auth_school_id() and public.is_admin_or_principal());

-- ─── payments: parents can see their children's payments ────────
create policy "payments_school_select" on public.payments
  for select to authenticated using (school_id = public.auth_school_id());

create policy "payments_school_insert" on public.payments
  for insert to authenticated
  with check (school_id = public.auth_school_id() and public.is_admin_or_principal());

create policy "payments_school_update" on public.payments
  for update to authenticated
  using (school_id = public.auth_school_id() and public.is_admin_or_principal())
  with check (school_id = public.auth_school_id());

create policy "payments_school_delete" on public.payments
  for delete to authenticated
  using (school_id = public.auth_school_id() and public.is_admin_or_principal());

-- ─── user_sessions: own sessions only ───────────────────────────
create policy "user_sessions_select" on public.user_sessions
  for select to authenticated using (user_id = auth.uid());

create policy "user_sessions_insert" on public.user_sessions
  for insert to authenticated with check (user_id = auth.uid());

create policy "user_sessions_delete" on public.user_sessions
  for delete to authenticated using (user_id = auth.uid());
