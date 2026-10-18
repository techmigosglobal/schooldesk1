-- Interpret dated enrollment membership in the selected school timezone.
-- Preserve saved attendance priority, ambiguity checks and transfer selection unchanged.
create or replace function public.attendance_roster(p_school uuid,p_section uuid,p_year uuid,p_date date)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare v_items jsonb; v_zone text;
begin
  select coalesce(nullif(timezone,''),'Asia/Kolkata') into v_zone from public.schools where id=p_school;
  if v_zone is null then return jsonb_build_object('items','[]'::jsonb); end if;
  if exists(
    select 1 from enrollments e where e.school_id=p_school and e.academic_year_id=p_year
    and (e.created_at at time zone v_zone)::date<=p_date
    and e.created_at=(select max(x.created_at) from enrollments x where x.school_id=e.school_id and x.student_id=e.student_id
      and x.academic_year_id=p_year and (x.created_at at time zone v_zone)::date<=p_date)
    group by e.student_id having count(distinct e.section_id)>1 and bool_or(e.section_id=p_section)
  ) then raise exception 'Historical class membership is ambiguous; ask school leadership to verify enrollments'; end if;
  with latest as (
    select distinct on(e.student_id) e.* from enrollments e where e.school_id=p_school and e.academic_year_id=p_year
      and (e.created_at at time zone v_zone)::date<=p_date order by e.student_id,e.created_at desc,e.id
  ), roster as (
    select e.student_id,e.id enrollment_id,1 priority from latest e where e.section_id=p_section and e.status in ('active','transferred','completed')
    union all
    select a.student_id,a.enrollment_id,case when a.enrollment_id is null then 2 else 0 end priority from student_attendances a join attendance_sessions s on s.id=a.session_id
      where s.school_id=p_school and s.section_id=p_section and s.academic_year_id=p_year and s.date=p_date and s.period_number=1
  ), resolved as (
    select distinct on(student_id) student_id,enrollment_id from roster
      order by student_id,priority,enrollment_id
  )
  select coalesce(jsonb_agg(to_jsonb(s)||jsonb_build_object('active_enrollment_id',r.enrollment_id) order by s.first_name,s.id),'[]'::jsonb)
    into v_items from resolved r join students s on s.id=r.student_id and s.school_id=p_school;
  return jsonb_build_object('items',v_items);
end $$;
revoke all on function public.attendance_roster(uuid,uuid,uuid,date) from public,anon,authenticated;
grant execute on function public.attendance_roster(uuid,uuid,uuid,date) to service_role;

notify pgrst,'reload schema';
