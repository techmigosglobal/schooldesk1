-- Reconcile the Arishville student placement with the supplied Students CSV.
-- The CSV contains IDs 1-61. Testing account 098 is intentionally untouched.
-- Do not resolve a class by section name alone: A is shared by multiple grades.
do $$
declare
  v_school_id uuid := 'b3409710-78ac-446d-b8f5-45c58d72a004';
  v_play_group_a uuid;
  v_lkg_a uuid;
  v_nursery_a uuid;
  v_nursery_b uuid;
begin
  select sec.id into strict v_play_group_a
  from public.sections sec
  join public.grades g on g.id = sec.grade_id
  where sec.school_id = v_school_id
    and g.school_id = v_school_id
    and g.grade_name = 'Play Group'
    and sec.section_name = 'A';

  select sec.id into strict v_lkg_a
  from public.sections sec
  join public.grades g on g.id = sec.grade_id
  where sec.school_id = v_school_id
    and g.school_id = v_school_id
    and g.grade_name = 'LKG'
    and sec.section_name = 'A';

  select sec.id into strict v_nursery_a
  from public.sections sec
  join public.grades g on g.id = sec.grade_id
  where sec.school_id = v_school_id
    and g.school_id = v_school_id
    and g.grade_name = 'NURSERY'
    and sec.section_name = 'A';

  select sec.id into strict v_nursery_b
  from public.sections sec
  join public.grades g on g.id = sec.grade_id
  where sec.school_id = v_school_id
    and g.school_id = v_school_id
    and g.grade_name = 'NURSERY'
    and sec.section_name = 'B';

  if (
    select count(*)
    from public.students
    where school_id = v_school_id
      and student_id_number in (
        '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',
        '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23',
        '24', '25', '26', '27', '28', '29', '30', '31', '32', '33', '34',
        '35', '36', '37', '38', '39', '40', '41', '42', '43', '44', '45',
        '46', '47', '48', '49', '50', '51', '52', '53', '54', '55', '56',
        '57', '58', '59', '60', '61'
      )
  ) <> 61 then
    raise exception 'Expected all CSV student IDs 1-61 before placement repair';
  end if;

  update public.students
  set current_section_id = v_play_group_a,
      class_name = 'Play Group',
      updated_at = now()
  where school_id = v_school_id
    and student_id_number in (
      '1', '2', '3', '4', '17', '18', '19', '20', '21', '22', '23', '24',
      '25', '26', '27', '61'
    );

  update public.students
  set current_section_id = v_lkg_a,
      class_name = 'LKG',
      updated_at = now()
  where school_id = v_school_id
    and student_id_number in (
      '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16'
    );

  update public.students
  set current_section_id = v_nursery_a,
      class_name = 'NURSERY',
      updated_at = now()
  where school_id = v_school_id
    and student_id_number in (
      '28', '29', '30', '32', '33', '34', '35', '36', '37', '38', '39',
      '40', '41', '42', '59', '60'
    );

  update public.students
  set current_section_id = v_nursery_b,
      class_name = 'NURSERY',
      updated_at = now()
  where school_id = v_school_id
    and student_id_number in (
      '31', '43', '44', '45', '46', '47', '48', '49', '50', '51', '52',
      '53', '54', '55', '56', '57', '58'
    );
end
$$;
