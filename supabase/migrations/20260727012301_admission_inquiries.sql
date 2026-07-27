create table public.admission_inquiries (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  source text not null check (source in ('homepage', 'contact', 'admissions')),
  parent_name text not null,
  phone text not null,
  email text not null,
  child_name text not null default '',
  child_age text not null,
  program text not null check (program in ('Daycare', 'Playgroup', 'Nursery', 'PP1', 'PP2')),
  message text not null default '',
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index admission_inquiries_school_submitted_idx
  on public.admission_inquiries (school_id, submitted_at desc);

alter table public.admission_inquiries enable row level security;

-- All application access is through the Edge Function after leadership checks.
