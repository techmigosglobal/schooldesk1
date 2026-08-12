-- Leave data contains private staff and student records. The original
-- school-wide policies let every authenticated user in a school read and write
-- every row, even though the Edge Function correctly applies ownership checks.
-- Replace those permissive policies with the same role/ownership boundaries at
-- the database layer so the Data API remains safe as a second line of defense.

create index if not exists idx_users_school_linked
  on public.users (school_id, linked_id)
  where linked_id is not null;

create index if not exists idx_leave_balances_school_staff
  on public.leave_balances (school_id, staff_id);

create index if not exists idx_leave_applications_school_staff
  on public.leave_applications (school_id, staff_id);

create index if not exists idx_student_leave_applications_school_student
  on public.student_leave_applications (school_id, student_id);

create index if not exists idx_parent_student_links_scope
  on public.parent_student_links (school_id, parent_user_id, student_id);

-- Leave types are shared configuration, but only school leadership may change
-- them directly.
drop policy if exists "leave_types_school_select" on public.leave_types;
drop policy if exists "leave_types_school_insert" on public.leave_types;
drop policy if exists "leave_types_school_update" on public.leave_types;
drop policy if exists "leave_types_school_delete" on public.leave_types;

create policy "leave_types_scoped_select"
  on public.leave_types for select to authenticated
  using (
    (select auth.uid()) is not null
    and school_id = (select public.auth_school_id())
  );

create policy "leave_types_leadership_insert"
  on public.leave_types for insert to authenticated
  with check (
    school_id = (select public.auth_school_id())
    and lower(coalesce((select public.auth_role_name()), ''))
      in ('principal', 'coordinator', 'admin', 'super_admin')
  );

create policy "leave_types_leadership_update"
  on public.leave_types for update to authenticated
  using (
    school_id = (select public.auth_school_id())
    and lower(coalesce((select public.auth_role_name()), ''))
      in ('principal', 'coordinator', 'admin', 'super_admin')
  )
  with check (
    school_id = (select public.auth_school_id())
    and lower(coalesce((select public.auth_role_name()), ''))
      in ('principal', 'coordinator', 'admin', 'super_admin')
  );

create policy "leave_types_leadership_delete"
  on public.leave_types for delete to authenticated
  using (
    school_id = (select public.auth_school_id())
    and lower(coalesce((select public.auth_role_name()), ''))
      in ('principal', 'coordinator', 'admin', 'super_admin')
  );

-- Staff leave balances: teachers see only the staff record linked to their
-- authenticated user. Leadership retains school-wide review access.
drop policy if exists "leave_balances_school_select" on public.leave_balances;
drop policy if exists "leave_balances_school_insert" on public.leave_balances;
drop policy if exists "leave_balances_school_update" on public.leave_balances;
drop policy if exists "leave_balances_school_delete" on public.leave_balances;

create policy "leave_balances_owner_or_leadership_select"
  on public.leave_balances for select to authenticated
  using (
    school_id = (select public.auth_school_id())
    and (
      lower(coalesce((select public.auth_role_name()), ''))
        in ('principal', 'coordinator', 'admin', 'super_admin')
      or (
        lower(coalesce((select public.auth_role_name()), '')) = 'teacher'
        and exists (
          select 1
          from public.users account
          where account.id = (select auth.uid())
            and account.school_id = leave_balances.school_id
            and account.linked_id = leave_balances.staff_id
            and lower(coalesce(account.role_name, '')) = 'teacher'
        )
      )
    )
  );

create policy "leave_balances_leadership_insert"
  on public.leave_balances for insert to authenticated
  with check (
    school_id = (select public.auth_school_id())
    and lower(coalesce((select public.auth_role_name()), ''))
      in ('principal', 'coordinator', 'admin', 'super_admin')
  );

create policy "leave_balances_leadership_update"
  on public.leave_balances for update to authenticated
  using (
    school_id = (select public.auth_school_id())
    and lower(coalesce((select public.auth_role_name()), ''))
      in ('principal', 'coordinator', 'admin', 'super_admin')
  )
  with check (
    school_id = (select public.auth_school_id())
    and lower(coalesce((select public.auth_role_name()), ''))
      in ('principal', 'coordinator', 'admin', 'super_admin')
  );

create policy "leave_balances_leadership_delete"
  on public.leave_balances for delete to authenticated
  using (
    school_id = (select public.auth_school_id())
    and lower(coalesce((select public.auth_role_name()), ''))
      in ('principal', 'coordinator', 'admin', 'super_admin')
  );

-- Staff leave applications: teachers can read and submit only their own
-- pending requests. Approval, rejection, recall, and administrative mutations
-- continue through the authenticated Edge Function or leadership access.
drop policy if exists "leave_applications_school_select"
  on public.leave_applications;
drop policy if exists "leave_applications_school_insert"
  on public.leave_applications;
