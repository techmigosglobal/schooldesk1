-- Preserve how staff attendance was recorded and who initiated the scan.
alter table public.staff_attendances
  add column if not exists source text not null default 'manual',
  add column if not exists marked_by uuid references public.users(id) on delete set null;

create index if not exists idx_staff_attendances_staff_date
  on public.staff_attendances(staff_id, date);
