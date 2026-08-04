-- Replace one class timetable template across selected days atomically.
-- The API validates school/role/subject scope before calling this function.
create or replace function public.replace_timetable_days(
  p_school_id uuid,
  p_section_id uuid,
  p_academic_year_id uuid,
  p_days integer[],
  p_rows jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer := 0;
  created_count integer := 0;
begin
  delete from public.timetable_slots
  where school_id = p_school_id
    and section_id = p_section_id
    and academic_year_id = p_academic_year_id
    and day_of_week = any(p_days);
  get diagnostics deleted_count = row_count;

  insert into public.timetable_slots (
    school_id,
    section_id,
    academic_year_id,
    day_of_week,
    period_number,
    subject_id,
    staff_id,
    start_time,
    end_time,
    slot_type
  )
  select
    p_school_id,
    p_section_id,
    p_academic_year_id,
    day_number,
    row_data.ordinality::integer,
    nullif(row_data.value ->> 'subject_id', '')::uuid,
    nullif(row_data.value ->> 'staff_id', '')::uuid,
    row_data.value ->> 'start_time',
    row_data.value ->> 'end_time',
    case
      when nullif(row_data.value ->> 'subject_id', '') is null then 'free'
      else 'regular'
    end
  from unnest(p_days) as selected_day(day_number)
  cross join jsonb_array_elements(p_rows) with ordinality as row_data(value, ordinality);
  get diagnostics created_count = row_count;

  return jsonb_build_object(
    'deleted_count', deleted_count,
    'created_count', created_count,
    'days', p_days
  );
end;
$$;

revoke all on function public.replace_timetable_days(uuid, uuid, uuid, integer[], jsonb)
  from public, anon, authenticated;
grant execute on function public.replace_timetable_days(uuid, uuid, uuid, integer[], jsonb)
  to service_role;
