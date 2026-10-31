-- Read-only branch audit, including active students without a section.
-- psql -v school_id='<school UUID>' -f scripts/student_enrollment_integrity.sql
\set ON_ERROR_STOP on
begin read only;
with scope as (
  select s.id,s.first_name,s.last_name,s.current_section_id,s.is_test_account,
    sec.academic_year_id,sec.section_name,g.grade_name,y.is_current,
    latest.id enrollment_id,latest.section_id enrollment_section_id,latest.status enrollment_status,
    case
      when s.current_section_id is null then 'unassigned_section'
      when sec.id is null then 'invalid_section'
      when not coalesce(y.is_current,false) then 'noncurrent_academic_year'
      when latest.id is null then 'missing_effective_enrollment'
      when latest.section_id<>s.current_section_id then 'enrollment_section_mismatch'
      when latest.status not in ('active','transferred','completed') then 'inactive_enrollment'
      when exists(select 1 from public.enrollments tied
        where tied.student_id=s.id and tied.school_id=s.school_id
          and tied.academic_year_id=sec.academic_year_id
          and tied.created_at=latest.created_at and tied.section_id<>latest.section_id)
        then 'ambiguous_enrollment'
    end issue
  from public.students s
  join public.schools sch on sch.id=s.school_id
  left join public.sections sec on sec.id=s.current_section_id and sec.school_id=s.school_id
  left join public.grades g on g.id=sec.grade_id
  left join public.academic_years y on y.id=sec.academic_year_id and y.school_id=s.school_id
  left join lateral (
    select e.* from public.enrollments e where e.student_id=s.id and e.school_id=s.school_id
      and e.academic_year_id=sec.academic_year_id
      and (e.created_at at time zone coalesce(nullif(sch.timezone,''),'Asia/Kolkata'))::date
        <=(statement_timestamp() at time zone coalesce(nullif(sch.timezone,''),'Asia/Kolkata'))::date
    order by e.created_at desc,e.id limit 1
  ) latest on true
  where s.school_id=:'school_id'::uuid and s.status='active'
)
select jsonb_build_object(
  'active_real_students',count(*) filter(where not is_test_account),
  'assigned_real_students',count(*) filter(where not is_test_account and current_section_id is not null),
  'healthy_assigned_real_students',count(*) filter(where not is_test_account and issue is null),
  'active_test_accounts',count(*) filter(where is_test_account),
  'issues',coalesce(jsonb_agg(jsonb_build_object(
    'student_id',id,'name',concat_ws(' ',first_name,last_name),
    'section_id',current_section_id,'class',concat_ws(' - ',grade_name,section_name),
    'is_test_account',is_test_account,'issue',issue
  ) order by first_name,id) filter(where issue is not null),'[]'::jsonb)
) from scope;
rollback;
