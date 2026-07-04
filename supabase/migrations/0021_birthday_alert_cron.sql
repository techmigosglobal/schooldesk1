-- ============================================================
-- Migration 0021: Birthday Alert Cron Job
-- Schedule a daily pg_cron job to trigger the birthday alert
-- Edge Function endpoint at 06:00 UTC every day.
-- ============================================================

-- Enable required extensions (idempotent)
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- Remove any previous birthday alert cron job (idempotent)
select cron.unschedule('daily-birthday-alerts');

-- Schedule the birthday alert job to run daily at 06:00 UTC.
-- The Edge Function uses the service role key via the ANON_KEY header,
-- so it bypasses RLS and can read all students + write notifications.
select cron.schedule(
  'daily-birthday-alerts',
  '0 6 * * *',
  $$
  select net.http_post(
    url    := current_setting('app.settings.supabase_url') || '/functions/v1/api/jobs/birthday-alerts/run',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type',  'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
