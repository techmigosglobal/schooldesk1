-- Balance-first fee payments, per-child daycare plans, and reliable reminders.
-- New operational tables are private to the API/service role; RLS remains
-- enabled as defense in depth even when the Data API is configured to expose
-- the public schema.

alter table public.fee_invoices
  add column if not exists billing_period date,
  add column if not exists billing_details jsonb not null default '{}'::jsonb;

-- One annual/general invoice remains unique per structure. Daycare needs a
-- separate, immutable invoice snapshot for each billed month.
drop index if exists public.fee_invoices_student_structure_key;
create unique index if not exists fee_invoices_student_structure_general_key
  on public.fee_invoices(school_id, student_id, fee_structure_id)
  where fee_structure_id is not null and billing_period is null;
create unique index if not exists fee_invoices_student_structure_period_key
  on public.fee_invoices(
    school_id,
    student_id,
    fee_structure_id,
    billing_period
  )
  where fee_structure_id is not null and billing_period is not null;

create table if not exists public.daycare_fee_plans (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  academic_year_id uuid not null references public.academic_years(id) on delete cascade,
  fee_structure_id uuid not null references public.fee_structures(id) on delete restrict,
  hourly_rate numeric(12,2) not null check (hourly_rate > 0),
  contracted_hours_per_month numeric(10,2) not null check (contracted_hours_per_month > 0),
  effective_from date not null,
  effective_to date,
  is_active boolean not null default true,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);
create index if not exists daycare_fee_plans_school_student_idx
  on public.daycare_fee_plans(school_id, student_id, is_active, effective_from desc);
create index if not exists daycare_fee_plans_structure_idx
  on public.daycare_fee_plans(school_id, fee_structure_id, is_active);
alter table public.daycare_fee_plans enable row level security;
revoke all on table public.daycare_fee_plans from anon, authenticated;
grant all on table public.daycare_fee_plans to service_role;

create table if not exists public.fee_reminder_deliveries (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  invoice_id uuid not null references public.fee_invoices(id) on delete cascade,
  parent_user_id uuid not null references public.users(id) on delete cascade,
  stage text not null check (stage in ('before_due_7', 'due_date', 'overdue_7', 'overdue_14', 'manual')),
  delivery_date date not null,
  notification_event_id uuid references public.notification_events(id) on delete set null,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(invoice_id, parent_user_id, stage, delivery_date)
);
create index if not exists fee_reminder_deliveries_school_invoice_idx
  on public.fee_reminder_deliveries(school_id, invoice_id, created_at desc);
alter table public.fee_reminder_deliveries enable row level security;
revoke all on table public.fee_reminder_deliveries from anon, authenticated;
grant all on table public.fee_reminder_deliveries to service_role;

-- Daycare is a monthly service, but unlike tuition it must never create the
-- June-March selection ledger. A per-child plan creates monthly snapshots.
create or replace function public.normalize_fee_structure_classification()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_category_name text := '';
  v_hint text := lower(coalesce(new.fee_type, ''));
begin
  select lower(coalesce(name, ''))
    into v_category_name
  from public.fee_categories
  where id = coalesce(new.fee_category_id, new.category_id);

  if v_category_name like '%daycare%'
     or v_category_name like '%day care%'
     or v_hint in ('daycare_hourly', 'daycare') then
    new.fee_type := 'daycare_hourly';
    new.billing_mode := 'monthly';
    new.frequency := 'monthly';
    new.priority := 3;
  elsif v_category_name like '%tuition%' or v_hint like '%tuition%' then
    new.fee_type := 'tuition';
    new.billing_mode := 'monthly';
    new.frequency := 'monthly';
    new.priority := 2;
  else
    new.fee_type := 'other';
    new.billing_mode := 'one_time';
    new.priority := 1;
  end if;
  return new;
end;
$$;

-- Daycare structures act as a plan template. Do not auto-create an annual
-- generic invoice when a daycare structure or student is saved.
create or replace function public.ensure_fee_invoice_for_student_structure(
  p_student_id uuid,
  p_fee_structure_id uuid
)
returns boolean
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_assignment record;
  v_invoice_id uuid;
  v_fee_type text;
  v_billing_mode text;
  v_priority integer;
  v_due_date date;
  v_invoice_number text;
