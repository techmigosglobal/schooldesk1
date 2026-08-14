-- Align Arishville public branch receipt tokens with the requested receipt
-- format, e.g. AVP/26-27/MIY/AUG/001. Stored legacy receipt_number values
-- remain immutable; only the public display alias is corrected.

with target_schools as (
  select
    id,
    name,
    branch_code as old_branch_code,
    case
      when lower(name) like '%miyapur%' then 'MIY'
      when lower(name) like '%madhapur%' then 'MAD'
      else upper(regexp_replace(coalesce(nullif(trim(branch_code), ''), 'MAIN'), '[^A-Za-z0-9]+', '', 'g'))
    end as new_branch_code
  from public.schools
  where lower(name) like '%arish%ville%'
),
updated_schools as (
  update public.schools s
  set branch_code = t.new_branch_code,
      updated_at = now()
  from target_schools t
  where s.id = t.id
    and coalesce(s.branch_code, '') is distinct from t.new_branch_code
  returning s.id, s.name, t.old_branch_code, s.branch_code as new_branch_code
)
insert into public.audit_logs (
  school_id, action, entity_type, entity_id, details
)
select
  id,
  'school_public_branch_code_aligned',
  'schools',
  id::text,
  jsonb_build_object(
    'school_name', name,
    'old_branch_code', old_branch_code,
    'new_branch_code', new_branch_code,
    'reason', 'receipt_public_number_format'
  )
from updated_schools;

with numbered_receipts as (
  select
    r.id,
    r.school_id,
    r.receipt_number,
    r.display_receipt_number as previous_display_receipt_number,
    coalesce(nullif(trim(fs.receipt_prefix), ''), 'RCP') as receipt_prefix,
    coalesce(nullif(trim(s.branch_code), ''), 'MAIN') as branch_code,
    coalesce(p.paid_at, r.issued_at, now()) as paid_at,
    coalesce(
      case
        when ay.start_date is not null and ay.end_date is not null
          then to_char(ay.start_date, 'YY') || '-' || to_char(ay.end_date, 'YY')
      end,
      to_char(coalesce(p.paid_at, r.issued_at, now()), 'YY') || '-' ||
        to_char(coalesce(p.paid_at, r.issued_at, now()) + interval '1 year', 'YY')
    ) as fiscal_year,
    row_number() over (
      partition by r.school_id,
        coalesce(
          case
            when ay.start_date is not null and ay.end_date is not null
              then to_char(ay.start_date, 'YY') || '-' || to_char(ay.end_date, 'YY')
          end,
          to_char(coalesce(p.paid_at, r.issued_at, now()), 'YY') || '-' ||
            to_char(coalesce(p.paid_at, r.issued_at, now()) + interval '1 year', 'YY')
        )
      order by r.issued_at, r.id
    ) as receipt_sequence
  from public.fee_receipts r
  join public.schools s on s.id = r.school_id
  left join public.school_finance_settings fs on fs.school_id = r.school_id
  left join public.payments p on p.id = r.payment_id and p.school_id = r.school_id
  left join public.fee_invoices fi on fi.id = r.invoice_id and fi.school_id = r.school_id
  left join public.academic_years ay on ay.id = fi.academic_year_id and ay.school_id = r.school_id
  where lower(s.name) like '%arish%ville%'
),
formatted_receipts as (
  select
    id,
    school_id,
    receipt_number,
    previous_display_receipt_number,
    upper(regexp_replace(receipt_prefix, '[^A-Za-z0-9]+', '', 'g')) || '/' ||
      fiscal_year || '/' ||
      upper(regexp_replace(branch_code, '[^A-Za-z0-9]+', '', 'g')) || '/' ||
      upper(trim(to_char(paid_at, 'MON'))) || '/' ||
      lpad(receipt_sequence::text, 3, '0') as display_receipt_number
  from numbered_receipts
),
updated_receipts as (
  update public.fee_receipts r
  set display_receipt_number = f.display_receipt_number
  from formatted_receipts f
  where r.id = f.id
    and coalesce(r.display_receipt_number, '') is distinct from f.display_receipt_number
  returning
    r.id,
    r.school_id,
    f.receipt_number,
    f.previous_display_receipt_number,
    r.display_receipt_number
)
insert into public.audit_logs (
  school_id, action, entity_type, entity_id, details
)
select
  school_id,
  'fee_receipt_display_number_corrected',
  'fee_receipts',
  id::text,
  jsonb_build_object(
    'legacy_receipt_number', receipt_number,
    'previous_display_receipt_number', previous_display_receipt_number,
    'display_receipt_number', display_receipt_number,
    'reason', 'arishville_public_branch_code_alignment'
  )
from updated_receipts;
