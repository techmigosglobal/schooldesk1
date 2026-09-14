-- Feed destinations are filtered with JSONB containment in the authenticated
-- Edge API. The GIN index keeps the teacher/parent/gallery feeds bounded as
-- event-post history grows.
create index if not exists idx_event_posts_destinations_gin
  on public.event_posts using gin (destinations jsonb_path_ops);

comment on column public.event_posts.destinations is
  'In-app/public audiences: PARENTS_HOME, TEACHERS_HOME, SCHOOL_GALLERY, or SCHOOL_LANDING.';
