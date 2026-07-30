-- Every completed payment already receives a unique fee_receipts row through
-- record_fee_payment. Capture its financial state at that exact point so each
-- dated receipt remains correct after later partial payments are collected.

create or replace function public.capture_payment_receipt_snapshot()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_payment public.payments%rowtype;
  v_invoice public.fee_invoices%rowtype;
  v_snapshot_id uuid;
  v_paid_amount numeric;
  v_balance numeric;
begin
  select * into v_payment
  from public.payments
  where id = new.payment_id and school_id = new.school_id;
  if not found then
    raise exception 'Payment for receipt % was not found', new.id;
  end if;

  select * into v_invoice
  from public.fee_invoices
  where id = new.invoice_id and school_id = new.school_id;
  if not found then
    raise exception 'Invoice for receipt % was not found', new.id;
  end if;

  -- This trigger runs before record_fee_payment updates the invoice totals.
  v_paid_amount := coalesce(v_invoice.paid_amount, 0) + coalesce(new.amount, 0);
  v_balance := greatest(0, coalesce(v_invoice.net_amount, v_invoice.total_amount, 0) - v_paid_amount);

  insert into public.finance_document_snapshots (
    school_id,
    invoice_id,
    payment_id,
    receipt_id,
    document_kind,
    document_number,
    source_totals,
    source_snapshot,
    generated_by
  ) values (
    new.school_id,
    new.invoice_id,
    new.payment_id,
    new.id,
    'payment_receipt',
    new.receipt_number,
    jsonb_build_object(
      'total_amount', coalesce(v_invoice.net_amount, v_invoice.total_amount, 0),
      'paid_amount', v_paid_amount,
      'balance', v_balance,
      'this_payment_amount', new.amount
    ),
    jsonb_build_object(
      'receipt_number', new.receipt_number,
      'payment_date', v_payment.paid_at,
      'issued_at', new.issued_at,
      'payment_method', coalesce(new.payment_method, v_payment.payment_method, ''),
      'reference_number', coalesce(new.transaction_ref, v_payment.reference_number, ''),
      'notes', coalesce(v_payment.notes, ''),
      'invoice_number', v_invoice.invoice_number,
      'student_id', v_payment.student_id,
      'fee_items', coalesce((
        select jsonb_agg(jsonb_build_object(
          'description', coalesce(item.category_name, 'Fee'),
          'amount', item.amount
        ) order by item.created_at nulls last, item.id)
        from public.fee_invoice_items item
        where item.invoice_id = new.invoice_id
      ), '[]'::jsonb)
    ),
    v_payment.created_by
  ) on conflict (school_id, document_kind, document_number, version)
  do nothing
  returning id into v_snapshot_id;

  if v_snapshot_id is null then
    select id into v_snapshot_id
    from public.finance_document_snapshots
    where school_id = new.school_id
      and document_kind = 'payment_receipt'
      and document_number = new.receipt_number
      and version = 1;
  end if;

  update public.fee_receipts
  set document_snapshot_id = v_snapshot_id
  where id = new.id and document_snapshot_id is null;
  return new;
end;
$$;

drop trigger if exists capture_payment_receipt_snapshot on public.fee_receipts;
create trigger capture_payment_receipt_snapshot
after insert on public.fee_receipts
for each row execute function public.capture_payment_receipt_snapshot();

-- Preserve historical collections as dated receipt records too. Their exact
-- legacy totals remain the best data available; no payment or invoice is
-- changed by this backfill.
insert into public.finance_document_snapshots (
  school_id,
  invoice_id,
  payment_id,
  receipt_id,
  document_kind,
  document_number,
  source_totals,
  source_snapshot,
  generated_by
)
select
  receipt.school_id,
  receipt.invoice_id,
  receipt.payment_id,
  receipt.id,
  'payment_receipt',
  receipt.receipt_number,
  jsonb_build_object(
    'total_amount', coalesce(invoice.net_amount, invoice.total_amount, 0),
    'paid_amount', coalesce(invoice.paid_amount, 0),
    'balance', coalesce(invoice.balance, 0),
    'this_payment_amount', receipt.amount
  ),
  jsonb_build_object(
    'receipt_number', receipt.receipt_number,
    'payment_date', payment.paid_at,
    'issued_at', receipt.issued_at,
    'payment_method', coalesce(receipt.payment_method, payment.payment_method, ''),
    'reference_number', coalesce(receipt.transaction_ref, payment.reference_number, ''),
    'notes', coalesce(payment.notes, ''),
    'invoice_number', invoice.invoice_number,
    'student_id', payment.student_id,
    'fee_items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'description', coalesce(item.category_name, 'Fee'),
        'amount', item.amount
      ) order by item.created_at nulls last, item.id)
      from public.fee_invoice_items item
      where item.invoice_id = receipt.invoice_id
    ), '[]'::jsonb)
  ),
  payment.created_by
from public.fee_receipts receipt
join public.payments payment on payment.id = receipt.payment_id
join public.fee_invoices invoice on invoice.id = receipt.invoice_id
where receipt.document_snapshot_id is null
on conflict (school_id, document_kind, document_number, version) do nothing;

update public.fee_receipts receipt
set document_snapshot_id = snapshot.id
from public.finance_document_snapshots snapshot
where receipt.document_snapshot_id is null
  and snapshot.receipt_id = receipt.id
  and snapshot.document_kind = 'payment_receipt';

revoke all on function public.capture_payment_receipt_snapshot() from public, anon, authenticated;
