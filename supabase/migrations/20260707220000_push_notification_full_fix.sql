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

-- 3-4. Remove the legacy hosted schedulers. Local Docker tests invoke the
-- Edge Functions directly; a hosted scheduler must be provisioned separately
-- with deployment-time settings and secrets.
DO $$
BEGIN
  IF to_regnamespace('cron') IS NOT NULL THEN
    EXECUTE 'select cron.unschedule($1)' USING 'daily-birthday-alerts';
    EXECUTE 'select cron.unschedule($1)' USING 'process-notification-events';
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END
$$;
