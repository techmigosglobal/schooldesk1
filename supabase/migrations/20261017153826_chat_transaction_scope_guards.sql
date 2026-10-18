-- Recheck authorization inside the send transaction as well as at the HTTP boundary.
create or replace function public.schooldesk_assert_chat_send(p_school uuid,p_sender uuid,p_conversation jsonb)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_role text; v_staff uuid; v_teacher uuid:=nullif(p_conversation->>'teacher_id','')::uuid;
 v_parent uuid:=nullif(p_conversation->>'parent_id','')::uuid; v_student uuid:=nullif(p_conversation->>'student_id','')::uuid;
 v_leader uuid:=nullif(coalesce(p_conversation->>'leader_id',p_conversation->>'created_by'),'')::uuid;
 v_type text:=coalesce(p_conversation->>'type','parent_teacher'); v_section uuid;
begin
 select lower(role_name),linked_id into v_role,v_staff from users where id=p_sender and school_id=p_school and is_active for share;
 if not found or v_role not in ('parent','teacher','principal','coordinator','admin','super_admin') then raise exception 'Invalid chat sender'; end if;
 if v_type not in ('parent_teacher','principal_parent','principal_teacher') then raise exception 'Invalid conversation type'; end if;
 if v_student is not null then
  select current_section_id into v_section from students where id=v_student and school_id=p_school for share;
  if not found then raise exception 'Student outside school'; end if;
 end if;
 if v_type in ('parent_teacher','principal_parent') then
  if not exists(select 1 from users where id=v_parent and school_id=p_school and role_name='parent' and is_active)
   or not exists(select 1 from parent_student_links where school_id=p_school and parent_user_id=v_parent and student_id=v_student) then
   raise exception 'Parent must be linked to student'; end if;
 end if;
 if v_type in ('parent_teacher','principal_teacher') then
  if not exists(select 1 from staff where id=v_teacher and school_id=p_school and is_active) then raise exception 'Invalid teacher'; end if;
 end if;
 if v_type='parent_teacher' then
  if not exists(select 1 from sections s where s.id=v_section and s.school_id=p_school and
    (s.class_teacher_id=v_teacher or s.co_teacher_id=v_teacher or exists(select 1 from staff_subjects a where a.school_id=p_school and a.staff_id=v_teacher and a.subject_id is not null
      and (a.academic_year_id is null or a.academic_year_id=s.academic_year_id) and (a.section_id=s.id or a.section_id is null and a.grade_id=s.grade_id)))) then raise exception 'Teacher not assigned to student section'; end if;
 else
  if not exists(select 1 from users where id=v_leader and school_id=p_school and role_name in ('principal','coordinator') and is_active) then raise exception 'Invalid school leader'; end if;
  if v_role in ('principal','coordinator','admin','super_admin') and v_leader<>p_sender then raise exception 'Conversation belongs to another leader'; end if;
 end if;
 if v_role='parent' and (v_type='principal_teacher' or v_parent is distinct from p_sender) then raise exception 'Parent outside conversation'; end if;
 if v_role='teacher' and (v_type='principal_parent' or v_teacher is distinct from v_staff) then raise exception 'Teacher outside conversation'; end if;
