-- Read-only contract smoke test for the payment-proof approval boundary.
-- Run against a linked/staging database after migrations are applied.
do $$
declare
  status_definition text;
  rpc_definition text;
begin
  select pg_get_constraintdef(oid)
    into status_definition
  from pg_constraint
  where conrelid = 'public.parent_payment_requests'::regclass
    and conname = 'parent_payment_requests_status_check';

  if status_definition is null
     or status_definition not like '%pending%'
     or status_definition not like '%submitted%'
     or status_definition not like '%resubmitted%' then
    raise exception 'legacy payment-request statuses are not retained';
  end if;

  select pg_get_functiondef(
    'public.record_fee_payment(uuid,uuid,uuid,numeric,text,text,timestamptz,text,uuid,uuid,text)'::regprocedure
  )
    into rpc_definition;

  if rpc_definition not like '%''pending''%'
     or rpc_definition not like '%''pending_verification''%'
     or rpc_definition not like '%''resubmitted''%'
     or rpc_definition not like '%''submitted''%' then
    raise exception 'record_fee_payment does not accept every reviewable alias';
  end if;
  if rpc_definition like '%''initiated''%'
     or rpc_definition like '%''clarification_required''%' then
    raise exception 'record_fee_payment accepts a non-actionable status';
  end if;
end;
$$;
