-- Keep existing shared demo access easy to communicate. Login remains limited
-- to the enabled fictional demo account and passwords still rotate every 72 h.
update public.demo_accounts
set username = 'demo1'
where username = 'schooldesk-demo'
  and not exists (
    select 1 from public.demo_accounts existing where existing.username = 'demo1'
  );
