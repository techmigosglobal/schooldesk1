-- Official fee receipts include a searchable student identifier and timestamp.
create or replace function public.record_fee_payment(
  p_school_id uuid, p_invoice_id uuid, p_student_id uuid, p_amount numeric,
  p_payment_method text, p_reference_number text, p_paid_at timestamptz,
  p_notes text, p_created_by uuid, p_selected_month_names text[] default '{}',
  p_selected_months int default 0, p_request_id uuid default null
)
returns table(payment_id uuid, receipt_id uuid, receipt_number text, invoice_status text, balance numeric, paid_month_names text[])
language plpgsql security definer set search_path = public as $$
declare
  v_invoice public.fee_invoices%rowtype; v_request public.parent_payment_requests%rowtype;
  v_payment_id uuid; v_receipt_id uuid; v_receipt_number text;
  v_student_identifier text; v_paid numeric; v_balance numeric; v_status text; v_months text[];
begin
  select * into v_invoice from public.fee_invoices where id = p_invoice_id and school_id = p_school_id and student_id = p_student_id for update;
  if not found then raise exception 'Invoice not found'; end if;
  select coalesce(nullif(student_id_number, ''), nullif(admission_number, ''), right(p_student_id::text, 8))
    into v_student_identifier from public.students where id = p_student_id and school_id = p_school_id;
  v_student_identifier := upper(regexp_replace(coalesce(v_student_identifier, right(p_student_id::text, 8)), '[^A-Za-z0-9]+', '-', 'g'));
  if p_request_id is not null then
    select * into v_request from public.parent_payment_requests where id = p_request_id and school_id = p_school_id for update;
    if not found then raise exception 'Payment request not found'; end if;
    if v_request.payment_id is not null or v_request.status in ('approved','completed','paid') then raise exception 'Payment request has already been approved'; end if;
  end if;
  if p_amount <= 0 or p_amount > v_invoice.balance then raise exception 'Invalid payment amount'; end if;
  v_months := case when lower(v_invoice.fee_type) = 'tuition' then array(select distinct unnest(coalesce(v_invoice.paid_month_names, '{}') || coalesce(p_selected_month_names, '{}'))) else coalesce(v_invoice.paid_month_names, '{}') end;
  v_paid := v_invoice.paid_amount + p_amount; v_balance := greatest(0, v_invoice.net_amount - v_paid);
  v_status := case when v_balance = 0 then 'paid' else 'partial' end;
  insert into public.payments (school_id, student_id, invoice_id, amount, payment_method, reference_number, paid_at, notes, status, created_by, selected_months, selected_month_names)
    values (p_school_id, p_student_id, p_invoice_id, p_amount, p_payment_method, nullif(p_reference_number, ''), coalesce(p_paid_at, now()), nullif(p_notes, ''), 'completed', p_created_by, p_selected_months, coalesce(p_selected_month_names, '{}')) returning id into v_payment_id;
  v_receipt_number := 'RCP-' || v_student_identifier || '-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS');
  insert into public.fee_receipts (school_id, invoice_id, payment_id, receipt_number, amount, payment_method, transaction_ref)
    values (p_school_id, v_invoice.id, v_payment_id, v_receipt_number, p_amount, p_payment_method, nullif(p_reference_number, '')) returning id into v_receipt_id;
  update public.fee_invoices set paid_amount = v_paid, balance = v_balance, status = v_status, paid_month_names = v_months, updated_at = now() where id = v_invoice.id;
  if p_request_id is not null then update public.parent_payment_requests set status = 'approved', payment_id = v_payment_id, receipt_id = v_receipt_id, reviewed_by = p_created_by, reviewed_at = now(), updated_at = now() where id = v_request.id; end if;
  return query select v_payment_id, v_receipt_id, v_receipt_number, v_status, v_balance, v_months;
end;
$$;
