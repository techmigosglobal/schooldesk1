-- Public school website content is intentionally isolated from operational media.
create table if not exists public.school_website_content (
  school_id uuid primary key references public.schools(id) on delete cascade,
  hero_title text not null default 'A place to learn, belong, and grow.',
  hero_body text not null default 'Where curiosity is nurtured, values are lived, and every child is encouraged to shine.',
  mission_title text not null default 'Our Mission',
  mission_body text not null default 'We help every learner build knowledge, character, and confidence for a changing world.',
  updated_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.school_website_gallery_items (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  media_path text not null,
  title text not null default '',
  alt_text text not null default '',
  caption text not null default '',
  sort_order integer not null default 0,
  is_published boolean not null default false,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, media_path)
);

create index if not exists idx_school_website_gallery_public
  on public.school_website_gallery_items (school_id, is_published, sort_order, created_at desc);

drop trigger if exists school_website_content_updated_at on public.school_website_content;
create trigger school_website_content_updated_at before update on public.school_website_content
  for each row execute function public.set_updated_at();
drop trigger if exists school_website_gallery_items_updated_at on public.school_website_gallery_items;
create trigger school_website_gallery_items_updated_at before update on public.school_website_gallery_items
  for each row execute function public.set_updated_at();

alter table public.school_website_content enable row level security;
alter table public.school_website_gallery_items enable row level security;

create policy "website_content_principal_read" on public.school_website_content
  for select to authenticated
  using (school_id = public.auth_school_id() and public.auth_role_name() = 'principal');
create policy "website_content_principal_write" on public.school_website_content
  for all to authenticated
  using (school_id = public.auth_school_id() and public.auth_role_name() = 'principal')
  with check (school_id = public.auth_school_id() and public.auth_role_name() = 'principal');
create policy "website_gallery_principal_read" on public.school_website_gallery_items
  for select to authenticated
  using (school_id = public.auth_school_id() and public.auth_role_name() = 'principal');
create policy "website_gallery_principal_write" on public.school_website_gallery_items
  for all to authenticated
  using (school_id = public.auth_school_id() and public.auth_role_name() = 'principal')
  with check (school_id = public.auth_school_id() and public.auth_role_name() = 'principal');

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('school-public-media', 'school-public-media', true, 10485760,
  array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "public_site_media_read" on storage.objects;
drop policy if exists "principal_site_media_insert" on storage.objects;
drop policy if exists "principal_site_media_delete" on storage.objects;
create policy "public_site_media_read" on storage.objects for select to anon, authenticated
  using (bucket_id = 'school-public-media');
create policy "principal_site_media_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'school-public-media'
    and (storage.foldername(name))[1] = public.auth_school_id()::text
    and public.auth_role_name() = 'principal');
create policy "principal_site_media_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'school-public-media'
    and (storage.foldername(name))[1] = public.auth_school_id()::text
    and public.auth_role_name() = 'principal');
