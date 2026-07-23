-- Parents can only modify or remove the health reminders they created.
-- The API duplicates these checks because it uses the service client.

drop policy if exists "health_reminders_parent_update" on public.health_reminders;
create policy "health_reminders_parent_update" on public.health_reminders
  for update to authenticated
  using (
    school_id = public.auth_school_id()
    and created_by_parent_user_id = auth.uid()
  )
  with check (
    school_id = public.auth_school_id()
    and created_by_parent_user_id = auth.uid()
  );

drop policy if exists "health_reminders_parent_delete" on public.health_reminders;
create policy "health_reminders_parent_delete" on public.health_reminders
  for delete to authenticated
  using (
    school_id = public.auth_school_id()
    and created_by_parent_user_id = auth.uid()
  );
