-- Serialize proof decisions with ledger writes and keep the existing receipt
-- generation inside the same transaction as the request transition.
create function public.decide_parent_payment_request(
  p_school_id uuid,
  p_request_id uuid,
  p_status text,
  p_admin_remarks text,
  p_reviewed_by uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_initial public.parent_payment_requests%rowtype;
  v_request public.parent_payment_requests%rowtype;
  v_invoice_id uuid;
  v_payment_id uuid;
  v_receipt_id uuid;
  v_reviewed_at timestamptz;
begin
  if p_status is null or p_status not in ('approved', 'rejected', 'clarification_required') then
    raise sqlstate 'PT400' using message = 'Invalid payment request decision';
  end if;

  select * into v_initial
  from public.parent_payment_requests
  where id = p_request_id and school_id = p_school_id;
  if not found then
    raise sqlstate 'PT404' using message = 'Payment request not found';
  end if;

  -- Match record_fee_payment's invoice-before-request lock order. Legacy
  -- requests without an invoice may still be rejected or clarified.
  select id into v_invoice_id from public.fee_invoices
  where id = v_initial.invoice_id and school_id = p_school_id
    and student_id = v_initial.student_id
  for update;

  select * into v_request
  from public.parent_payment_requests
  where id = p_request_id and school_id = p_school_id
  for update;
  if not found then
    raise sqlstate 'PT404' using message = 'Payment request not found';
  end if;

  if v_request.status = p_status
    and nullif(btrim(v_request.admin_remarks), '') is not distinct from nullif(btrim(p_admin_remarks), '')
    and (p_status <> 'approved' or (v_request.payment_id is not null and v_request.receipt_id is not null))
  then
    return jsonb_build_object('request', to_jsonb(v_request), 'replayed', true);
  end if;

  if v_request.status not in ('pending', 'submitted', 'pending_verification', 'resubmitted')
    or v_request.payment_id is not null or v_request.receipt_id is not null
    or v_request.invoice_id is distinct from v_initial.invoice_id
    or v_request.student_id is distinct from v_initial.student_id
    or v_request.updated_at is distinct from v_initial.updated_at
  then
    raise sqlstate 'PT409' using message = 'Payment request changed or was already decided. Refresh before reviewing.';
  end if;

  if p_status = 'approved' then
    if v_invoice_id is null then
      raise sqlstate 'PT404' using message = 'Invoice not found';
    end if;

    select payment.payment_id, payment.receipt_id into strict v_payment_id, v_receipt_id
    from public.record_fee_payment(
      p_school_id, v_invoice_id, v_request.student_id, v_request.amount,
      coalesce(v_request.payment_method, 'upi'),
      coalesce(v_request.transaction_ref, v_request.transaction_id, v_request.request_reference),
      coalesce(v_request.payment_date::timestamptz, now()),
      coalesce(v_request.remarks, ''), p_reviewed_by, p_request_id,
      'request:' || p_request_id
    ) as payment;

    -- Older deployments could commit a payment before updating the request.
    -- Only reuse that ledger entry if it still matches this exact proof.
    if not exists (
      select 1 from public.payments p
      join public.fee_receipts r on r.payment_id = p.id and r.school_id = p.school_id
      where p.id = v_payment_id and r.id = v_receipt_id
        and p.school_id = p_school_id and p.student_id = v_request.student_id
        and p.invoice_id = v_invoice_id and p.amount = v_request.amount
        and p.status = 'completed' and r.voided_at is null and r.document_snapshot_id is not null
    ) then
      raise sqlstate 'PT409' using message = 'Existing payment or receipt does not match this proof';
    end if;
  end if;

  v_reviewed_at := clock_timestamp();
  update public.parent_payment_requests
  set status = p_status,
      admin_remarks = p_admin_remarks,
      reviewed_by = p_reviewed_by,
      reviewed_at = v_reviewed_at,
      updated_at = v_reviewed_at,
      payment_id = v_payment_id,
      receipt_id = v_receipt_id
  where id = p_request_id and school_id = p_school_id
  returning * into strict v_request;

  return jsonb_build_object('request', to_jsonb(v_request), 'replayed', false);
end;
$$;

revoke all on function public.decide_parent_payment_request(uuid, uuid, text, text, uuid)
  from public, anon, authenticated;
grant execute on function public.decide_parent_payment_request(uuid, uuid, text, text, uuid)
  to service_role;
notify pgrst, 'reload schema';
