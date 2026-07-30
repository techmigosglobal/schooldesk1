-- Repair historical account linkage without changing credentials, financial data,
-- or any existing alias.  A missing alias makes a valid username/password unable
-- to reach Supabase Auth even though the parent account itself remains active.
--
-- Conflicting usernames are deliberately left untouched: the login handler can
-- still resolve the profile by its authenticated account id, and no account is
-- ever reassigned by this maintenance migration.
insert into public.username_aliases (username, auth_user_id, school_id)
select
  lower(trim(u.username)),
  u.id,
  u.school_id
from public.users u
join auth.users au on au.id = u.id
left join public.username_aliases own_alias
  on own_alias.auth_user_id = u.id
where nullif(trim(u.username), '') is not null
  and own_alias.auth_user_id is null
on conflict (username) do nothing;
