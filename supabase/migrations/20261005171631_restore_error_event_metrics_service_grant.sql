-- The System Monitor calls this RPC through the Edge API's service-role
-- client. Restore that backend-only permission without exposing the metrics
-- function to browser roles.
revoke execute on function public.error_event_retention_metrics(uuid)
  from public, anon, authenticated;
grant execute on function public.error_event_retention_metrics(uuid)
  to service_role;
