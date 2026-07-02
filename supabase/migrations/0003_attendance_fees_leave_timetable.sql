-- ============================================================
-- Migration 0003: Attendance, Fees, Leave, Timetable
-- ============================================================

-- ── Attendance Sessions ───────────────────────────────────────
create table public.attendance_sessions (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  section_id       uuid not null references public.sections(id) on delete cascade,
  academic_year_id uuid not null references public.academic_years(id) on delete cascade,
  subject_id       uuid references public.subjects(id) on delete set null,
  staff_id         uuid references public.staff(id) on delete set null,
  date             date not null,
  period_number    int,
  timetable_slot_id uuid,
  is_finalized     boolean not null default false,
  correction_request text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index idx_attendance_sessions_school on public.attendance_sessions(school_id, date);
create index idx_attendance_sessions_section on public.attendance_sessions(section_id, date);
alter table public.attendance_sessions enable row level security;

create table public.student_attendances (
  id            uuid primary key default uuid_generate_v4(),
  session_id    uuid not null references public.attendance_sessions(id) on delete cascade,
  student_id    uuid not null references public.students(id) on delete cascade,
  status        text not null default 'present', -- present, absent, late, excused
  remarks       text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique(session_id, student_id)
);
create index idx_student_attendances_student on public.student_attendances(student_id);
alter table public.student_attendances enable row level security;

create table public.staff_attendances (
  id           uuid primary key default uuid_generate_v4(),
  school_id    uuid not null references public.schools(id) on delete cascade,
  staff_id     uuid not null references public.staff(id) on delete cascade,
  date         date not null,
  status       text not null default 'present',
  check_in     time,
  check_out    time,
  notes        text,
  qr_scanned   boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique(staff_id, date)
);
create index idx_staff_attendances_school on public.staff_attendances(school_id, date);
alter table public.staff_attendances enable row level security;

create table public.attendance_summaries (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  student_id       uuid not null references public.students(id) on delete cascade,
  academic_year_id uuid not null references public.academic_years(id) on delete cascade,
  term_id          uuid references public.terms(id) on delete set null,
  total_days       int not null default 0,
  present_days     int not null default 0,
  absent_days      int not null default 0,
  late_days        int not null default 0,
  percentage       numeric(5,2),
  updated_at       timestamptz not null default now()
);
alter table public.attendance_summaries enable row level security;

create table public.substitutions (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  original_staff_id uuid references public.staff(id) on delete set null,
  substitute_staff_id uuid references public.staff(id) on delete set null,
  section_id       uuid references public.sections(id) on delete set null,
  date             date not null,
  period_number    int,
  reason           text,
  created_at       timestamptz not null default now()
);
alter table public.substitutions enable row level security;

-- ── Fee Categories ────────────────────────────────────────────
create table public.fee_categories (
  id             uuid primary key default uuid_generate_v4(),
  school_id      uuid not null references public.schools(id) on delete cascade,
  name           text not null,
  description    text,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
alter table public.fee_categories enable row level security;

-- ── Fee Structures ────────────────────────────────────────────
create table public.fee_structures (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  academic_year_id uuid not null references public.academic_years(id) on delete cascade,
  grade_id         uuid references public.grades(id) on delete set null,
  section_id       uuid references public.sections(id) on delete set null,
  category_id      uuid not null references public.fee_categories(id) on delete cascade,
  amount           numeric(12,2) not null default 0,
  due_date         date,
  frequency        text not null default 'term',
  is_mandatory     boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index idx_fee_structures_school on public.fee_structures(school_id, academic_year_id);
alter table public.fee_structures enable row level security;

create table public.fee_installments (
  id               uuid primary key default uuid_generate_v4(),
  fee_structure_id uuid not null references public.fee_structures(id) on delete cascade,
  installment_no   int not null,
  amount           numeric(12,2) not null,
  due_date         date,
  created_at       timestamptz not null default now()
);
alter table public.fee_installments enable row level security;

-- ── Fee Invoices ──────────────────────────────────────────────
create table public.fee_invoices (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  student_id       uuid not null references public.students(id) on delete cascade,
  academic_year_id uuid not null references public.academic_years(id) on delete cascade,
  invoice_number   text not null,
  invoice_date     date not null default current_date,
  due_date         date,
  total_amount     numeric(12,2) not null default 0,
  discount_amount  numeric(12,2) not null default 0,
  net_amount       numeric(12,2) not null default 0,
  paid_amount      numeric(12,2) not null default 0,
  balance          numeric(12,2) not null default 0,
  status           text not null default 'pending',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index idx_fee_invoices_school on public.fee_invoices(school_id, academic_year_id);
create index idx_fee_invoices_student on public.fee_invoices(student_id);
alter table public.fee_invoices enable row level security;

create table public.fee_invoice_items (
  id               uuid primary key default uuid_generate_v4(),
  invoice_id       uuid not null references public.fee_invoices(id) on delete cascade,
  fee_structure_id uuid references public.fee_structures(id) on delete set null,
  category_name    text not null,
  amount           numeric(12,2) not null,
  discount         numeric(12,2) not null default 0,
  created_at       timestamptz not null default now()
);
alter table public.fee_invoice_items enable row level security;

-- ── Payments ──────────────────────────────────────────────────
create table public.payments (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  student_id       uuid not null references public.students(id) on delete cascade,
  invoice_id       uuid references public.fee_invoices(id) on delete set null,
  amount           numeric(12,2) not null,
  payment_method   text not null,
  reference_number text,
  paid_at          timestamptz not null default now(),
  notes            text,
  status           text not null default 'completed',
  created_by       uuid references public.users(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index idx_payments_school on public.payments(school_id);
create index idx_payments_student on public.payments(student_id);
alter table public.payments enable row level security;

create table public.fee_receipts (
  id             uuid primary key default uuid_generate_v4(),
  payment_id     uuid not null references public.payments(id) on delete cascade,
  receipt_number text not null,
  issued_at      timestamptz not null default now()
);
alter table public.fee_receipts enable row level security;

create table public.fee_concessions (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  student_id       uuid not null references public.students(id) on delete cascade,
  fee_structure_id uuid references public.fee_structures(id) on delete set null,
  amount           numeric(12,2),
  percentage       numeric(5,2),
  reason           text,
  approved_by      uuid references public.users(id) on delete set null,
  created_at       timestamptz not null default now()
);
alter table public.fee_concessions enable row level security;

create table public.parent_payment_requests (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  student_id       uuid not null references public.students(id) on delete cascade,
  invoice_id       uuid references public.fee_invoices(id) on delete set null,
  amount           numeric(12,2) not null,
  payment_method   text,
  proof_url        text,
  remarks          text,
  status           text not null default 'pending',
  reviewed_by      uuid references public.users(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
alter table public.parent_payment_requests enable row level security;

create table public.school_payment_settings (
  id                    uuid primary key default uuid_generate_v4(),
  school_id             uuid not null unique references public.schools(id) on delete cascade,
  accept_online_payment boolean not null default false,
  razorpay_key_id       text,
  late_fine_per_day     numeric(8,2) not null default 0,
  grace_period_days     int not null default 0,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
alter table public.school_payment_settings enable row level security;

-- ── Leave ─────────────────────────────────────────────────────
create table public.leave_types (
  id          uuid primary key default uuid_generate_v4(),
  school_id   uuid not null references public.schools(id) on delete cascade,
  name        text not null,
  max_days    int,
  is_paid     boolean not null default true,
  created_at  timestamptz not null default now()
);
alter table public.leave_types enable row level security;

create table public.leave_balances (
  id             uuid primary key default uuid_generate_v4(),
  school_id      uuid not null references public.schools(id) on delete cascade,
  staff_id       uuid not null references public.staff(id) on delete cascade,
  leave_type_id  uuid not null references public.leave_types(id) on delete cascade,
  academic_year_id uuid references public.academic_years(id) on delete set null,
  allocated_days int not null default 0,
  used_days      int not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
alter table public.leave_balances enable row level security;

create table public.leave_applications (
  id              uuid primary key default uuid_generate_v4(),
  school_id       uuid not null references public.schools(id) on delete cascade,
  staff_id        uuid references public.staff(id) on delete set null,
  leave_type_id   uuid references public.leave_types(id) on delete set null,
  leave_type      text not null default 'casual',
  start_date      date not null,
  end_date        date not null,
  total_days      int,
  reason          text,
  attachment_urls jsonb,
  status          text not null default 'pending',
  reviewed_by     uuid references public.users(id) on delete set null,
  review_note     text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index idx_leave_applications_school on public.leave_applications(school_id);
alter table public.leave_applications enable row level security;

create table public.student_leave_applications (
  id          uuid primary key default uuid_generate_v4(),
  school_id   uuid not null references public.schools(id) on delete cascade,
  student_id  uuid not null references public.students(id) on delete cascade,
  leave_type  text not null default 'sick',
  start_date  date not null,
  end_date    date not null,
  total_days  int,
  reason      text,
  status      text not null default 'pending',
  reviewed_by uuid references public.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
alter table public.student_leave_applications enable row level security;

-- ── Timetable ─────────────────────────────────────────────────
create table public.timetable_slots (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  section_id       uuid not null references public.sections(id) on delete cascade,
  subject_id       uuid references public.subjects(id) on delete set null,
  staff_id         uuid references public.staff(id) on delete set null,
  room_id          uuid references public.rooms(id) on delete set null,
  academic_year_id uuid references public.academic_years(id) on delete cascade,
  day_of_week      int not null, -- 1=Mon, 7=Sun
  start_time       text not null,
  end_time         text not null,
  period_number    int,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index idx_timetable_slots_school on public.timetable_slots(school_id);
create index idx_timetable_slots_section on public.timetable_slots(section_id, day_of_week);
alter table public.timetable_slots enable row level security;

create table public.timetable_templates (
  id         uuid primary key default uuid_generate_v4(),
  school_id  uuid not null references public.schools(id) on delete cascade,
  name       text not null,
  config     jsonb,
  created_at timestamptz not null default now()
);
alter table public.timetable_templates enable row level security;

-- updated_at triggers
do $$
declare t text;
begin
  foreach t in array array[
    'attendance_sessions','student_attendances','staff_attendances',
    'fee_categories','fee_structures','fee_invoices','payments',
    'school_payment_settings','leave_balances','leave_applications',
    'student_leave_applications','timetable_slots','parent_payment_requests'
  ] loop
    execute format(
      'create trigger trg_%I_updated_at before update on public.%I
       for each row execute function public.set_updated_at()',
      t, t
    );
  end loop;
end;
$$;
