-- ============================================================
-- Migration 0002: People Schema (Staff, Students, Users, Auth)
-- ============================================================

-- ── Roles & Permissions ───────────────────────────────────────
create table public.roles (
  id          uuid primary key default uuid_generate_v4(),
  school_id   uuid not null references public.schools(id) on delete cascade,
  role_name   text not null,
  description text,
  is_system   boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
alter table public.roles enable row level security;

create table public.permissions (
  id          uuid primary key default uuid_generate_v4(),
  school_id   uuid not null references public.schools(id) on delete cascade,
  role_id     uuid not null references public.roles(id) on delete cascade,
  module      text not null,
  action      text not null,
  created_at  timestamptz not null default now()
);
alter table public.permissions enable row level security;

-- ── Staff ─────────────────────────────────────────────────────
create table public.staff (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  first_name       text not null,
  last_name        text not null,
  staff_code       text,
  email            text,
  phone            text,
  gender           text,
  date_of_birth    date,
  join_date        date,
  designation      text,
  employment_type  text not null default 'full_time',
  account_role     text not null default 'teacher',
  basic_salary     numeric(12,2),
  photo_url        text,
  department_id    uuid references public.departments(id) on delete set null,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index idx_staff_school on public.staff(school_id);
create index idx_staff_email on public.staff(email);
alter table public.staff enable row level security;

create table public.staff_qualifications (
  id           uuid primary key default uuid_generate_v4(),
  staff_id     uuid not null references public.staff(id) on delete cascade,
  degree       text,
  institution  text,
  year         int,
  created_at   timestamptz not null default now()
);
alter table public.staff_qualifications enable row level security;

create table public.staff_subjects (
  id         uuid primary key default uuid_generate_v4(),
  school_id  uuid not null references public.schools(id) on delete cascade,
  staff_id   uuid not null references public.staff(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  grade_id   uuid references public.grades(id) on delete cascade,
  section_id uuid references public.sections(id) on delete set null,
  academic_year_id uuid references public.academic_years(id) on delete cascade,
  is_primary boolean not null default true,
  periods_per_week int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_staff_subjects_school on public.staff_subjects(school_id);
create index idx_staff_subjects_grade on public.staff_subjects(grade_id, academic_year_id);
alter table public.staff_subjects enable row level security;

create table public.staff_documents (
  id          uuid primary key default uuid_generate_v4(),
  staff_id    uuid not null references public.staff(id) on delete cascade,
  school_id   uuid not null references public.schools(id) on delete cascade,
  doc_type    text not null,
  title       text,
  file_url    text,
  expires_at  date,
  created_at  timestamptz not null default now()
);
alter table public.staff_documents enable row level security;

-- ── Students ──────────────────────────────────────────────────
create table public.students (
  id                  uuid primary key default uuid_generate_v4(),
  school_id           uuid not null references public.schools(id) on delete cascade,
  first_name          text not null,
  last_name           text not null,
  admission_number    text,
  student_code        text,
  date_of_birth       date,
  gender              text,
  admission_date      date,
  current_section_id  uuid references public.sections(id) on delete set null,
  status              text not null default 'active',
  photo_url           text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index idx_students_school on public.students(school_id);
create index idx_students_section on public.students(current_section_id);
alter table public.students enable row level security;

create table public.guardians (
  id           uuid primary key default uuid_generate_v4(),
  school_id    uuid not null references public.schools(id) on delete cascade,
  student_id   uuid not null references public.students(id) on delete cascade,
  full_name    text not null,
  relationship text not null default 'parent',
  phone        text,
  email        text,
  occupation   text,
  is_primary   boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
alter table public.guardians enable row level security;

create table public.student_guardians (
  id         uuid primary key default uuid_generate_v4(),
  student_id uuid not null references public.students(id) on delete cascade,
  guardian_id uuid not null references public.guardians(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.student_guardians enable row level security;

create table public.medical_records (
  id           uuid primary key default uuid_generate_v4(),
  student_id   uuid not null references public.students(id) on delete cascade,
  blood_group  text,
  allergies    text,
  conditions   text,
  medications  text,
  emergency_contact text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
alter table public.medical_records enable row level security;

create table public.student_documents (
  id          uuid primary key default uuid_generate_v4(),
  student_id  uuid not null references public.students(id) on delete cascade,
  school_id   uuid not null references public.schools(id) on delete cascade,
  doc_type    text not null,
  title       text,
  file_url    text,
  expires_at  date,
  created_at  timestamptz not null default now()
);
alter table public.student_documents enable row level security;

create table public.enrollments (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  student_id       uuid not null references public.students(id) on delete cascade,
  section_id       uuid not null references public.sections(id) on delete cascade,
  academic_year_id uuid not null references public.academic_years(id) on delete cascade,
  roll_number      text,
  status           text not null default 'active',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index idx_enrollments_school on public.enrollments(school_id, academic_year_id);
create index idx_enrollments_student on public.enrollments(student_id);
alter table public.enrollments enable row level security;

create table public.parent_student_links (
  id             uuid primary key default uuid_generate_v4(),
  school_id      uuid not null references public.schools(id) on delete cascade,
  parent_user_id uuid not null,  -- references users.id (added after users table)
  student_id     uuid not null references public.students(id) on delete cascade,
  created_at     timestamptz not null default now(),
  unique(parent_user_id, student_id)
);
alter table public.parent_student_links enable row level security;

create table public.transfer_records (
  id              uuid primary key default uuid_generate_v4(),
  student_id      uuid not null references public.students(id) on delete cascade,
  school_id       uuid not null references public.schools(id) on delete cascade,
  transfer_type   text not null default 'out',
  transfer_date   date,
  reason          text,
  tc_issued       boolean not null default false,
  created_at      timestamptz not null default now()
);
alter table public.transfer_records enable row level security;

-- ── Users (internal app users, bridged to Supabase Auth) ──────
create table public.users (
  id             uuid primary key, -- MUST equal auth.users.id
  school_id      uuid not null references public.schools(id) on delete cascade,
  username       text,
  name           text,
  email          text,
  phone          text,
  avatar         text,
  role_id        uuid references public.roles(id) on delete set null,
  role_name      text not null default 'staff',
  linked_type    text,
  linked_id      uuid,
  is_active      boolean not null default true,
  is_verified    boolean not null default false,
  last_login     timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index idx_users_school on public.users(school_id);
create index idx_users_username on public.users(username);
alter table public.users enable row level security;

-- ── Username Aliases (username → Supabase Auth email mapping) ─
create table public.username_aliases (
  username     text primary key,
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  school_id    uuid not null references public.schools(id) on delete cascade,
  created_at   timestamptz not null default now()
);
create index idx_username_aliases_auth on public.username_aliases(auth_user_id);
alter table public.username_aliases enable row level security;

-- ── User Sessions (for logout/tracking) ───────────────────────
create table public.user_sessions (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references public.users(id) on delete cascade,
  refresh_token text,
  device_id    text,
  user_agent   text,
  ip_address   text,
  last_active  timestamptz,
  created_at   timestamptz not null default now()
);
alter table public.user_sessions enable row level security;

-- ── Audit Logs ────────────────────────────────────────────────
create table public.audit_logs (
  id           uuid primary key default uuid_generate_v4(),
  school_id    uuid references public.schools(id) on delete cascade,
  user_id      uuid,
  action       text not null,
  entity_type  text,
  entity_id    text,
  details      jsonb,
  ip_address   text,
  created_at   timestamptz not null default now()
);
create index idx_audit_logs_school on public.audit_logs(school_id, created_at desc);
alter table public.audit_logs enable row level security;

-- ── Updated-at triggers ───────────────────────────────────────
do $$
declare t text;
begin
  foreach t in array array[
    'roles','staff','staff_subjects','students','guardians',
    'medical_records','enrollments','users'
  ] loop
    execute format(
      'create trigger trg_%I_updated_at before update on public.%I
       for each row execute function public.set_updated_at()',
      t, t
    );
  end loop;
end;
$$;
