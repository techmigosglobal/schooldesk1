-- ============================================================
-- Migration 0013: Fee Receipt Remote Alignment
-- Adds receipt metadata for projects that already had the older receipt table.
-- ============================================================

alter table public.fee_receipts
  add column if not exists school_id uuid references public.schools(id) on delete cascade,
  add column if not exists invoice_id uuid references public.fee_invoices(id) on delete set null,
  add column if not exists amount numeric(12,2),
  add column if not exists payment_method text,
  add column if not exists transaction_ref text;

update public.fee_receipts fr
set school_id = p.school_id,
    invoice_id = p.invoice_id,
    amount = coalesce(fr.amount, p.amount),
    payment_method = coalesce(fr.payment_method, p.payment_method),
    transaction_ref = coalesce(fr.transaction_ref, p.reference_number)
from public.payments p
where fr.payment_id = p.id
  and (fr.school_id is null or fr.invoice_id is null or fr.amount is null);

create index if not exists idx_fee_receipts_school
  on public.fee_receipts(school_id, issued_at desc);

create index if not exists idx_fee_receipts_invoice
  on public.fee_receipts(invoice_id);
