-- Create public.help_contents table
create table if not exists public.help_contents (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  role_name text not null,
  question text not null,
  answer text not null,
  video_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Enable RLS
alter table public.help_contents enable row level security;

-- Drop existing policies if any
drop policy if exists "Anyone can read help content" on public.help_contents;
drop policy if exists "Super admins can manage help content" on public.help_contents;

-- Create policies
create policy "Anyone can read help content" on public.help_contents
  for select using (true);

create policy "Super admins can manage help content" on public.help_contents
  for all using (
    auth.uid() in (
      select id from public.users where role_name = 'super_admin'
    )
  );

-- Grant select to authenticated/anon roles and all privileges to service_role
grant select on public.help_contents to anon, authenticated;
grant all on public.help_contents to service_role;
