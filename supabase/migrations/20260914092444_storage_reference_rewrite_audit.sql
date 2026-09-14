-- Service-only audit records for the legacy Supabase Storage -> R2 reference
-- cutover.  These tables deliberately do not expose file contents or URLs to
-- the Data API.  A rewrite is only complete when every changed value has an
-- auditable reverse mapping and every cleanup candidate has an R2 integrity
-- record.

create schema if not exists schooldesk_internal;

create table if not exists schooldesk_internal.storage_migration_rewrites (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references schooldesk_internal.storage_migration_batches(id)
    on delete cascade,
  rewrite_key text not null unique,
  table_name text not null,
  row_id text not null,
  column_name text not null,
  json_path text not null default '',
  source_value text not null,
  target_value text not null,
  status text not null default 'pending' check (status in (
    'pending', 'applied', 'skipped', 'failed', 'rolled_back'
  )),
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  applied_at timestamptz,
  rolled_back_at timestamptz
);

create index if not exists storage_migration_rewrites_batch_status_idx
  on schooldesk_internal.storage_migration_rewrites (batch_id, status, id);

create index if not exists storage_migration_rewrites_source_idx
  on schooldesk_internal.storage_migration_rewrites (table_name, column_name, status);

create table if not exists schooldesk_internal.storage_source_cleanup_batches (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'dry_run' check (status in (
    'dry_run', 'approved', 'running', 'completed', 'failed', 'cancelled'
  )),
  target_bytes bigint not null default 900000000,
  source_bytes_before bigint not null default 0,
  source_bytes_after bigint,
  candidate_bytes bigint not null default 0,
  deleted_count bigint not null default 0,
  failed_count bigint not null default 0,
  report jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists schooldesk_internal.storage_source_cleanup_items (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references schooldesk_internal.storage_source_cleanup_batches(id)
    on delete cascade,
  source_bucket text not null,
  source_key text not null,
  r2_reference text not null,
  source_size bigint not null default 0,
  source_sha256 text,
  destination_sha256 text,
  live_reference_count bigint not null default 0,
  reason text not null,
  status text not null default 'pending' check (status in (
    'pending', 'deleted', 'skipped', 'failed'
  )),
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (batch_id, source_bucket, source_key)
);

create index if not exists storage_source_cleanup_items_batch_status_idx
  on schooldesk_internal.storage_source_cleanup_items (batch_id, status, id);

create index if not exists storage_source_cleanup_items_source_idx
  on schooldesk_internal.storage_source_cleanup_items (source_bucket, source_key);

alter table schooldesk_internal.storage_migration_rewrites enable row level security;
alter table schooldesk_internal.storage_migration_rewrites force row level security;
alter table schooldesk_internal.storage_source_cleanup_batches enable row level security;
alter table schooldesk_internal.storage_source_cleanup_batches force row level security;
alter table schooldesk_internal.storage_source_cleanup_items enable row level security;
alter table schooldesk_internal.storage_source_cleanup_items force row level security;

revoke all on schooldesk_internal.storage_migration_rewrites,
  schooldesk_internal.storage_source_cleanup_batches,
  schooldesk_internal.storage_source_cleanup_items
  from public, anon, authenticated;
grant all on schooldesk_internal.storage_migration_rewrites,
  schooldesk_internal.storage_source_cleanup_batches,
  schooldesk_internal.storage_source_cleanup_items
  to service_role;

comment on table schooldesk_internal.storage_migration_rewrites is
  'Service-only rollback audit for canonical Supabase Storage to R2 reference rewrites.';
comment on table schooldesk_internal.storage_source_cleanup_batches is
  'Service-only dry-run and execution batches for safe legacy Supabase source cleanup.';
comment on table schooldesk_internal.storage_source_cleanup_items is
  'Service-only per-object cleanup evidence; deletion requires an R2 integrity match and either zero live references or the explicit user-approved referenced-delete guard.';

-- Extend the existing queue with a provider discriminator. Existing R2
-- cleanup callers retain the default provider; the migration runner uses the
-- Supabase provider for legacy-source deletion so an R2 cleanup worker can
-- never interpret a legacy source key as an R2 reference.
alter table public.storage_cleanup_queue
  add column if not exists provider text not null default 'cloudflare_r2'
    check (provider in ('cloudflare_r2', 'supabase_storage')),
  add column if not exists source_bucket text,
  add column if not exists source_key text,
  add column if not exists destination_ref text;

create index if not exists storage_cleanup_queue_provider_status_idx
  on public.storage_cleanup_queue (provider, status, available_at, created_at);

comment on column public.storage_cleanup_queue.provider is
  'Cleanup provider discriminator; cloudflare_r2 is the legacy/default behavior and supabase_storage is source cleanup only.';
