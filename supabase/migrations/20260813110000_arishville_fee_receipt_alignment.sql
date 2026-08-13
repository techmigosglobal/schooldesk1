-- Arishville receipt identity and immutable presentation data.
-- Existing finalized receipt numbers remain untouched.

alter table public.school_finance_settings
  add column if not exists receipt_prefix text not null default 'RCP';

-- Configure Arishville without forcing the prefix onto other tenant schools.
insert into public.school_finance_settings (school_id, receipt_prefix)
select id, 'AV'
from public.schools
where lower(name) like '%arish%ville%'
on conflict (school_id) do update
set receipt_prefix = excluded.receipt_prefix,
    updated_at = now();

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
  v_paid numeric;
  v_balance numeric;
  v_status text;
  v_sequence bigint;
  v_receipt_prefix text;
  v_year_label text;
  v_year_start text;
  v_class_order integer;
  v_section_token text;
  v_student_identifier text;
  v_student_token text;
begin
  if p_amount <= 0 then
    raise exception 'Payment amount must be greater than zero';
  end if;

  if nullif(trim(coalesce(p_idempotency_key, '')), '') is not null then
    select * into v_existing_payment
    from public.payments
    where school_id = p_school_id
      and idempotency_key = p_idempotency_key;
    if found then
      select r.id, r.receipt_number
      into v_receipt_id, v_receipt_number
      from public.fee_receipts r
      where r.payment_id = v_existing_payment.id
      order by r.issued_at desc
      limit 1;
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
    if v_request.status not in ('pending_verification', 'resubmitted') then
      raise exception 'Payment request is not awaiting approval';
    end if;
    if v_request.payment_id is not null or v_request.amount <> p_amount then
      raise exception 'Payment request has changed';
    end if;
  end if;

  select
    coalesce(nullif(trim(fs.receipt_prefix), ''), 'RCP'),
    coalesce(nullif(trim(ay.year_label), ''), nullif(trim(ay.year), '')),
    coalesce(
      to_char(ay.start_date, 'YYYY'),
      substring(coalesce(ay.year_label, ay.year, '') from '([0-9]{4})'),
      to_char(coalesce(p_paid_at, now()), 'YYYY')
    ),
    greatest(1, coalesce(nullif(s.sort_order, 9999), g.grade_number, 1)),
    upper(regexp_replace(coalesce(s.section_name, 'A'), '[^A-Za-z0-9]+', '', 'g')),
    coalesce(nullif(trim(st.student_id_number), ''), nullif(trim(st.admission_number), ''), p_student_id::text)
  into
    v_receipt_prefix,
    v_year_label,
    v_year_start,
    v_class_order,
    v_section_token,
    v_student_identifier
  from public.students st
  join public.sections s
    on s.id = st.current_section_id and s.school_id = st.school_id
  join public.grades g
    on g.id = s.grade_id and g.school_id = s.school_id
  left join public.academic_years ay
    on ay.id = v_invoice.academic_year_id and ay.school_id = p_school_id
  left join public.school_finance_settings fs
    on fs.school_id = p_school_id
  where st.id = p_student_id and st.school_id = p_school_id;

  if v_year_start is null or v_year_start = '' then
    v_year_start := to_char(coalesce(p_paid_at, now()), 'YYYY');
  end if;
  if v_section_token is null or v_section_token = '' then
    v_section_token := 'A';
  end if;
  v_student_token := nullif(ltrim(regexp_replace(coalesce(v_student_identifier, ''), '[^0-9]+', '', 'g'), '0'), '');
  if v_student_token is null then
    v_student_token := '0';
  end if;

  insert into public.finance_document_sequences(
    school_id, fiscal_year, document_kind, current_value
  ) values (
    p_school_id, v_year_start, 'receipt', 1
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
    coalesce(p_paid_at, now()), nullif(p_notes, ''), 'completed',
    p_created_by, nullif(trim(p_idempotency_key), '')
  ) returning id into v_payment_id;

  v_receipt_number := upper(v_receipt_prefix) || '-' || v_year_start ||
    '-C' || lpad(v_class_order::text, 2, '0') || '-' || v_section_token ||
    '-' || v_student_token || '-' || lpad(v_sequence::text, 3, '0');
  insert into public.fee_receipts(
    school_id, invoice_id, payment_id, receipt_number, amount,
    payment_method, transaction_ref
  ) values (
    p_school_id, p_invoice_id, v_payment_id, v_receipt_number, p_amount,
    nullif(trim(p_payment_method), ''), nullif(trim(p_reference_number), '')
  ) returning id into v_receipt_id;

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
  v_section record;
  v_fee_items jsonb;
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
    new.receipt_number,
    jsonb_build_object(
      'total_amount', new.amount,
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
      'authorized_signatory_name', coalesce(v_school.principal_name, '')
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

-- Fill only missing presentation keys on historic snapshots. Financial values
-- and receipt numbers are deliberately not altered.
update public.finance_document_snapshots snapshot
set source_snapshot = snapshot.source_snapshot
  || case when snapshot.source_snapshot ? 'student_name' then '{}'::jsonb else jsonb_build_object('student_name', trim(concat_ws(' ', student.first_name, student.last_name))) end
  || case when snapshot.source_snapshot ? 'student_id_number' then '{}'::jsonb else jsonb_build_object('student_id_number', coalesce(student.student_id_number, student.admission_number, '')) end
  || case when snapshot.source_snapshot ? 'admission_number' then '{}'::jsonb else jsonb_build_object('admission_number', coalesce(student.admission_number, '')) end
  || case when snapshot.source_snapshot ? 'class_name' then '{}'::jsonb else jsonb_build_object('class_name', trim(concat_ws(' - ', grade.grade_name, section.section_name))) end
  || case when snapshot.source_snapshot ? 'section_name' then '{}'::jsonb else jsonb_build_object('section_name', coalesce(section.section_name, '')) end
  || case when snapshot.source_snapshot ? 'academic_year' then '{}'::jsonb else jsonb_build_object('academic_year', coalesce(year_row.year_label, year_row.year, '')) end
  || case when snapshot.source_snapshot ? 'school_name' then '{}'::jsonb else jsonb_build_object('school_name', coalesce(nullif(finance.legal_name, ''), school_row.name, '')) end
  || case when snapshot.source_snapshot ? 'school_address' then '{}'::jsonb else jsonb_build_object('school_address', coalesce(nullif(finance.address, ''), concat_ws(', ', school_row.address_line1, school_row.address_line2, school_row.city, school_row.state, school_row.postal_code))) end
  || case when snapshot.source_snapshot ? 'school_logo_url' then '{}'::jsonb else jsonb_build_object('school_logo_url', coalesce(school_row.logo_url, '')) end
  || case when snapshot.source_snapshot ? 'signature_path' then '{}'::jsonb else jsonb_build_object('signature_path', coalesce(finance.signature_path, school_row.authorized_signature_path, '')) end
  || case when snapshot.source_snapshot ? 'authorized_signatory_name' then '{}'::jsonb else jsonb_build_object('authorized_signatory_name', coalesce(school_row.principal_name, '')) end
from public.payments payment
join public.students student on student.id = payment.student_id
left join public.sections section on section.id = student.current_section_id
left join public.grades grade on grade.id = section.grade_id
left join public.fee_invoices invoice on invoice.id = payment.invoice_id
left join public.academic_years year_row on year_row.id = invoice.academic_year_id
join public.schools school_row on school_row.id = payment.school_id
left join public.school_finance_settings finance on finance.school_id = payment.school_id
where snapshot.document_kind = 'payment_receipt'
  and payment.id = snapshot.payment_id
  and payment.school_id = snapshot.school_id
  and student.school_id = snapshot.school_id
  and (section.school_id is null or section.school_id = snapshot.school_id)
  and (grade.school_id is null or grade.school_id = snapshot.school_id)
  and (invoice.school_id is null or invoice.school_id = snapshot.school_id)
  and (year_row.school_id is null or year_row.school_id = snapshot.school_id)
  and (
    not (snapshot.source_snapshot ? 'student_name')
    or not (snapshot.source_snapshot ? 'class_name')
    or not (snapshot.source_snapshot ? 'academic_year')
    or not (snapshot.source_snapshot ? 'school_name')
  );

revoke all on function public.record_fee_payment(
  uuid, uuid, uuid, numeric, text, text, timestamptz, text, uuid, uuid, text
) from public, anon, authenticated;
grant execute on function public.record_fee_payment(
  uuid, uuid, uuid, numeric, text, text, timestamptz, text, uuid, uuid, text
) to service_role;
