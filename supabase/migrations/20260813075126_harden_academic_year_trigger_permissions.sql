-- The trigger function is created by the following principal-workflow
-- migration. Keep this ordering-compatible on a clean replay: older hosted
-- databases may already have it, while a fresh local reset has not reached
-- that later file yet.
do $$
begin
  if to_regprocedure('public.guard_academic_year_invariants()') is not null then
    execute 'revoke execute on function public.guard_academic_year_invariants() from public, anon, authenticated';
    execute 'grant execute on function public.guard_academic_year_invariants() to service_role';
  end if;
end;
$$;
