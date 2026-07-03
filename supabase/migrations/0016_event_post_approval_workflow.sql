alter table public.event_posts
  add column if not exists event_date timestamptz,
  add column if not exists destinations jsonb not null default '[]'::jsonb,
  add column if not exists rejection_reason text,
  add column if not exists approved_by uuid references public.users(id) on delete set null,
  add column if not exists approved_at timestamptz;

update public.event_posts
set destinations = case
  when visibility = 'public' then '["SCHOOL_LANDING"]'::jsonb
  when visibility = 'gallery' then '["SCHOOL_GALLERY"]'::jsonb
  else '["PARENTS_HOME"]'::jsonb
end
where destinations is null
   or jsonb_typeof(destinations) is distinct from 'array'
   or destinations = '[]'::jsonb;

update public.event_posts
set event_date = coalesce(event_date, created_at)
where event_date is null;

create index if not exists idx_event_posts_school_status
  on public.event_posts(school_id, status, created_at desc);
