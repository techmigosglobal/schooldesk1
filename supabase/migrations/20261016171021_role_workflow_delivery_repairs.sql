-- Additive client contract and transactional inbox/outbox for reported workflows.
alter table public.schools add column if not exists display_name text;
alter table public.issues drop constraint if exists issues_raised_by_role_check;
alter table public.issues add constraint issues_raised_by_role_check
  check (raised_by_role in ('principal','coordinator','teacher','parent'));
alter table public.issues add column if not exists delivery_ready boolean not null default true;

create or replace function public.schooldesk_queue_notice(
  p_school uuid, p_user uuid, p_role text, p_type text, p_entity text,
  p_entity_id text, p_title text, p_body text, p_route text,
  p_student uuid, p_section uuid, p_teacher uuid, p_reference_type text,
  p_reference_id text, p_revision text, p_push boolean default true
) returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare v_event uuid; v_notice uuid;
begin
  if not exists(select 1 from public.users where id=p_user and school_id=p_school and is_active=true) then
    raise exception 'Notification recipient is outside the active school';
  end if;
  insert into public.notification_logs(school_id,user_id,target_role,title,body,type,
    entity_type,entity_id,route,student_id,section_id,teacher_id,reference_type,reference_id,priority,is_read)
  values(p_school,p_user,p_role,p_title,p_body,
    case when p_type='homework_feedback' then 'homework' when p_type='health_reminder' then 'health' else p_type end,
    p_entity,p_entity_id,p_route,p_student,p_section,p_teacher,p_reference_type,p_reference_id,'high',false)
  on conflict(user_id,entity_type,entity_id) do update set
    title=excluded.title,body=excluded.body,route=excluded.route,reference_type=excluded.reference_type,
    reference_id=excluded.reference_id,student_id=excluded.student_id,section_id=excluded.section_id,
    teacher_id=excluded.teacher_id,is_read=false,deleted_at=null,created_at=now() returning id into v_notice;
  if p_push then
    insert into public.notification_events(school_id,user_id,event_type,dedupe_key,event_data)
    values(p_school,p_user,p_type,
      p_type||':'||p_user||':'||p_entity_id||':'||p_revision,
      jsonb_build_object('title',p_title,'message',p_body,'route',p_route,'notification_id',v_notice,
        'reference_type',p_reference_type,'reference_id',p_reference_id,
        'student_id',p_student,'section_id',p_section,'teacher_id',p_teacher,
        'homework_id',case when p_type='homework_feedback' then p_reference_id else null end,
        'health_reminder_id',case when p_type='health_reminder' then p_entity_id else null end))
    on conflict(dedupe_key) where dedupe_key is not null do nothing returning id into v_event;
  end if;
  return v_event;
end $$;
revoke all on function public.schooldesk_queue_notice(uuid,uuid,text,text,text,text,text,text,text,uuid,uuid,uuid,text,text,text,boolean) from public,anon,authenticated;
grant execute on function public.schooldesk_queue_notice(uuid,uuid,text,text,text,text,text,text,text,uuid,uuid,uuid,text,text,text,boolean) to service_role;

create or replace function public.schooldesk_workflow_notice() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare r record; v_section uuid; v_student uuid; v_title text; v_body text; v_route text;
begin
  if tg_table_name='issues' then
    if not new.delivery_ready then return new; end if;
    if tg_op='UPDATE' then
      if old.delivery_ready and new.status is not distinct from old.status then return new; end if;
    end if;
    if tg_op='INSERT' or (tg_op='UPDATE' and not old.delivery_ready) then
      for r in select id,role_name from public.users where school_id=new.school_id and role_name='super_admin' and is_active=true loop
        perform public.schooldesk_queue_notice(new.school_id,r.id,r.role_name,'issue','issue',new.id::text,
          'New issue raised',new.title,'/super-admin-issues-screen',null,null,null,'issue',new.id::text,'created');
      end loop;
    else
      v_route := case new.raised_by_role when 'parent' then '/parent-complaints-screen' when 'teacher' then '/teacher-complaints-screen' else '/complaint-management-screen' end;
      perform public.schooldesk_queue_notice(new.school_id,new.raised_by,new.raised_by_role,'issue','issue',new.id::text,
        'Issue '||replace(new.status,'_',' '),coalesce(nullif(new.resolution_note,''),new.title),v_route,
        null,null,null,'issue',new.id::text,new.status||':'||new.updated_at::text);
    end if;
  elsif tg_table_name='homework_submissions' then
    if new.status not in ('reviewed','needs_revision') or nullif(trim(new.teacher_feedback),'') is null then return new; end if;
    if tg_op='UPDATE' then
      if new.status is not distinct from old.status and new.teacher_feedback is not distinct from old.teacher_feedback then return new; end if;
    end if;
    select current_section_id into v_section from public.students where id=new.student_id and school_id=new.school_id;
    for r in select u.id,u.role_name from public.parent_student_links l join public.users u on u.id=l.parent_user_id and u.school_id=l.school_id
      where l.school_id=new.school_id and l.student_id=new.student_id and u.is_active=true loop
      perform public.schooldesk_queue_notice(new.school_id,r.id,'parent','homework_feedback','homework_feedback',new.id::text,
        case when new.status='reviewed' then 'Diary reviewed' else 'Diary needs revision' end,
        new.teacher_feedback,'/parent-homework-screen/submit',new.student_id,v_section,null,'homework',new.homework_id::text,new.updated_at::text);
    end loop;
  elsif tg_table_name='health_reminders' then
    if not new.is_active then return new; end if;
    if tg_op='UPDATE' and to_jsonb(new)-'updated_at' = to_jsonb(old)-'updated_at' then return new; end if;
    select current_section_id, concat_ws(' ',first_name,last_name) into v_section,v_title from public.students where id=new.student_id and school_id=new.school_id;
    v_body := concat_ws(' - ',v_title,nullif(new.condition,''),nullif(new.medication,''),nullif(new.dosage,''),nullif(new.reminder_time,''));
    for r in select distinct u.id,u.role_name,u.linked_id from public.users u
      left join public.sections s on s.school_id=u.school_id and s.id=v_section
      where u.school_id=new.school_id and u.is_active=true and
        (u.role_name in ('principal','coordinator') or (u.role_name='teacher' and
          (u.linked_id in (s.class_teacher_id,s.co_teacher_id) or u.id in (s.class_teacher_id,s.co_teacher_id)))) loop
      perform public.schooldesk_queue_notice(new.school_id,r.id,r.role_name,'health_reminder','health_reminder',new.id::text,
        'Health Reminder',v_body,'/notification-center-screen',new.student_id,v_section,
        case when r.role_name='teacher' then r.linked_id else null end,'health_reminder',new.id::text,
        new.created_at::text||':'||md5(to_jsonb(new)::text));
    end loop;
  end if;
  return new;
