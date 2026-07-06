-- Configure the hosted notification processor scheduler.
-- The notification-processor function is deployed with verify_jwt=false, so
-- the cron job can invoke it without storing service-role material in Postgres.

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema extensions;

do $$
begin
  perform cron.unschedule('process-notification-events');
exception
  when others then
    null;
end $$;

select cron.schedule(
  'process-notification-events',
  '*/2 * * * *',
  $$
  select net.http_post(
    url := 'https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/notification-processor',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object('source', 'pg_cron')
  );
  $$
);
