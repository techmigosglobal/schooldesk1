-- Keep notification storage bounded and remove stale class records that no
-- longer have a section. Fee invoice item snapshots preserve historic amounts
-- and labels when their source fee structure is removed.

delete from public.fee_structures fs
where not exists (
  select 1
  from public.sections s
  where s.school_id = fs.school_id
    and s.grade_id = fs.grade_id
);

delete from public.grades g
where not exists (
  select 1
  from public.sections s
  where s.school_id = g.school_id
    and s.grade_id = g.id
);

delete from public.notification_events
where created_at < now() - interval '10 days';

delete from public.notification_logs
where created_at < now() - interval '10 days';

create index if not exists idx_notification_logs_retention
  on public.notification_logs(created_at);

create index if not exists idx_notification_events_retention
  on public.notification_events(created_at);

do $$
begin
  perform cron.unschedule('purge-expired-notifications');
exception when others then
  null;
end
$$;

select cron.schedule(
  'purge-expired-notifications',
  '15 2 * * *',
  $$
    delete from public.notification_events
    where created_at < now() - interval '10 days';

    delete from public.notification_logs
    where created_at < now() - interval '10 days';
  $$
);
