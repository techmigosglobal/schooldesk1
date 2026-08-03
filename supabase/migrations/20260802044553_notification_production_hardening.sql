-- Notification production hardening:
-- - retain user dismissals without deleting the delivery history;
-- - persist the app-facing notification switches;
-- - bound and back off failed push deliveries.

alter table public.notification_logs
  add column if not exists deleted_at timestamptz;

create index if not exists idx_notification_logs_user_unread
  on public.notification_logs(user_id, created_at desc)
  where is_read = false and deleted_at is null;

alter table public.notification_preferences
  add column if not exists pending_approvals boolean not null default true,
  add column if not exists fee_reminders boolean not null default true,
  add column if not exists general_alerts boolean not null default true;

alter table public.notification_events
  add column if not exists retry_count integer not null default 0,
  add column if not exists next_retry_at timestamptz,
  add column if not exists last_error text;

alter table public.notification_events
  drop constraint if exists notification_events_retry_count_check,
  add constraint notification_events_retry_count_check
    check (retry_count >= 0);

create index if not exists idx_notification_events_retryable
  on public.notification_events(created_at)
  where processed = false and retry_count < 5;

notify pgrst, 'reload schema';
notify pgrst, 'reload config';