end $$;
revoke all on function public.schooldesk_workflow_notice() from public,anon,authenticated;
create trigger schooldesk_issue_delivery after insert or update on public.issues for each row execute function public.schooldesk_workflow_notice();
create trigger schooldesk_review_delivery after insert or update on public.homework_submissions for each row execute function public.schooldesk_workflow_notice();
create trigger schooldesk_health_delivery after insert or update on public.health_reminders for each row execute function public.schooldesk_workflow_notice();
notify pgrst,'reload schema';

-- Aggregate inside PostgreSQL; a REST row limit must never truncate history.
create or replace function public.parent_attendance_overview(p_school uuid,p_students uuid[])
returns table(student_id uuid,attendance_pct numeric,attendance_today jsonb)
language sql stable security definer set search_path=public,pg_temp as $$
  with day as (select (now() at time zone coalesce(timezone,'Asia/Kolkata'))::date d from schools where id=p_school),
  marks as (
    select a.student_id,a.status,a.marked_at,s.id session_id,s.date,s.is_finalized,y.is_current
    from student_attendances a join attendance_sessions s on s.id=a.session_id
    join academic_years y on y.id=s.academic_year_id and y.school_id=s.school_id
    where s.school_id=p_school and a.student_id=any(p_students) and s.period_number=1
  )
  select child.id,
    (select round(100.0*count(*) filter(where lower(m.status) in ('present','p','late','l','excused','e'))/nullif(count(*),0),2)
      from marks m where m.student_id=child.id and m.is_current and m.is_finalized),
    coalesce((select jsonb_build_object('date',m.date,'status',m.status,'is_finalized',m.is_finalized,'session_id',m.session_id)
      from marks m,day where m.student_id=child.id and m.date=day.d order by m.marked_at desc nulls last,m.session_id limit 1),
      jsonb_build_object('date',(select d from day),'status',null,'is_finalized',false,'session_id',null))
  from students child where child.school_id=p_school and child.id=any(p_students);
$$;
revoke all on function public.parent_attendance_overview(uuid,uuid[]) from public,anon,authenticated;
grant execute on function public.parent_attendance_overview(uuid,uuid[]) to service_role;

create or replace function public.attendance_roster(p_school uuid,p_section uuid,p_year uuid,p_date date)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare v_items jsonb;
begin
  if exists(
    select 1 from enrollments e where e.school_id=p_school and e.academic_year_id=p_year
    and (e.created_at at time zone 'Asia/Kolkata')::date<=p_date
    and e.created_at=(select max(x.created_at) from enrollments x where x.school_id=e.school_id and x.student_id=e.student_id
      and x.academic_year_id=p_year and (x.created_at at time zone 'Asia/Kolkata')::date<=p_date)
    group by e.student_id having count(distinct e.section_id)>1
  ) then raise exception 'Historical class membership is ambiguous; ask school leadership to verify enrollments'; end if;
  with latest as (
    select distinct on(e.student_id) e.* from enrollments e where e.school_id=p_school and e.academic_year_id=p_year
      and (e.created_at at time zone 'Asia/Kolkata')::date<=p_date order by e.student_id,e.created_at desc,e.id
  ), roster as (
    select e.student_id,e.id enrollment_id from latest e where e.section_id=p_section and e.status in ('active','transferred','completed')
    union
    select a.student_id,a.enrollment_id from student_attendances a join attendance_sessions s on s.id=a.session_id
      where s.school_id=p_school and s.section_id=p_section and s.academic_year_id=p_year and s.date=p_date and s.period_number=1
  )
  select coalesce(jsonb_agg(to_jsonb(s)||jsonb_build_object('active_enrollment_id',r.enrollment_id) order by s.first_name,s.id),'[]'::jsonb)
    into v_items from roster r join students s on s.id=r.student_id and s.school_id=p_school;
  return jsonb_build_object('items',v_items);
