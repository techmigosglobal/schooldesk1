-- Ensure the two existing RLS-protected chat tables can deliver their intended
-- Postgres Changes subscriptions. Preserve every other publication member.
do $$
begin
  if not exists (select 1 from pg_publication where pubname='supabase_realtime') then
    create publication supabase_realtime;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='message_conversations'
  ) then
    alter publication supabase_realtime add table public.message_conversations;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
  if exists (select 1 from pg_class where oid='public.message_conversations'::regclass and relreplident<>'f') then
    alter table public.message_conversations replica identity full;
  end if;
  if exists (select 1 from pg_class where oid='public.messages'::regclass and relreplident<>'f') then
    alter table public.messages replica identity full;
  end if;
end;
$$;
