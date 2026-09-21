-- These four service-only RPCs have recorded production calls in
-- pg_stat_statements. Preserve their signatures and query behavior while
-- fixing the SECURITY DEFINER search path and making object lookup explicit.

create or replace function public.authorize_schooldesk_request(
  p_user_id uuid,
  p_requested_school_id uuid,
  p_role_name text
)
returns table(profile_school_id uuid, is_active boolean, permitted boolean)
language sql
security definer
set search_path = ''
as $function$
  with profile as (
    select id, school_id, is_active
    from public.users
    where id = p_user_id
    limit 1
  ),
  super_admin_scope as (
    select
      home.organization_id as home_organization_id,
      requested.organization_id as requested_organization_id
    from profile
    left join public.schools home on home.id = profile.school_id
    left join public.schools requested on requested.id = p_requested_school_id
  )
  select
    profile.school_id as profile_school_id,
    profile.is_active,
    case
      when profile.id is null or profile.is_active is not true then false
      when p_requested_school_id is null then true
      when pg_catalog.lower(coalesce(p_role_name, '')) = 'super_admin' then exists (
        select 1
        from super_admin_scope scope
        where scope.home_organization_id is not null
          and scope.requested_organization_id is not null
          and scope.home_organization_id = scope.requested_organization_id
      )
      when pg_catalog.lower(coalesce(p_role_name, '')) = 'coordinator' then
        p_requested_school_id = profile.school_id and exists (
          select 1
          from public.branch_memberships membership
          where membership.user_id = p_user_id
            and membership.school_id = p_requested_school_id
            and membership.is_active = true
        )
      else exists (
        select 1
        from public.branch_memberships membership
        where membership.user_id = p_user_id
          and membership.school_id = p_requested_school_id
          and membership.is_active = true
      )
    end as permitted
  from profile;
$function$;

alter function public.authorize_schooldesk_request(uuid, uuid, text)
  owner to postgres;
