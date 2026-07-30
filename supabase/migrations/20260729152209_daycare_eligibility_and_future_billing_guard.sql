-- Day Care plans belong only to students currently enrolled in a Day Care
-- section. Historical plans, invoices, and payments stay immutable; this guard
-- only prevents a plan for a moved or incorrectly enrolled child from creating
-- another monthly invoice.
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

  -- Accept Daycare, Day Care, and Day-Care, but never a merely similar label.
  if not exists (
    select 1
    from public.students student
    join public.sections section on section.id = student.current_section_id
    join public.grades grade on grade.id = section.grade_id
    where student.id = v_plan.student_id
      and student.school_id = v_plan.school_id
      and student.status = 'active'
      and regexp_replace(lower(coalesce(grade.grade_name, '')), '[^a-z0-9]+', '', 'g') = 'daycare'
  ) then
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

revoke all on function public.ensure_daycare_invoice_for_plan(uuid, date)
  from public, anon, authenticated;
grant execute on function public.ensure_daycare_invoice_for_plan(uuid, date)
  to service_role;