end $$;
revoke all on function public.attendance_roster(uuid,uuid,uuid,date) from public,anon,authenticated;
grant execute on function public.attendance_roster(uuid,uuid,uuid,date) to service_role;

-- Withdrawn reminders must not remain actionable in the inbox or retry queue.
create or replace function public.schooldesk_cancel_workflow_notice() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id text; v_school uuid;
begin
  if tg_op='UPDATE' then
    if new.is_active then return new; end if;
    v_id:=new.id::text; v_school:=new.school_id;
  else v_id:=old.id::text; v_school:=old.school_id;
  end if;
  update notification_logs set deleted_at=now(),is_read=true where school_id=v_school and entity_id=v_id
    and entity_type=case when tg_table_name='issues' then 'issue' else 'health_reminder' end;
  update notification_events set processed=true,processing_state='completed',delivery_status='cancelled',
    processing_lease_until=null where school_id=v_school and event_data->>'reference_id'=v_id and processed=false;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
revoke all on function public.schooldesk_cancel_workflow_notice() from public,anon,authenticated;
create trigger schooldesk_health_withdrawal after update or delete on public.health_reminders for each row execute function public.schooldesk_cancel_workflow_notice();
create trigger schooldesk_issue_withdrawal after delete on public.issues for each row execute function public.schooldesk_cancel_workflow_notice();

-- A repairable read-side reconciliation: no FCM events are generated for history.
create or replace function public.reconcile_workflow_inboxes(p_school uuid) returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare r record; v_count integer:=0;
begin
  for r in select h.*,l.parent_user_id from homework_submissions h
    join parent_student_links l on l.school_id=h.school_id and l.student_id=h.student_id
    join users u on u.id=l.parent_user_id and u.school_id=h.school_id and u.is_active
    where h.school_id=p_school and h.status in ('reviewed','needs_revision') and nullif(trim(h.teacher_feedback),'') is not null
    and not exists(select 1 from notification_logs n where n.school_id=h.school_id and n.user_id=l.parent_user_id
      and n.deleted_at is null and n.body=h.teacher_feedback and
      ((n.entity_type='homework_feedback' and n.entity_id=h.id::text) or
       (n.entity_type='homework' and n.entity_id=h.homework_id::text and n.student_id=h.student_id))) loop
    perform public.schooldesk_queue_notice(p_school,r.parent_user_id,'parent','homework_feedback','homework_feedback',r.id::text,
      'Diary reviewed',r.teacher_feedback,'/parent-homework-screen/submit',r.student_id,null,null,'homework',r.homework_id::text,r.updated_at::text,false);
    v_count:=v_count+1;
  end loop;
  for r in select h.*,u.id recipient_id,u.role_name,u.linked_id,st.current_section_id,
    concat_ws(' ',st.first_name,st.last_name) student_name
    from health_reminders h join students st on st.id=h.student_id and st.school_id=h.school_id
    left join sections s on s.id=st.current_section_id and s.school_id=h.school_id
    join users u on u.school_id=h.school_id and u.is_active and (u.role_name in ('principal','coordinator') or
      (u.role_name='teacher' and u.linked_id in(s.class_teacher_id,s.co_teacher_id)))
    join schools sc on sc.id=h.school_id
    where h.school_id=p_school and h.is_active and h.reminder_date=(now() at time zone sc.timezone)::date
    and not exists(select 1 from notification_logs n where n.school_id=h.school_id and n.user_id=u.id
      and n.entity_type='health_reminder' and n.entity_id=h.id::text and n.deleted_at is null) loop
    perform public.schooldesk_queue_notice(p_school,r.recipient_id,r.role_name,'health_reminder','health_reminder',r.id::text,
      'Health Reminder',concat_ws(' - ',r.student_name,r.condition,r.medication,r.dosage,r.reminder_time),'/notification-center-screen',
      r.student_id,r.current_section_id,case when r.role_name='teacher' then r.linked_id else null end,'health_reminder',r.id::text,'repair',false);
    v_count:=v_count+1;
  end loop;
  return v_count;
end $$;
revoke all on function public.reconcile_workflow_inboxes(uuid) from public,anon,authenticated;
grant execute on function public.reconcile_workflow_inboxes(uuid) to service_role;
