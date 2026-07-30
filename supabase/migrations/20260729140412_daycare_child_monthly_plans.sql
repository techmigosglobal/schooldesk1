-- Day Care is priced for each child, not for an academic class or section.
-- Keep the former structure reference only for historical plans/invoices.
alter table public.daycare_fee_plans
  alter column fee_structure_id drop not null,
  alter column hourly_rate drop not null,
  alter column contracted_hours_per_month drop not null,
  add column if not exists monthly_amount numeric(12,2),
  add column if not exists due_day integer,
  add column if not exists fee_label text;

update public.daycare_fee_plans p
set
  monthly_amount = coalesce(
    p.monthly_amount,
    round(coalesce(p.hourly_rate, 0) * coalesce(p.contracted_hours_per_month, 0), 2)
  ),
  due_day = coalesce(p.due_day, fs.due_day, 10),
  fee_label = coalesce(nullif(p.fee_label, ''), 'Day Care')
from public.fee_structures fs
where fs.id = p.fee_structure_id;

update public.daycare_fee_plans
set
  monthly_amount = coalesce(monthly_amount, 0),
  due_day = least(greatest(coalesce(due_day, 10), 1), 28),
  fee_label = coalesce(nullif(fee_label, ''), 'Day Care');

alter table public.daycare_fee_plans
  alter column monthly_amount set not null,
  alter column due_day set not null,
  alter column fee_label set not null,
  add constraint daycare_fee_plans_monthly_amount_positive
    check (monthly_amount > 0),
  add constraint daycare_fee_plans_due_day_range
    check (due_day between 1 and 28);

alter table public.fee_invoices
  add column if not exists daycare_plan_id uuid
    references public.daycare_fee_plans(id) on delete set null;

-- Backfill only the immutable historical snapshots that can be matched safely.
update public.fee_invoices invoice
set daycare_plan_id = plan.id
from public.daycare_fee_plans plan
where invoice.daycare_plan_id is null
  and invoice.student_id = plan.student_id
  and invoice.fee_structure_id = plan.fee_structure_id
  and invoice.billing_period is not null
  and date_trunc('month', invoice.billing_period) >= date_trunc('month', plan.effective_from)
  and (plan.effective_to is null or date_trunc('month', invoice.billing_period) <= date_trunc('month', plan.effective_to));

create unique index if not exists fee_invoices_daycare_plan_period_unique
  on public.fee_invoices(school_id, daycare_plan_id, billing_period)
  where daycare_plan_id is not null and billing_period is not null;

create or replace function public.ensure_daycare_invoice_for_plan(
  p_plan_id uuid,
  p_period date default ((now() at time zone 'Asia/Kolkata')::date)
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_plan public.daycare_fee_plans%rowtype;
  v_period date := date_trunc('month', p_period)::date;
  v_due_date date;
  v_invoice_id uuid;
  v_invoice_number text;
begin
  select * into v_plan
  from public.daycare_fee_plans
  where id = p_plan_id and is_active = true;
  if not found then return null; end if;
  if date_trunc('month', v_plan.effective_from)::date > v_period
     or (v_plan.effective_to is not null and date_trunc('month', v_plan.effective_to)::date < v_period) then
    return null;
  end if;

  v_due_date := make_date(
    extract(year from v_period)::integer,
    extract(month from v_period)::integer,
    least(v_plan.due_day, extract(day from (v_period + interval '1 month - 1 day'))::integer)
  );
  v_invoice_number := 'DAY-' || to_char(v_period, 'YYYYMM') || '-'
    || upper(substr(replace(v_plan.student_id::text, '-', ''), 1, 8)) || '-'
    || upper(substr(replace(v_plan.id::text, '-', ''), 1, 8));

  insert into public.fee_invoices (
    school_id, student_id, academic_year_id, fee_structure_id, daycare_plan_id,
    invoice_number, invoice_date, due_date, total_amount, net_amount, balance,
    status, fee_type, billing_mode, priority, billing_period, billing_details,
    monthly_amount, allowed_month_names, paid_month_names
  ) values (
    v_plan.school_id, v_plan.student_id, v_plan.academic_year_id, null, v_plan.id,
    v_invoice_number, v_period, v_due_date, v_plan.monthly_amount,
    v_plan.monthly_amount, v_plan.monthly_amount, 'pending', 'daycare', 'monthly',
    3, v_period,
    jsonb_build_object('daycare_plan_id', v_plan.id, 'monthly_amount', v_plan.monthly_amount,
      'fee_label', v_plan.fee_label, 'billing_period', v_period),
    v_plan.monthly_amount, '{}'::text[], '{}'::text[]
  ) on conflict do nothing returning id into v_invoice_id;

  if v_invoice_id is null then
    select id into v_invoice_id from public.fee_invoices
    where school_id = v_plan.school_id and daycare_plan_id = v_plan.id
      and billing_period = v_period;
    return v_invoice_id;
  end if;

  insert into public.fee_invoice_items (invoice_id, fee_structure_id, category_name, amount)
  values (
    v_invoice_id,
    null,
    v_plan.fee_label || ' - ' || to_char(v_period, 'Mon YYYY'),
    v_plan.monthly_amount
  );
  return v_invoice_id;
end;
$$;

-- These privileged helpers are Edge-API-only; never expose them to browser roles.
revoke all on function public.ensure_daycare_invoice_for_plan(uuid, date)
  from public, anon, authenticated;
grant execute on function public.ensure_daycare_invoice_for_plan(uuid, date)
  to service_role;
