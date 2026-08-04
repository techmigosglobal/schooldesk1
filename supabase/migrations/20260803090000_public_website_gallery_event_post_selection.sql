alter table public.event_posts
  add column if not exists public_gallery_visible boolean not null default false;

create index if not exists idx_event_posts_public_gallery
  on public.event_posts(school_id, public_gallery_visible, status, created_at desc);

comment on column public.event_posts.public_gallery_visible is
  'Controls visibility in the public website gallery without changing the in-app School Gallery destination.';
