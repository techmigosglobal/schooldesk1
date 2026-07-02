-- ============================================================
-- Migration 0001: Core Academic Schema
-- Supabase SchoolDesk Migration — Exams and marks EXCLUDED
-- ============================================================

-- ── Extensions ───────────────────────────────────────────────
create extension if not exists "uuid-ossp";
create extension if not exists "pg_trgm"; -- for search

-- ── Schools ──────────────────────────────────────────────────
create table public.schools (
  id              uuid primary key default uuid_generate_v4(),
  name            text not null,
  school_type     text not null default 'school',
  affiliation_board text,
  email           text,
  phone           text,
  website         text,
  logo_url        text,
  address_line1   text,
  address_line2   text,
  city            text,
  state           text,
  postal_code     text,
  principal_name  text,
  registration_no text,
  udise_code      text,
  established_year text,
  motto           text,
  timezone        text not null default 'Asia/Kolkata',
  currency        text not null default 'INR',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
alter table public.schools enable row level security;

-- ── Academic Years ────────────────────────────────────────────
create table public.academic_years (
  id           uuid primary key default uuid_generate_v4(),
  school_id    uuid not null references public.schools(id) on delete cascade,
  year_label   text not null,
  year         text,
  start_date   date,
  end_date     date,
  is_current   boolean not null default false,
  status       text not null default 'upcoming',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index idx_academic_years_school on public.academic_years(school_id);
alter table public.academic_years enable row level security;

-- ── Terms ─────────────────────────────────────────────────────
create table public.terms (
  id              uuid primary key default uuid_generate_v4(),
  academic_year_id uuid not null references public.academic_years(id) on delete cascade,
  term_number     int not null,
  term_name       text not null,
  start_date      date,
  end_date        date,
  is_current      boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index idx_terms_academic_year on public.terms(academic_year_id);
alter table public.terms enable row level security;

-- ── Holidays ──────────────────────────────────────────────────
create table public.holidays (
  id              uuid primary key default uuid_generate_v4(),
  school_id       uuid not null references public.schools(id) on delete cascade,
  academic_year_id uuid not null references public.academic_years(id) on delete cascade,
  holiday_name    text not null,
  from_date       date,
  to_date         date,
  type            text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
alter table public.holidays enable row level security;

-- ── Working Day Config ────────────────────────────────────────
create table public.working_day_configs (
  id                   uuid primary key default uuid_generate_v4(),
  school_id            uuid not null references public.schools(id) on delete cascade,
  day_of_week          int not null,
  is_working           boolean not null default true,
  periods_per_day      int,
  period_duration_min  int,
  school_start_time    text,
  school_end_time      text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
alter table public.working_day_configs enable row level security;

-- ── Departments ───────────────────────────────────────────────
create table public.departments (
  id              uuid primary key default uuid_generate_v4(),
  school_id       uuid not null references public.schools(id) on delete cascade,
  department_name text not null,
  hod_staff_id    uuid,
  description     text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index idx_departments_school on public.departments(school_id);
alter table public.departments enable row level security;

-- ── Subjects ──────────────────────────────────────────────────
create table public.subjects (
  id            uuid primary key default uuid_generate_v4(),
  school_id     uuid not null references public.schools(id) on delete cascade,
  department_id uuid references public.departments(id) on delete set null,
  subject_name  text not null,
  subject_code  text,
  subject_type  text not null default 'core',
  subject_color text,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index idx_subjects_school on public.subjects(school_id);
alter table public.subjects enable row level security;

-- ── Grades ────────────────────────────────────────────────────
create table public.grades (
  id           uuid primary key default uuid_generate_v4(),
  school_id    uuid not null references public.schools(id) on delete cascade,
  grade_number int not null,
  grade_name   text not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index idx_grades_school on public.grades(school_id);
alter table public.grades enable row level security;

-- ── Rooms ─────────────────────────────────────────────────────
create table public.rooms (
  id          uuid primary key default uuid_generate_v4(),
  school_id   uuid not null references public.schools(id) on delete cascade,
  room_number text not null,
  room_type   text not null default 'classroom',
  capacity    int,
  block       text,
  floor       text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
alter table public.rooms enable row level security;

-- ── Sections ─────────────────────────────────────────────────
create table public.sections (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  grade_id         uuid not null references public.grades(id) on delete cascade,
  academic_year_id uuid not null references public.academic_years(id) on delete cascade,
  section_name     text not null,
  capacity         int,
  class_teacher_id uuid, -- references staff.id (set after staff table created)
  co_teacher_id    uuid,
  room_id          uuid references public.rooms(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index idx_sections_school on public.sections(school_id);
create index idx_sections_grade on public.sections(grade_id, academic_year_id);
alter table public.sections enable row level security;

-- ── Grade Subjects (NO max_marks / pass_marks) ────────────────
create table public.grade_subjects (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  academic_year_id uuid not null references public.academic_years(id) on delete cascade,
  grade_id         uuid not null references public.grades(id) on delete cascade,
  section_id       uuid references public.sections(id) on delete cascade,
  subject_id       uuid not null references public.subjects(id) on delete cascade,
  periods_per_week int not null default 5,
  is_mandatory     boolean not null default true,
  is_primary       boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
  -- NOTE: max_marks and pass_marks are intentionally absent per migration plan
);
create index idx_grade_subjects_school on public.grade_subjects(school_id, academic_year_id);
alter table public.grade_subjects enable row level security;

-- ── updated_at triggers ───────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'schools','academic_years','terms','holidays','working_day_configs',
    'departments','subjects','grades','rooms','sections','grade_subjects'
  ] loop
    execute format(
      'create trigger trg_%I_updated_at before update on public.%I
       for each row execute function public.set_updated_at()',
      t, t
    );
  end loop;
end;
$$;