begin
  select
    s.id as student_id,
    s.school_id,
    s.admission_number,
    s.student_id_number,
    fs.id as fee_structure_id,
    fs.academic_year_id,
    fs.amount,
    fs.due_date,
    fs.due_day,
    fs.frequency,
    fs.fee_type,
    fs.billing_mode,
    fs.priority,
    coalesce(fc.name, 'Fee') as category_name
  into v_assignment
  from public.students s
  join public.sections sec
    on sec.id = s.current_section_id
   and sec.school_id = s.school_id
  join public.fee_structures fs
    on fs.id = p_fee_structure_id
   and fs.school_id = s.school_id
   and fs.academic_year_id = sec.academic_year_id
   and fs.grade_id = sec.grade_id
   and (fs.section_id is null or fs.section_id = sec.id)
  left join public.fee_categories fc
    on fc.id = coalesce(fs.fee_category_id, fs.category_id)
   and fc.school_id = fs.school_id
  where s.id = p_student_id
    and s.status = 'active';

  if not found then
    return false;
  end if;

  v_fee_type := case
    when lower(coalesce(v_assignment.fee_type, '')) in ('daycare_hourly', 'daycare')
      or lower(coalesce(v_assignment.category_name, '')) like '%daycare%'
      or lower(coalesce(v_assignment.category_name, '')) like '%day care%'
      then 'daycare_hourly'
    when lower(coalesce(nullif(v_assignment.fee_type, ''), v_assignment.category_name, '')) like '%tuition%'
      then 'tuition'
    else 'other'
  end;
  if v_fee_type = 'daycare_hourly' then
    return false;
  end if;

  if exists (
    select 1 from public.fee_invoices fi
    where fi.student_id = p_student_id
      and fi.fee_structure_id = p_fee_structure_id
      and fi.billing_period is null
  ) then
    return false;
  end if;

  v_billing_mode := coalesce(
    nullif(v_assignment.billing_mode, ''),
    case
      when v_fee_type = 'tuition' then 'monthly'
      when lower(coalesce(v_assignment.frequency, '')) like '%month%' then 'monthly'
      else 'one_time'
    end
  );
  v_priority := case
    when coalesce(v_assignment.priority, 99) <> 99 then v_assignment.priority
    when v_fee_type = 'tuition' then 2
    else 1
  end;
  v_due_date := coalesce(
    v_assignment.due_date,
    make_date(
      extract(year from current_date)::integer,
      extract(month from current_date)::integer,
      least(greatest(coalesce(v_assignment.due_day, 10), 1), 28)
    )
  );
  v_invoice_number := 'FEE-AUTO-'
    || upper(substr(replace(v_assignment.school_id::text, '-', ''), 1, 6))
    || '-'
    || upper(substr(replace(v_assignment.student_id::text, '-', ''), 1, 8))
    || '-'
    || upper(substr(replace(v_assignment.fee_structure_id::text, '-', ''), 1, 8));

  insert into public.fee_invoices (
    school_id, student_id, academic_year_id, fee_structure_id, invoice_number,
    due_date, total_amount, net_amount, balance, status, fee_type,
    billing_mode, priority, monthly_amount, term_amount, term_count,
    allowed_month_names, paid_month_names
  ) values (
    v_assignment.school_id, v_assignment.student_id,
    v_assignment.academic_year_id, v_assignment.fee_structure_id,
    v_invoice_number, v_due_date, v_assignment.amount, v_assignment.amount,
    v_assignment.amount, 'pending', v_fee_type, v_billing_mode, v_priority,
    case when v_billing_mode = 'monthly' then round(v_assignment.amount / 10.0, 2) else 0 end,
    0, 0,
    case when v_billing_mode = 'monthly' then array['June','July','August','September','October','November','December','January','February','March']::text[] else '{}'::text[] end,
    '{}'::text[]
  ) on conflict do nothing returning id into v_invoice_id;
  if v_invoice_id is null then return false; end if;
  insert into public.fee_invoice_items (invoice_id, fee_structure_id, category_name, amount)
    values (v_invoice_id, v_assignment.fee_structure_id, v_assignment.category_name, v_assignment.amount);
  return true;
end;
$$;

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
  v_plan record;
  v_period date := date_trunc('month', p_period)::date;
  v_total numeric(12,2);
  v_due_date date;
  v_invoice_id uuid;
  v_invoice_number text;
