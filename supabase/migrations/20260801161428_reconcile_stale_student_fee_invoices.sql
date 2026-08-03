-- The student placement repair created the correct current-class invoices, but
-- the old invoices created while students were in the wrong class remained
-- outstanding. Keep those invoice rows for auditability; cancel only the
-- unpaid rows whose linked structure no longer matches the student's current
-- grade/section. Paid and partially paid invoices are never changed.

alter table public.fee_invoices
  add column if not exists voided_at timestamptz,
  add column if not exists voided_by uuid references public.users(id) on delete set null,
  add column if not exists void_reason text;

do $$
declare
  v_school_id uuid := 'b3409710-78ac-446d-b8f5-45c58d72a004';
  v_academic_year_id uuid := 'e6cbcc4f-4840-464e-9c3f-c8984d7a3813';
  v_cancelled_count integer;
begin
  update public.fee_invoices fi
  set status = 'cancelled',
      balance = 0,
      voided_at = coalesce(fi.voided_at, now()),
      void_reason = coalesce(
        nullif(fi.void_reason, ''),
        'Cancelled during student placement reconciliation: fee structure no longer matches current grade/section'
      ),
      updated_at = now()
  where fi.school_id = v_school_id
    and fi.academic_year_id = v_academic_year_id
    and fi.fee_structure_id is not null
    and coalesce(fi.paid_amount, 0) = 0
    and coalesce(fi.status, '') not in ('paid', 'settled', 'void', 'cancelled')
    and exists (
      select 1
      from public.students s
      join public.sections current_section
        on current_section.id = s.current_section_id
       and current_section.school_id = s.school_id
      join public.fee_structures fs
        on fs.id = fi.fee_structure_id
       and fs.school_id = fi.school_id
      where s.id = fi.student_id
        and s.school_id = fi.school_id
        and (
          fs.grade_id is distinct from current_section.grade_id
          or (
            fs.section_id is not null
            and fs.section_id is distinct from current_section.id
          )
        )
    );

  get diagnostics v_cancelled_count = row_count;
  raise notice 'Cancelled % stale unpaid fee invoices after student placement reconciliation', v_cancelled_count;
end
$$;
