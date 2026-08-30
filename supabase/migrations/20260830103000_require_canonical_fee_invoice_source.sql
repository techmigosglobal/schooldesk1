-- Prevent new structure-less operational invoices from creating a second
-- balance for the same student. Existing legacy rows are left untouched for
-- an explicit, reviewed reconciliation; this migration must not merge or
-- delete production financial history automatically.
--
-- A trigger is used instead of a CHECK constraint so an old legacy row can
-- still receive a payment/balance update while it is being reconciled. The
-- source columns themselves are protected on INSERT and whenever they are
-- changed.

create or replace function public.reject_structureless_fee_invoice()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.fee_structure_id is null and new.daycare_plan_id is null and (
    tg_op = 'INSERT'
    or old.fee_structure_id is distinct from new.fee_structure_id
    or old.daycare_plan_id is distinct from new.daycare_plan_id
  ) then
    raise exception
      'fee invoice must reference fee_structure_id or daycare_plan_id';
  end if;
  return new;
end;
$$;

drop trigger if exists fee_invoices_require_canonical_source
  on public.fee_invoices;
create trigger fee_invoices_require_canonical_source
before insert or update of fee_structure_id, daycare_plan_id
on public.fee_invoices
for each row execute function public.reject_structureless_fee_invoice();

revoke all on function public.reject_structureless_fee_invoice()
  from public, anon, authenticated;
grant execute on function public.reject_structureless_fee_invoice()
  to service_role;

-- Keep one canonical invoice per student and fee structure.  The index is
-- intentionally partial so legacy rows can be audited while all new
-- structure-linked invoices are idempotent at the database boundary.
create unique index if not exists fee_invoices_student_structure_canonical_key
  on public.fee_invoices(school_id, student_id, fee_structure_id)
  where fee_structure_id is not null;
