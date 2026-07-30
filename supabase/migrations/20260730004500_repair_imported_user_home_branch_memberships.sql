-- Every active account needs access to its own school branch. The original
-- organization migration backfilled then-existing users, but later Excel
-- imports could create parent accounts without a branch_memberships row. That
-- made authenticated parent requests with the normal branch header fail.

insert into public.branch_memberships (user_id, school_id, role_name, is_active)
select u.id, u.school_id, lower(trim(u.role_name)), u.is_active
from public.users u
where u.school_id is not null
on conflict (user_id, school_id) do update
set role_name = excluded.role_name,
    is_active = excluded.is_active;

create or replace function public.ensure_user_home_branch_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.school_id is null then
    return new;
  end if;

  insert into public.branch_memberships (user_id, school_id, role_name, is_active)
  values (new.id, new.school_id, lower(trim(new.role_name)), new.is_active)
  on conflict (user_id, school_id) do update
  set role_name = excluded.role_name,
      is_active = excluded.is_active;

  return new;
end;
$$;

drop trigger if exists trg_user_home_branch_membership on public.users;
create trigger trg_user_home_branch_membership
after insert or update of school_id, role_name, is_active on public.users
for each row execute function public.ensure_user_home_branch_membership();

notify pgrst, 'reload schema';
