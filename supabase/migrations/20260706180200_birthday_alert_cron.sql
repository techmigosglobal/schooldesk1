-- ============================================================
-- Migration 0021: Birthday Alert Cron Job
-- Schedule a daily pg_cron job to trigger the birthday alert
-- Edge Function endpoint at 06:00 UTC every day.
-- ============================================================

-- Enable required extensions (idempotent)
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- Remove any previous birthday alert cron job (idempotent)
do $$
begin
  perform cron.unschedule('daily-birthday-alerts');
exception when others then
  -- Job does not exist yet; nothing to unschedule.
  null;
end
$$;

-- Schedule only when deployment-time settings explicitly opt in. Local
-- Docker resets leave these settings unset, so no outbound job is created.
do $$
begin
  if nullif(current_setting('app.settings.supabase_url', true), '') is not null
     and nullif(current_setting('app.settings.service_role_key', true), '') is not null then
    perform cron.schedule(
      'daily-birthday-alerts',
      '0 6 * * *',
      $cron$
      select net.http_post(
        url    := current_setting('app.settings.supabase_url', true) || '/functions/v1/api/jobs/birthday-alerts/run',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true),
          'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
      );
      $cron$
    );
  end if;
end
$$;
