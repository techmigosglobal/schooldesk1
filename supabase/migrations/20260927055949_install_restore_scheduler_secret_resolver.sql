-- Restore-only scheduler credential resolver.
--
-- Cron commands must not embed credentials.  The restore runner writes the
-- fresh target secrets to Vault and this private, allow-listed function is the
-- only database-side path that may read them.

create schema if not exists private;

create or replace function private.restore_scheduler_secret(secret_name text)
returns text
language plpgsql
security definer
set search_path = pg_catalog, pg_temp
as $$
declare
  resolved_secret text;
begin
  if secret_name not in (
    'NOTIFICATION_PROCESSOR_SECRET',
    'BIRTHDAY_ALERT_JOB_SECRET',
    'HEALTH_REMINDER_JOB_SECRET'
  ) then
    raise exception 'Unsupported scheduler secret name';
  end if;

  select decrypted_secret
    into resolved_secret
  from vault.decrypted_secrets
  where name = secret_name
  order by created_at desc
  limit 1;

  if resolved_secret is null or resolved_secret = '' then
    raise exception 'Scheduler secret % is not configured', secret_name;
  end if;

  return resolved_secret;
end;
$$;

alter function private.restore_scheduler_secret(text) owner to postgres;
revoke all on function private.restore_scheduler_secret(text) from public, anon, authenticated;
grant execute on function private.restore_scheduler_secret(text) to postgres;
