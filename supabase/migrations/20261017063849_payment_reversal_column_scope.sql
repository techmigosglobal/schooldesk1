-- Qualify columns that share names with the RETURNS TABLE output variables.
create or replace function public.reverse_fee_payment(
  p_school_id uuid,
  p_payment_id uuid,
  p_reversed_by uuid,
  p_reason text default 'Payment reversed'
)
returns table(payment_id uuid, invoice_id uuid, invoice_status text, balance numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_payment public.payments%rowtype;
  v_invoice public.fee_invoices%rowtype;
  v_paid numeric;
  v_balance numeric;
  v_status text;
  v_now timestamptz := now();
begin
  select * into v_payment
  from public.payments
  where id = p_payment_id and school_id = p_school_id
  for update;
  if not found then raise exception 'Payment not found'; end if;
  if lower(coalesce(v_payment.status, '')) = 'reversed' then
    raise exception 'Payment has already been reversed';
  end if;

  if v_payment.invoice_id is null then
    raise exception 'Payment is not linked to an invoice';
  end if;
  select * into v_invoice
  from public.fee_invoices
  where id = v_payment.invoice_id and school_id = p_school_id
  for update;
  if not found then raise exception 'Invoice not found'; end if;

  update public.payments as p
  set status = 'reversed', reversed_at = v_now, reversed_by = p_reversed_by,
      reversal_reason = nullif(trim(coalesce(p_reason, '')), ''), updated_at = v_now
  where p.id = v_payment.id and p.school_id = p_school_id;

  update public.fee_receipts as receipt
  set voided_at = v_now, voided_by = p_reversed_by,
      void_reason = nullif(trim(coalesce(p_reason, '')), '')
  where receipt.payment_id = v_payment.id and receipt.school_id = p_school_id;

  update public.parent_payment_requests as request
  set status = 'reversed', admin_remarks = nullif(trim(coalesce(p_reason, '')), ''),
      updated_at = v_now
  where request.payment_id = v_payment.id and request.school_id = p_school_id;

  select coalesce(sum(p.amount) filter (where lower(coalesce(p.status, '')) not in
    ('reversed', 'void', 'voided', 'cancelled')), 0)
    into v_paid
  from public.payments p
  where p.invoice_id = v_invoice.id and p.school_id = p_school_id;
  v_balance := greatest(0, v_invoice.net_amount - v_paid);
  v_status := case when v_balance <= 0 then 'paid'
                   when v_paid > 0 then 'partial' else 'unpaid' end;

  update public.fee_invoices as invoice
  set paid_amount = v_paid, balance = v_balance, status = v_status, updated_at = v_now
  where invoice.id = v_invoice.id and invoice.school_id = p_school_id;

  return query select v_payment.id, v_invoice.id, v_status, v_balance;
end;
$$;

revoke all on function public.reverse_fee_payment(uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.reverse_fee_payment(uuid,uuid,uuid,text) to service_role;
notify pgrst,'reload schema';
