alter table public.school_website_gallery_items
  add column if not exists media_type text not null default 'image';

update public.school_website_gallery_items
set media_type = case
  when media_path ~* '\\.(mp4)$' then 'video/mp4'
  when media_path ~* '\\.(webm)$' then 'video/webm'
  when media_path ~* '\\.(mov)$' then 'video/quicktime'
  else 'image'
end
where media_type = 'image';

update storage.buckets
set file_size_limit = 52428800,
    allowed_mime_types = array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime']
where id = 'school-public-media';
