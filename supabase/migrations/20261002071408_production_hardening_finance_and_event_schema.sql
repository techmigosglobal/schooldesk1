-- Production hardening: move finance consistency into database transactions and
-- keep late-fine application idempotent across retries and scheduled runs.
alter table public.fee_invoices
  add column if not exists late_fine_amount numeric(12,2) not null default 0,
  add column if not exists late_fine_applied_at timestamptz;

create or replace function public.apply_late_fines(
  p_school_id uuid,
  p_run_date date default current_date
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_invoice record;
  v_rate numeric(12,2);
  v_grace integer;
  v_days integer;
  v_target numeric(12,2);
  v_delta numeric(12,2);
  v_updated integer := 0;
begin
  select coalesce(late_fine_per_day, 0), coalesce(grace_period_days, 0)
    into v_rate, v_grace
  from public.school_payment_settings
  where school_id = p_school_id;

  for v_invoice in
    select fi.*,
           coalesce(fs.late_fine_per_day, v_rate, 0) as structure_rate
    from public.fee_invoices fi
    left join public.fee_structures fs on fs.id = fi.fee_structure_id
    where fi.school_id = p_school_id
      and fi.due_date is not null
      and fi.due_date < p_run_date
      and fi.balance > 0
      and lower(coalesce(fi.status, '')) not in ('paid', 'void', 'cancelled')
    order by fi.id
    for update of fi
  loop
    v_rate := greatest(0, coalesce(v_invoice.structure_rate, 0));
    v_days := greatest(0, p_run_date - v_invoice.due_date - v_grace);
    v_target := round(v_days * v_rate, 2);
    v_delta := greatest(0, v_target - coalesce(v_invoice.late_fine_amount, 0));
    if v_delta <= 0 then
      continue;
    end if;

    update public.fee_invoices
    set late_fine_amount = coalesce(late_fine_amount, 0) + v_delta,
        total_amount = total_amount + v_delta,
        net_amount = net_amount + v_delta,
        balance = balance + v_delta,
        late_fine_applied_at = now(),
        updated_at = now()
    where id = v_invoice.id and school_id = p_school_id;
    v_updated := v_updated + 1;
  end loop;
  return v_updated;
end;
$$;

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

  update public.payments
  set status = 'reversed', reversed_at = v_now, reversed_by = p_reversed_by,
      reversal_reason = nullif(trim(coalesce(p_reason, '')), ''), updated_at = v_now
  where id = v_payment.id and school_id = p_school_id;

  update public.fee_receipts
  set voided_at = v_now, voided_by = p_reversed_by,
      void_reason = nullif(trim(coalesce(p_reason, '')), '')
  where payment_id = v_payment.id and school_id = p_school_id;

  update public.parent_payment_requests
  set status = 'reversed', admin_remarks = nullif(trim(coalesce(p_reason, '')), ''),
      updated_at = v_now
  where payment_id = v_payment.id and school_id = p_school_id;

  select coalesce(sum(amount) filter (where lower(coalesce(status, '')) not in
    ('reversed', 'void', 'voided', 'cancelled')), 0)
    into v_paid
  from public.payments
  where invoice_id = v_invoice.id and school_id = p_school_id;
  v_balance := greatest(0, v_invoice.net_amount - v_paid);
  v_status := case when v_balance <= 0 then 'paid'
                   when v_paid > 0 then 'partial' else 'unpaid' end;

  update public.fee_invoices
  set paid_amount = v_paid, balance = v_balance, status = v_status, updated_at = v_now
  where id = v_invoice.id and school_id = p_school_id;

  return query select v_payment.id, v_invoice.id, v_status, v_balance;
end;
$$;

revoke all on function public.apply_late_fines(uuid, date) from public, anon, authenticated;
grant execute on function public.apply_late_fines(uuid, date) to service_role;
revoke all on function public.reverse_fee_payment(uuid, uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.reverse_fee_payment(uuid, uuid, uuid, text) to service_role;
