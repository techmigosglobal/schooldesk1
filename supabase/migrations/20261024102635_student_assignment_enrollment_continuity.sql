-- Keep dated membership in the same transaction as an active class change.
-- Ordinary saves do not infer or backfill a legacy student's history.
create or replace function public.ensure_initial_student_enrollment()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_year uuid;
  v_start date;
  v_end date;
  v_today date;
  v_effective date;
  v_zone text;
  v_existing public.enrollments%rowtype;
  v_changed_class boolean := false;
begin
  if new.status<>'active' or new.current_section_id is null then return new; end if;
  if tg_op='UPDATE' then
    if old.status='active' and old.current_section_id is not null then
      if old.current_section_id=new.current_section_id then return new; end if;
      v_changed_class := true;
    end if;
  end if;

  select section.academic_year_id, academic_year.start_date, academic_year.end_date,
      coalesce(nullif(school.timezone,''),'Asia/Kolkata')
    into v_year,v_start,v_end,v_zone
  from public.sections section
  join public.academic_years academic_year on academic_year.id=section.academic_year_id
    and academic_year.school_id=new.school_id and academic_year.is_current
  join public.schools school on school.id=section.school_id
  where section.id=new.current_section_id and section.school_id=new.school_id;
  if not found then
    raise exception using errcode='23514', message='Active class assignment requires a section in the school current academic year';
  end if;
  if v_start is null or v_end is null or v_start>v_end then
    raise exception using errcode='23514', message='Active class assignment requires valid academic year dates';
  end if;
  v_today := (statement_timestamp() at time zone v_zone)::date;

  select * into v_existing from public.enrollments
    where student_id=new.id and academic_year_id=v_year
    order by created_at desc,id limit 1;
  if found then
    if v_existing.school_id<>new.school_id then
      raise exception using errcode='23514', message='Student enrollment belongs to another school';
    end if;
    if (v_existing.created_at at time zone v_zone)::date>v_today then
      raise exception using errcode='23514', message='Verify the future-dated enrollment before changing this class assignment';
    end if;
    if exists(select 1 from public.enrollments e where e.student_id=new.id
      and e.academic_year_id=v_year and e.created_at=v_existing.created_at
      and e.section_id<>v_existing.section_id) then
      raise exception using errcode='23514', message='Verify ambiguous enrollment history before changing this class assignment';
    end if;
    -- A separately recorded matching membership is safe to reuse on activation.
    if v_existing.section_id=new.current_section_id and v_existing.status='active' then
      return new;
    end if;
    -- A changed/renewed assignment is effective now, never at the old admission.
    if v_existing.created_at>=statement_timestamp() then
      raise exception using errcode='23514', message='Retry this class assignment after the previous enrollment transaction';
    end if;
    v_changed_class := true;
  end if;

  v_effective := greatest(coalesce(new.admission_date,v_today),v_start);
  if tg_op='UPDATE' then v_effective := greatest(v_effective,v_today); end if;
  if v_effective>v_end then
    raise exception using errcode='23514', message='Enrollment effective date is outside the current academic year';
  end if;
  if v_changed_class and v_today<v_start then
    raise exception using errcode='23514', message='Class transfer requires the current academic year to have started';
  end if;

  insert into public.enrollments(school_id,student_id,section_id,academic_year_id,status,created_at)
    values(new.school_id,new.id,new.current_section_id,v_year,'active',
      case when v_changed_class and v_effective=v_today then statement_timestamp()
        else v_effective::timestamp at time zone v_zone end);
  return new;
end;
$$;
revoke all on function public.ensure_initial_student_enrollment() from public,anon,authenticated;

notify pgrst,'reload schema';
