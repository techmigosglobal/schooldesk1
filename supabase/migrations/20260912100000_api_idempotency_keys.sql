-- Offline replay sends the same mutation more than once when a connection
-- drops after the server commits. Keep the replay contract at the API
-- boundary so business handlers do not need to implement it independently.
create table if not exists public.api_idempotency_keys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  idempotency_key text not null,
  method text not null,
  path text not null,
  request_hash text not null,
  state text not null default 'processing'
    check (state in ('processing', 'completed')),
  response_status integer,
  response_body text,
  response_content_type text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint api_idempotency_keys_key_length
    check (char_length(idempotency_key) between 8 and 200),
  constraint api_idempotency_keys_response_pair
    check (
      (state = 'processing' and response_status is null) or
      (state = 'completed' and response_status is not null)
    )
);

create unique index if not exists api_idempotency_keys_user_key_idx
  on public.api_idempotency_keys (user_id, school_id, idempotency_key);

create index if not exists api_idempotency_keys_created_at_idx
  on public.api_idempotency_keys (created_at);

alter table public.api_idempotency_keys enable row level security;
alter table public.api_idempotency_keys force row level security;
revoke all on public.api_idempotency_keys from anon, authenticated;
revoke all on public.api_idempotency_keys from public;
grant select, insert, update, delete on public.api_idempotency_keys to service_role;

comment on table public.api_idempotency_keys is
  'Service-role API replay ledger for client mutations carrying Idempotency-Key.';
