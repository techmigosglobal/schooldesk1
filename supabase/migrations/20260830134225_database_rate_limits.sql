-- Database-backed fixed-window rate limiting for the Edge API.
--
-- Counter rows live outside the Data API schemas and are intentionally not
-- directly readable or writable by browser roles (or by the service role).
-- The only API surface is the service-role-only RPC below, which owns the
-- atomic increment and returns enough metadata to form a Retry-After header.

create schema if not exists schooldesk_internal;

create table schooldesk_internal.rate_limit_buckets (
  bucket_key text not null,
  window_started_at timestamptz not null,
  request_count bigint not null default 0
    check (request_count >= 0),
  updated_at timestamptz not null default clock_timestamp(),
  primary key (bucket_key, window_started_at)
);

alter table schooldesk_internal.rate_limit_buckets enable row level security;
alter table schooldesk_internal.rate_limit_buckets force row level security;

create index rate_limit_buckets_expiry_idx
  on schooldesk_internal.rate_limit_buckets (window_started_at);

-- The internal schema is never exposed through PostgREST.  Keep direct table
-- access closed even for the Edge service role so all mutations use the
-- bounded, validated, atomic RPC.
revoke all on schema schooldesk_internal
  from public, anon, authenticated, service_role;
revoke all on table schooldesk_internal.rate_limit_buckets
  from public, anon, authenticated, service_role;

create or replace function public.consume_rate_limit(
  p_bucket_key text,
  p_limit integer,
  p_window_seconds integer
)
returns table (
  allowed boolean,
  limit_value integer,
  remaining integer,
  reset_at timestamptz,
  retry_after_seconds integer
)
language plpgsql
security definer
set search_path = pg_catalog, pg_temp
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_window_started_at timestamptz;
  v_reset_at timestamptz;
  v_request_count bigint;
begin
  -- The Edge helper hashes identifiers before reaching this boundary.  The
  -- narrow character/size bound also prevents accidental unbounded storage.
  if p_bucket_key is null
    or p_bucket_key !~ '^rl:[A-Za-z][A-Za-z0-9_-]{0,63}:[a-f0-9]{64}$' then
    raise exception using
      errcode = '22023',
      message = 'invalid rate limit key';
  end if;

  if p_limit is null or p_limit < 1 or p_limit > 1000000 then
    raise exception using
      errcode = '22023',
      message = 'invalid rate limit';
  end if;

  if p_window_seconds is null
    or p_window_seconds < 1
    or p_window_seconds > 86400 then
    raise exception using
      errcode = '22023',
      message = 'invalid rate limit window';
  end if;

  v_window_started_at := to_timestamp(
    (
      floor(extract(epoch from v_now) / p_window_seconds) *
      p_window_seconds
    )::double precision
  );
  v_reset_at := v_window_started_at + make_interval(secs => p_window_seconds);

  -- INSERT ... ON CONFLICT serializes callers of a single bucket/window.  A
  -- denied request is deliberately counted too, so an attacker cannot extend
  -- a window by repeatedly retrying after the first rejection.
  insert into schooldesk_internal.rate_limit_buckets as bucket (
    bucket_key,
    window_started_at,
    request_count,
    updated_at
  ) values (
    p_bucket_key,
    v_window_started_at,
    1,
    v_now
  )
  on conflict (bucket_key, window_started_at) do update
  set
    request_count = bucket.request_count + 1,
    updated_at = excluded.updated_at
  returning request_count into v_request_count;

  return query
  select
    v_request_count <= p_limit,
    p_limit,
    greatest(p_limit::bigint - v_request_count, 0)::integer,
    v_reset_at,
    case
      when v_request_count <= p_limit then 0
      else greatest(
        1,
        ceil(extract(epoch from v_reset_at - clock_timestamp()))::integer
      )
    end;
end;
$$;

-- Retention is explicit rather than being performed on every request.  A
-- trusted scheduled job or maintenance endpoint can call this at any cadence
-- without granting direct table access.
create or replace function public.prune_rate_limit_buckets(
  p_retention_seconds integer default 604800
)
returns bigint
language plpgsql
security definer
set search_path = pg_catalog, pg_temp
as $$
declare
  v_deleted bigint;
begin
  if p_retention_seconds is null
    or p_retention_seconds < 60
    or p_retention_seconds > 2592000 then
    raise exception using
      errcode = '22023',
      message = 'invalid rate limit retention';
  end if;

  delete from schooldesk_internal.rate_limit_buckets
  where window_started_at < clock_timestamp() -
    make_interval(secs => p_retention_seconds);
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

-- New functions receive EXECUTE from PUBLIC by default.  The public-schema
-- wrappers are exposed only so the Edge service client can invoke them via
-- PostgREST; no unauthenticated or user JWT can call either RPC.
revoke all on function public.consume_rate_limit(text, integer, integer)
  from public, anon, authenticated;
revoke all on function public.prune_rate_limit_buckets(integer)
  from public, anon, authenticated;
grant execute on function public.consume_rate_limit(text, integer, integer)
  to service_role;
grant execute on function public.prune_rate_limit_buckets(integer)
  to service_role;

comment on table schooldesk_internal.rate_limit_buckets is
  'Private fixed-window API rate limit counters; Edge service RPC only.';
comment on function public.consume_rate_limit(text, integer, integer) is
  'Service-role-only atomic fixed-window rate limiter for the Edge API.';
comment on function public.prune_rate_limit_buckets(integer) is
  'Service-role-only maintenance function for stale rate-limit counter rows.';

-- Audit rows are written by the Edge service after authorization decisions.
-- Browser roles may read them only as school leaders; no browser role may
-- forge, alter, or delete the trail directly.
alter table public.audit_logs enable row level security;
alter table public.audit_logs force row level security;
revoke all on table public.audit_logs from public, anon, authenticated;
grant select on table public.audit_logs to authenticated;
grant all on table public.audit_logs to service_role;
drop policy if exists "audit_logs_school_select" on public.audit_logs;
drop policy if exists "audit_logs_school_insert" on public.audit_logs;
drop policy if exists "audit_logs_school_update" on public.audit_logs;
drop policy if exists "audit_logs_school_delete" on public.audit_logs;
create policy "audit_logs_leader_select" on public.audit_logs
  for select to authenticated
  using (
    school_id = public.auth_school_id()
    and public.auth_role_name() in ('principal', 'admin', 'coordinator', 'super_admin')
  );
