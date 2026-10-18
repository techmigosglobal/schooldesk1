-- Authorize the selected branch against current persisted role and organization.
-- Recipient, history and idempotency queries retain their exact school boundary.
create function public.notification_principal_has_branch_access(p_school uuid,p_sender uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists (
    select 1 from public.users u
    join public.schools home on home.id=u.school_id
    join public.schools selected on selected.id=p_school
    where u.id=p_sender and u.is_active and lower(u.role_name)='principal'
      and home.organization_id=selected.organization_id
      and (u.school_id=p_school or exists (
        select 1 from public.branch_memberships membership
        where membership.user_id=u.id and membership.school_id=p_school
          and membership.is_active and lower(membership.role_name)='principal'
      ))
  );
$$;
revoke all on function public.notification_principal_has_branch_access(uuid,uuid) from public,anon,authenticated;
grant execute on function public.notification_principal_has_branch_access(uuid,uuid) to service_role;

create or replace function public.notification_recipient_search(p_school uuid,p_sender uuid,p_roles text[],p_search text default '',p_page integer default 1)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
  if not public.notification_principal_has_branch_access(p_school,p_sender) then
    raise exception using errcode='42501', message='Principal access required';
  end if;
  if cardinality(p_roles)=0 or not p_roles <@ array['parent','teacher','coordinator','principal']::text[] then raise exception 'Invalid recipient roles'; end if;
  with eligible as (
    select id,coalesce(nullif(name,''),username,'School user') name,lower(role_name) role_name from users
    where school_id=p_school and is_active and lower(role_name)=any(p_roles)
      and (p_search='' or position(lower(p_search) in lower(coalesce(name,'')||' '||coalesce(username,'')))>0)
  ) select jsonb_build_object('items',coalesce((select jsonb_agg(r) from (
      select * from eligible order by name,id limit 50 offset (greatest(p_page,1)-1)*50) r),'[]'::jsonb),
      'total',(select count(*) from eligible),'page',greatest(p_page,1),'page_size',50) into result;
  return result;
end $$;

create or replace function public.send_notification_broadcast(p_school uuid,p_sender uuid,p_key uuid,p_title text,p_message text,p_roles text[],p_mode text,p_users uuid[] default '{}')
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_selection jsonb; v_existing notification_broadcasts%rowtype; v_id uuid; v_ids uuid[]; r record; v_count integer:=0;
begin
  if not public.notification_principal_has_branch_access(p_school,p_sender) then
    raise exception using errcode='42501', message='Principal access required';
  end if;
  if length(trim(p_title)) not between 1 and 120 or length(trim(p_message)) not between 1 and 2000 then raise exception 'Title or message length is invalid'; end if;
  if cardinality(p_roles)=0 or not p_roles <@ array['parent','teacher','coordinator','principal']::text[] or p_mode not in ('all','selected') then raise exception 'Invalid recipient selection'; end if;
  p_roles := array(select distinct x from unnest(p_roles) x order by x);
  p_users := array(select distinct x from unnest(p_users) x order by x);
  if (p_mode='all' and cardinality(p_users)>0) or (p_mode='selected' and cardinality(p_users)=0) then raise exception 'Invalid recipient selection'; end if;
  v_selection := jsonb_build_object('roles',p_roles,'mode',p_mode,'user_ids',p_users);
  perform pg_advisory_xact_lock(hashtextextended(p_school::text||p_sender::text||p_key::text,0));
  select * into v_existing from notification_broadcasts where school_id=p_school and sender_id=p_sender and idempotency_key=p_key;
  if found then
    if v_existing.title<>trim(p_title) or v_existing.message<>trim(p_message) or v_existing.selection<>v_selection then raise exception 'Idempotency key was already used for different content'; end if;
    return jsonb_build_object('id',v_existing.id,'recipient_count',v_existing.recipient_count,'status','saved','replayed',true);
  end if;
  select array_agg(id order by id) into v_ids from users where school_id=p_school and is_active
    and lower(role_name)=any(p_roles) and (p_mode='all' or id=any(p_users));
  if coalesce(cardinality(v_ids),0)=0 then raise exception 'No active recipients selected'; end if;
  if p_mode='selected' and cardinality(v_ids)<>cardinality(p_users) then raise exception 'Recipient is outside the selected active school roles'; end if;
  insert into notification_broadcasts(school_id,sender_id,title,message,selection,idempotency_key)
    values(p_school,p_sender,trim(p_title),trim(p_message),v_selection,p_key) returning id into v_id;
  for r in select id,lower(role_name) role_name from users where id=any(v_ids) loop
    perform public.schooldesk_queue_notice(p_school,r.id,r.role_name,'custom_notification','notification_broadcast',v_id::text,
      trim(p_title),trim(p_message),'/notification-center-screen',null,null,null,'notification_broadcast',v_id::text,'created');
    v_count := v_count+1;
  end loop;
  update notification_broadcasts set recipient_count=v_count where id=v_id;
  return jsonb_build_object('id',v_id,'recipient_count',v_count,'status','queued','replayed',false);
end $$;

create or replace function public.notification_broadcast_history(p_school uuid,p_sender uuid,p_page integer default 1)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
  if not public.notification_principal_has_branch_access(p_school,p_sender) then
    raise exception using errcode='42501', message='Principal access required';
  end if;
  select jsonb_build_object('items',coalesce(jsonb_agg(x),'[]'::jsonb),'page',greatest(p_page,1),'page_size',20) into result from (
    select b.id,b.title,b.message,b.recipient_count,b.created_at,b.selection->'roles' roles,
      (select jsonb_build_object('queued',count(*) filter(where not e.processed),
        'push_accepted',count(*) filter(where e.delivery_status='sent'),
        'no_device',count(*) filter(where e.delivery_status='deferred_no_device'),
        'failed',count(*) filter(where e.delivery_status in ('invalid_tokens','failed','permanent_failure')),
        'other',count(*) filter(where e.processed and coalesce(e.delivery_status,'') not in ('sent','deferred_no_device','invalid_tokens','failed','permanent_failure')))
       from notification_events e where e.school_id=p_school and e.event_data->>'reference_id'=b.id::text and e.event_type='custom_notification') delivery
    from notification_broadcasts b where b.school_id=p_school and b.sender_id=p_sender
    order by b.created_at desc,b.id desc limit 20 offset (greatest(p_page,1)-1)*20
  ) x;
  return result;
end $$;
revoke all on function public.notification_recipient_search(uuid,uuid,text[],text,integer) from public,anon,authenticated;
revoke all on function public.send_notification_broadcast(uuid,uuid,uuid,text,text,text[],text,uuid[]) from public,anon,authenticated;
revoke all on function public.notification_broadcast_history(uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.notification_recipient_search(uuid,uuid,text[],text,integer) to service_role;
grant execute on function public.send_notification_broadcast(uuid,uuid,uuid,text,text,text[],text,uuid[]) to service_role;
grant execute on function public.notification_broadcast_history(uuid,uuid,integer) to service_role;
notify pgrst,'reload schema';
