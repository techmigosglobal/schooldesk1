-- Historical hosted scheduler migration.
--
-- The old version embedded a hosted project URL.  Local resets must never
-- enqueue requests to a cloud project, so this migration only removes a job
-- left by an older database.  A separately approved hosted deployment can
-- create its scheduler with deployment-time settings.
do $$
begin
  if to_regnamespace('cron') is not null then
    execute 'select cron.unschedule($1)' using 'process-notification-events';
  end if;
exception when others then
  null;
end $$;
