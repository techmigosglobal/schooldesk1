-- Align principal timetable manual editing with the Supabase runtime contract.
-- A slot can now be teaching, break, or free; break/free slots may omit subject_id.

alter table public.timetable_slots
  add column if not exists slot_type text not null default 'regular';

update public.timetable_slots
set slot_type = 'regular'
where slot_type is null or trim(slot_type) = '';

alter table public.timetable_slots
  drop constraint if exists timetable_slots_slot_type_check;

alter table public.timetable_slots
  add constraint timetable_slots_slot_type_check
  check (slot_type in ('regular', 'teaching', 'break', 'free'));

create index if not exists idx_timetable_slots_type
  on public.timetable_slots(school_id, section_id, day_of_week, slot_type);
