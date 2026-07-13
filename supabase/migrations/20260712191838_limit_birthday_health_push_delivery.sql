-- Prevent duplicate birthday and health-reminder push delivery.
--
-- notification_logs is already unique per logical notification, but the push
-- queue previously accepted a fresh notification_events row every time a
-- dashboard triggered the birthday endpoint. Immediate processing could also
-- race the two-minute cron processor. The queue now has a durable idempotency
-- key; processor code claims each row before contacting FCM.

alter table public.notification_events
  add column if not exists dedupe_key text;

create unique index if not exists uniq_notification_events_dedupe_key
  on public.notification_events(dedupe_key)
  where dedupe_key is not null;

create index if not exists idx_notification_events_pending_created
  on public.notification_events(created_at)
  where processed = false;

-- Do not deliver yesterday's accumulated birthday backlog after this fix is
-- released. The durable notification_log rows remain available in-app.
update public.notification_events
set processed = true,
    sent_at = coalesce(sent_at, now())
where processed = false
  and event_type in ('birthday', 'birthday_wish');

-- Replace the single late-morning birthday run with one morning and one
-- afternoon run in Asia/Kolkata (03:30 and 09:30 UTC respectively). Reuse the
-- existing command so its already-configured authorization material is not
-- duplicated into another migration.
do $$
declare
  existing_command text;
  morning_command text;
  afternoon_command text;
begin
  select command
    into existing_command
  from cron.job
  where jobname = 'daily-birthday-alerts'
  limit 1;

  begin
    perform cron.unschedule('daily-birthday-alerts');
  exception when others then
    null;
  end;
  begin
    perform cron.unschedule('daily-birthday-alerts-morning');
  exception when others then
    null;
  end;
  begin
    perform cron.unschedule('daily-birthday-alerts-afternoon');
  exception when others then
    null;
  end;

  if existing_command is not null then
    morning_command := replace(
      existing_command,
      '''{}''::jsonb',
      '''{"delivery_window":"morning"}''::jsonb'
    );
    afternoon_command := replace(
      existing_command,
      '''{}''::jsonb',
      '''{"delivery_window":"afternoon"}''::jsonb'
    );

    perform cron.schedule(
      'daily-birthday-alerts-morning',
      '30 3 * * *',
      morning_command
    );
    perform cron.schedule(
      'daily-birthday-alerts-afternoon',
      '30 9 * * *',
      afternoon_command
    );
  end if;
end
$$;
