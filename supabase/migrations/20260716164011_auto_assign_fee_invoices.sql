-- Keep fee structures and student invoices synchronized at the data boundary.
-- The application may create students/structures through several screens; the
-- assignment must not depend on a particular screen issuing a second request.

create unique index if not exists fee_invoices_student_structure_key
  on public.fee_invoices(school_id, student_id, fee_structure_id)
  where fee_structure_id is not null;

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
  if exists (
    select 1
    from public.fee_invoices fi
    where fi.student_id = p_student_id
      and fi.fee_structure_id = p_fee_structure_id
  ) then
    return false;
  end if;

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
    when lower(coalesce(nullif(v_assignment.fee_type, ''), v_assignment.category_name, '')) like '%tuition%'
      then 'tuition'
    else 'other'
  end;
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
    school_id,
    student_id,
    academic_year_id,
    fee_structure_id,
    invoice_number,
    due_date,
    total_amount,
    net_amount,
    balance,
    status,
    fee_type,
    billing_mode,
    priority,
    monthly_amount,
    term_amount,
    term_count,
    allowed_month_names,
    paid_month_names
  ) values (
    v_assignment.school_id,
    v_assignment.student_id,
    v_assignment.academic_year_id,
    v_assignment.fee_structure_id,
    v_invoice_number,
    v_due_date,
    v_assignment.amount,
    v_assignment.amount,
    v_assignment.amount,
    'pending',
    v_fee_type,
    v_billing_mode,
    v_priority,
    case
      when v_billing_mode = 'monthly' then round(v_assignment.amount / 10.0, 2)
      else 0
    end,
    0,
    0,
    case
      when v_billing_mode = 'monthly' then array[
        'June', 'July', 'August', 'September', 'October',
        'November', 'December', 'January', 'February', 'March'
      ]::text[]
      else '{}'::text[]
    end,
    '{}'::text[]
  )
  on conflict do nothing
  returning id into v_invoice_id;

  if v_invoice_id is null then
    return false;
  end if;

  insert into public.fee_invoice_items (
    invoice_id,
    fee_structure_id,
    category_name,
    amount
  ) values (
    v_invoice_id,
    v_assignment.fee_structure_id,
    v_assignment.category_name,
    v_assignment.amount
  );

  return true;
end;
$$;

create or replace function public.ensure_fee_invoices_for_student(
  p_student_id uuid
)
returns integer
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_structure_id uuid;
  v_created integer := 0;
begin
  for v_structure_id in
    select fs.id
    from public.students s
    join public.sections sec
      on sec.id = s.current_section_id
     and sec.school_id = s.school_id
    join public.fee_structures fs
      on fs.school_id = s.school_id
     and fs.academic_year_id = sec.academic_year_id
     and fs.grade_id = sec.grade_id
     and (fs.section_id is null or fs.section_id = sec.id)
    where s.id = p_student_id
      and s.status = 'active'
  loop
    if public.ensure_fee_invoice_for_student_structure(
      p_student_id,
      v_structure_id
    ) then
      v_created := v_created + 1;
    end if;
  end loop;
  return v_created;
end;
$$;

create or replace function public.ensure_fee_invoices_for_structure(
  p_fee_structure_id uuid
)
returns integer
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_student_id uuid;
  v_created integer := 0;
begin
  for v_student_id in
    select s.id
    from public.fee_structures fs
    join public.sections sec
      on sec.school_id = fs.school_id
     and sec.academic_year_id = fs.academic_year_id
     and sec.grade_id = fs.grade_id
     and (fs.section_id is null or fs.section_id = sec.id)
    join public.students s
      on s.school_id = fs.school_id
     and s.current_section_id = sec.id
     and s.status = 'active'
    where fs.id = p_fee_structure_id
  loop
    if public.ensure_fee_invoice_for_student_structure(
      v_student_id,
      p_fee_structure_id
    ) then
      v_created := v_created + 1;
    end if;
  end loop;
  return v_created;
end;
$$;

create or replace function public.sync_student_fee_invoices_trigger()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  if new.status = 'active' and new.current_section_id is not null then
    perform public.ensure_fee_invoices_for_student(new.id);
  end if;
  return new;
end;
$$;

create or replace function public.sync_structure_fee_invoices_trigger()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  perform public.ensure_fee_invoices_for_structure(new.id);
  return new;
end;
$$;

drop trigger if exists students_auto_assign_fee_invoices on public.students;
create trigger students_auto_assign_fee_invoices
after insert or update of current_section_id, status
on public.students
for each row
execute function public.sync_student_fee_invoices_trigger();

drop trigger if exists structures_auto_assign_fee_invoices on public.fee_structures;
create trigger structures_auto_assign_fee_invoices
after insert or update of academic_year_id, grade_id, section_id
on public.fee_structures
for each row
execute function public.sync_structure_fee_invoices_trigger();

revoke all on function public.ensure_fee_invoice_for_student_structure(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.ensure_fee_invoices_for_student(uuid)
  from public, anon, authenticated;
revoke all on function public.ensure_fee_invoices_for_structure(uuid)
  from public, anon, authenticated;
revoke all on function public.sync_student_fee_invoices_trigger()
  from public, anon, authenticated;
revoke all on function public.sync_structure_fee_invoices_trigger()
  from public, anon, authenticated;

grant execute on function public.ensure_fee_invoice_for_student_structure(uuid, uuid)
  to service_role;
grant execute on function public.ensure_fee_invoices_for_student(uuid)
  to service_role;
grant execute on function public.ensure_fee_invoices_for_structure(uuid)
  to service_role;

-- Repair existing gaps before enabling the new behavior for future writes.
do $$
declare
  v_student_id uuid;
begin
  for v_student_id in
    select id
    from public.students
    where status = 'active'
      and current_section_id is not null
  loop
    perform public.ensure_fee_invoices_for_student(v_student_id);
  end loop;
end;
$$;
