-- The public SECURITY DEFINER wrapper runs as its owner. On the VPS that is
-- postgres, while the internal function is owned by supabase_admin, so the
-- wrapper owner needs the narrowly scoped privileges required for delegation.
do $$
declare
  wrapper_owner name;
begin
  select pg_get_userbyid(p.proowner)::name
    into strict wrapper_owner
  from pg_proc p
  where p.oid = 'public.error_event_retention_metrics(uuid)'::regprocedure;

  execute format(
    'grant usage on schema schooldesk_internal to %I',
    wrapper_owner
  );
  execute format(
    'grant execute on function schooldesk_internal.error_event_retention_metrics(uuid) to %I',
    wrapper_owner
  );
end;
$$;

-- The Edge API is the only caller of the public RPC. Keep browser roles out.
revoke execute on function public.error_event_retention_metrics(uuid)
  from public, anon, authenticated;
grant execute on function public.error_event_retention_metrics(uuid)
  to service_role;