end $$;
revoke all on function public.schooldesk_assert_chat_send(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.schooldesk_assert_chat_send(uuid,uuid,jsonb) to service_role;

create or replace function public.schooldesk_send_chat(
  p_school uuid, p_sender uuid, p_client uuid, p_body text,
  p_sender_role text, p_sender_name text, p_conversation jsonb, p_targets jsonb
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare c public.message_conversations%rowtype; m public.messages%rowtype;
  v_id uuid; r jsonb; v_events jsonb:='[]'::jsonb; v_event uuid;
  v_teacher uuid:=nullif(p_conversation->>'teacher_id','')::uuid;
  v_parent uuid:=nullif(p_conversation->>'parent_id','')::uuid;
  v_student uuid:=nullif(p_conversation->>'student_id','')::uuid;
  v_leader uuid:=nullif(p_conversation->>'leader_id','')::uuid;
  v_type text:=coalesce(nullif(p_conversation->>'type',''),'parent_teacher');
begin
  if p_client is null or length(trim(p_body)) not between 1 and 10000 then raise exception 'Invalid chat message'; end if;
  if not exists(select 1 from users where id=p_sender and school_id=p_school and is_active) then raise exception 'Invalid sender'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_school::text||p_sender::text||p_client::text,0));
  select * into m from messages where school_id=p_school and sender_id=p_sender and client_message_id=p_client;
  if found then
    select * into c from message_conversations where id=m.conversation_id and school_id=p_school;
    perform schooldesk_assert_chat_send(p_school,p_sender,to_jsonb(c));
    return jsonb_build_object('message',to_jsonb(m),'conversation',to_jsonb(c),'duplicate',true,'event_ids','[]'::jsonb);
  end if;
  if nullif(p_conversation->>'id','') is null then perform schooldesk_assert_chat_send(p_school,p_sender,p_conversation); end if;
  v_id:=nullif(p_conversation->>'id','')::uuid;
  if v_id is null then
    perform pg_advisory_xact_lock(hashtextextended(p_school::text||v_type||coalesce(v_teacher::text,'')||coalesce(v_parent::text,'')||coalesce(v_student::text,'')||coalesce(v_leader::text,''),1));
    -- Reuse one matching thread deterministically; never merge historical threads.
    select * into c from message_conversations where school_id=p_school and type=v_type
      and teacher_id is not distinct from v_teacher and parent_id is not distinct from v_parent
      and student_id is not distinct from v_student and leader_id is not distinct from v_leader
      order by created_at,id limit 1 for update;
    if not found then
      insert into message_conversations(school_id,type,teacher_id,parent_id,student_id,leader_id,title,section_id,class_label,participant_ids,created_by)
      values(p_school,v_type,v_teacher,v_parent,v_student,v_leader,nullif(p_conversation->>'title',''),
        nullif(p_conversation->>'section_id','')::uuid,nullif(p_conversation->>'class_label',''),
        to_jsonb(array_remove(array[v_teacher,v_parent,v_leader],null)),p_sender) returning * into c;
    end if;
  else
    select * into c from message_conversations where id=v_id and school_id=p_school for update;
    if not found then raise exception 'Conversation not found'; end if;
  end if;
  perform schooldesk_assert_chat_send(p_school,p_sender,to_jsonb(c));
  insert into messages(school_id,conversation_id,sender_id,client_message_id,body,sender_role,sender_name,read_by,sent_at,delivered_at)
    values(p_school,c.id,p_sender,p_client,trim(p_body),p_sender_role,p_sender_name,jsonb_build_array(p_sender),clock_timestamp(),clock_timestamp()) returning * into m;
  update message_conversations set last_message=m.body,last_message_at=m.sent_at,last_sender_id=p_sender,updated_at=m.sent_at
    where id=c.id returning * into c;
  for r in select value from jsonb_array_elements(p_targets) loop
    if r->>'id'=p_sender::text then continue; end if;
    v_event:=schooldesk_queue_notice(p_school,(r->>'id')::uuid,r->>'role','message','chat_message',m.id::text,
      'New message',m.body,r->>'route',c.student_id,c.section_id,c.teacher_id,'conversation',c.id::text,m.id::text,true);
    if v_event is not null then v_events:=v_events||jsonb_build_array(v_event); end if;
  end loop;
  return jsonb_build_object('message',to_jsonb(m),'conversation',to_jsonb(c),'duplicate',false,'event_ids',v_events);
end $$;
revoke all on function public.schooldesk_send_chat(uuid,uuid,uuid,text,text,text,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.schooldesk_send_chat(uuid,uuid,uuid,text,text,text,jsonb,jsonb) to service_role;
