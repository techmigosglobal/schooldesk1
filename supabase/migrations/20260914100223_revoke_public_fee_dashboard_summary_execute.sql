-- Fee dashboard aggregates are reached through the authorized Edge API. They
-- must not be callable through the public PostgREST RPC surface because this
-- function is SECURITY DEFINER and its arguments are school identifiers.
revoke execute on function public.fee_dashboard_summary(uuid, uuid)
  from anon, authenticated;

grant execute on function public.fee_dashboard_summary(uuid, uuid)
  to service_role;
