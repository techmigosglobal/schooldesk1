-- Additive chat delivery. Existing conversations remain separate and unchanged.
alter table public.messages add column if not exists client_message_id uuid;
create unique index if not exists messages_sender_client_message_unique
  on public.messages(school_id,sender_id,client_message_id) where client_message_id is not null;
create index if not exists messages_stable_cursor
  on public.messages(school_id,conversation_id,sent_at desc,id desc);

-- Only the authenticated Edge handler (service_role) calls this after scope checks.
-- Both locks are transaction scoped: retries and concurrent first sends serialize.
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
    return jsonb_build_object('message',to_jsonb(m),'conversation',to_jsonb(c),'duplicate',true,'event_ids','[]'::jsonb);
  end if;
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

create or replace function public.schooldesk_read_chat(p_school uuid,p_conversation uuid,p_user uuid,p_through_at timestamptz default null,p_through_id uuid default null)
returns void language sql security definer set search_path=public,pg_temp as $$
  update messages set read_by=coalesce(read_by,'[]'::jsonb)||jsonb_build_array(p_user)
  where school_id=p_school and conversation_id=p_conversation
    and not(coalesce(read_by,'[]'::jsonb) @> jsonb_build_array(p_user))
    and (p_through_at is null or (sent_at,id)<=(p_through_at,p_through_id));
$$;
revoke all on function public.schooldesk_read_chat(uuid,uuid,uuid,timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.schooldesk_read_chat(uuid,uuid,uuid,timestamptz,uuid) to service_role;
-- Exact counts avoid the PostgREST row cap for large inboxes.
create or replace function public.schooldesk_chat_unread(p_school uuid,p_user uuid,p_ids uuid[])
returns table(conversation_id uuid,unread_count bigint) language sql stable security definer set search_path=public,pg_temp as $$
 select m.conversation_id,count(*) from messages m where m.school_id=p_school and m.conversation_id=any(p_ids)
 and m.sender_id is distinct from p_user and not(coalesce(m.read_by,'[]'::jsonb) @> jsonb_build_array(p_user)) group by m.conversation_id;
$$;
revoke all on function public.schooldesk_chat_unread(uuid,uuid,uuid[]) from public,anon,authenticated;
grant execute on function public.schooldesk_chat_unread(uuid,uuid,uuid[]) to service_role;
