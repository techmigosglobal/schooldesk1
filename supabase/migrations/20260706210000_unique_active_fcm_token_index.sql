-- Belt-and-suspenders: enforce that each FCM token can be active for at most
-- one user per school at the database level. If two concurrent registrations
-- race past the application-level deactivation, Postgres will reject the
-- second upsert with a unique_violation instead of silently leaving two
-- active rows.

CREATE UNIQUE INDEX IF NOT EXISTS idx_notification_devices_active_token
  ON public.notification_devices (school_id, fcm_token)
  WHERE is_active = true;

COMMENT ON INDEX public.idx_notification_devices_active_token IS
  'Enforces single-active-user invariant per FCM token within a school. '
  'Prevents the notification processor from sending pushes to the wrong user '
  'if two concurrent registerDeviceToken calls race.';
