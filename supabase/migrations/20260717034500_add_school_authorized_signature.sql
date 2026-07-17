-- Keep authorization signatures private and expose them only through short-
-- lived signed URLs returned by the authenticated school profile endpoint.
alter table public.schools
  add column if not exists authorized_signature_path text;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'school-signatures',
  'school-signatures',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

comment on column public.schools.authorized_signature_path is
  'Private Storage path for the principal-authorized receipt signature.';
