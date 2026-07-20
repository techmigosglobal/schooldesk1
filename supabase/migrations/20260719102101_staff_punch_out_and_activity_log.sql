-- Teacher attendance now records a complete attendance window, while
-- user_sessions tracks portal sessions without retaining sensitive tokens.
alter table public.staff_attendances
  add column if not exists check_out_source text,
  add column if not exists check_out_marked_by uuid references public.users(id) on delete set null,
  add column if not exists check_out_notes text;

alter table public.user_sessions
  add column if not exists school_id uuid references public.schools(id) on delete cascade,
  add column if not exists role_name text,
  add column if not exists session_type text not null default 'app',
  add column if not exists signed_out_at timestamptz;

-- This table must never retain reusable credentials.
update public.user_sessions
set refresh_token = null
where refresh_token is not null;

create index if not exists idx_user_sessions_open_by_user
  on public.user_sessions(user_id, signed_out_at, created_at desc);

-- The existing audit table is retained and extended with display-ready,
-- non-sensitive activity metadata.
alter table public.audit_logs
  add column if not exists module text,
  add column if not exists event_type text,
  add column if not exists summary text,
  add column if not exists actor_role text,
  add column if not exists actor_name text;

update public.audit_logs
set event_type = coalesce(nullif(event_type, ''), action),
    summary = coalesce(nullif(summary, ''), action),
    module = coalesce(nullif(module, ''), entity_type, 'system')
where event_type is null or summary is null or module is null;

create index if not exists idx_audit_logs_school_filters
  on public.audit_logs(school_id, created_at desc, module, event_type);
