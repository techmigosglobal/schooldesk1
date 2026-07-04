-- ============================================================
-- Migration 0019: Scoped Chat Realtime Enablement
-- ============================================================

-- Ensure replica identity is full so that updates publish complete rows
alter table public.message_conversations replica identity full;
alter table public.messages replica identity full;

-- Add the tables to the supabase_realtime publication
alter publication supabase_realtime add table public.message_conversations;
alter publication supabase_realtime add table public.messages;
