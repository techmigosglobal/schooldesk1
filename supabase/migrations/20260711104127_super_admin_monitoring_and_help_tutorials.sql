-- Super-admin monitoring and private role-scoped help tutorials.

alter table public.help_contents
  add column if not exists video_path text,
  add column if not exists video_file_name text,
  add column if not exists video_mime_type text,
  add column if not exists video_size bigint;

create index if not exists idx_error_events_school_created
  on public.error_events (school_id, created_at desc);
create index if not exists idx_help_contents_school_role
  on public.help_contents (school_id, role_name, created_at);
create index if not exists idx_permissions_role
  on public.permissions (role_id, module, action);

-- Help videos never use the public school-assets bucket. Playback is issued by
-- the authenticated Edge Function after it verifies school and role access.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'help-tutorial-videos',
  'help-tutorial-videos',
  false,
  262144000,
  array['video/mp4', 'video/webm', 'video/quicktime']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;
