-- ============================================================
-- Migration 0015: Local storage buckets used by Edge Functions
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'school-assets',
  'school-assets',
  true,
  52428800,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/svg+xml',
    'application/pdf',
    'text/csv'
  ]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "school_assets_public_read" on storage.objects;
drop policy if exists "school_assets_authenticated_insert" on storage.objects;
drop policy if exists "school_assets_authenticated_update" on storage.objects;
drop policy if exists "school_assets_authenticated_delete" on storage.objects;

create policy "school_assets_public_read" on storage.objects
  for select using (bucket_id = 'school-assets');

create policy "school_assets_authenticated_insert" on storage.objects
  for insert to authenticated with check (bucket_id = 'school-assets');

create policy "school_assets_authenticated_update" on storage.objects
  for update to authenticated using (bucket_id = 'school-assets')
  with check (bucket_id = 'school-assets');

create policy "school_assets_authenticated_delete" on storage.objects
  for delete to authenticated using (bucket_id = 'school-assets');
