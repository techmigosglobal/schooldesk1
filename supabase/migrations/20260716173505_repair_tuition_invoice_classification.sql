-- Keep fee structures and their generated invoices aligned with the concrete
-- fee-category label. Older clients could submit fee_type=other even when the
-- selected category was Tuition, which removed the June-March month workflow.

create or replace function public.normalize_fee_structure_classification()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_category_name text;
begin
  select fc.name
  into v_category_name
  from public.fee_categories fc
  where fc.id = coalesce(new.fee_category_id, new.category_id)
    and fc.school_id = new.school_id;

  if lower(coalesce(v_category_name, new.fee_type, '')) like '%tuition%'
     or lower(coalesce(new.fee_type, '')) like '%tuition%' then
    new.fee_type := 'tuition';
    new.billing_mode := 'monthly';
    new.priority := 2;
  else
    new.fee_type := 'other';
    new.billing_mode := 'one_time';
    new.priority := 1;
  end if;

  return new;
end;
$$;

revoke all on function public.normalize_fee_structure_classification()
from public, anon, authenticated;
grant execute on function public.normalize_fee_structure_classification()
to service_role;

drop trigger if exists structures_normalize_fee_classification
on public.fee_structures;
create trigger structures_normalize_fee_classification
before insert or update of
  fee_category_id,
  category_id,
  fee_type,
  billing_mode
on public.fee_structures
for each row
execute function public.normalize_fee_structure_classification();

update public.fee_structures fs
set
  fee_type = case
    when lower(coalesce(fc.name, fs.fee_type, '')) like '%tuition%'
      then 'tuition'
    else 'other'
  end,
  billing_mode = case
    when lower(coalesce(fc.name, fs.fee_type, '')) like '%tuition%'
      then 'monthly'
    else 'one_time'
  end,
  priority = case
    when lower(coalesce(fc.name, fs.fee_type, '')) like '%tuition%'
      then 2
    else 1
  end,
  updated_at = now()
from public.fee_categories fc
where fc.id = coalesce(fs.fee_category_id, fs.category_id)
  and fc.school_id = fs.school_id;

with classified_invoices as (
  select
    fi.id,
    bool_or(
      lower(coalesce(fii.category_name, fc.name, fi.fee_type, ''))
      like '%tuition%'
    ) as is_tuition
  from public.fee_invoices fi
  left join public.fee_invoice_items fii
    on fii.invoice_id = fi.id
  left join public.fee_structures fs
    on fs.id = fi.fee_structure_id
   and fs.school_id = fi.school_id
  left join public.fee_categories fc
    on fc.id = coalesce(fs.fee_category_id, fs.category_id)
   and fc.school_id = fi.school_id
  where fi.fee_structure_id is not null
  group by fi.id
)
update public.fee_invoices fi
set
  fee_type = case when ci.is_tuition then 'tuition' else 'other' end,
  billing_mode = case when ci.is_tuition then 'monthly' else 'one_time' end,
  priority = case when ci.is_tuition then 2 else 1 end,
  monthly_amount = case
    when ci.is_tuition
      then round(coalesce(fi.net_amount, fi.total_amount, 0) / 10.0, 2)
    else 0
  end,
  allowed_month_names = case
    when ci.is_tuition then array[
      'June', 'July', 'August', 'September', 'October',
      'November', 'December', 'January', 'February', 'March'
    ]::text[]
    else '{}'::text[]
  end,
  updated_at = now()
from classified_invoices ci
where ci.id = fi.id;