begin
  select
    p.*, fs.due_day, fs.id as structure_id,
    coalesce(fc.name, 'Daycare') as category_name
  into v_plan
  from public.daycare_fee_plans p
  join public.fee_structures fs on fs.id = p.fee_structure_id and fs.school_id = p.school_id
  left join public.fee_categories fc on fc.id = coalesce(fs.fee_category_id, fs.category_id)
  where p.id = p_plan_id
    and p.is_active = true;
  if not found then return null; end if;
  if date_trunc('month', v_plan.effective_from)::date > v_period
     or (v_plan.effective_to is not null and date_trunc('month', v_plan.effective_to)::date < v_period) then
    return null;
  end if;

  v_total := round(v_plan.hourly_rate * v_plan.contracted_hours_per_month, 2);
  v_due_date := make_date(
    extract(year from v_period)::integer,
    extract(month from v_period)::integer,
    least(
      greatest(coalesce(v_plan.due_day, 10), 1),
      extract(day from (v_period + interval '1 month - 1 day'))::integer
    )
  );
  v_invoice_number := 'DAY-'
    || to_char(v_period, 'YYYYMM') || '-'
    || upper(substr(replace(v_plan.student_id::text, '-', ''), 1, 8)) || '-'
    || upper(substr(replace(v_plan.fee_structure_id::text, '-', ''), 1, 8));

  insert into public.fee_invoices (
    school_id, student_id, academic_year_id, fee_structure_id, invoice_number,
    invoice_date, due_date, total_amount, net_amount, balance, status,
    fee_type, billing_mode, priority, billing_period, billing_details,
    monthly_amount, allowed_month_names, paid_month_names
  ) values (
    v_plan.school_id, v_plan.student_id, v_plan.academic_year_id,
    v_plan.fee_structure_id, v_invoice_number, v_period, v_due_date, v_total,
    v_total, v_total, 'pending', 'daycare_hourly', 'monthly', 3, v_period,
    jsonb_build_object(
      'hourly_rate', v_plan.hourly_rate,
      'contracted_hours_per_month', v_plan.contracted_hours_per_month,
      'billing_period', v_period
    ),
    v_total, '{}'::text[], '{}'::text[]
  ) on conflict do nothing returning id into v_invoice_id;
  if v_invoice_id is null then
    select id into v_invoice_id from public.fee_invoices
    where school_id = v_plan.school_id and student_id = v_plan.student_id
      and fee_structure_id = v_plan.fee_structure_id and billing_period = v_period;
    return v_invoice_id;
  end if;
  insert into public.fee_invoice_items (invoice_id, fee_structure_id, category_name, amount)
    values (v_invoice_id, v_plan.fee_structure_id,
      v_plan.category_name || ' — ' || to_char(v_period, 'Mon YYYY')
        || ' (' || trim(to_char(v_plan.contracted_hours_per_month, 'FM999999990.00'))
        || ' hours × ₹' || trim(to_char(v_plan.hourly_rate, 'FM999999990.00')) || ')',
      v_total);
  return v_invoice_id;
end;
$$;

