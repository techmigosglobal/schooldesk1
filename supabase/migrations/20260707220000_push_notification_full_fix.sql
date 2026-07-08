-- ============================================================
-- Migration: Push Notification Full Fix
-- 1. Fix overly permissive RLS on notification_events
-- 2. Deduplicate active FCM tokens per user to prevent duplicate push sends
-- 3. Re-schedule pg_cron jobs with exact API URL and service role key
-- ============================================================

-- 1. Fix notification_events RLS policy to restrict to service_role
DROP POLICY IF EXISTS "Service can manage notification events" ON public.notification_events;
CREATE POLICY "Service can manage notification events" ON public.notification_events
  FOR ALL TO service_role USING (true);

-- 2. Deduplicate active tokens: keep only the most recently registered active token per user
WITH ranked_user_tokens AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY school_id, user_id
      ORDER BY last_registered_at DESC NULLS LAST, created_at DESC NULLS LAST
    ) AS rn
  FROM public.notification_devices
  WHERE is_active = true
)
UPDATE public.notification_devices nd
SET is_active = false
FROM ranked_user_tokens rut
WHERE nd.id = rut.id
  AND rut.rn > 1;

-- 3. Re-schedule daily-birthday-alerts cron job
DO $$
BEGIN
  PERFORM cron.unschedule('daily-birthday-alerts');
EXCEPTION WHEN OTHERS THEN
  NULL;
END
$$;

SELECT cron.schedule(
  'daily-birthday-alerts',
  '0 6 * * *',
  $$
  SELECT net.http_post(
    url    := 'https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api/jobs/birthday-alerts/run',
    headers := jsonb_build_object(
      'Authorization', 'Bearer 18fd0a5339c8e5e81c3122a7607608e48631ef47cf3f5ac72c3486f7d115ee41',
      'Content-Type',  'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- 4. Re-schedule process-notification-events cron job
DO $$
BEGIN
  PERFORM cron.unschedule('process-notification-events');
EXCEPTION WHEN OTHERS THEN
  NULL;
END
$$;

SELECT cron.schedule(
  'process-notification-events',
  '*/2 * * * *',
  $$
  SELECT net.http_post(
    url    := 'https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/notification-processor',
    headers := jsonb_build_object(
      'Authorization', 'Bearer 18fd0a5339c8e5e81c3122a7607608e48631ef47cf3f5ac72c3486f7d115ee41',
      'Content-Type',  'application/json'
    ),
    body := jsonb_build_object('source', 'pg_cron')
  );
  $$
);
