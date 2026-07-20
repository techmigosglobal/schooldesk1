alter table public.message_conversations
  add column if not exists leader_id uuid references public.users(id) on delete set null;

create index if not exists idx_message_conversations_leader
  on public.message_conversations (school_id, leader_id, updated_at desc);

-- Preserve the owner of pre-existing principal-created direct conversations.
update public.message_conversations as conversation
set leader_id = conversation.created_by
from public.users as account
where conversation.leader_id is null
  and conversation.created_by = account.id
  and lower(account.role_name) in ('principal', 'coordinator', 'admin');
