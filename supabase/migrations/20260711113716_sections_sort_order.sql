alter table public.sections add column if not exists sort_order integer;

with ranked as (
  select id, row_number() over (
    partition by school_id, academic_year_id
    order by created_at asc, id asc
  ) as position
  from public.sections
)
update public.sections section_row
set sort_order = ranked.position
from ranked
where section_row.id = ranked.id and section_row.sort_order is null;

alter table public.sections alter column sort_order set default 9999;
create index if not exists idx_sections_school_year_sort
  on public.sections (school_id, academic_year_id, sort_order, created_at);
