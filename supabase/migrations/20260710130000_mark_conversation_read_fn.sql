-- Replaces the N+1 per-message UPDATE loop in the /chat/conversations/{id}/read
-- endpoint with a single bulk UPDATE that appends the user's id to read_by for
-- every unread message in the conversation at once.

create or replace function public.mark_conversation_read(
  p_conversation_id uuid,
  p_school_id       uuid,
  p_user_id         text
)
returns void
language sql
security invoker
as $$
  update public.messages
  set    read_by = coalesce(read_by, '[]'::jsonb) || jsonb_build_array(p_user_id)
  where  conversation_id = p_conversation_id
    and  school_id       = p_school_id
    and  not (coalesce(read_by, '[]'::jsonb) @> jsonb_build_array(p_user_id));
$$;

grant execute on function public.mark_conversation_read(uuid, uuid, text) to authenticated;
