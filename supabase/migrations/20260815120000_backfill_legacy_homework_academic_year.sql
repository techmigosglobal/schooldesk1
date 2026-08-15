-- Legacy homework imports predate academic_year_id. Keep every record and
-- payload intact while filling only the missing value from its section.
update public.frontend_records as fr
set data = jsonb_set(
  fr.data,
  '{academic_year_id}',
  to_jsonb(sec.academic_year_id::text),
  true
)
from public.sections as sec
where fr.table_name = 'homework'
  and jsonb_typeof(fr.data) = 'object'
  and nullif(fr.data->>'academic_year_id', '') is null
  and nullif(fr.data->>'section_id', '') = sec.id::text
  and sec.academic_year_id is not null;