drop policy if exists "leave_applications_school_update"
  on public.leave_applications;
drop policy if exists "leave_applications_school_delete"
  on public.leave_applications;

create policy "leave_applications_owner_or_leadership_select"
  on public.leave_applications for select to authenticated
  using (
    school_id = (select public.auth_school_id())
    and (
      lower(coalesce((select public.auth_role_name()), ''))
        in ('principal', 'coordinator', 'admin', 'super_admin')
      or (
        lower(coalesce((select public.auth_role_name()), '')) = 'teacher'
        and exists (
          select 1
          from public.users account
          where account.id = (select auth.uid())
            and account.school_id = leave_applications.school_id
            and account.linked_id = leave_applications.staff_id
            and lower(coalesce(account.role_name, '')) = 'teacher'
        )
      )
    )
  );

create policy "leave_applications_owner_or_leadership_insert"
  on public.leave_applications for insert to authenticated
  with check (
    school_id = (select public.auth_school_id())
    and (
      lower(coalesce((select public.auth_role_name()), ''))
        in ('principal', 'coordinator', 'admin', 'super_admin')
      or (
        lower(coalesce((select public.auth_role_name()), '')) = 'teacher'
        and lower(coalesce(status, 'pending')) = 'pending'
        and reviewed_by is null
        and exists (
          select 1
          from public.users account
          where account.id = (select auth.uid())
            and account.school_id = leave_applications.school_id
            and account.linked_id = leave_applications.staff_id
            and lower(coalesce(account.role_name, '')) = 'teacher'
        )
      )
    )
  );

create policy "leave_applications_leadership_update"
  on public.leave_applications for update to authenticated
  using (
    school_id = (select public.auth_school_id())
    and lower(coalesce((select public.auth_role_name()), ''))
      in ('principal', 'coordinator', 'admin', 'super_admin')
  )
  with check (
    school_id = (select public.auth_school_id())
    and lower(coalesce((select public.auth_role_name()), ''))
      in ('principal', 'coordinator', 'admin', 'super_admin')
  );

create policy "leave_applications_leadership_delete"
  on public.leave_applications for delete to authenticated
  using (
    school_id = (select public.auth_school_id())
    and lower(coalesce((select public.auth_role_name()), ''))
      in ('principal', 'coordinator', 'admin', 'super_admin')
  );

-- Student leave applications: a parent may see and submit only for a linked
-- child. Leadership can review all requests in the current school.
drop policy if exists "student_leave_applications_school_select"
  on public.student_leave_applications;
drop policy if exists "student_leave_applications_school_insert"
  on public.student_leave_applications;
drop policy if exists "student_leave_applications_school_update"
  on public.student_leave_applications;
drop policy if exists "student_leave_applications_school_delete"
  on public.student_leave_applications;

create policy "student_leave_parent_or_leadership_select"
  on public.student_leave_applications for select to authenticated
  using (
    school_id = (select public.auth_school_id())
    and (
      lower(coalesce((select public.auth_role_name()), ''))
        in ('principal', 'coordinator', 'admin', 'super_admin')
      or (
        lower(coalesce((select public.auth_role_name()), '')) = 'parent'
        and exists (
          select 1
          from public.parent_student_links link
          where link.school_id = student_leave_applications.school_id
            and link.parent_user_id = (select auth.uid())
            and link.student_id = student_leave_applications.student_id
        )
      )
    )
  );

create policy "student_leave_parent_or_leadership_insert"
  on public.student_leave_applications for insert to authenticated
  with check (
    school_id = (select public.auth_school_id())
    and (
      lower(coalesce((select public.auth_role_name()), ''))
        in ('principal', 'coordinator', 'admin', 'super_admin')
      or (
        lower(coalesce((select public.auth_role_name()), '')) = 'parent'
        and lower(coalesce(status, 'pending')) = 'pending'
        and reviewed_by is null
        and exists (
          select 1
          from public.parent_student_links link
          where link.school_id = student_leave_applications.school_id
            and link.parent_user_id = (select auth.uid())
            and link.student_id = student_leave_applications.student_id
        )
      )
    )
  );

create policy "student_leave_leadership_update"
  on public.student_leave_applications for update to authenticated
  using (
    school_id = (select public.auth_school_id())
    and lower(coalesce((select public.auth_role_name()), ''))
      in ('principal', 'coordinator', 'admin', 'super_admin')
  )
  with check (
    school_id = (select public.auth_school_id())
    and lower(coalesce((select public.auth_role_name()), ''))
      in ('principal', 'coordinator', 'admin', 'super_admin')
  );

create policy "student_leave_leadership_delete"
  on public.student_leave_applications for delete to authenticated
  using (
    school_id = (select public.auth_school_id())
    and lower(coalesce((select public.auth_role_name()), ''))
      in ('principal', 'coordinator', 'admin', 'super_admin')
  );
