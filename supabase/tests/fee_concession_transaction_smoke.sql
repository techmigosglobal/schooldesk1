begin;

do $$
declare
  v_invoice record;
  v_before_discount numeric;
  v_before_balance numeric;
  v_after_discount numeric;
  v_after_balance numeric;
  v_concession_id uuid;
  v_approved_by uuid;
begin
  select id, school_id, student_id, fee_structure_id, discount_amount, balance
  into v_invoice
  from public.fee_invoices
  where fee_structure_id is not null
    and balance >= 1
  order by created_at desc
  limit 1
  for update;

  if not found then
    raise exception 'No eligible outstanding invoice for concession smoke';
  end if;

  select id
  into v_approved_by
  from public.users
  where school_id = v_invoice.school_id
    and role_name = 'principal'
    and is_active
  order by id
  limit 1;

  if v_approved_by is null then
    raise exception 'No active Principal is available for concession smoke';
  end if;

  v_before_discount := v_invoice.discount_amount;
  v_before_balance := v_invoice.balance;

  insert into public.fee_concessions (
    school_id,
    student_id,
    fee_structure_id,
    invoice_id,
    approved_by,
    amount,
    reason,
    status
  ) values (
    v_invoice.school_id,
    v_invoice.student_id,
    v_invoice.fee_structure_id,
    v_invoice.id,
    v_approved_by,
    1,
    'Transactional concession smoke',
    'approved'
  ) returning id into v_concession_id;

  select discount_amount, balance
  into v_after_discount, v_after_balance
  from public.fee_invoices
  where id = v_invoice.id;

  if v_after_discount <> v_before_discount + 1
    or v_after_balance <> v_before_balance - 1 then
    raise exception 'Concession did not reduce the invoice correctly';
  end if;

  delete from public.fee_concessions where id = v_concession_id;

  select discount_amount, balance
  into v_after_discount, v_after_balance
  from public.fee_invoices
  where id = v_invoice.id;

  if v_after_discount <> v_before_discount
    or v_after_balance <> v_before_balance then
    raise exception 'Removing concession did not restore the invoice';
  end if;
end;
$$;

rollback;

select 'fee concession trigger smoke passed' as result;
