-- Fix FCM token sharing: deactivate tokens where the same FCM token is
-- active for multiple users in the same school. A physical device can only
-- belong to one user at a time.

-- 1. For each FCM token that appears for multiple active users in the same
--    school, keep only the MOST RECENTLY registered one active and deactivate
--    all older rows.
WITH ranked AS (
  SELECT
    id,
    school_id,
    user_id,
    fcm_token,
    last_registered_at,
    ROW_NUMBER() OVER (
      PARTITION BY school_id, fcm_token
      ORDER BY last_registered_at DESC NULLS LAST, created_at DESC NULLS LAST
    ) AS rn
  FROM public.notification_devices
  WHERE is_active = true
    AND coalesce(fcm_token, '') <> ''
)
UPDATE public.notification_devices nd
SET is_active = false
FROM ranked r
WHERE nd.id = r.id
  AND r.rn > 1;

-- 2. Also clean up the deprecated legacy table: for each token that appears
--    for multiple users, delete all but the most recent row.
WITH ranked_legacy AS (
  SELECT
    id,
    user_id,
    token,
    created_at,
    ROW_NUMBER() OVER (
      PARTITION BY token
      ORDER BY created_at DESC NULLS LAST
    ) AS rn
  FROM public.notification_device_tokens
  WHERE coalesce(token, '') <> ''
)
DELETE FROM public.notification_device_tokens ndt
USING ranked_legacy r
WHERE ndt.id = r.id
  AND r.rn > 1;

-- 3. Log the cleanup results
DO $$
DECLARE
  cleaned_canonical INT;
  cleaned_legacy INT;
BEGIN
  SELECT COUNT(*) INTO cleaned_canonical
    FROM public.notification_devices
    WHERE is_active = false
      AND updated_at >= now() - interval '1 minute';

  SELECT COUNT(*) INTO cleaned_legacy
    FROM public.notification_device_tokens
    WHERE created_at >= now() - interval '1 minute';

  RAISE NOTICE 'FCM token sharing fix: deactivated % canonical rows, deleted % legacy rows',
    cleaned_canonical, cleaned_legacy;
END $$;

-- 4. Add a comment explaining the invariant
COMMENT ON TABLE public.notification_devices IS
  'Canonical push token registry. Each FCM token must be active for at most '
  'one user per school — registerDeviceToken deactivates other users'' rows '
  'before upserting.';