create or replace function public.generate_current_daycare_invoices(
  p_period date default ((now() at time zone 'Asia/Kolkata')::date)
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_plan_id uuid;
  v_count integer := 0;
begin
  for v_plan_id in
    select id from public.daycare_fee_plans
    where is_active = true
      and date_trunc('month', effective_from)::date <= date_trunc('month', p_period)::date
      and (effective_to is null or date_trunc('month', effective_to)::date >= date_trunc('month', p_period)::date)
  loop
    if public.ensure_daycare_invoice_for_plan(v_plan_id, p_period) is not null then
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end;
$$;

-- Payments are balance-first. Historical month metadata stays untouched, but
-- new payments always write an empty allocation and use the locked live balance.
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
  select * into v_invoice from public.fee_invoices
    where id = p_invoice_id and school_id = p_school_id and student_id = p_student_id for update;
  if not found then raise exception 'Invoice not found'; end if;
  select coalesce(nullif(student_id_number, ''), nullif(admission_number, ''), right(p_student_id::text, 8))
    into v_student_identifier from public.students where id = p_student_id and school_id = p_school_id;
  v_student_identifier := upper(regexp_replace(coalesce(v_student_identifier, right(p_student_id::text, 8)), '[^A-Za-z0-9]+', '-', 'g'));
  if p_request_id is not null then
    select * into v_request from public.parent_payment_requests where id = p_request_id and school_id = p_school_id for update;
    if not found then raise exception 'Payment request not found'; end if;
    if v_request.payment_id is not null or v_request.status in ('approved','completed','paid') then raise exception 'Payment request has already been approved'; end if;
    if p_amount <> v_request.amount then raise exception 'Payment request amount has changed'; end if;
  end if;
  if p_amount <= 0 or p_amount > v_invoice.balance then raise exception 'Invalid payment amount'; end if;
  v_months := coalesce(v_invoice.paid_month_names, '{}');
  v_paid := v_invoice.paid_amount + p_amount;
  v_balance := greatest(0, v_invoice.net_amount - v_paid);
  v_status := case when v_balance = 0 then 'paid' else 'partial' end;
  insert into public.payments (school_id, student_id, invoice_id, amount, payment_method, reference_number, paid_at, notes, status, created_by, selected_months, selected_month_names)
    values (p_school_id, p_student_id, p_invoice_id, p_amount, p_payment_method, nullif(p_reference_number, ''), coalesce(p_paid_at, now()), nullif(p_notes, ''), 'completed', p_created_by, 0, '{}'::text[])
    returning id into v_payment_id;
  v_receipt_number := 'RCP-' || v_student_identifier || '-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS');
  insert into public.fee_receipts (school_id, invoice_id, payment_id, receipt_number, amount, payment_method, transaction_ref)
    values (p_school_id, v_invoice.id, v_payment_id, v_receipt_number, p_amount, p_payment_method, nullif(p_reference_number, '')) returning id into v_receipt_id;
  update public.fee_invoices set paid_amount = v_paid, balance = v_balance, status = v_status, updated_at = now() where id = v_invoice.id;
  if p_request_id is not null then
    update public.parent_payment_requests set status = 'approved', payment_id = v_payment_id, receipt_id = v_receipt_id, reviewed_by = p_created_by, reviewed_at = now(), updated_at = now() where id = v_request.id;
  end if;
  return query select v_payment_id, v_receipt_id, v_receipt_number, v_status, v_balance, v_months;
end;
$$;
revoke all on function public.record_fee_payment(uuid,uuid,uuid,numeric,text,text,timestamptz,text,uuid,text[],int,uuid) from public;
grant execute on function public.record_fee_payment(uuid,uuid,uuid,numeric,text,text,timestamptz,text,uuid,text[],int,uuid) to service_role;

-- This database-side scheduler only queues durable events; the existing
-- notification processor continues to deliver them to FCM every two minutes.
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
        school_id, user_id, title, body, type, entity_type, entity_id,
        reference_type, reference_id, route, student_id, is_read
      ) values (
        v_invoice.school_id, v_parent.parent_user_id, 'Fee payment reminder', v_message,
        'fee', 'fee_invoice', v_invoice.id, 'fee', v_invoice.id,
        '/parent-fees-screen', v_invoice.student_id, false
      );
      v_queued := v_queued + 1;
    end loop;
  end loop;
  return v_queued;
end;
$$;
revoke all on function public.ensure_daycare_invoice_for_plan(uuid,date) from public;
revoke all on function public.generate_current_daycare_invoices(date) from public;
revoke all on function public.queue_fee_reminders(date) from public;
grant execute on function public.ensure_daycare_invoice_for_plan(uuid,date) to service_role;
grant execute on function public.generate_current_daycare_invoices(date) to service_role;
grant execute on function public.queue_fee_reminders(date) to service_role;

create extension if not exists pg_cron with schema extensions;
do $$ begin
  perform cron.unschedule('queue-fee-reminders-daily');
exception when others then null;
end $$;
select cron.schedule(
  'queue-fee-reminders-daily',
  '30 3 * * *', -- 09:00 Asia/Kolkata
  $$select public.queue_fee_reminders();$$
);
do $$ begin
  perform cron.unschedule('generate-current-daycare-invoices');
exception when others then null;
end $$;
select cron.schedule(
  'generate-current-daycare-invoices',
  '10 0 1 * *', -- first day of the month, 05:40 Asia/Kolkata
  $$select public.generate_current_daycare_invoices();$$
);
