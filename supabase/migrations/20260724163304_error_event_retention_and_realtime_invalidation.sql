-- Bound error telemetry growth, retain useful trends, and provide a safe
-- invalidation-only Realtime stream.  Operational records continue to be
-- read and written through the Edge API; no client receives raw fee,
-- attendance, or student rows through Realtime.

alter table public.error_events
  add column if not exists severity text not null default 'error',
  add column if not exists status text not null default 'open',
  add column if not exists fingerprint text,
  add column if not exists occurrence_count integer not null default 1,
  add column if not exists first_seen_at timestamptz not null default now(),
  add column if not exists last_seen_at timestamptz not null default now(),
  add column if not exists resolved_at timestamptz,
  add column if not exists resolved_by uuid references public.users(id) on delete set null,
  add column if not exists resolution_note text;

update public.error_events
set
  severity = case
    when coalesce(context ->> 'severity', '') in ('info', 'warning', 'error', 'fatal')
      then context ->> 'severity'
    else severity
  end,
  status = case
    when coalesce(context ->> 'status', '') in ('open', 'resolved')
      then context ->> 'status'
    else status
  end,
  first_seen_at = created_at,
  last_seen_at = created_at,
  resolved_at = nullif(context ->> 'resolved_at', '')::timestamptz,
  resolved_by = case
    when coalesce(context ->> 'resolved_by', '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      then (context ->> 'resolved_by')::uuid
    else null
  end,
  resolution_note = nullif(context ->> 'resolution_note', '')
where first_seen_at = created_at and last_seen_at = created_at;

alter table public.error_events
  drop constraint if exists error_events_severity_check,
  add constraint error_events_severity_check
    check (severity in ('info', 'warning', 'error', 'fatal')),
  drop constraint if exists error_events_status_check,
  add constraint error_events_status_check
    check (status in ('open', 'resolved')),
  drop constraint if exists error_events_occurrence_count_check,
  add constraint error_events_occurrence_count_check
    check (occurrence_count >= 1);

create unique index if not exists idx_error_events_school_fingerprint
  on public.error_events(school_id, fingerprint)
  where fingerprint is not null;
create index if not exists idx_error_events_school_status_last_seen
  on public.error_events(school_id, status, last_seen_at desc);
create index if not exists idx_error_events_retention
  on public.error_events(school_id, severity, status, last_seen_at);

create table if not exists public.error_event_retention_settings (
  school_id uuid primary key references public.schools(id) on delete cascade,
  warning_keep_days integer not null default 14
    check (warning_keep_days between 7 and 30),
  resolved_keep_days integer not null default 30
    check (resolved_keep_days between 14 and 180),
  resolved_fatal_keep_days integer not null default 90
    check (resolved_fatal_keep_days between 30 and 365),
  max_raw_events integer not null default 10000
    check (max_raw_events between 1000 and 100000),
  updated_by uuid references public.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table public.error_event_retention_settings enable row level security;

create table if not exists public.error_event_daily_summaries (
  school_id uuid not null references public.schools(id) on delete cascade,
  occurred_on date not null,
  severity text not null check (severity in ('info', 'warning', 'error', 'fatal')),
  fingerprint text not null,
  occurrence_count bigint not null default 0,
  unique_users_count integer not null default 0,
  primary key (school_id, occurred_on, severity, fingerprint)
);
alter table public.error_event_daily_summaries enable row level security;

-- This schema is not exposed through the Data API.  Functions are invoked
-- only by the service-role Edge API or pg_cron; direct public execution is
-- explicitly revoked below.
create schema if not exists schooldesk_internal;

create or replace function schooldesk_internal.record_error_event(
  p_school_id uuid,
  p_user_id uuid,
  p_message text,
  p_error_type text,
  p_stack_trace text,
  p_context jsonb,
  p_severity text,
  p_fingerprint text
) returns public.error_events
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  saved public.error_events;
begin
  insert into public.error_events (
    school_id, user_id, message, error_type, stack_trace, context, severity,
    status, fingerprint, occurrence_count, first_seen_at, last_seen_at
  ) values (
    p_school_id,
    p_user_id,
    left(coalesce(p_message, ''), 2048),
    left(coalesce(p_error_type, ''), 256),
    left(coalesce(p_stack_trace, ''), 12288),
    coalesce(p_context, '{}'::jsonb),
    case when p_severity in ('info', 'warning', 'error', 'fatal') then p_severity else 'error' end,
    'open',
    nullif(left(coalesce(p_fingerprint, ''), 128), ''),
    1,
    now(),
    now()
  )
  on conflict (school_id, fingerprint) where fingerprint is not null do update
  set
    user_id = excluded.user_id,
    message = excluded.message,
    error_type = excluded.error_type,
    stack_trace = excluded.stack_trace,
    context = excluded.context,
    severity = excluded.severity,
    status = 'open',
    occurrence_count = public.error_events.occurrence_count + 1,
    last_seen_at = now(),
    resolved_at = null,
    resolved_by = null,
    resolution_note = null
  returning * into saved;
  return saved;
end;
$$;

create or replace function schooldesk_internal.error_event_retention_metrics(
  p_school_id uuid
) returns jsonb
language sql
security definer
set search_path = public, pg_temp
as $$
  with settings as (
    select * from public.error_event_retention_settings where school_id = p_school_id
  ), stats as (
    select
      count(*)::bigint as total_events,
      count(*) filter (where status = 'open')::bigint as open_events,
      count(*) filter (where status = 'resolved')::bigint as resolved_events,
      coalesce(sum(pg_column_size(e)), 0)::bigint as storage_bytes,
      count(*) filter (
        where status = 'resolved'
          and coalesce(last_seen_at, created_at) <= now() - interval '30 days'
      )::bigint as cleanup_eligible
    from public.error_events e where e.school_id = p_school_id
  )
  select jsonb_build_object(
    'settings', coalesce((select to_jsonb(settings) - 'school_id' - 'updated_by' from settings),
      jsonb_build_object('warning_keep_days', 14, 'resolved_keep_days', 30,
        'resolved_fatal_keep_days', 90, 'max_raw_events', 10000)),
    'total_events', stats.total_events,
    'open_events', stats.open_events,
    'resolved_events', stats.resolved_events,
    'storage_bytes', stats.storage_bytes,
    'cleanup_eligible', stats.cleanup_eligible
  ) from stats;
$$;

create or replace function schooldesk_internal.cleanup_resolved_error_events(
  p_school_id uuid,
  p_before timestamptz,
  p_severity text default null,
  p_preview boolean default true
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  result jsonb;
begin
  if p_preview then
    select jsonb_build_object(
      'deleted_count', count(*)::bigint,
      'deleted_bytes', coalesce(sum(pg_column_size(e)), 0)::bigint
    ) into result
    from public.error_events e
    where e.school_id = p_school_id
      and e.status = 'resolved'
      and coalesce(e.last_seen_at, e.created_at) <= p_before
      and (p_severity is null or e.severity = p_severity);
    return result;
  end if;

  with deleted as (
    delete from public.error_events e
    where e.school_id = p_school_id
      and e.status = 'resolved'
      and coalesce(e.last_seen_at, e.created_at) <= p_before
      and (p_severity is null or e.severity = p_severity)
    returning pg_column_size(e)::bigint as row_bytes
  )
  select jsonb_build_object(
    'deleted_count', count(*)::bigint,
    'deleted_bytes', coalesce(sum(row_bytes), 0)::bigint
  ) into result from deleted;
  return result;
end;
$$;

create or replace function schooldesk_internal.enforce_error_event_retention()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- Keep aggregate trends before deleting raw records.  Recent summary rows
  -- are recomputed so deduplicated occurrence counters remain accurate.
  delete from public.error_event_daily_summaries
  where occurred_on >= current_date - 120;
  insert into public.error_event_daily_summaries (
    school_id, occurred_on, severity, fingerprint, occurrence_count, unique_users_count
  )
  select
    school_id,
    coalesce(last_seen_at, created_at)::date,
    severity,
    coalesce(fingerprint, 'legacy:' || id::text),
    sum(occurrence_count)::bigint,
    count(distinct user_id)::integer
  from public.error_events
  where coalesce(last_seen_at, created_at)::date >= current_date - 120
  group by school_id, coalesce(last_seen_at, created_at)::date, severity,
    coalesce(fingerprint, 'legacy:' || id::text)
  on conflict (school_id, occurred_on, severity, fingerprint) do update
  set occurrence_count = excluded.occurrence_count,
      unique_users_count = excluded.unique_users_count;

  -- Defaults apply until a Super Admin saves a school-specific configuration.
  delete from public.error_events e
  using public.error_event_retention_settings s
  where e.school_id = s.school_id
    and e.severity in ('info', 'warning')
    and coalesce(e.last_seen_at, e.created_at) < now() - make_interval(days => s.warning_keep_days);

  delete from public.error_events e
  using public.error_event_retention_settings s
  where e.school_id = s.school_id
    and e.status = 'resolved'
    and e.severity <> 'fatal'
    and coalesce(e.last_seen_at, e.created_at) < now() - make_interval(days => s.resolved_keep_days);

  delete from public.error_events e
  using public.error_event_retention_settings s
  where e.school_id = s.school_id
    and e.status = 'resolved'
    and e.severity = 'fatal'
    and coalesce(e.last_seen_at, e.created_at) < now() - make_interval(days => s.resolved_fatal_keep_days);

  -- Enforce the hard cap without ever deleting open or fatal events.
  with settings as (
    select s.id as school_id, coalesce(r.max_raw_events, 10000) as max_raw_events
    from public.schools s
    left join public.error_event_retention_settings r on r.school_id = s.id
  ), counts as (
    select e.school_id, count(*)::integer as total_events
    from public.error_events e join settings s on s.school_id = e.school_id
    group by e.school_id
  ), candidates as (
    select e.id, e.school_id,
      row_number() over (partition by e.school_id order by coalesce(e.last_seen_at, e.created_at)) as candidate_rank,
      greatest(c.total_events - s.max_raw_events, 0) as overage
    from public.error_events e
    join settings s on s.school_id = e.school_id
    join counts c on c.school_id = e.school_id
    where e.status = 'resolved' and e.severity <> 'fatal'
  )
  delete from public.error_events e using candidates c
  where e.id = c.id and c.candidate_rank <= c.overage;

  -- Schools that have not saved settings still receive safe defaults.
  delete from public.error_events e
  where not exists (
    select 1 from public.error_event_retention_settings s where s.school_id = e.school_id
  ) and (
    (e.severity in ('info', 'warning') and coalesce(e.last_seen_at, e.created_at) < now() - interval '14 days')
    or (e.status = 'resolved' and e.severity <> 'fatal' and coalesce(e.last_seen_at, e.created_at) < now() - interval '30 days')
    or (e.status = 'resolved' and e.severity = 'fatal' and coalesce(e.last_seen_at, e.created_at) < now() - interval '90 days')
  );
end;
$$;

-- Public-schema wrappers are required for PostgREST RPC, but are not granted
-- to browser roles.  Only the service role used by the Edge API can execute.
create or replace function public.record_error_event(
  p_school_id uuid, p_user_id uuid, p_message text, p_error_type text,
  p_stack_trace text, p_context jsonb, p_severity text, p_fingerprint text
) returns public.error_events
language sql security definer set search_path = public, schooldesk_internal, pg_temp
as $$select schooldesk_internal.record_error_event($1, $2, $3, $4, $5, $6, $7, $8);$$;

create or replace function public.error_event_retention_metrics(p_school_id uuid)
returns jsonb language sql security definer set search_path = public, schooldesk_internal, pg_temp
as $$select schooldesk_internal.error_event_retention_metrics($1);$$;

create or replace function public.cleanup_resolved_error_events(
  p_school_id uuid, p_before timestamptz, p_severity text default null,
  p_preview boolean default true
) returns jsonb language sql security definer set search_path = public, schooldesk_internal, pg_temp
as $$select schooldesk_internal.cleanup_resolved_error_events($1, $2, $3, $4);$$;

revoke all on function schooldesk_internal.record_error_event(uuid, uuid, text, text, text, jsonb, text, text) from public;
revoke all on function schooldesk_internal.error_event_retention_metrics(uuid) from public;
revoke all on function schooldesk_internal.cleanup_resolved_error_events(uuid, timestamptz, text, boolean) from public;
revoke all on function schooldesk_internal.enforce_error_event_retention() from public;
revoke all on function public.record_error_event(uuid, uuid, text, text, text, jsonb, text, text) from public;
revoke all on function public.error_event_retention_metrics(uuid) from public;
revoke all on function public.cleanup_resolved_error_events(uuid, timestamptz, text, boolean) from public;
grant execute on function public.record_error_event(uuid, uuid, text, text, text, jsonb, text, text) to service_role;
grant execute on function public.error_event_retention_metrics(uuid) to service_role;
grant execute on function public.cleanup_resolved_error_events(uuid, timestamptz, text, boolean) to service_role;

do $$
begin
  perform cron.unschedule('enforce-error-event-retention');
exception when others then null;
end $$;
select cron.schedule(
  'enforce-error-event-retention',
  '30 2 * * *',
  $$select schooldesk_internal.enforce_error_event_retention();$$
);

-- Realtime transport deliberately has no business payload.  A changed module
-- prompts the existing secured API to refresh the visible screen.
create table if not exists public.realtime_invalidation_events (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  recipient_user_id uuid references public.users(id) on delete cascade,
  target_roles text[] not null default '{}',
  module text not null,
  event_type text not null default 'changed',
  created_at timestamptz not null default now()
);
alter table public.realtime_invalidation_events enable row level security;
create index if not exists idx_realtime_invalidations_school_created
  on public.realtime_invalidation_events(school_id, created_at desc);
create index if not exists idx_realtime_invalidations_recipient_created
  on public.realtime_invalidation_events(recipient_user_id, created_at desc)
  where recipient_user_id is not null;

create policy "realtime_invalidations_scoped_select"
on public.realtime_invalidation_events for select to authenticated
using (
  recipient_user_id = auth.uid()
  or (
    recipient_user_id is null
    and school_id = public.auth_school_id()
    and (
      cardinality(target_roles) = 0
      or public.auth_role_name() = any(target_roles)
    )
  )
);

create or replace function schooldesk_internal.publish_school_invalidation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  record_school_id uuid;
  record_module text := tg_argv[0];
  record_event text := lower(tg_op);
  publish_to_all boolean := true;
  author_id uuid;
begin
  record_school_id := case when tg_op = 'DELETE' then old.school_id else new.school_id end;
  if record_module in ('announcements', 'event_posts') then
    publish_to_all := case when tg_op = 'DELETE'
      then coalesce(old.status, 'draft') = 'published'
      else coalesce(new.status, 'draft') = 'published'
    end;
    author_id := case when tg_op = 'DELETE' then old.created_by else new.created_by end;
  end if;
  if record_module = 'notifications' then
    author_id := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
    publish_to_all := false;
  end if;
  if publish_to_all then
    insert into public.realtime_invalidation_events(school_id, module, event_type)
    values (record_school_id, record_module, record_event);
  elsif author_id is not null then
    insert into public.realtime_invalidation_events(school_id, recipient_user_id, module, event_type)
    values (record_school_id, author_id, record_module, record_event);
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function schooldesk_internal.publish_school_invalidation() from public;

drop trigger if exists trg_realtime_announcements on public.announcements;
create trigger trg_realtime_announcements after insert or update or delete
on public.announcements for each row
execute function schooldesk_internal.publish_school_invalidation('announcements');
drop trigger if exists trg_realtime_event_posts on public.event_posts;
create trigger trg_realtime_event_posts after insert or update or delete
on public.event_posts for each row
execute function schooldesk_internal.publish_school_invalidation('event_posts');
drop trigger if exists trg_realtime_attendance_sessions on public.attendance_sessions;
create trigger trg_realtime_attendance_sessions after insert or update or delete
on public.attendance_sessions for each row
execute function schooldesk_internal.publish_school_invalidation('attendance');
drop trigger if exists trg_realtime_fee_invoices on public.fee_invoices;
create trigger trg_realtime_fee_invoices after insert or update or delete
on public.fee_invoices for each row
execute function schooldesk_internal.publish_school_invalidation('fees');
drop trigger if exists trg_realtime_payments on public.payments;
create trigger trg_realtime_payments after insert or update or delete
on public.payments for each row
execute function schooldesk_internal.publish_school_invalidation('fees');
drop trigger if exists trg_realtime_parent_payment_requests on public.parent_payment_requests;
create trigger trg_realtime_parent_payment_requests after insert or update or delete
on public.parent_payment_requests for each row
execute function schooldesk_internal.publish_school_invalidation('fees');
drop trigger if exists trg_realtime_notification_logs on public.notification_logs;
create trigger trg_realtime_notification_logs after insert or update or delete
on public.notification_logs for each row
execute function schooldesk_internal.publish_school_invalidation('notifications');

alter table public.realtime_invalidation_events replica identity full;
alter publication supabase_realtime add table public.realtime_invalidation_events;

do $$
begin
  perform cron.unschedule('purge-realtime-invalidations');
exception when others then null;
end $$;
select cron.schedule(
  'purge-realtime-invalidations',
  '45 2 * * *',
  $$delete from public.realtime_invalidation_events where created_at < now() - interval '7 days';$$
);
