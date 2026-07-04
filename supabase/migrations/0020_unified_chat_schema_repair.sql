-- ============================================================
-- Migration 0017: Repair unified chat schema on environments
-- where migration history exists but columns were not applied.
-- ============================================================

alter table public.message_conversations
  add column if not exists type text not null default 'parent_teacher',
  add column if not exists teacher_id uuid references public.staff(id) on delete set null,
  add column if not exists parent_id uuid references public.users(id) on delete set null,
  add column if not exists last_message text,
  add column if not exists last_message_at timestamptz,
  add column if not exists last_sender_id uuid references public.users(id) on delete set null,
  add column if not exists created_by uuid references public.users(id) on delete set null;

create index if not exists idx_message_conversations_teacher
  on public.message_conversations(school_id, teacher_id, updated_at desc);

create index if not exists idx_message_conversations_parent
  on public.message_conversations(school_id, parent_id, updated_at desc);

alter table public.messages
  add column if not exists sender_role text,
  add column if not exists sender_name text,
  add column if not exists message_type text not null default 'text',
  add column if not exists attachment_url text,
  add column if not exists sent_at timestamptz,
  add column if not exists delivered_at timestamptz;

update public.messages
set sent_at = created_at
where sent_at is null;

create index if not exists idx_messages_sent_at
  on public.messages(conversation_id, sent_at desc);
