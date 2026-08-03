-- Keep student lifecycle values consistent across Flutter, the website, and
-- the active-student dashboard/fee workflows. The API also normalizes these
-- aliases, but this repairs rows written before that boundary existed.
update public.students
set
  status = case lower(trim(status))
    when 'acive' then 'active'
    when 'transferred' then 'transfer'
    when 'withdrawn' then 'inactive'
    else lower(trim(status))
  end,
  updated_at = now()
where lower(trim(status)) in ('acive', 'transferred', 'withdrawn');

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.students'::regclass
      and conname = 'students_status_check'
  ) then
    alter table public.students
      add constraint students_status_check
      check (status in ('active', 'inactive', 'transfer', 'pending'));
  end if;
end
$$;

-- This is a trigger-only helper for imported-user branch membership repair;
-- it must not be exposed as an RPC to client roles.
revoke all on function public.ensure_user_home_branch_membership() from public;
revoke all on function public.ensure_user_home_branch_membership() from anon;
revoke all on function public.ensure_user_home_branch_membership() from authenticated;
