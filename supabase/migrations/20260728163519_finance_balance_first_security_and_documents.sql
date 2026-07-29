-- Finance hardening: balance-first payments, immutable documents, and API-only
-- access. Historical month values are intentionally retained on old rows only;
-- no new payment or invoice workflow reads or writes them.

alter table public.fee_categories
  add column if not exists archived_at timestamptz,
  add column if not exists archived_by uuid references public.users(id) on delete set null;

alter table public.fee_structures
  add column if not exists is_active boolean not null default true,
  add column if not exists archived_at timestamptz,
  add column if not exists archived_by uuid references public.users(id) on delete set null;

alter table public.payments
  add column if not exists idempotency_key text,
  add column if not exists reversal_of_payment_id uuid references public.payments(id) on delete restrict,
  add column if not exists reversed_at timestamptz,
  add column if not exists reversed_by uuid references public.users(id) on delete set null,
  add column if not exists reversal_reason text;

alter table public.fee_receipts
  add column if not exists document_snapshot_id uuid,
  add column if not exists voided_at timestamptz,
  add column if not exists voided_by uuid references public.users(id) on delete set null,
  add column if not exists void_reason text;

alter table public.parent_payment_requests
  add column if not exists idempotency_key text,
  add column if not exists clarification_requested_at timestamptz,
  add column if not exists submitted_at timestamptz;

create unique index if not exists payments_school_idempotency_key
  on public.payments(school_id, idempotency_key)
  where idempotency_key is not null and idempotency_key <> '';
create unique index if not exists fee_receipts_school_receipt_number_key
  on public.fee_receipts(school_id, receipt_number)
  where school_id is not null;
create unique index if not exists parent_payment_requests_active_invoice_parent_key
  on public.parent_payment_requests(school_id, invoice_id, parent_user_id)
  where parent_user_id is not null
    and status in ('initiated', 'pending_verification', 'clarification_required', 'resubmitted');

alter table public.parent_payment_requests
  drop constraint if exists parent_payment_requests_status_check;
alter table public.parent_payment_requests
  add constraint parent_payment_requests_status_check check (
    status in ('initiated', 'pending_verification', 'clarification_required',
      'resubmitted', 'approved', 'rejected', 'reversed')
  ) not valid;

create table if not exists public.finance_document_sequences (
  school_id uuid not null references public.schools(id) on delete cascade,
  fiscal_year text not null,
  document_kind text not null check (document_kind in ('invoice', 'receipt')),
  current_value bigint not null default 0 check (current_value >= 0),
  primary key (school_id, fiscal_year, document_kind)
);

create table if not exists public.finance_document_snapshots (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  invoice_id uuid references public.fee_invoices(id) on delete restrict,
  payment_id uuid references public.payments(id) on delete restrict,
  receipt_id uuid references public.fee_receipts(id) on delete restrict,
  document_kind text not null check (document_kind in ('invoice', 'payment_receipt', 'account_statement', 'fee_report')),
  document_number text,
  version integer not null default 1 check (version > 0),
  source_totals jsonb not null default '{}'::jsonb,
  source_snapshot jsonb not null default '{}'::jsonb,
  content_sha256 text,
  storage_bucket text not null default 'finance-documents',
  storage_path text,
  generated_at timestamptz not null default now(),
  generated_by uuid references public.users(id) on delete set null,
  supersedes_snapshot_id uuid references public.finance_document_snapshots(id) on delete restrict,
  unique (school_id, document_kind, document_number, version)
);
alter table public.finance_document_snapshots enable row level security;
create index if not exists finance_document_snapshots_lookup_idx
  on public.finance_document_snapshots(school_id, invoice_id, payment_id, receipt_id, generated_at desc);

create table if not exists public.school_finance_settings (
  school_id uuid primary key references public.schools(id) on delete cascade,
  legal_name text,
  address text,
  contact_phone text,
  contact_email text,
  invoice_prefix text not null default 'INV',
  receipt_prefix text not null default 'RCP',
  payment_terms text,
  signature_path text,
  seal_path text,
  gst_enabled boolean not null default false,
  gstin text,
  state_code text,
  place_of_supply text,
  updated_by uuid references public.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table public.school_finance_settings enable row level security;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'finance-documents', 'finance-documents', false, 20971520,
  array['application/pdf']
) on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit;

-- Direct Data API access to financial records is forbidden. The service-role
-- Edge API performs authorization and uses narrowly scoped responses.
revoke all on table public.fee_categories, public.fee_structures,
  public.fee_installments, public.fee_invoices, public.fee_invoice_items,
  public.fee_concessions, public.payments, public.fee_receipts,
  public.parent_payment_requests, public.finance_document_sequences,
  public.finance_document_snapshots, public.school_finance_settings
  from anon, authenticated;
grant all on table public.finance_document_sequences, public.finance_document_snapshots,
  public.school_finance_settings to service_role;

