-- Backfill legacy notification_device_tokens into notification_devices so the
-- hosted notification processor can see older registered devices too.

insert into public.notification_devices (
  school_id,
  user_id,
  fcm_token,
  device_type,
  is_active,
  last_registered_at
)
select
  u.school_id,
  t.user_id,
  t.token,
  coalesce(nullif(t.platform, ''), 'android'),
  true,
  coalesce(t.created_at, now())
from public.notification_device_tokens t
join public.users u on u.id = t.user_id
where coalesce(t.token, '') <> ''
  and u.school_id is not null
on conflict (school_id, user_id, fcm_token)
do update set
  device_type = excluded.device_type,
  is_active = true,
  last_registered_at = coalesce(
    greatest(
      public.notification_devices.last_registered_at,
      excluded.last_registered_at
    ),
    excluded.last_registered_at,
    public.notification_devices.last_registered_at
  );
