-- Targeted performance and security hardening.
-- Keep this list intentionally focused on relationships used by the fee,
-- people, leave, messaging, and parent-communication read paths.

create index if not exists idx_fee_installments_fee_structure_id
  on public.fee_installments (fee_structure_id);
create index if not exists idx_fee_installments_academic_year_id
  on public.fee_installments (academic_year_id);
create index if not exists idx_fee_installments_school_id
  on public.fee_installments (school_id);
create index if not exists idx_fee_installments_grade_id
  on public.fee_installments (grade_id);
create index if not exists idx_fee_installments_section_id
  on public.fee_installments (section_id);

create index if not exists idx_guardians_school_id
  on public.guardians (school_id);
create index if not exists idx_guardians_student_id
  on public.guardians (student_id);

create index if not exists idx_parent_payment_requests_student_id
  on public.parent_payment_requests (student_id);
create index if not exists idx_parent_payment_requests_invoice_id
  on public.parent_payment_requests (invoice_id);
create index if not exists idx_parent_payment_requests_payment_id
  on public.parent_payment_requests (payment_id);

create index if not exists idx_parent_teacher_meetings_student_id
  on public.parent_teacher_meetings (student_id);
create index if not exists idx_parent_teacher_meetings_teacher_id
  on public.parent_teacher_meetings (teacher_id);
create index if not exists idx_parent_teacher_meetings_section_id
  on public.parent_teacher_meetings (section_id);

create index if not exists idx_leave_applications_staff_id
  on public.leave_applications (staff_id);
create index if not exists idx_leave_applications_leave_type_id
  on public.leave_applications (leave_type_id);

create index if not exists idx_messages_sender_id
  on public.messages (sender_id);
create index if not exists idx_messages_school_id
  on public.messages (school_id);

-- Avoid public-role policy overlap. Browser users retain the same effective
-- access, while service_role continues to bypass RLS for Edge Functions.
drop policy if exists "Anyone can read help content" on public.help_contents;
drop policy if exists "Super admins can manage help content" on public.help_contents;
drop policy if exists "Super admins can insert help content" on public.help_contents;
drop policy if exists "Super admins can update help content" on public.help_contents;
drop policy if exists "Super admins can delete help content" on public.help_contents;
create policy "Anyone can read help content" on public.help_contents
  for select to anon, authenticated
  using (true);
create policy "Super admins can insert help content" on public.help_contents
  for insert to authenticated
  with check (
    exists (
      select 1 from public.users
      where id = (select auth.uid())
        and role_name = 'super_admin'
    )
  );
create policy "Super admins can update help content" on public.help_contents
  for update to authenticated
  using (
    exists (
      select 1 from public.users
      where id = (select auth.uid())
        and role_name = 'super_admin'
    )
  )
  with check (
    exists (
      select 1 from public.users
      where id = (select auth.uid())
        and role_name = 'super_admin'
    )
  );
create policy "Super admins can delete help content" on public.help_contents
  for delete to authenticated
  using (
    exists (
      select 1 from public.users
      where id = (select auth.uid())
        and role_name = 'super_admin'
    )
  );

drop policy if exists "Admins can see school notification devices" on public.notification_devices;
drop policy if exists "Users can see own notification devices" on public.notification_devices;
drop policy if exists "Users can manage own notification devices" on public.notification_devices;
drop policy if exists "Users and admins can see notification devices" on public.notification_devices;
drop policy if exists "Users can insert own notification devices" on public.notification_devices;
drop policy if exists "Users can update own notification devices" on public.notification_devices;
drop policy if exists "Users can delete own notification devices" on public.notification_devices;
create policy "Users and admins can see notification devices"
  on public.notification_devices
  for select to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.users u
      where u.id = (select auth.uid())
        and u.school_id = notification_devices.school_id
        and u.role_name in ('admin', 'principal', 'super_admin')
    )
  );
create policy "Users can insert own notification devices"
  on public.notification_devices
  for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update own notification devices"
  on public.notification_devices
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete own notification devices"
  on public.notification_devices
  for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Admins can see school notification events" on public.notification_events;
drop policy if exists "Users can see own notification events" on public.notification_events;
drop policy if exists "Users and admins can see notification events" on public.notification_events;
create policy "Users and admins can see notification events"
  on public.notification_events
  for select to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.users u
      where u.id = (select auth.uid())
        and u.school_id = notification_events.school_id
        and u.role_name in ('admin', 'principal', 'super_admin')
    )
  );

-- These operational tables are intentionally Edge-Function/service-role
-- owned. Explicit browser-deny policies document that boundary and remove
-- the advisor ambiguity without granting any client access.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'admission_inquiries',
    'daycare_fee_plans',
    'demo_accounts',
    'error_event_daily_summaries',
    'error_event_retention_settings',
    'fee_reminder_deliveries',
    'finance_document_snapshots',
    'issue_attachments',
    'issues',
    'organizations',
    'school_finance_settings',
    'school_website_entries',
    'school_website_sections'
  ] loop
    execute format(
      'drop policy if exists %I on public.%I',
      table_name || '_browser_deny',
      table_name
    );
    execute format(
      'create policy %I on public.%I for all to anon, authenticated using (false) with check (false)',
      table_name || '_browser_deny',
      table_name
    );
  end loop;
end;
$$;

-- Lock down SECURITY DEFINER wrappers to their actual callers. The API
-- monitoring handler uses service_role; can_access_branch is used by an
-- authenticated database/RLS path. The branch sync functions are triggers.
revoke execute on function public.can_access_branch(uuid)
  from public, anon, authenticated;
grant execute on function public.can_access_branch(uuid) to authenticated;

revoke execute on function public.record_error_event(uuid, uuid, text, text, text, jsonb, text, text)
  from public, anon, authenticated;
grant execute on function public.record_error_event(uuid, uuid, text, text, text, jsonb, text, text)
  to service_role;
revoke execute on function public.error_event_retention_metrics(uuid)
  from public, anon, authenticated;
grant execute on function public.error_event_retention_metrics(uuid) to service_role;
revoke execute on function public.cleanup_resolved_error_events(uuid, timestamptz, text, boolean)
  from public, anon, authenticated;
grant execute on function public.cleanup_resolved_error_events(uuid, timestamptz, text, boolean)
  to service_role;

revoke execute on function public.sync_branch_principals()
  from public, anon, authenticated, service_role;
revoke execute on function public.sync_principal_branch_memberships()
  from public, anon, authenticated, service_role;

-- Set a deterministic search path on all flagged mutable-path functions.
alter function public.set_updated_at() set search_path = public, pg_temp;
alter function public.update_notification_devices_updated_at()
  set search_path = public, pg_temp;
alter function public.update_notification_preferences_updated_at()
  set search_path = public, pg_temp;
alter function public.on_complaint_escalated()
  set search_path = public, pg_temp;
alter function public.mark_conversation_read(uuid, uuid, text)
  set search_path = public, pg_temp;
alter function public.enforce_lowercase_role_name()
  set search_path = public, pg_temp;
alter function public.chat_user_role()
  set search_path = public, pg_temp;
alter function public.chat_can_access_conversation(message_conversations)
  set search_path = public, pg_temp;

-- pg_trgm is used by the database search operators/index definitions, but it
-- does not need to be exposed from public. Supabase's conventional extensions
-- schema keeps extension objects out of the API schema.
create schema if not exists extensions;
alter extension pg_trgm set schema extensions;
