-- Restore student photo references whose Storage objects survived a previous
-- student Sheets sync. This is intentionally idempotent and only fills empty
-- photo_url fields; it never removes Storage objects or overwrites a reference.
with ranked_objects as (
  select
    s.id as student_id,
    o.name,
    row_number() over (
      partition by s.id
      order by o.created_at desc, o.name desc
    ) as row_number
  from public.students s
  join storage.objects o
    on o.bucket_id = 'school-assets'
   and split_part(o.name, '/', 1) = 'students'
   and split_part(o.name, '/', 3) = s.id::text
   and coalesce(o.metadata ->> 'mimetype', '') like 'image/%'
  where nullif(trim(s.photo_url), '') is null
),
storage_origin as (
  select split_part(photo_url, '/storage/v1/object/public/', 1) as origin
  from public.students
  where position('/storage/v1/object/public/' in photo_url) > 0
  limit 1
),
repair_candidates as (
  select
    ranked_objects.student_id,
    coalesce(
      (select origin from storage_origin),
      'https://ouvwogguttybmpgfgctc.supabase.co'
    ) || '/storage/v1/object/public/school-assets/' || ranked_objects.name as photo_url
  from ranked_objects
  where ranked_objects.row_number = 1
)
update public.students s
set photo_url = repair_candidates.photo_url,
    updated_at = now()
from repair_candidates
where s.id = repair_candidates.student_id
  and nullif(trim(s.photo_url), '') is null;
