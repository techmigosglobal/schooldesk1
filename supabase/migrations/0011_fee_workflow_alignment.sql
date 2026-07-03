-- ============================================================
-- Migration 0011: Fee Workflow Schema Alignment
-- Aligns Supabase fee runtime with the Flutter fee contract.
-- ============================================================

alter table public.fee_structures
  add column if not exists fee_category_id uuid references public.fee_categories(id) on delete cascade,
  add column if not exists due_day int not null default 10,
  add column if not exists late_fine_per_day numeric(8,2) not null default 0,
  add column if not exists replace_existing boolean not null default false;

update public.fee_structures
set fee_category_id = category_id
where fee_category_id is null and category_id is not null;

alter table public.fee_installments
  add column if not exists school_id uuid references public.schools(id) on delete cascade,
  add column if not exists academic_year_id uuid references public.academic_years(id) on delete cascade,
  add column if not exists grade_id uuid references public.grades(id) on delete set null,
  add column if not exists section_id uuid references public.sections(id) on delete set null,
  add column if not exists method text not null default 'equal',
  add column if not exists status text not null default 'active',
  add column if not exists percentage numeric(5,2);

update public.fee_installments fi
set school_id = fs.school_id,
    academic_year_id = fs.academic_year_id,
    grade_id = fs.grade_id,
    section_id = fs.section_id
from public.fee_structures fs
where fi.fee_structure_id = fs.id
  and (fi.school_id is null or fi.academic_year_id is null);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'fee_invoices_invoice_number_key'
      and conrelid = 'public.fee_invoices'::regclass
  ) then
    alter table public.fee_invoices
      add constraint fee_invoices_invoice_number_key unique (invoice_number);
  end if;
end;
$$;

create table if not exists public.fee_receipts (
  id             uuid primary key default uuid_generate_v4(),
  payment_id     uuid not null references public.payments(id) on delete cascade,
  receipt_number text not null,
  issued_at      timestamptz not null default now(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table public.fee_receipts enable row level security;

alter table public.parent_payment_requests
  add column if not exists parent_user_id uuid,
  add column if not exists payment_id uuid references public.payments(id) on delete set null,
  add column if not exists receipt_id uuid references public.fee_receipts(id) on delete set null,
  add column if not exists request_reference text,
  add column if not exists transaction_ref text,
  add column if not exists transaction_id text,
  add column if not exists payment_date date,
  add column if not exists selected_months int not null default 0,
  add column if not exists selected_month_names text[] not null default '{}',
  add column if not exists selected_terms int not null default 0,
  add column if not exists proof_file_name text,
  add column if not exists proof_content_type text,
  add column if not exists proof_size bigint,
  add column if not exists reviewed_at timestamptz;

create unique index if not exists parent_payment_requests_reference_key
  on public.parent_payment_requests(request_reference)
  where request_reference is not null and request_reference <> '';

drop policy if exists "parent_payment_requests_school_select" on public.parent_payment_requests;
drop policy if exists "parent_payment_requests_school_insert" on public.parent_payment_requests;
drop policy if exists "parent_payment_requests_school_update" on public.parent_payment_requests;
drop policy if exists "parent_payment_requests_school_delete" on public.parent_payment_requests;

create policy "parent_payment_requests_linked_select" on public.parent_payment_requests
  for select to authenticated
  using (
    school_id = public.auth_school_id()
    and (
      public.is_admin_or_principal()
      or parent_user_id = auth.uid()
      or exists (
        select 1 from public.parent_student_links psl
        where psl.school_id = parent_payment_requests.school_id
          and psl.student_id = parent_payment_requests.student_id
          and psl.parent_user_id = auth.uid()
      )
    )
  );

create policy "parent_payment_requests_linked_insert" on public.parent_payment_requests
  for insert to authenticated
  with check (
    school_id = public.auth_school_id()
    and (
      public.is_admin_or_principal()
      or exists (
        select 1 from public.parent_student_links psl
        where psl.school_id = parent_payment_requests.school_id
          and psl.student_id = parent_payment_requests.student_id
          and psl.parent_user_id = auth.uid()
      )
    )
  );

create policy "parent_payment_requests_linked_update" on public.parent_payment_requests
  for update to authenticated
  using (
    school_id = public.auth_school_id()
    and (
      public.is_admin_or_principal()
      or parent_user_id = auth.uid()
    )
  )
  with check (
    school_id = public.auth_school_id()
    and (
      public.is_admin_or_principal()
      or parent_user_id = auth.uid()
    )
  );

create policy "parent_payment_requests_admin_delete" on public.parent_payment_requests
  for delete to authenticated
  using (school_id = public.auth_school_id() and public.is_admin_or_principal());
