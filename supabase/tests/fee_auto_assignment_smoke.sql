begin;

do $$
declare
  v_scope record;
  v_student_id uuid := gen_random_uuid();
  v_structure_id uuid;
  v_expected integer;
  v_actual integer;
begin
  select
    fs.school_id,
    fs.academic_year_id,
    fs.grade_id,
    sec.id as section_id,
    coalesce(fs.fee_category_id, fs.category_id) as category_id
  into v_scope
  from public.fee_structures fs
  join public.sections sec
    on sec.school_id = fs.school_id
   and sec.academic_year_id = fs.academic_year_id
   and sec.grade_id = fs.grade_id
   and (fs.section_id is null or fs.section_id = sec.id)
  limit 1;

  if not found then
    raise exception 'fee assignment smoke requires an existing fee structure';
  end if;

  insert into public.students (
    id,
    school_id,
    first_name,
    last_name,
    admission_number,
    student_id_number,
    current_section_id,
    status
  ) values (
    v_student_id,
    v_scope.school_id,
    'Fee',
    'Trigger Smoke',
    'AUTO-' || substr(v_student_id::text, 1, 8),
    'AUTO-' || substr(v_student_id::text, 1, 8),
    v_scope.section_id,
    'active'
  );

  select count(*)
  into v_expected
  from public.fee_structures fs
  where fs.school_id = v_scope.school_id
    and fs.academic_year_id = v_scope.academic_year_id
    and fs.grade_id = v_scope.grade_id
    and (fs.section_id is null or fs.section_id = v_scope.section_id);

  select count(*)
  into v_actual
  from public.fee_invoices fi
  where fi.student_id = v_student_id;

  if v_actual <> v_expected then
    raise exception 'new student assignment mismatch: expected %, got %',
      v_expected,
      v_actual;
  end if;

  insert into public.fee_structures (
    school_id,
    academic_year_id,
    grade_id,
    section_id,
    category_id,
    fee_category_id,
    amount,
    frequency,
    fee_type,
    billing_mode,
    priority,
    due_day
  ) values (
    v_scope.school_id,
    v_scope.academic_year_id,
    v_scope.grade_id,
    v_scope.section_id,
    v_scope.category_id,
    v_scope.category_id,
    1,
    'one_time',
    'other',
    'one_time',
    1,
    10
  )
  returning id into v_structure_id;

  select count(*)
  into v_expected
  from public.students s
  where s.school_id = v_scope.school_id
    and s.current_section_id = v_scope.section_id
    and s.status = 'active';

  select count(distinct fi.student_id)
  into v_actual
  from public.fee_invoices fi
  where fi.fee_structure_id = v_structure_id;

  if v_actual <> v_expected then
    raise exception 'new structure assignment mismatch: expected %, got %',
      v_expected,
      v_actual;
  end if;
end;
$$;

rollback;
