-- A student has one parent login association. A parent login may be shared by
-- any number of students, so the uniqueness key is student_id alone.
-- Keep the oldest link when repairing legacy many-to-many rows; this is
-- deterministic and preserves the first association already visible to staff.
with ranked_links as (
  select
    id,
    row_number() over (
      partition by student_id
      order by created_at asc, id asc
    ) as link_rank
  from public.parent_student_links
)
delete from public.parent_student_links links
using ranked_links ranked
where links.id = ranked.id
  and ranked.link_rank > 1;

create unique index if not exists uq_parent_student_links_student
  on public.parent_student_links (student_id);

comment on index public.uq_parent_student_links_student is
  'Each student has at most one parent login; one parent can have many students';
