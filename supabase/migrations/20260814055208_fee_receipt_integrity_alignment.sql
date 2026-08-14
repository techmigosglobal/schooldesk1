-- Fee receipt integrity alignment:
-- - New receipts use PREFIX/FY/BRANCH/MON/NNN (e.g. AVP/26-27/MIY/AUG/001).
-- - Historic receipt_number values stay immutable; display_receipt_number is
--   the public alias used by receipt views and PDFs.
-- - Receipt settlement fails if the immutable snapshot cannot be created.

alter table public.fee_receipts
  add column if not exists display_receipt_number text;

create unique index if not exists fee_receipts_school_display_receipt_number_key
  on public.fee_receipts(school_id, display_receipt_number)
  where display_receipt_number is not null and display_receipt_number <> '';

drop index if exists public.parent_payment_requests_active_invoice_parent_key;
create unique index parent_payment_requests_active_invoice_parent_key
  on public.parent_payment_requests(school_id, invoice_id, parent_user_id)
  where parent_user_id is not null
    and status in (
      'initiated', 'pending', 'pending_verification',
      'submitted', 'clarification_required', 'resubmitted'
    );

alter table public.parent_payment_requests
  drop constraint if exists parent_payment_requests_status_check;
alter table public.parent_payment_requests
  add constraint parent_payment_requests_status_check check (
    status in (
      'initiated', 'pending', 'pending_verification',
      'submitted', 'clarification_required',
      'resubmitted', 'approved', 'rejected', 'reversed'
    )
  );

insert into public.school_finance_settings (school_id, receipt_prefix)
select id, 'AVP'
from public.schools
where lower(name) like '%arish%ville%'
on conflict (school_id) do update
set receipt_prefix = excluded.receipt_prefix,
    updated_at = now();

do $$
declare
  receipt_row record;
  v_prefix text;
  v_year_label text;
  v_branch text;
  v_month text;
  v_display_number text;
  v_sequence bigint;
begin
  for receipt_row in
    select
      r.id,
      r.school_id,
      r.receipt_number,
      r.issued_at,
      coalesce(p.paid_at, r.issued_at) as paid_at,
      coalesce(nullif(trim(fs.receipt_prefix), ''), 'RCP') as receipt_prefix,
      coalesce(nullif(trim(s.branch_code), ''), 'MAIN') as branch_code,
      ay.start_date as year_start,
      ay.end_date as year_end,
      ay.year_label,
      ay.year,
      row_number() over (
        partition by r.school_id,
          coalesce(
            case
              when ay.start_date is not null and ay.end_date is not null
                then to_char(ay.start_date, 'YY') || '-' || to_char(ay.end_date, 'YY')
            end,
            to_char(coalesce(p.paid_at, r.issued_at, now()), 'YY') || '-' ||
              to_char(coalesce(p.paid_at, r.issued_at, now()) + interval '1 year', 'YY')
          )
        order by r.issued_at, r.id
      ) as receipt_sequence
    from public.fee_receipts r
    join public.schools s on s.id = r.school_id
    left join public.school_finance_settings fs on fs.school_id = r.school_id
    left join public.payments p on p.id = r.payment_id and p.school_id = r.school_id
    left join public.fee_invoices fi on fi.id = r.invoice_id and fi.school_id = r.school_id
    left join public.academic_years ay on ay.id = fi.academic_year_id and ay.school_id = r.school_id
    where coalesce(nullif(trim(r.display_receipt_number), ''), '') = ''
    order by r.school_id, r.issued_at, r.id
  loop
    v_prefix := upper(regexp_replace(receipt_row.receipt_prefix, '[^A-Za-z0-9]+', '', 'g'));
    if v_prefix = '' then v_prefix := 'RCP'; end if;

    v_branch := upper(regexp_replace(receipt_row.branch_code, '[^A-Za-z0-9]+', '', 'g'));
    if v_branch = '' then v_branch := 'MAIN'; end if;

    v_month := upper(trim(to_char(coalesce(receipt_row.paid_at, receipt_row.issued_at, now()), 'MON')));

    if receipt_row.year_start is not null and receipt_row.year_end is not null then
      v_year_label := to_char(receipt_row.year_start, 'YY') || '-' || to_char(receipt_row.year_end, 'YY');
    else
      v_year_label := to_char(coalesce(receipt_row.paid_at, receipt_row.issued_at, now()), 'YY') || '-' ||
        to_char(coalesce(receipt_row.paid_at, receipt_row.issued_at, now()) + interval '1 year', 'YY');
    end if;

    v_display_number := v_prefix || '/' || v_year_label || '/' || v_branch || '/' ||
      v_month || '/' || lpad(receipt_row.receipt_sequence::text, 3, '0');

    update public.fee_receipts
    set display_receipt_number = v_display_number
    where id = receipt_row.id
      and coalesce(nullif(trim(display_receipt_number), ''), '') = '';

    insert into public.audit_logs (
      school_id, action, entity_type, entity_id, details
    ) values (
      receipt_row.school_id,
      'fee_receipt_display_number_backfilled',
      'fee_receipts',
      receipt_row.id::text,
      jsonb_build_object(
        'legacy_receipt_number', receipt_row.receipt_number,
        'display_receipt_number', v_display_number
      )
    );
  end loop;

  for receipt_row in
    select
      r.school_id,
      coalesce(
        case
          when ay.start_date is not null and ay.end_date is not null
            then to_char(ay.start_date, 'YY') || '-' || to_char(ay.end_date, 'YY')
        end,
        to_char(coalesce(p.paid_at, r.issued_at, now()), 'YY') || '-' ||
          to_char(coalesce(p.paid_at, r.issued_at, now()) + interval '1 year', 'YY')
      ) as fiscal_year,
      count(*)::bigint as current_value
    from public.fee_receipts r
    left join public.payments p on p.id = r.payment_id and p.school_id = r.school_id
    left join public.fee_invoices fi on fi.id = r.invoice_id and fi.school_id = r.school_id
    left join public.academic_years ay on ay.id = fi.academic_year_id and ay.school_id = r.school_id
    group by r.school_id, fiscal_year
  loop
    insert into public.finance_document_sequences(
      school_id, fiscal_year, document_kind, current_value
    ) values (
      receipt_row.school_id, receipt_row.fiscal_year, 'receipt', receipt_row.current_value
    ) on conflict (school_id, fiscal_year, document_kind)
    do update set current_value = greatest(
      public.finance_document_sequences.current_value,
      excluded.current_value
    );
  end loop;