revoke all on function public.authorize_schooldesk_request(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.authorize_schooldesk_request(uuid, uuid, text)
  to service_role;

create or replace function public.schooldesk_dashboard_summary(
  p_school_id uuid,
  p_today_start timestamp with time zone
)
returns jsonb
language sql
security definer
set search_path = ''
as $function$
  with active_students as (
    select current_section_id
    from public.students
    where school_id = p_school_id
      and is_test_account = false
      and pg_catalog.lower(coalesce(status, '')) = 'active'
  ),
  student_counts as (
    select
      pg_catalog.count(*) filter (where current_section_id is not null)::integer
        as active_assigned_students,
      pg_catalog.count(*) filter (where current_section_id is null)::integer
        as active_unassigned_students
    from active_students
  ),
  staff_counts as (
    select pg_catalog.count(*)::integer as total_staff
    from public.staff
    where school_id = p_school_id
  ),
  section_counts as (
    select pg_catalog.count(*)::integer as total_sections
    from public.sections
    where school_id = p_school_id
  ),
  fee_counts as (
    select
      coalesce(pg_catalog.sum(balance) filter (where status = 'pending'), 0)::numeric
        as pending_fee_balance,
      coalesce(pg_catalog.sum(paid_amount) filter (where status = 'paid'), 0)::numeric
        as total_paid
    from public.fee_invoices
    where school_id = p_school_id
      and status in ('pending', 'paid')
  ),
  leave_counts as (
    select pg_catalog.count(*)::integer as pending_leave_requests
    from public.leave_applications
    where school_id = p_school_id
      and status = 'pending'
  ),
  today_attendance_counts as (
    select
      pg_catalog.count(attendance.id)::integer as marked,
      pg_catalog.count(attendance.id) filter (where attendance.status = 'present')::integer
        as present
    from public.attendance_sessions session
    left join public.student_attendances attendance
      on attendance.session_id = session.id
    where session.school_id = p_school_id
      and session.date = p_today_start::date
  ),
  all_attendance_counts as (
    select pg_catalog.count(attendance.id)::integer as attendance_today
    from public.attendance_sessions session
    join public.student_attendances attendance
      on attendance.session_id = session.id
    where session.school_id = p_school_id
  ),
  payment_request_counts as (
    select pg_catalog.count(*)::integer as pending_fee_requests
    from public.parent_payment_requests
    where school_id = p_school_id
      and status = 'pending'
  ),
  approval_counts as (
    select pg_catalog.count(*)::integer as pending_approvals
    from public.approval_requests
    where school_id = p_school_id
      and status = 'pending'
  )
  select pg_catalog.jsonb_build_object(
    'total_students', coalesce(sc.active_assigned_students, 0),
    'active_unassigned_students', coalesce(sc.active_unassigned_students, 0),
    'total_staff', coalesce(st.total_staff, 0),
    'total_sections', coalesce(sec.total_sections, 0),
    'pending_fee_balance', coalesce(fee.pending_fee_balance, 0),
    'total_paid', coalesce(fee.total_paid, 0),
    'total_due', coalesce(fee.pending_fee_balance, 0),
    'pending_leave_requests', coalesce(leave.pending_leave_requests, 0),
    'today_marked', coalesce(today.marked, 0),
    'today_present', coalesce(today.present, 0),
    'attendance_today', coalesce(attendance.attendance_today, 0),
    'pending_fee_requests', coalesce(payments.pending_fee_requests, 0),
    'pending_approvals', coalesce(approvals.pending_approvals, 0)
  )
  from student_counts sc
  cross join staff_counts st
  cross join section_counts sec
  cross join fee_counts fee
  cross join leave_counts leave
  cross join today_attendance_counts today
  cross join all_attendance_counts attendance
  cross join payment_request_counts payments
  cross join approval_counts approvals;
$function$;

alter function public.schooldesk_dashboard_summary(uuid, timestamptz)
  owner to postgres;
revoke all on function public.schooldesk_dashboard_summary(uuid, timestamptz)
  from public, anon, authenticated;
grant execute on function public.schooldesk_dashboard_summary(uuid, timestamptz)
  to service_role;

create or replace function public.schooldesk_parent_fee_balances(
  p_school_id uuid,
  p_student_ids uuid[]
)
returns table(student_id uuid, balance numeric)
language sql
security definer
set search_path = ''
as $function$
  select
    invoice.student_id,
    coalesce(
      pg_catalog.sum(
        greatest(
          0,
          coalesce(
            invoice.balance,
            coalesce(invoice.net_amount, 0) - coalesce(invoice.paid_amount, 0)
          )
        )
      ),
      0
    ) as balance
  from public.fee_invoices invoice
  where invoice.school_id = p_school_id
    and invoice.student_id = any(p_student_ids)
    and pg_catalog.lower(coalesce(invoice.status, '')) not in ('cancelled', 'canceled', 'void')
  group by invoice.student_id;
$function$;

alter function public.schooldesk_parent_fee_balances(uuid, uuid[])
  owner to postgres;
revoke all on function public.schooldesk_parent_fee_balances(uuid, uuid[])
  from public, anon, authenticated;
grant execute on function public.schooldesk_parent_fee_balances(uuid, uuid[])
  to service_role;

create or replace function public.schooldesk_parent_homework_due(
  p_school_id uuid,
  p_student_ids uuid[]
)
returns table(student_id uuid, due_count integer)
language sql
security definer
set search_path = ''
as $function$
  with student_scope as (
    select id as student_id, current_section_id
    from public.students
    where school_id = p_school_id
      and id = any(p_student_ids)
      and pg_catalog.lower(coalesce(status, '')) = 'active'
  ),
  homework_rows as (
    select
      coalesce(
        nullif(data->>'homework_id', ''),
        nullif(data->>'id', ''),
        record_id::text,
        id::text
      ) as homework_key,
      coalesce(nullif(data->>'student_id', ''), '') as target_student_id,
      coalesce(nullif(data->>'section_id', ''), '') as target_section_id
    from public.frontend_records
    where school_id = p_school_id
      and table_name = 'homework'
  ),
  latest_submissions as (
    select distinct on (submission.homework_id::text, submission.student_id)
      submission.homework_id::text as homework_key,
      submission.student_id,
      pg_catalog.lower(coalesce(submission.status, '')) as status
    from public.homework_submissions submission
    where submission.school_id = p_school_id
      and submission.student_id = any(p_student_ids)
    order by submission.homework_id::text, submission.student_id,
      submission.updated_at desc nulls last,
      submission.created_at desc nulls last
  ),
  matched_homework as (
    select scope.student_id, homework.homework_key
    from student_scope scope
    join homework_rows homework
      on homework.target_student_id = scope.student_id::text
      or (
        homework.target_student_id = ''
        and homework.target_section_id <> ''
        and homework.target_section_id = scope.current_section_id::text
      )
    left join latest_submissions latest
      on latest.homework_key = homework.homework_key
      and latest.student_id = scope.student_id
    where coalesce(latest.status, '') not in ('submitted', 'reviewed')
  )
  select matched_homework.student_id, pg_catalog.count(*)::integer as due_count
  from matched_homework
  group by matched_homework.student_id;
$function$;

alter function public.schooldesk_parent_homework_due(uuid, uuid[])
  owner to postgres;
revoke all on function public.schooldesk_parent_homework_due(uuid, uuid[])
  from public, anon, authenticated;
grant execute on function public.schooldesk_parent_homework_due(uuid, uuid[])
  to service_role;
