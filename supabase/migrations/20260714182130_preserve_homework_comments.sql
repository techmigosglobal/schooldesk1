-- Keep the parent's submitted comment separate from teacher feedback.
-- `remarks` remains for compatibility with legacy clients and old records.
alter table public.homework_submissions
  add column if not exists parent_comment text,
  add column if not exists teacher_feedback text;

-- Best-effort historical repair: submitted rows' remarks are parent comments,
-- while reviewed rows' remarks were overwritten by teacher feedback.
update public.homework_submissions
set parent_comment = remarks
where parent_comment is null
  and status = 'submitted'
  and coalesce(remarks, '') <> '';

update public.homework_submissions
set teacher_feedback = remarks
where teacher_feedback is null
  and status in ('reviewed', 'needs_revision')
  and coalesce(remarks, '') <> '';
