-- One transaction validates the requested context and reopens its register and
-- daily claim together. Only the trusted API service may invoke this function.
-- Keep correction history on the register; the general audit-log product was
-- retired by 20261003143942 and must not be restored by this repair.
alter table public.attendance_sessions
  add column if not exists reopen_history jsonb not null default '[]'::jsonb;

create or replace function public.reopen_attendance_session_scoped(
  p_school_id uuid,
  p_session_id uuid,
  p_actor_id uuid,
  p_reason text,
  p_section_id uuid,
  p_date date,
  p_student_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.attendance_sessions%rowtype;
  v_actor public.users%rowtype;
  v_before jsonb;
  v_at timestamptz := now();
begin
  if p_school_id is null or p_session_id is null or p_actor_id is null
     or p_section_id is null or p_date is null
     or nullif(btrim(p_reason), '') is null then
    raise exception 'class, date and reason are required to reopen attendance'
      using errcode = '22023';
  end if;

  select * into v_actor from public.users
  where id = p_actor_id and is_active
    and lower(role_name) in ('principal', 'admin', 'coordinator', 'super_admin')
    and (school_id = p_school_id or lower(role_name) = 'super_admin');
  if not found then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_session from public.attendance_sessions
  where id = p_session_id and school_id = p_school_id for update;
  if not found then
    raise exception 'attendance session not found' using errcode = 'P0002';
  end if;
  if v_session.section_id is distinct from p_section_id
     or v_session.date is distinct from p_date then
    raise exception 'attendance class or date does not match the selected register';
  end if;

  -- A historical record remains valid after the student changes class. Never
  -- substitute current_section_id for the record's actual session membership.
  if p_student_id is not null and not exists (
    select 1 from public.student_attendances a
    join public.students s on s.id = a.student_id
    where a.session_id = p_session_id and a.student_id = p_student_id
      and s.school_id = p_school_id
  ) then
    raise exception 'student does not belong to the selected attendance register';
  end if;

  if not exists (select 1 from public.sections
      where id = v_session.section_id and school_id = p_school_id)
    or not exists (select 1 from public.academic_years
      where id = v_session.academic_year_id and school_id = p_school_id)
    or not exists (select 1 from public.staff
      where id = v_session.staff_id and school_id = p_school_id) then
    raise exception 'attendance register has an invalid school context';
  end if;

  v_before := jsonb_build_object(
    'status', v_session.status, 'is_finalized', v_session.is_finalized,
    'reopened_at', v_session.reopened_at, 'reopened_by', v_session.reopened_by,
    'reopen_reason', v_session.reopen_reason
  );
  if v_session.status = 'reopened' and not v_session.is_finalized then
    v_at := coalesce(v_session.reopened_at, v_at);
  end if;

  -- Older registers may predate daily claims. Create the exact claim when
  -- absent and retain an existing claimant when a co-teacher marked attendance.
  insert into public.class_daily_operation_claims (
    school_id, academic_year_id, section_id, operation, operation_date,
    claimed_by_staff_id, status, reopened_at, reopened_by, reopen_reason
  ) values (
    p_school_id, v_session.academic_year_id, p_section_id, 'attendance', p_date,
    v_session.staff_id, 'reopened', v_at,
    case when v_session.status = 'reopened' and not v_session.is_finalized
      then coalesce(v_session.reopened_by, p_actor_id) else p_actor_id end,
    case when v_session.status = 'reopened' and not v_session.is_finalized
      then coalesce(v_session.reopen_reason, btrim(p_reason))
      else btrim(p_reason) end
  ) on conflict (school_id, academic_year_id, section_id, operation, operation_date)
  do update set status = 'reopened', reopened_at = excluded.reopened_at,
    reopened_by = excluded.reopened_by, reopen_reason = excluded.reopen_reason,
    updated_at = now();

  -- A retry must not overwrite the original reopen reason/actor or add another
  -- audit event. Claim synchronization above still repairs a missing claim.
  if v_session.status = 'reopened' and not v_session.is_finalized then
    return to_jsonb(v_session);
  end if;

  update public.attendance_sessions set
    is_finalized = false, status = 'reopened',
    correction_request = btrim(p_reason), reopen_reason = btrim(p_reason),
    reopened_by = p_actor_id, reopened_at = v_at, updated_at = v_at,
    reopen_history = coalesce(reopen_history, '[]'::jsonb) || jsonb_build_array(
      jsonb_build_object('reason', btrim(p_reason), 'actor_id', p_actor_id,
        'reopened_at', v_at, 'section_id', p_section_id, 'date', p_date,
        'student_id', p_student_id, 'previous_state', v_before)
    )
  where id = p_session_id and school_id = p_school_id
  returning * into v_session;

  return to_jsonb(v_session);
end;
$$;

revoke all on function public.reopen_attendance_session_scoped(
  uuid, uuid, uuid, text, uuid, date, uuid
) from public, anon, authenticated;
grant execute on function public.reopen_attendance_session_scoped(
  uuid, uuid, uuid, text, uuid, date, uuid
) to service_role;

notify pgrst, 'reload schema';
