-- Server-owned issue workflow for principals, teachers, and super admins.
create table if not exists public.issues (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  raised_by uuid not null references public.users(id) on delete cascade,
  raised_by_role text not null check (raised_by_role in ('principal', 'teacher')),
  title text not null check (char_length(trim(title)) between 1 and 180),
  category text not null default 'other',
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high')),
  description text not null check (char_length(trim(description)) between 1 and 5000),
  status text not null default 'pending' check (status in ('pending', 'in_progress', 'resolved')),
  resolution_note text,
  resolved_by uuid references public.users(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.issue_attachments (
  id uuid primary key default gen_random_uuid(),
  issue_id uuid not null references public.issues(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  storage_path text not null unique,
  file_name text not null,
  mime_type text not null,
  file_size bigint not null check (file_size > 0),
  created_at timestamptz not null default now()
);

create index if not exists idx_issues_school_status_created on public.issues (school_id, status, created_at desc);
create index if not exists idx_issues_requester_created on public.issues (raised_by, created_at desc);
create index if not exists idx_issue_attachments_issue on public.issue_attachments (issue_id, created_at);

alter table public.issues enable row level security;
alter table public.issue_attachments enable row level security;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'issue-attachments', 'issue-attachments', false, 52428800,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'video/mp4', 'video/webm', 'video/quicktime']
)
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
