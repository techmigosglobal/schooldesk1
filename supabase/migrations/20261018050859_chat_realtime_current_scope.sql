-- Realtime and direct PostgREST reads must honor the same current child/class
-- scope as the HTTP chat handler. Existing threads and messages stay intact.
-- Definer access lets these boolean checks read assignment/link rows without
-- inheriting unrelated table RLS. Identity, school and role remain JWT bound.
create or replace function public.chat_can_access_conversation(
  conversation public.message_conversations
) returns boolean
language sql stable security definer set search_path=public,pg_temp
as $$
  select coalesce(
    auth.uid() is not null and auth.role()='authenticated'
    and (
      conversation.school_id=public.auth_school_id()
      or (
        public.chat_user_role() in ('admin','principal','coordinator','super_admin')
        and exists (
          select 1 from public.branch_memberships membership
          where membership.user_id=auth.uid()
            and membership.school_id=conversation.school_id and membership.is_active
        )
      )
    )
    and (
      public.chat_user_role() in ('admin','principal','coordinator','super_admin')
      or (
        public.chat_user_role()='parent'
        and (conversation.parent_id=auth.uid()
          or coalesce(conversation.participant_ids,'[]'::jsonb) @> jsonb_build_array(auth.uid()))
        and exists (
          select 1 from public.parent_student_links link
          join public.students student on student.id=link.student_id and student.school_id=link.school_id
          where link.school_id=conversation.school_id and link.parent_user_id=auth.uid()
            and link.student_id=conversation.student_id
        )
      )
      or (
        public.chat_user_role()='teacher'
        and exists (
          select 1 from public.staff teacher
          where teacher.id::text=auth.jwt()->'app_metadata'->>'linked_id'
            and teacher.school_id=conversation.school_id and teacher.is_active
            and (conversation.teacher_id=teacher.id
              or coalesce(conversation.participant_ids,'[]'::jsonb) @> jsonb_build_array(teacher.id)
              or coalesce(conversation.participant_ids,'[]'::jsonb) @> jsonb_build_array(auth.uid()))
            and (
              conversation.student_id is null
              or exists (
                select 1 from public.students student
                join public.sections section on section.id=student.current_section_id
                  and section.school_id=student.school_id
                where student.id=conversation.student_id and student.school_id=conversation.school_id
                  and (
                    section.class_teacher_id=teacher.id or section.co_teacher_id=teacher.id
                    or exists (
                      select 1 from public.staff_subjects assignment
                      where assignment.school_id=conversation.school_id and assignment.staff_id=teacher.id
                        and assignment.subject_id is not null
                        and (assignment.academic_year_id is null or assignment.academic_year_id=section.academic_year_id)
                        and (assignment.section_id=section.id
                          or assignment.section_id is null and assignment.grade_id=section.grade_id)
                    )
                  )
              )
            )
        )
      )
    ), false
  );
$$;
revoke all on function public.chat_can_access_conversation(public.message_conversations) from public,anon;
grant execute on function public.chat_can_access_conversation(public.message_conversations) to authenticated,service_role;
