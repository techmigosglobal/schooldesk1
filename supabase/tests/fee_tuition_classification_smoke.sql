begin;

do $$
declare
  v_structure_id uuid;
begin
  select fs.id
  into v_structure_id
  from public.fee_structures fs
  join public.fee_categories fc
    on fc.id = coalesce(fs.fee_category_id, fs.category_id)
   and fc.school_id = fs.school_id
  where lower(fc.name) like '%tuition%'
  limit 1;

  if v_structure_id is null then
    raise exception 'No Tuition fee structure is available for the smoke test';
  end if;

  update public.fee_structures
  set fee_type = 'other', billing_mode = 'one_time'
  where id = v_structure_id;

  if exists (
    select 1
    from public.fee_structures
    where id = v_structure_id
      and (fee_type <> 'tuition' or billing_mode <> 'monthly')
  ) then
    raise exception 'Tuition structure normalization trigger did not run';
  end if;

  if exists (
    select 1
    from public.fee_invoices fi
    join public.fee_invoice_items fii on fii.invoice_id = fi.id
    where lower(fii.category_name) like '%tuition%'
      and (
        fi.fee_type <> 'tuition'
        or fi.billing_mode <> 'monthly'
        or cardinality(fi.allowed_month_names) <> 10
        or fi.monthly_amount <= 0
      )
  ) then
    raise exception 'One or more Tuition invoices still have one-time metadata';
  end if;
end;
$$;

rollback;
