alter table public.fee_concessions
  add column if not exists invoice_id uuid references public.fee_invoices(id) on delete cascade,
  add column if not exists status text not null default 'approved',
  add column if not exists updated_at timestamptz not null default now();

update public.fee_concessions
set status = 'approved'
where status is null or btrim(status) = '';

update public.fee_concessions concession
set invoice_id = invoice.id
from public.fee_invoices invoice
where concession.invoice_id is null
  and invoice.school_id = concession.school_id
  and invoice.student_id = concession.student_id
  and invoice.fee_structure_id = concession.fee_structure_id;

create index if not exists idx_fee_concessions_invoice
  on public.fee_concessions(invoice_id);
create index if not exists idx_fee_concessions_student_status
  on public.fee_concessions(school_id, student_id, status);

alter table public.fee_concessions
  drop constraint if exists fee_concessions_status_check;
alter table public.fee_concessions
  add constraint fee_concessions_status_check
  check (status in ('pending', 'approved', 'rejected'));

create or replace function public.sync_fee_concession_invoice()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_invoice_id uuid;
  v_invoice public.fee_invoices%rowtype;
  v_discount numeric(12,2);
  v_net numeric(12,2);
  v_balance numeric(12,2);
  v_status text;
begin
  v_invoice_id := case
    when tg_op = 'DELETE' then old.invoice_id
    else new.invoice_id
  end;
  if v_invoice_id is null then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  select * into v_invoice
  from public.fee_invoices
  where id = v_invoice_id
  for update;
  if not found then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  select coalesce(sum(
    case
      when coalesce(amount, 0) > 0 then amount
      when coalesce(percentage, 0) > 0
        then round(v_invoice.total_amount * percentage / 100.0, 2)
      else 0
    end
  ), 0)
  into v_discount
  from public.fee_concessions
  where invoice_id = v_invoice_id
    and status = 'approved';

  if v_discount > greatest(v_invoice.total_amount - v_invoice.paid_amount, 0) then
    raise exception 'Concession exceeds the outstanding invoice balance';
  end if;

  v_net := greatest(0, v_invoice.total_amount - v_discount);
  v_balance := greatest(0, v_net - v_invoice.paid_amount);
  v_status := case
    when v_balance = 0 then 'paid'
    when v_invoice.paid_amount > 0 then 'partial'
    else 'pending'
  end;

  update public.fee_invoices
  set discount_amount = v_discount,
      net_amount = v_net,
      balance = v_balance,
      status = v_status,
      updated_at = now()
  where id = v_invoice_id;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists fee_concessions_sync_invoice on public.fee_concessions;
create trigger fee_concessions_sync_invoice
after insert or update of amount, percentage, status, invoice_id or delete
on public.fee_concessions
for each row
execute function public.sync_fee_concession_invoice();

revoke all on function public.sync_fee_concession_invoice()
  from public, anon, authenticated;
grant execute on function public.sync_fee_concession_invoice()
  to service_role;

-- Recalculate invoice balances for any pre-existing concessions.
update public.fee_concessions
set updated_at = now()
where invoice_id is not null;
