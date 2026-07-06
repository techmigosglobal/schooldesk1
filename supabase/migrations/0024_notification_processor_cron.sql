-- Migration: Set up pg_cron job to periodically invoke the notification-processor edge function
-- This ensures push notifications are sent even when no direct trigger exists.
--
-- PREREQUISITE: The pg_net extension must be enabled and the Supabase URL + service role key
-- must be available. If your Supabase project does not expose these as postgres settings,
-- set them via: ALTER DATABASE postgres SET app.settings.supabase_url = '<url>';
--                ALTER DATABASE postgres SET app.settings.service_role_key = '<key>';

-- Enable required extensions
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- Remove any previous notification processor cron job (idempotent)
select cron.unschedule('process-notification-events');

-- Schedule the notification processor to run every 2 minutes
-- It fetches unprocessed notification_events and sends FCM push notifications
select cron.schedule(
  'process-notification-events',
  '*/2 * * * *',
  $$
  select net.http_post(
    url    := current_setting('app.settings.supabase_url', true) || '/functions/v1/notification-processor',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
