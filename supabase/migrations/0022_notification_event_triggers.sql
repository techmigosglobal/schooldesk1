-- Migration: Create notification event triggers
-- Sets up database triggers to send push notifications for key events

-- Insert notification event log when a complaint is escalated to super admin
create or replace function on_complaint_escalated()
returns trigger as $$
declare
  v_principal_id uuid;
  v_super_admin_school_id uuid;
begin
  -- Get the school ID from the complaint
  select school_id into v_super_admin_school_id
  from public.schools
  where id = new.school_id
  limit 1;

  -- Get super admin user IDs for this school
  for v_principal_id in 
    select id 
    from public.users 
    where school_id = new.school_id 
    and role_name = 'super_admin'
  loop
    -- Insert notification event to be processed by edge function
    insert into public.notification_events (
      school_id,
      user_id,
      event_type,
      event_data,
      created_at
    ) values (
      new.school_id,
      v_principal_id,
      'complaint_escalated',
      jsonb_build_object(
        'complaint_id', new.id,
        'complaint_type', new.complaint_type,
        'submitted_by', new.submitted_by,
        'priority', coalesce(new.priority, 'normal'),
        'subject', new.subject,
        'description', new.description
      ),
      now()
    );
  end loop;

  return new;
end;
$$ language plpgsql;

-- Table to queue notification events
create table if not exists public.notification_events (
  id uuid default gen_random_uuid() primary key,
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  event_type text not null,
  event_data jsonb default '{}'::jsonb,
  processed boolean default false,
  sent_at timestamp with time zone,
  created_at timestamp with time zone default now()
);

create index if not exists idx_notification_events_school on public.notification_events(school_id);
create index if not exists idx_notification_events_user on public.notification_events(user_id);
create index if not exists idx_notification_events_processed on public.notification_events(processed);
create index if not exists idx_notification_events_created on public.notification_events(created_at);

-- Enable RLS
alter table public.notification_events enable row level security;

-- RLS Policies
create policy "Users can see own notification events" on public.notification_events
  for select using (auth.uid() = user_id);

create policy "Admins can see school notification events" on public.notification_events
  for select using (
    auth.uid() in (
      select id from public.users 
      where school_id = notification_events.school_id 
      and role_name in ('admin', 'principal', 'super_admin')
    )
  );

-- Service role can insert notification events
create policy "Service can manage notification events" on public.notification_events
  for all using (true);
