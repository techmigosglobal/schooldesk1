-- Media egress and sensitive-file storage hardening.
-- Public feed/gallery/profile media remains in the existing public buckets.
-- Operational documents use this private bucket and are exposed only by the
-- API as short-lived signed URLs.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'school-private-files',
  'school-private-files',
  false,
  26214400,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'application/pdf',
    'text/csv', 'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ]
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "school_private_files_authenticated_read" on storage.objects;
drop policy if exists "school_private_files_authenticated_insert" on storage.objects;
drop policy if exists "school_private_files_authenticated_update" on storage.objects;
drop policy if exists "school_private_files_authenticated_delete" on storage.objects;

create policy "school_private_files_authenticated_read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'school-private-files'
    and (storage.foldername(name))[1] = public.auth_school_id()::text
  );

create policy "school_private_files_authenticated_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'school-private-files'
    and (storage.foldername(name))[1] = public.auth_school_id()::text
  );

create policy "school_private_files_authenticated_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'school-private-files'
    and (storage.foldername(name))[1] = public.auth_school_id()::text
  )
  with check (
    bucket_id = 'school-private-files'
    and (storage.foldername(name))[1] = public.auth_school_id()::text
  );

create policy "school_private_files_authenticated_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'school-private-files'
    and (storage.foldername(name))[1] = public.auth_school_id()::text
  );
