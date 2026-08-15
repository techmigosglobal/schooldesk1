-- Keep every historical parent payment-request status valid while making the
-- approval queue treat only the four reviewable aliases as actionable.
-- Existing rows are intentionally left untouched.

alter table public.fee_receipts
  add column if not exists display_receipt_number text;

alter table public.parent_payment_requests
  drop constraint if exists parent_payment_requests_status_check;

alter table public.parent_payment_requests
  add constraint parent_payment_requests_status_check check (
    status in (
      'initiated',
      'pending',
      'pending_verification',
      'submitted',
      'clarification_required',
      'resubmitted',
      'approved',
      'rejected',
      'reversed'
    )
  ) not valid;

-- This is the current receipt-producing implementation. The only workflow
-- change here is allowing the legacy `pending` alias through the same atomic
-- payment, receipt snapshot, balance, and idempotency path.
create or replace function public.record_fee_payment(
  p_school_id uuid,
  p_invoice_id uuid,
  p_student_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_reference_number text,
  p_paid_at timestamptz,
  p_notes text,
  p_created_by uuid,
  p_request_id uuid default null,
  p_idempotency_key text default null
)
returns table(
  payment_id uuid,
  receipt_id uuid,
  receipt_number text,
  invoice_status text,
  balance numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_invoice public.fee_invoices%rowtype;
  v_request public.parent_payment_requests%rowtype;
  v_existing_payment public.payments%rowtype;
  v_payment_id uuid;
  v_receipt_id uuid;
  v_receipt_number text;
  v_snapshot_id uuid;
  v_paid numeric;
  v_balance numeric;
  v_status text;
  v_sequence bigint;
  v_receipt_prefix text;
  v_year_label text;
  v_branch_token text;
  v_month_token text;
  v_paid_at timestamptz;
  v_year_start date;
  v_year_end date;
begin
  if p_amount <= 0 then
    raise exception 'Payment amount must be greater than zero';
  end if;

  v_paid_at := coalesce(p_paid_at, now());

  if nullif(trim(coalesce(p_idempotency_key, '')), '') is not null then
    select * into v_existing_payment
    from public.payments
    where school_id = p_school_id
      and idempotency_key = p_idempotency_key;
    if found then
      select r.id,
             coalesce(nullif(trim(r.display_receipt_number), ''), r.receipt_number),
             r.document_snapshot_id
      into v_receipt_id, v_receipt_number, v_snapshot_id
      from public.fee_receipts r
      where r.payment_id = v_existing_payment.id
      order by r.issued_at desc
      limit 1;
      if v_receipt_id is null or v_snapshot_id is null then
        raise exception 'Receipt snapshot was not generated';
      end if;
      return query
      select
        v_existing_payment.id,
        v_receipt_id,
        v_receipt_number,
        coalesce((
          select fi.status from public.fee_invoices fi
          where fi.id = v_existing_payment.invoice_id
        ), 'partial'),
        coalesce((
          select fi.balance from public.fee_invoices fi
          where fi.id = v_existing_payment.invoice_id
        ), 0);
      return;
    end if;
  end if;

  select * into v_invoice
  from public.fee_invoices
  where id = p_invoice_id
    and school_id = p_school_id
    and student_id = p_student_id
  for update;
  if not found then
    raise exception 'Invoice not found';
  end if;
  if p_amount > v_invoice.balance then
    raise exception 'Payment amount exceeds the remaining balance';
  end if;

  if p_request_id is not null then
    select * into v_request
    from public.parent_payment_requests
    where id = p_request_id and school_id = p_school_id
    for update;
    if not found then
      raise exception 'Payment request not found';
    end if;
    if v_request.status not in (
      'pending', 'pending_verification', 'resubmitted', 'submitted'
    ) then
      raise exception 'Payment request is not awaiting approval';
    end if;
    if v_request.payment_id is not null or v_request.amount <> p_amount then
      raise exception 'Payment request has changed';
    end if;
  end if;

  select
    upper(regexp_replace(coalesce(nullif(trim(fs.receipt_prefix), ''), 'RCP'), '[^A-Za-z0-9]+', '', 'g')),
    upper(regexp_replace(coalesce(nullif(trim(sc.branch_code), ''), 'MAIN'), '[^A-Za-z0-9]+', '', 'g')),
    ay.start_date,
    ay.end_date
  into
    v_receipt_prefix,
    v_branch_token,
    v_year_start,
    v_year_end
  from public.schools sc
  left join public.school_finance_settings fs
    on fs.school_id = sc.id
  left join public.academic_years ay
    on ay.id = v_invoice.academic_year_id and ay.school_id = p_school_id
  where sc.id = p_school_id;

  if v_receipt_prefix is null or v_receipt_prefix = '' then
    v_receipt_prefix := 'RCP';
  end if;
  if v_branch_token is null or v_branch_token = '' then
    v_branch_token := 'MAIN';
  end if;
  if v_year_start is not null and v_year_end is not null then
    v_year_label := to_char(v_year_start, 'YY') || '-' || to_char(v_year_end, 'YY');
  else
    v_year_label := to_char(v_paid_at, 'YY') || '-' || to_char(v_paid_at + interval '1 year', 'YY');
  end if;
  v_month_token := upper(trim(to_char(v_paid_at, 'MON')));

  insert into public.finance_document_sequences(
    school_id, fiscal_year, document_kind, current_value
  ) values (
    p_school_id, v_year_label, 'receipt', 1
  ) on conflict (school_id, fiscal_year, document_kind)
  do update set current_value = public.finance_document_sequences.current_value + 1
  returning current_value into v_sequence;

  v_paid := v_invoice.paid_amount + p_amount;
  v_balance := greatest(0, v_invoice.net_amount - v_paid);
  v_status := case when v_balance = 0 then 'paid' else 'partial' end;

  insert into public.payments(
    school_id, student_id, invoice_id, amount, payment_method,
    reference_number, paid_at, notes, status, created_by, idempotency_key
  ) values (
    p_school_id, p_student_id, p_invoice_id, p_amount,
    nullif(trim(p_payment_method), ''), nullif(trim(p_reference_number), ''),
    v_paid_at, nullif(p_notes, ''), 'completed',
    p_created_by, nullif(trim(p_idempotency_key), '')
  ) returning id into v_payment_id;

  v_receipt_number := v_receipt_prefix || '/' || v_year_label || '/' ||
    v_branch_token || '/' || v_month_token || '/' || lpad(v_sequence::text, 3, '0');
  insert into public.fee_receipts(
    school_id, invoice_id, payment_id, receipt_number, display_receipt_number,
    amount, payment_method, transaction_ref
  ) values (
    p_school_id, p_invoice_id, v_payment_id, v_receipt_number, v_receipt_number,
    p_amount, nullif(trim(p_payment_method), ''), nullif(trim(p_reference_number), '')
  ) returning id into v_receipt_id;

  select document_snapshot_id into v_snapshot_id
  from public.fee_receipts
  where id = v_receipt_id and school_id = p_school_id;
  if v_snapshot_id is null then
    raise exception 'Receipt snapshot was not generated';
  end if;

  update public.fee_invoices
  set paid_amount = v_paid,
      balance = v_balance,
      status = v_status,
      updated_at = now()
  where id = v_invoice.id;

  return query
  select v_payment_id, v_receipt_id, v_receipt_number, v_status, v_balance;
end;
$$;

revoke all on function public.record_fee_payment(
  uuid, uuid, uuid, numeric, text, text, timestamptz, text, uuid, uuid, text
) from public, anon, authenticated;
grant execute on function public.record_fee_payment(
  uuid, uuid, uuid, numeric, text, text, timestamptz, text, uuid, uuid, text
) to service_role;
