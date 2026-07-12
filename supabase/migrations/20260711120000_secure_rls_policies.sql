-- Secure RLS policies for administrative tables.
-- Drops generic write policies and replaces them with strict role-based checks.

do $$
declare
  t text;
  tables text[] := array[
    'staff', 'staff_subjects', 'staff_documents',
    'students', 'guardians', 'student_documents', 'enrollments', 'transfer_records',
    'fee_categories', 'fee_structures', 'fee_invoices', 'school_payment_settings',
    'timetable_slots', 'timetable_templates', 'audit_logs',
    'holidays', 'working_day_configs', 'departments', 'subjects', 'grades', 'rooms', 'sections', 'grade_subjects',
    'roles', 'permissions'
  ];
begin
  foreach t in array tables loop
    -- Drop old generic insert/update/delete policies
    execute format('drop policy if exists %I_school_insert on public.%I', t, t);
    execute format('drop policy if exists %I_school_update on public.%I', t, t);
    execute format('drop policy if exists %I_school_delete on public.%I', t, t);

    -- Create new secure policies
    execute format(
      'create policy %I_school_insert on public.%I
       for insert to authenticated with check (school_id = public.auth_school_id() and public.is_admin_or_principal())',
      t, t
    );

    execute format(
      'create policy %I_school_update on public.%I
       for update to authenticated
       using (school_id = public.auth_school_id() and public.is_admin_or_principal())
       with check (school_id = public.auth_school_id() and public.is_admin_or_principal())',
      t, t
    );

    execute format(
      'create policy %I_school_delete on public.%I
       for delete to authenticated using (school_id = public.auth_school_id() and public.is_admin_or_principal())',
      t, t
    );
  end loop;
end;
$$;
