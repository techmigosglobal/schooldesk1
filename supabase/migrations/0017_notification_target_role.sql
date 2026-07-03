alter table public.notification_logs
  add column if not exists target_role text;

create index if not exists idx_notification_logs_target_role
  on public.notification_logs(target_role, created_at desc);
