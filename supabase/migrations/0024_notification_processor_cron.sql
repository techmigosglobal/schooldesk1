-- Migration: retain the notification-processor scheduler contract.
--
-- Local Docker resets intentionally do not schedule outbound HTTP jobs. A
-- separately approved hosted deployment may opt in by setting both values at
-- deployment time; no URL or credential is stored in this migration.

-- Enable required extensions
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- Remove any previous notification processor cron job. pg_cron raises when the
-- named job does not exist on a fresh database, so make the cleanup explicit.
do $$
begin
  perform cron.unschedule('process-notification-events');
exception when others then
  -- A fresh local reset has nothing to unschedule.
  null;
end;
$$;

do $$
begin
  if nullif(current_setting('app.settings.supabase_url', true), '') is not null
     and nullif(current_setting('app.settings.service_role_key', true), '') is not null then
    perform cron.schedule(
      'process-notification-events',
      '*/2 * * * *',
      $cron$
      select net.http_post(
        url    := current_setting('app.settings.supabase_url', true) || '/functions/v1/notification-processor',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true),
          'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
      );
      $cron$
    );
  end if;
end $$;
