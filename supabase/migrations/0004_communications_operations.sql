-- ============================================================
-- Migration 0004: Communications, Approvals, Operations
-- ============================================================

-- ── Announcements ─────────────────────────────────────────────
create table public.announcements (
  id           uuid primary key default uuid_generate_v4(),
  school_id    uuid not null references public.schools(id) on delete cascade,
  title        text not null,
  body         text not null,
  audience     text not null default 'all',
  priority     text not null default 'normal',
  attachments  jsonb,
  scheduled_at timestamptz,
  published_at timestamptz,
  status       text not null default 'draft',
  created_by   uuid references public.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index idx_announcements_school on public.announcements(school_id, created_at desc);
alter table public.announcements enable row level security;

-- ── Event Posts ───────────────────────────────────────────────
create table public.event_posts (
  id           uuid primary key default uuid_generate_v4(),
  school_id    uuid not null references public.schools(id) on delete cascade,
  title        text not null,
  body         text,
  media_urls   jsonb,
  event_id     uuid,
  visibility   text not null default 'school',
  status       text not null default 'published',
  created_by   uuid references public.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index idx_event_posts_school on public.event_posts(school_id, created_at desc);
alter table public.event_posts enable row level security;

-- ── Message Conversations & Messages ──────────────────────────
create table public.message_conversations (
  id              uuid primary key default uuid_generate_v4(),
  school_id       uuid not null references public.schools(id) on delete cascade,
  title           text,
  student_id      uuid references public.students(id) on delete set null,
  participant_ids jsonb,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
alter table public.message_conversations enable row level security;

create table public.messages (
  id              uuid primary key default uuid_generate_v4(),
  school_id       uuid not null references public.schools(id) on delete cascade,
  conversation_id uuid not null references public.message_conversations(id) on delete cascade,
  sender_id       uuid references public.users(id) on delete set null,
  body            text not null,
  attachments     jsonb,
  read_by         jsonb,
  created_at      timestamptz not null default now()
);
create index idx_messages_conversation on public.messages(conversation_id, created_at desc);
alter table public.messages enable row level security;

-- ── Notifications ─────────────────────────────────────────────
-- NOTE: No exam notification type — removed per migration plan
create table public.notification_logs (
  id           uuid primary key default uuid_generate_v4(),
  school_id    uuid not null references public.schools(id) on delete cascade,
  user_id      uuid references public.users(id) on delete set null,
  title        text not null,
  body         text,
  type         text not null default 'general',
  entity_type  text,
  entity_id    text,
  is_read      boolean not null default false,
  created_at   timestamptz not null default now()
);
create index idx_notification_logs_user on public.notification_logs(user_id, is_read, created_at desc);
alter table public.notification_logs enable row level security;

create table public.notification_device_tokens (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.users(id) on delete cascade,
  token       text not null,
  platform    text not null default 'android',
  created_at  timestamptz not null default now(),
  unique(user_id, token)
);
alter table public.notification_device_tokens enable row level security;

-- ── Diary Entries ─────────────────────────────────────────────
create table public.diary_entries (
  id          uuid primary key default uuid_generate_v4(),
  school_id   uuid not null references public.schools(id) on delete cascade,
  section_id  uuid references public.sections(id) on delete set null,
  student_id  uuid references public.students(id) on delete set null,
  date        date not null,
  subject     text,
  content     text,
  created_by  uuid references public.users(id) on delete set null,
  created_at  timestamptz not null default now()
);
alter table public.diary_entries enable row level security;

-- ── Lesson Planners ───────────────────────────────────────────
create table public.lesson_planners (
  id               uuid primary key default uuid_generate_v4(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  staff_id         uuid references public.staff(id) on delete set null,
  section_id       uuid references public.sections(id) on delete set null,
  subject_id       uuid references public.subjects(id) on delete set null,
  academic_year_id uuid references public.academic_years(id) on delete cascade,
  title            text not null,
  content          text,
  date             date,
  status           text not null default 'draft',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
alter table public.lesson_planners enable row level security;

-- ── Homework Submissions ──────────────────────────────────────
create table public.homework_submissions (
  id              uuid primary key default uuid_generate_v4(),
  school_id       uuid not null references public.schools(id) on delete cascade,
  homework_id     text not null,  -- references tables_md homework table
  student_id      uuid references public.students(id) on delete cascade,
  submitted_at    timestamptz,
  file_urls       jsonb,
  remarks         text,
  grade           text,
  status          text not null default 'submitted',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
alter table public.homework_submissions enable row level security;

-- ── Approvals ─────────────────────────────────────────────────
-- NOTE: module 'exam' is intentionally excluded
create table public.approval_requests (
  id                    uuid primary key default uuid_generate_v4(),
  school_id             uuid not null references public.schools(id) on delete cascade,
  requested_by          uuid references public.users(id) on delete set null,
  reviewed_by           uuid references public.users(id) on delete set null,
  module                text not null, -- 'fee', 'leave', 'student', 'class', 'timetable', etc. NOT 'exam'
  operation_type        text not null, -- 'create', 'update', 'delete', 'approve'
  entity_type           text,
  entity_id             uuid,
  academic_year_id      uuid references public.academic_years(id) on delete set null,
  status                text not null default 'draft',
  payload_json          jsonb,
  before_snapshot_json  jsonb,
  after_snapshot_json   jsonb,
  review_note           text,
  submitted_at          timestamptz,
  reviewed_at           timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index idx_approval_requests_school on public.approval_requests(school_id, status);
alter table public.approval_requests enable row level security;

create table public.account_approvals (
  id          uuid primary key default uuid_generate_v4(),
  school_id   uuid not null references public.schools(id) on delete cascade,
  user_id     uuid references public.users(id) on delete cascade,
  role        text,
  status      text not null default 'pending',
  reason      text,
  reviewed_by uuid references public.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
alter table public.account_approvals enable row level security;

-- ── Uploaded Files ────────────────────────────────────────────
create table public.uploaded_files (
  id          uuid primary key default uuid_generate_v4(),
  school_id   uuid references public.schools(id) on delete cascade,
  uploader_id uuid references public.users(id) on delete set null,
  url         text not null,
  path        text,
  folder      text,
  entity_type text,
  entity_id   text,
  file_name   text,
  file_size   bigint,
  mime_type   text,
  created_at  timestamptz not null default now()
);
alter table public.uploaded_files enable row level security;

-- ── Frontend Records (Tables.md dynamic tables) ───────────────
create table public.frontend_records (
  id          uuid primary key default uuid_generate_v4(),
  school_id   uuid not null references public.schools(id) on delete cascade,
  table_name  text not null,
  record_id   text not null,
  data        jsonb not null default '{}',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index idx_frontend_records_school on public.frontend_records(school_id, table_name);
alter table public.frontend_records enable row level security;

-- ── Bulk Import Jobs ──────────────────────────────────────────
create table public.bulk_import_jobs (
  id           uuid primary key default uuid_generate_v4(),
  school_id    uuid not null references public.schools(id) on delete cascade,
  import_type  text not null,
  status       text not null default 'pending',
  row_count    int,
  error_count  int,
  file_url     text,
  started_at   timestamptz,
  finished_at  timestamptz,
  created_by   uuid references public.users(id) on delete set null,
  created_at   timestamptz not null default now()
);
alter table public.bulk_import_jobs enable row level security;

-- ── Error Events ──────────────────────────────────────────────
create table public.error_events (
  id          uuid primary key default uuid_generate_v4(),
  school_id   uuid references public.schools(id) on delete cascade,
  user_id     uuid references public.users(id) on delete set null,
  error_type  text,
  message     text,
  stack_trace text,
  context     jsonb,
  created_at  timestamptz not null default now()
);
alter table public.error_events enable row level security;

-- ── Updated-at triggers ───────────────────────────────────────
do $$
declare t text;
begin
  foreach t in array array[
    'announcements','event_posts','message_conversations',
    'lesson_planners','homework_submissions',
    'approval_requests','account_approvals','frontend_records'
  ] loop
    execute format(
      'create trigger trg_%I_updated_at before update on public.%I
       for each row execute function public.set_updated_at()',
      t, t
    );
  end loop;
end;
$$;
