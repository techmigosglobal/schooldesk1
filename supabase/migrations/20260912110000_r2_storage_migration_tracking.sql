-- R2 migration state is operational metadata, not application data. It is
-- intentionally isolated from the public Data API and is service-role only.
create schema if not exists schooldesk_internal;

create table if not exists schooldesk_internal.storage_migration_batches (
  id uuid primary key default gen_random_uuid(),
  mode text not null check (mode in ('inventory', 'copy', 'verify', 'rewrite')),
  source_provider text not null default 'supabase_storage',
  destination_provider text not null default 'cloudflare_r2',
  status text not null default 'pending' check (status in (
    'pending', 'running', 'completed', 'failed', 'cancelled'
  )),
  started_at timestamptz,
  completed_at timestamptz,
  object_count bigint not null default 0,
  completed_count bigint not null default 0,
  failed_count bigint not null default 0,
  source_bytes bigint not null default 0,
  destination_bytes bigint not null default 0,
  report jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists schooldesk_internal.storage_migration_items (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references schooldesk_internal.storage_migration_batches(id)
    on delete cascade,
  source_bucket text not null,
  source_key text not null,
  destination_bucket text not null,
  destination_key text not null,
  visibility text not null check (visibility in ('private', 'public')),
  status text not null default 'pending' check (status in (
    'pending', 'copying', 'verified', 'failed', 'skipped'
  )),
  attempts integer not null default 0,
  source_size bigint,
  destination_size bigint,
  source_sha256 text,
  destination_sha256 text,
  metadata jsonb not null default '{}'::jsonb,
  error text,
  last_attempt_at timestamptz,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source_bucket, source_key)
);

create index if not exists storage_migration_items_batch_status_idx
  on schooldesk_internal.storage_migration_items (batch_id, status, id);

alter table schooldesk_internal.storage_migration_batches enable row level security;
alter table schooldesk_internal.storage_migration_batches force row level security;
alter table schooldesk_internal.storage_migration_items enable row level security;
alter table schooldesk_internal.storage_migration_items force row level security;

revoke all on schema schooldesk_internal from public, anon, authenticated;
grant usage on schema schooldesk_internal to service_role;
revoke all on schooldesk_internal.storage_migration_batches,
  schooldesk_internal.storage_migration_items
  from public, anon, authenticated;
grant all on schooldesk_internal.storage_migration_batches,
  schooldesk_internal.storage_migration_items to service_role;

comment on table schooldesk_internal.storage_migration_batches is
  'Service-only resumable Supabase Storage to Cloudflare R2 migration batches.';
comment on table schooldesk_internal.storage_migration_items is
  'Service-only per-object migration and SHA-256 verification state.';

-- R2 promotion/demotion and database-first deletion use the same operational
-- boundary. A failed object cleanup can be retried without exposing queue
-- state through the application API.
create table if not exists public.storage_cleanup_queue (
  id uuid primary key default gen_random_uuid(),
  storage_ref text not null unique,
  reason text not null,
  status text not null default 'pending' check (status in (
    'pending', 'running', 'completed', 'failed'
  )),
  attempts integer not null default 0,
  available_at timestamptz not null default now(),
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists storage_cleanup_queue_ready_idx
  on public.storage_cleanup_queue (status, available_at, created_at);

alter table public.storage_cleanup_queue enable row level security;
alter table public.storage_cleanup_queue force row level security;
revoke all on public.storage_cleanup_queue from public, anon, authenticated;
grant all on public.storage_cleanup_queue to service_role;

comment on table public.storage_cleanup_queue is
  'Service-only retryable cleanup queue for promoted or deleted R2 objects.';
