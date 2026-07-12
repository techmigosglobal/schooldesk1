-- Fix role_name data-integrity issues discovered during audit:
--
-- 1. The production Super Admin account (vinay@schooldesk.local) had
--    role_name = 'kiosk' in BOTH public.users and auth.users app_metadata,
--    causing the app to route the Super Admin login to the Staff Attendance
--    QR Display (kiosk) screen instead of the Super Admin dashboard.
--
-- 2. Several parent accounts had role_name = 'Parent' (mixed case) instead
--    of the lowercase 'parent' used everywhere in application/RLS logic.
--    Most edge-function handlers defensively lowercase role_name before
--    comparing, but a few (e.g. monitoring.ts super_admin checks) use a
--    strict equality check, so any future mixed-case role is a latent
--    authorization bug. Normalize existing data and guard against
--    recurrence with a trigger.

-- ── Fix the known super_admin account misassigned as kiosk ──────────────────
update public.users u
set role_name = 'super_admin'
from auth.users au
where u.id = au.id
  and au.email = 'vinay@schooldesk.local'
  and u.role_name <> 'super_admin';

update auth.users
set raw_app_meta_data = jsonb_set(raw_app_meta_data, '{role_name}', '"super_admin"')
where email = 'vinay@schooldesk.local'
  and raw_app_meta_data->>'role_name' is distinct from 'super_admin';

-- ── Normalize casing for all existing rows ──────────────────────────────────
update public.users
set role_name = lower(role_name)
where role_name is not null
  and role_name <> lower(role_name);

update auth.users
set raw_app_meta_data = jsonb_set(
  raw_app_meta_data,
  '{role_name}',
  to_jsonb(lower(raw_app_meta_data->>'role_name'))
)
where raw_app_meta_data->>'role_name' is not null
  and raw_app_meta_data->>'role_name' <> lower(raw_app_meta_data->>'role_name');

-- ── Guard against future casing drift on public.users ───────────────────────
create or replace function public.enforce_lowercase_role_name()
returns trigger
language plpgsql
as $$
begin
  if new.role_name is not null then
    new.role_name := lower(new.role_name);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_users_lowercase_role_name on public.users;
create trigger trg_users_lowercase_role_name
before insert or update of role_name on public.users
for each row
execute function public.enforce_lowercase_role_name();
