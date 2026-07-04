-- ============================================================
-- Migration 0018: Fee month allocation workflow
-- Adds explicit fee-type and month-ledger fields required by the
-- parent/principal fees workflow.
-- ============================================================

alter table public.fee_structures
  add column if not exists fee_type text not null default '',
  add column if not exists billing_mode text not null default '',
  add column if not exists priority int not null default 99;

update public.fee_structures
set fee_type = case
      when lower(coalesce(fc.name, '')) like '%book%' or lower(coalesce(fc.name, '')) like '%kit%' then 'book_kit'
      else 'tuition'
    end,
    billing_mode = case
      when coalesce(public.fee_structures.frequency, '') = 'one_time' then 'one_time'
      else 'monthly'
    end,
    priority = case
      when lower(coalesce(fc.name, '')) like '%book%' or lower(coalesce(fc.name, '')) like '%kit%' then 1
      else 2
    end
from public.fee_categories fc
where fc.id = coalesce(public.fee_structures.fee_category_id, public.fee_structures.category_id)
  and (
    public.fee_structures.fee_type = ''
    or public.fee_structures.billing_mode = ''
    or public.fee_structures.priority = 99
  );

alter table public.fee_invoices
  add column if not exists fee_structure_id uuid references public.fee_structures(id) on delete set null,
  add column if not exists fee_type text not null default '',
  add column if not exists billing_mode text not null default '',
  add column if not exists priority int not null default 99,
  add column if not exists monthly_amount numeric(12,2) not null default 0,
  add column if not exists term_amount numeric(12,2) not null default 0,
  add column if not exists term_count int not null default 0,
  add column if not exists allowed_month_names text[] not null default '{}',
  add column if not exists paid_month_names text[] not null default '{}';

update public.fee_invoices fi
set fee_structure_id = fii.fee_structure_id,
    fee_type = case
      when coalesce(fs.fee_type, '') <> '' then fs.fee_type
      when lower(coalesce(fii.category_name, '')) like '%book%' or lower(coalesce(fii.category_name, '')) like '%kit%' then 'book_kit'
      else 'tuition'
    end,
    billing_mode = case
      when coalesce(fs.billing_mode, '') <> '' then fs.billing_mode
      when coalesce(fs.frequency, '') = 'one_time' then 'one_time'
      else 'monthly'
    end,
    priority = case
      when fs.priority is not null and fs.priority <> 99 then fs.priority
      when lower(coalesce(fii.category_name, '')) like '%book%' or lower(coalesce(fii.category_name, '')) like '%kit%' then 1
      else 2
    end,
    monthly_amount = case
      when coalesce(fs.fee_type, '') = 'book_kit'
        or lower(coalesce(fii.category_name, '')) like '%book%'
        or lower(coalesce(fii.category_name, '')) like '%kit%' then 0
      when fi.net_amount > 0 then round((fi.net_amount / 12.0)::numeric, 2)
      else fi.monthly_amount
    end,
    allowed_month_names = case
      when coalesce(fs.fee_type, '') = 'book_kit'
        or lower(coalesce(fii.category_name, '')) like '%book%'
        or lower(coalesce(fii.category_name, '')) like '%kit%' then '{}'
      else array[
        'January','February','March','April','May','June',
        'July','August','September','October','November','December'
      ]::text[]
    end
from public.fee_invoice_items fii
left join public.fee_structures fs on fs.id = fii.fee_structure_id
where fii.invoice_id = fi.id
  and (
    fi.fee_structure_id is null
    or fi.fee_type = ''
    or fi.billing_mode = ''
    or fi.priority = 99
    or fi.allowed_month_names = '{}'
  );

alter table public.parent_payment_requests
  add column if not exists admin_remarks text;

alter table public.payments
  add column if not exists selected_months int not null default 0,
  add column if not exists selected_month_names text[] not null default '{}',
  add column if not exists selected_terms int not null default 0;
