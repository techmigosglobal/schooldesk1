-- Keep notification delivery metadata used by fee, attendance, homework, and
-- chat workflows in the durable in-app notification log. These fields are
-- intentionally nullable so older notification rows remain valid.
alter table public.notification_logs
  add column if not exists reference_type text,
  add column if not exists reference_id text,
  add column if not exists action text;

create index if not exists idx_notification_logs_reference
  on public.notification_logs(reference_type, reference_id, created_at desc);

notify pgrst, 'reload schema';
notify pgrst, 'reload config';
