-- can_access_branch is not called by the Flutter client, Edge Functions, or
-- any live RLS policy. Keep it available to trusted backend code only instead
-- of exposing a SECURITY DEFINER RPC to authenticated REST callers.
revoke execute on function public.can_access_branch(uuid)
  from authenticated;
grant execute on function public.can_access_branch(uuid)
  to service_role;
