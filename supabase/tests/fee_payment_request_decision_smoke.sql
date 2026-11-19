-- Run against the synthetic Docker database. All fixture changes roll back.
begin;

do $$
declare
  invoice public.fee_invoices%rowtype;
  actor uuid;
  request_id uuid;
  oversized_id uuid;
  first_result jsonb;
  replay_result jsonb;
begin
  select * into strict invoice
  from public.fee_invoices where balance >= 2 order by id limit 1;
  select id into strict actor from public.users
  where school_id = invoice.school_id and role_name = 'principal' and is_active
  order by id limit 1;

  if has_function_privilege(
    'authenticated', 'public.decide_parent_payment_request(uuid,uuid,text,text,uuid)', 'execute'
  ) then
    raise exception 'Only the Edge service role can commit a proof decision';
  end if;

  insert into public.parent_payment_requests (school_id, student_id, invoice_id, amount, status)
  values (invoice.school_id, invoice.student_id, invoice.id, 1, 'pending')
  returning id into request_id;

  first_result := public.decide_parent_payment_request(
    invoice.school_id, request_id, 'approved', 'Test approval', actor
  );
  replay_result := public.decide_parent_payment_request(
    invoice.school_id, request_id, 'approved', 'Test approval', actor
  );
  if first_result->>'replayed' is distinct from 'false'
    or replay_result->>'replayed' is distinct from 'true'
    or replay_result->'request' is distinct from first_result->'request'
    or not exists (
      select 1 from public.parent_payment_requests r
      join public.fee_receipts receipt on receipt.id = r.receipt_id
      where r.id = request_id and r.status = 'approved'
        and receipt.payment_id = r.payment_id and receipt.document_snapshot_id is not null
    )
    or (select balance from public.fee_invoices where id = invoice.id) <> invoice.balance - 1
    or (select count(*) from public.payments
        where school_id = invoice.school_id and idempotency_key = 'request:' || request_id) <> 1 then
    raise exception 'Approval, receipt, invoice and exact replay are inconsistent';
  end if;

  begin
    perform public.decide_parent_payment_request(invoice.school_id, request_id, 'rejected', null, actor);
    raise exception 'An approved request accepted a competing rejection';
  exception when sqlstate 'PT409' then null;
  end;
  begin
    perform public.decide_parent_payment_request(invoice.school_id, request_id, 'approved', 'Changed', actor);
    raise exception 'An approval replay accepted different remarks';
  exception when sqlstate 'PT409' then null;
  end;
  begin
    perform public.decide_parent_payment_request(gen_random_uuid(), request_id, 'approved', 'Test approval', actor);
    raise exception 'An approval replay crossed school boundaries';
  exception when sqlstate 'PT404' then null;
  end;

  insert into public.parent_payment_requests (school_id, student_id, invoice_id, amount, status)
  values (invoice.school_id, invoice.student_id, invoice.id, invoice.balance + 1, 'submitted')
  returning id into oversized_id;
  begin
    perform public.decide_parent_payment_request(invoice.school_id, oversized_id, 'approved', null, actor);
    raise exception using errcode = 'XX000', message = 'An over-balance approval succeeded';
  exception when sqlstate 'P0001' then null;
  end;
  if not exists (
    select 1 from public.parent_payment_requests r
    where r.id = oversized_id and r.status = 'submitted' and r.payment_id is null and r.receipt_id is null
  ) or (select balance from public.fee_invoices where id = invoice.id) <> invoice.balance - 1 then
    raise exception 'A failed approval changed the request or ledger';
  end if;
end;
$$;

rollback;

select 'payment request atomic decision smoke passed' as result;
