-- Canonical push-token storage is public.notification_devices.
-- Keep public.notification_device_tokens as a deprecated compatibility table
-- while the processor still reads legacy rows during the transition window.

comment on table public.notification_devices is
  'Canonical push token registry used by current app and API writes.';

comment on table public.notification_device_tokens is
  'DEPRECATED legacy push token store. Do not write new rows here; retained temporarily for compatibility reads and cleanup only.';
