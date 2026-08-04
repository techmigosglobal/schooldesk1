-- Messaging context and participant-scoped Realtime access.
-- The Edge Function remains the write boundary for chat rows.

alter table public.message_conversations
  add column if not exists section_id uuid references public.sections(id) on delete set null,
  add column if not exists class_label text;

update public.message_conversations as conversation
set
  section_id = student.current_section_id,
  class_label = nullif(
    concat_ws(' - ', grade.grade_name, section.section_name),
    ''
  )
from public.students as student
left join public.sections as section
  on section.id = student.current_section_id
left join public.grades as grade
  on grade.id = section.grade_id
where conversation.student_id = student.id
  and (conversation.section_id is null or conversation.class_label is null);

create index if not exists idx_message_conversations_section
  on public.message_conversations(school_id, section_id, updated_at desc);

create index if not exists idx_message_conversations_student_scope
  on public.message_conversations(school_id, parent_id, student_id, leader_id, updated_at desc);

create or replace function public.chat_user_role()
returns text
language sql
stable
as $$
  select lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role_name', ''));
$$;

create or replace function public.chat_can_access_conversation(
  conversation public.message_conversations
)
returns boolean
language sql
stable
security invoker
as $$
  select
    (
      conversation.school_id = public.auth_school_id()
      or (
        public.chat_user_role() in ('admin', 'principal', 'coordinator', 'super_admin')
        and exists (
          select 1
          from public.branch_memberships membership
          where membership.user_id = auth.uid()
            and membership.school_id = conversation.school_id
            and membership.is_active = true
        )
      )
    )
    and (
      public.chat_user_role() in ('admin', 'principal', 'coordinator', 'super_admin')
      or conversation.parent_id = auth.uid()
      or (
        public.chat_user_role() = 'teacher'
        and conversation.teacher_id::text = coalesce(
          auth.jwt() -> 'app_metadata' ->> 'linked_id',
          ''
        )
      )
    );
$$;

-- 0005 grants every authenticated account school-wide chat access. Remove
-- those policies before adding the narrow policies used by Realtime.
drop policy if exists "message_conversations_school_select"
  on public.message_conversations;
drop policy if exists "message_conversations_school_insert"
  on public.message_conversations;
drop policy if exists "message_conversations_school_update"
  on public.message_conversations;
drop policy if exists "message_conversations_school_delete"
  on public.message_conversations;
drop policy if exists "messages_school_select" on public.messages;
drop policy if exists "messages_school_insert" on public.messages;
drop policy if exists "messages_school_update" on public.messages;
drop policy if exists "messages_school_delete" on public.messages;

create policy "chat_conversations_participant_select"
  on public.message_conversations
  for select to authenticated
  using (public.chat_can_access_conversation(message_conversations));

create policy "chat_messages_participant_select"
  on public.messages
  for select to authenticated
  using (
    exists (
      select 1
      from public.message_conversations as conversation
      where conversation.id = messages.conversation_id
        and public.chat_can_access_conversation(conversation)
    )
  );

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'message_conversations'
  ) then
    alter publication supabase_realtime add table public.message_conversations;
  end if;
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;

alter table public.message_conversations replica identity full;
alter table public.messages replica identity full;
