-- Repair two pre-existing finance functions discovered by schema linting.
-- Payment history stays idempotent; the receipt lookup simply qualifies its
-- column. Reminder queueing writes only columns that notification_logs owns.

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
  v_student_identifier text;
  v_paid numeric;
  v_balance numeric;
  v_status text;
  v_fiscal_year text := to_char(coalesce(p_paid_at, now()), 'YY');
  v_sequence bigint;
begin
  if p_amount <= 0 then raise exception 'Payment amount must be greater than zero'; end if;

  if nullif(trim(coalesce(p_idempotency_key, '')), '') is not null then
    select * into v_existing_payment from public.payments
    where school_id = p_school_id and idempotency_key = p_idempotency_key;
    if found then
      select r.id, r.receipt_number into v_receipt_id, v_receipt_number
      from public.fee_receipts r
      where r.payment_id = v_existing_payment.id
      order by r.issued_at desc
      limit 1;
      return query select v_existing_payment.id, v_receipt_id, v_receipt_number,
        coalesce((select fi.status from public.fee_invoices fi where fi.id = v_existing_payment.invoice_id), 'partial'),
        coalesce((select fi.balance from public.fee_invoices fi where fi.id = v_existing_payment.invoice_id), 0);
      return;
    end if;
  end if;

  select * into v_invoice from public.fee_invoices
  where id = p_invoice_id and school_id = p_school_id and student_id = p_student_id
  for update;
  if not found then raise exception 'Invoice not found'; end if;
  if p_amount > v_invoice.balance then raise exception 'Payment amount exceeds the remaining balance'; end if;

  if p_request_id is not null then
    select * into v_request from public.parent_payment_requests
    where id = p_request_id and school_id = p_school_id for update;
    if not found then raise exception 'Payment request not found'; end if;
    if v_request.status not in ('pending_verification', 'resubmitted') then
      raise exception 'Payment request is not awaiting approval';
    end if;
    if v_request.payment_id is not null or v_request.amount <> p_amount then
      raise exception 'Payment request has changed';
    end if;
  end if;

  select coalesce(nullif(student_id_number, ''), nullif(admission_number, ''), right(p_student_id::text, 8))
  into v_student_identifier from public.students
  where id = p_student_id and school_id = p_school_id;
  v_student_identifier := upper(regexp_replace(coalesce(v_student_identifier, right(p_student_id::text, 8)), '[^A-Za-z0-9]+', '-', 'g'));

  insert into public.finance_document_sequences(school_id, fiscal_year, document_kind, current_value)
  values (p_school_id, v_fiscal_year, 'receipt', 1)
  on conflict (school_id, fiscal_year, document_kind)
  do update set current_value = public.finance_document_sequences.current_value + 1
  returning current_value into v_sequence;

  v_paid := v_invoice.paid_amount + p_amount;
  v_balance := greatest(0, v_invoice.net_amount - v_paid);
  v_status := case when v_balance = 0 then 'paid' else 'partial' end;

  insert into public.payments(
    school_id, student_id, invoice_id, amount, payment_method, reference_number,
    paid_at, notes, status, created_by, idempotency_key
  ) values (
    p_school_id, p_student_id, p_invoice_id, p_amount, nullif(trim(p_payment_method), ''),
    nullif(trim(p_reference_number), ''), coalesce(p_paid_at, now()), nullif(p_notes, ''),
    'completed', p_created_by, nullif(trim(p_idempotency_key), '')
  ) returning id into v_payment_id;

  v_receipt_number := 'RCP-' || v_student_identifier || '-' || v_fiscal_year || '-' || lpad(v_sequence::text, 6, '0');
  insert into public.fee_receipts(
    school_id, invoice_id, payment_id, receipt_number, amount, payment_method, transaction_ref
  ) values (
    p_school_id, p_invoice_id, v_payment_id, v_receipt_number, p_amount,
    nullif(trim(p_payment_method), ''), nullif(trim(p_reference_number), '')
  ) returning id into v_receipt_id;

  update public.fee_invoices
  set paid_amount = v_paid, balance = v_balance, status = v_status, updated_at = now()
  where id = v_invoice.id;

  return query select v_payment_id, v_receipt_id, v_receipt_number, v_status, v_balance;
end;
$$;

create or replace function public.queue_fee_reminders(
  p_run_date date default ((now() at time zone 'Asia/Kolkata')::date)
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_invoice record;
  v_parent record;
  v_stage text;
  v_event_id uuid;
  v_delivery_id uuid;
  v_queued integer := 0;
  v_message text;
begin
  for v_invoice in
    select fi.*, trim(concat_ws(' ', s.first_name, s.last_name)) as student_name
    from public.fee_invoices fi
    join public.students s on s.id = fi.student_id and s.school_id = fi.school_id
    where fi.balance > 0 and fi.status <> 'paid' and fi.due_date is not null
  loop
    v_stage := case
      when v_invoice.due_date = p_run_date + 7 then 'before_due_7'
      when v_invoice.due_date = p_run_date then 'due_date'
      when v_invoice.due_date = p_run_date - 7 then 'overdue_7'
      when v_invoice.due_date = p_run_date - 14 then 'overdue_14'
      else null
    end;
    if v_stage is null then continue; end if;
    for v_parent in
      select parent_user_id from public.parent_student_links
      where school_id = v_invoice.school_id and student_id = v_invoice.student_id
    loop
      v_delivery_id := null;
      insert into public.fee_reminder_deliveries (
        school_id, invoice_id, parent_user_id, stage, delivery_date
      ) values (
        v_invoice.school_id, v_invoice.id, v_parent.parent_user_id, v_stage, p_run_date
      ) on conflict do nothing returning id into v_delivery_id;
      if v_delivery_id is null then continue; end if;
      v_message := 'Fee reminder for ' || coalesce(nullif(v_invoice.student_name, ''), 'your child')
        || ': ₹' || trim(to_char(v_invoice.balance, 'FM999999990.00'))
        || ' is outstanding. Due date: ' || to_char(v_invoice.due_date, 'DD Mon YYYY') || '.';
      insert into public.notification_events (school_id, user_id, event_type, event_data, processed)
        values (v_invoice.school_id, v_parent.parent_user_id, 'fee_due', jsonb_build_object(
          'invoice_id', v_invoice.id, 'student_id', v_invoice.student_id,
          'reference_type', 'fee', 'reference_id', v_invoice.id,
          'route', '/parent-fees-screen', 'amount', v_invoice.balance,
          'due_date', v_invoice.due_date, 'message', v_message, 'stage', v_stage
        ), false) returning id into v_event_id;
      update public.fee_reminder_deliveries set notification_event_id = v_event_id where id = v_delivery_id;
      insert into public.notification_logs (
        school_id, user_id, title, body, type, entity_type, entity_id, is_read
      ) values (
        v_invoice.school_id, v_parent.parent_user_id, 'Fee payment reminder', v_message,
        'fee', 'fee_invoice', v_invoice.id::text, false
      );
      v_queued := v_queued + 1;
    end loop;
  end loop;
  return v_queued;
end;
$$;

revoke all on function public.record_fee_payment(
  uuid, uuid, uuid, numeric, text, text, timestamptz, text, uuid, uuid, text
) from public, anon, authenticated;
grant execute on function public.record_fee_payment(
  uuid, uuid, uuid, numeric, text, text, timestamptz, text, uuid, uuid, text
) to service_role;
revoke all on function public.queue_fee_reminders(date) from public, anon, authenticated;
grant execute on function public.queue_fee_reminders(date) to service_role;
