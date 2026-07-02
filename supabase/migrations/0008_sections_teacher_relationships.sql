-- Let PostgREST/Supabase embed the class teacher and co-teacher rows
-- for Classes Hub detail views.
alter table public.sections
  add constraint sections_class_teacher_id_fkey
  foreign key (class_teacher_id)
  references public.staff(id)
  on delete set null
  not valid;

alter table public.sections
  add constraint sections_co_teacher_id_fkey
  foreign key (co_teacher_id)
  references public.staff(id)
  on delete set null
  not valid;
