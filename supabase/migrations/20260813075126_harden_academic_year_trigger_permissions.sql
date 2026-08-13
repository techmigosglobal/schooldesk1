-- The academic-year invariant function is invoked by a table trigger. It is
-- not a public RPC surface and must not be callable through PostgREST.
revoke execute on function public.guard_academic_year_invariants()
  from public, anon, authenticated;
grant execute on function public.guard_academic_year_invariants()
  to service_role;
