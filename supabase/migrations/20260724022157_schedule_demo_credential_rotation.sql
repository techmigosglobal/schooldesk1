-- Run the server-side rotation check hourly. It only rotates credentials whose
-- password_rotated_at is at least 72 hours old. The request is authenticated
-- using the existing project service-role setting; no secret is embedded in
-- this migration or visible in the cron command.
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

do $$
begin
  perform cron.unschedule('rotate-schooldesk-demo-credential');
exception when others then
  null;
end $$;

do $$
begin
  if nullif(current_setting('app.settings.supabase_url', true), '') is not null
     and nullif(current_setting('app.settings.service_role_key', true), '') is not null then
    perform cron.schedule(
      'rotate-schooldesk-demo-credential',
      '0 * * * *',
      $cron$
      select net.http_post(
        url := current_setting('app.settings.supabase_url', true) || '/functions/v1/api/jobs/demo-credential-rotation',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true),
          'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
      );
      $cron$
    );
  end if;
end
$$;
