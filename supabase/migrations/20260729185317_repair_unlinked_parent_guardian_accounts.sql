-- Excel-era parent records can have a matching guardian but no parent/student
-- access link. Restore only an unambiguous same-school phone match. This never
-- alters accounts that already have a linked child and never guesses where one
-- parent phone maps to multiple students.
with candidates as (
  select
    u.id as parent_user_id,
    u.school_id,
    g.student_id
  from public.users u
  join public.guardians g
    on g.school_id = u.school_id
   and nullif(trim(u.phone), '') is not null
   and trim(g.phone) = trim(u.phone)
  where lower(coalesce(u.role_name, '')) = 'parent'
    and not exists (
      select 1
      from public.parent_student_links existing_link
      where existing_link.school_id = u.school_id
        and existing_link.parent_user_id = u.id
    )
), unambiguous as (
  select
    parent_user_id,
    school_id,
    min(student_id::text)::uuid as student_id
  from candidates
  group by parent_user_id, school_id
  having count(distinct student_id) = 1
)
insert into public.parent_student_links (school_id, parent_user_id, student_id)
select school_id, parent_user_id, student_id
from unambiguous
on conflict (parent_user_id, student_id) do nothing;