-- Recreate the payment RPC with an idempotency key and no active month
-- allocation. The historical columns remain untouched for already-issued rows.
drop function if exists public.record_fee_payment(
  uuid, uuid, uuid, numeric, text, text, timestamptz, text, uuid, text[], int, uuid
);
create or replace function public.record_fee_payment(
  p_school_id uuid,
  p_invoice_id uuid,
  p_student_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_reference_number text,
  p_paid_at timestamptz,
  p_notes text,
  p_created_by uuid,
  p_request_id uuid default null,
  p_idempotency_key text default null
)
returns table(
  payment_id uuid,
  receipt_id uuid,
  receipt_number text,
  invoice_status text,
  balance numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_invoice public.fee_invoices%rowtype;
  v_request public.parent_payment_requests%rowtype;
  v_existing_payment public.payments%rowtype;
  v_payment_id uuid;
  v_receipt_id uuid;
  v_receipt_number text;
  v_student_identifier text;
  v_paid numeric;
  v_balance numeric;
  v_status text;
  v_fiscal_year text := to_char(coalesce(p_paid_at, now()), 'YY');
  v_sequence bigint;
begin
  if p_amount <= 0 then raise exception 'Payment amount must be greater than zero'; end if;

  if nullif(trim(coalesce(p_idempotency_key, '')), '') is not null then
    select * into v_existing_payment from public.payments
    where school_id = p_school_id and idempotency_key = p_idempotency_key;
    if found then
      select id, receipt_number into v_receipt_id, v_receipt_number
      from public.fee_receipts where payment_id = v_existing_payment.id order by issued_at desc limit 1;
      return query select v_existing_payment.id, v_receipt_id, v_receipt_number,
        coalesce((select status from public.fee_invoices where id = v_existing_payment.invoice_id), 'partial'),
        coalesce((select balance from public.fee_invoices where id = v_existing_payment.invoice_id), 0);
      return;
    end if;
  end if;

  select * into v_invoice from public.fee_invoices
  where id = p_invoice_id and school_id = p_school_id and student_id = p_student_id
  for update;
  if not found then raise exception 'Invoice not found'; end if;
  if p_amount > v_invoice.balance then raise exception 'Payment amount exceeds the remaining balance'; end if;

  if p_request_id is not null then
    select * into v_request from public.parent_payment_requests
    where id = p_request_id and school_id = p_school_id for update;
    if not found then raise exception 'Payment request not found'; end if;
    if v_request.status not in ('pending_verification', 'resubmitted') then
      raise exception 'Payment request is not awaiting approval';
    end if;
    if v_request.payment_id is not null or v_request.amount <> p_amount then
      raise exception 'Payment request has changed';
    end if;
  end if;

  select coalesce(nullif(student_id_number, ''), nullif(admission_number, ''), right(p_student_id::text, 8))
  into v_student_identifier from public.students
  where id = p_student_id and school_id = p_school_id;
  v_student_identifier := upper(regexp_replace(coalesce(v_student_identifier, right(p_student_id::text, 8)), '[^A-Za-z0-9]+', '-', 'g'));

  insert into public.finance_document_sequences(school_id, fiscal_year, document_kind, current_value)
  values (p_school_id, v_fiscal_year, 'receipt', 1)
  on conflict (school_id, fiscal_year, document_kind)
  do update set current_value = public.finance_document_sequences.current_value + 1
  returning current_value into v_sequence;

  v_paid := v_invoice.paid_amount + p_amount;
  v_balance := greatest(0, v_invoice.net_amount - v_paid);
  v_status := case when v_balance = 0 then 'paid' else 'partial' end;

  insert into public.payments(
    school_id, student_id, invoice_id, amount, payment_method, reference_number,
    paid_at, notes, status, created_by, idempotency_key
  ) values (
    p_school_id, p_student_id, p_invoice_id, p_amount, nullif(trim(p_payment_method), ''),
    nullif(trim(p_reference_number), ''), coalesce(p_paid_at, now()), nullif(p_notes, ''),
    'completed', p_created_by, nullif(trim(p_idempotency_key), '')
  ) returning id into v_payment_id;

  v_receipt_number := 'RCP-' || v_student_identifier || '-' || v_fiscal_year || '-' || lpad(v_sequence::text, 6, '0');
  insert into public.fee_receipts(
    school_id, invoice_id, payment_id, receipt_number, amount, payment_method, transaction_ref
  ) values (
    p_school_id, p_invoice_id, v_payment_id, v_receipt_number, p_amount,
    nullif(trim(p_payment_method), ''), nullif(trim(p_reference_number), '')
  ) returning id into v_receipt_id;

  update public.fee_invoices
  set paid_amount = v_paid, balance = v_balance, status = v_status, updated_at = now()
  where id = v_invoice.id;

  return query select v_payment_id, v_receipt_id, v_receipt_number, v_status, v_balance;
end;
$$;

revoke all on function public.record_fee_payment(
  uuid, uuid, uuid, numeric, text, text, timestamptz, text, uuid, uuid, text
) from public, anon, authenticated;
grant execute on function public.record_fee_payment(
  uuid, uuid, uuid, numeric, text, text, timestamptz, text, uuid, uuid, text
) to service_role;

revoke all on function public.ensure_daycare_invoice_for_plan(uuid, date) from public, anon, authenticated;
revoke all on function public.generate_current_daycare_invoices(date) from public, anon, authenticated;
revoke all on function public.queue_fee_reminders(date) from public, anon, authenticated;
grant execute on function public.ensure_daycare_invoice_for_plan(uuid, date) to service_role;
grant execute on function public.generate_current_daycare_invoices(date) to service_role;
grant execute on function public.queue_fee_reminders(date) to service_role;