end $$;

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
    if v_request.status not in ('pending_verification', 'resubmitted', 'submitted') then
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
  v_student record;
  v_school record;
  v_year record;
  v_fee_items jsonb;
  v_document_number text;
begin
  v_document_number := coalesce(nullif(trim(new.display_receipt_number), ''), new.receipt_number);

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

  select st.*, s.section_name, g.grade_name
  into v_student
  from public.students st
  left join public.sections s
    on s.id = st.current_section_id and s.school_id = st.school_id
  left join public.grades g
    on g.id = s.grade_id and g.school_id = s.school_id
  where st.id = v_payment.student_id and st.school_id = new.school_id;
  select
    sc.*, fs.legal_name, fs.address,
    coalesce(fs.signature_path, sc.authorized_signature_path) as signature_path
  into v_school
  from public.schools sc
  left join public.school_finance_settings fs on fs.school_id = sc.id
  where sc.id = new.school_id;
  select * into v_year
  from public.academic_years
  where id = v_invoice.academic_year_id and school_id = new.school_id;

  v_paid_amount := coalesce(v_invoice.paid_amount, 0) + coalesce(new.amount, 0);
  v_balance := greatest(
    0,
    coalesce(v_invoice.net_amount, v_invoice.total_amount, 0) - v_paid_amount
  );
  select coalesce(jsonb_agg(jsonb_build_object(
    'description', coalesce(item.category_name, v_invoice.fee_type, 'Fee payment'),
    'amount', item.amount
  ) order by item.created_at nulls last, item.id), '[]'::jsonb)
  into v_fee_items
  from public.fee_invoice_items item
  where item.invoice_id = new.invoice_id;
  if jsonb_array_length(v_fee_items) <> 1
     or coalesce((v_fee_items->0->>'amount')::numeric, 0) <> new.amount then
    v_fee_items := jsonb_build_array(jsonb_build_object(
      'description', coalesce(v_invoice.fee_type, 'Fee payment'),
      'amount', new.amount
    ));
  end if;

  insert into public.finance_document_snapshots (
    school_id, invoice_id, payment_id, receipt_id, document_kind,
    document_number, source_totals, source_snapshot, generated_by
  ) values (
    new.school_id, new.invoice_id, new.payment_id, new.id, 'payment_receipt',
    v_document_number,
    jsonb_build_object(
      'total_amount', new.amount,
      'paid_amount', v_paid_amount,
      'balance', v_balance,
      'this_payment_amount', new.amount
    ),
    jsonb_build_object(
      'receipt_number', v_document_number,
      'legacy_receipt_number', case when v_document_number <> new.receipt_number then new.receipt_number else null end,
      'payment_date', v_payment.paid_at,
      'issued_at', new.issued_at,
      'payment_method', coalesce(new.payment_method, v_payment.payment_method, ''),
      'reference_number', coalesce(new.transaction_ref, v_payment.reference_number, ''),
      'invoice_number', v_invoice.invoice_number,
      'student_id', v_payment.student_id,
      'student_name', trim(concat_ws(' ', v_student.first_name, v_student.last_name)),
      'student_id_number', coalesce(v_student.student_id_number, v_student.admission_number, ''),
      'admission_number', coalesce(v_student.admission_number, ''),
      'class_name', trim(concat_ws(' - ', v_student.grade_name, v_student.section_name)),
      'section_name', coalesce(v_student.section_name, ''),
      'academic_year', coalesce(v_year.year_label, v_year.year, ''),
      'fee_period', coalesce(to_char(v_invoice.billing_period, 'FMMonth YYYY'), ''),
      'fee_items', v_fee_items,
      'school_name', coalesce(nullif(v_school.legal_name, ''), v_school.name, ''),
      'school_address', coalesce(nullif(v_school.address, ''), concat_ws(', ', v_school.address_line1, v_school.address_line2, v_school.city, v_school.state, v_school.postal_code)),
      'school_logo_url', coalesce(v_school.logo_url, ''),
      'signature_path', coalesce(v_school.signature_path, ''),
      'authorized_signatory_name', coalesce(v_school.principal_name, ''),
      'branch_code', coalesce(v_school.branch_code, 'MAIN'),
      'receipt_month', upper(trim(to_char(coalesce(v_payment.paid_at, new.issued_at), 'MON')))
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
      and document_number = v_document_number
      and version = 1;
  end if;
  if v_snapshot_id is null then
    raise exception 'Receipt snapshot was not generated for %', new.id;
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

revoke all on function public.record_fee_payment(
  uuid, uuid, uuid, numeric, text, text, timestamptz, text, uuid, uuid, text
) from public, anon, authenticated;
grant execute on function public.record_fee_payment(
  uuid, uuid, uuid, numeric, text, text, timestamptz, text, uuid, uuid, text
) to service_role;

revoke all on function public.capture_payment_receipt_snapshot()
  from public, anon, authenticated;
grant execute on function public.capture_payment_receipt_snapshot()
  to service_role;
