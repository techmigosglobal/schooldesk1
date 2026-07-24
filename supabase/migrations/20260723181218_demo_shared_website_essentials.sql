-- Shared mobile demo and the editorial data for the single public preschool site.
-- These records are only consumed through the Edge Function; RLS remains enabled
-- so a future direct Data API exposure cannot leak a demo credential or drafts.

create table if not exists public.demo_accounts (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references public.users(id) on delete set null,
  demo_school_id uuid references public.schools(id) on delete restrict,
  username text not null unique,
  is_enabled boolean not null default true,
  snapshot jsonb not null default '{}'::jsonb,
  snapshot_version integer not null default 1,
  password_secret_ciphertext text,
  password_secret_expires_at timestamptz,
  password_revealed_at timestamptz,
  password_rotated_at timestamptz not null default now(),
  created_by uuid references public.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create unique index if not exists demo_accounts_single_enabled
  on public.demo_accounts ((is_enabled)) where is_enabled;
alter table public.demo_accounts enable row level security;

create table if not exists public.school_website_sections (
  id uuid primary key default gen_random_uuid(),
  section_key text not null unique,
  title text not null,
  body text not null default '',
  image_url text not null default '',
  status text not null default 'draft' check (status in ('draft', 'published')),
  drafted_by uuid references public.users(id) on delete set null,
  published_by uuid references public.users(id) on delete set null,
  published_at timestamptz,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
alter table public.school_website_sections enable row level security;

create table if not exists public.school_website_entries (
  id uuid primary key default gen_random_uuid(),
  entry_type text not null check (entry_type in ('program', 'news_event', 'testimonial', 'enquiry')),
  title text not null default '',
  body text not null default '',
  image_url text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check (status in ('draft', 'published', 'new', 'contacted', 'closed')),
  submitted_at timestamptz,
  drafted_by uuid references public.users(id) on delete set null,
  published_by uuid references public.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists website_entries_public_index
  on public.school_website_entries (entry_type, status, created_at desc);
alter table public.school_website_entries enable row level security;

-- The Edge Function uses service role after role checks. No browser/table API
-- policy is created for unpublished content, enquiries, or demo metadata.

drop trigger if exists demo_accounts_updated_at on public.demo_accounts;
create trigger demo_accounts_updated_at before update on public.demo_accounts
  for each row execute function public.set_updated_at();
drop trigger if exists website_sections_updated_at on public.school_website_sections;
create trigger website_sections_updated_at before update on public.school_website_sections
  for each row execute function public.set_updated_at();
drop trigger if exists website_entries_updated_at on public.school_website_entries;
create trigger website_entries_updated_at before update on public.school_website_entries
  for each row execute function public.set_updated_at();

-- Rotate due credentials via the API once per hour. The URL is intentionally
-- read from app settings at deploy time rather than embedding a project URL.
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;
do $$ begin
  perform cron.unschedule('rotate-schooldesk-demo-credential');
exception when others then null;
end $$;

-- Configure this after deploy with the project-specific API URL and DEMO_JOB_SECRET.
-- Keeping a disabled schedule placeholder is safer than shipping a wrong URL.
