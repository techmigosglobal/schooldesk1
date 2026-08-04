alter table public.event_posts
  alter column public_gallery_visible set default false;

-- Preserve the old School Gallery behavior for existing rows while preventing
-- parent-only and landing-only posts from becoming public website media by
-- default. The website manager can explicitly display any approved post.
update public.event_posts
set public_gallery_visible = (
  coalesce(destinations, '[]'::jsonb) @> '["SCHOOL_GALLERY"]'::jsonb
  or lower(coalesce(visibility, '')) = 'gallery'
)
where public_gallery_visible is distinct from (
  coalesce(destinations, '[]'::jsonb) @> '["SCHOOL_GALLERY"]'::jsonb
  or lower(coalesce(visibility, '')) = 'gallery'
);

comment on column public.event_posts.public_gallery_visible is
  'Explicit principal-controlled visibility in the public website gallery; independent of in-app destinations.';
