-- Read-only migration contract. Run against a linked/staging database after
-- applying 20260815120000_backfill_legacy_homework_academic_year.sql.
do $$
declare
  missing_count bigint;
begin
  select count(*)
    into missing_count
  from public.frontend_records fr
  join public.sections sec
    on sec.id::text = nullif(fr.data->>'section_id', '')
   and sec.school_id = fr.school_id
  where fr.table_name = 'homework'
    and jsonb_typeof(fr.data) = 'object'
    and nullif(fr.data->>'academic_year_id', '') is null
    and sec.academic_year_id is not null;

  if missing_count <> 0 then
    raise exception 'homework rows with repairable academic years remain: %', missing_count;
  end if;
end;
$$;
