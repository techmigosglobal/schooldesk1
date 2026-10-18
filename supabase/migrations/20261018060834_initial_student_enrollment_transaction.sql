-- Enrollment.created_at is the existing attendance roster effective date.
-- Record only a first active class assignment, in the student write transaction.
-- Existing annual enrollment and transfer history is never rewritten or inferred.
create function public.ensure_initial_student_enrollment()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_year uuid;
  v_start date;
  v_end date;
  v_today date;
  v_effective date;
  v_zone text;
begin
  if new.status<>'active' or new.current_section_id is null then return new; end if;
  if tg_op='UPDATE' then
    -- An active student's section change is a transfer, not an initial assignment.
    -- A no-op save must not backfill historical missing rows either.
    if old.status='active' and old.current_section_id is not null then return new; end if;
  end if;

  select section.academic_year_id, academic_year.start_date, academic_year.end_date, coalesce(nullif(school.timezone,''),'Asia/Kolkata')
    into v_year,v_start,v_end,v_zone
  from public.sections section
  join public.academic_years academic_year on academic_year.id=section.academic_year_id
    and academic_year.school_id=new.school_id and academic_year.is_current
  join public.schools school on school.id=section.school_id
  where section.id=new.current_section_id and section.school_id=new.school_id;
  if not found then
    raise exception using errcode='23514', message='Initial active class assignment requires a section in the school current academic year';
  end if;

  -- Student INSERT/UPDATE holds this student's row lock, serializing trigger runs.
  -- Any record for the year may describe a dated transfer; leave it intact.
  if exists(select 1 from public.enrollments enrollment
    where enrollment.student_id=new.id and enrollment.academic_year_id=v_year) then
    return new;
  end if;
  if v_start is null or v_end is null or v_start>v_end then
    raise exception using errcode='23514', message='Initial active class assignment requires valid academic year dates';
  end if;
  v_today := (statement_timestamp() at time zone v_zone)::date;
  v_effective := greatest(coalesce(new.admission_date,v_today),v_start);
  if tg_op='UPDATE' then
    -- Later activation/first assignment is effective today, even for an old admission.
    v_effective := greatest(v_effective,v_today);
  end if;
  if v_effective>v_end then
    raise exception using errcode='23514', message='Initial enrollment effective date is outside the current academic year';
  end if;
  insert into public.enrollments(school_id,student_id,section_id,academic_year_id,status,created_at)
    values(new.school_id,new.id,new.current_section_id,v_year,'active',v_effective::timestamp at time zone v_zone);
  return new;
end;
$$;
revoke all on function public.ensure_initial_student_enrollment() from public,anon,authenticated;
create trigger students_initial_enrollment
after insert or update of current_section_id,status on public.students
for each row execute function public.ensure_initial_student_enrollment();
notify pgrst,'reload schema';
