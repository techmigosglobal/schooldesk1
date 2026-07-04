-- Migration: Create notification tables for push notification support
-- Tables: notification_devices, notification_preferences, notification_subscriptions

-- notification_devices: Store FCM tokens for push notifications
create table if not exists public.notification_devices (
  id uuid default gen_random_uuid() primary key,
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  fcm_token text not null,
  device_type text default 'unknown'::text,
  is_active boolean default true,
  last_registered_at timestamp with time zone default now(),
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  unique(school_id, user_id, fcm_token)
);

create index if not exists idx_notification_devices_school on public.notification_devices(school_id);
create index if not exists idx_notification_devices_user on public.notification_devices(user_id);
create index if not exists idx_notification_devices_active on public.notification_devices(is_active);

-- notification_preferences: User notification preferences
create table if not exists public.notification_preferences (
  id uuid default gen_random_uuid() primary key,
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  enable_push boolean default true,
  enable_email boolean default true,
  enable_sms boolean default false,
  announcements boolean default true,
  attendance boolean default true,
  fees boolean default true,
  academics boolean default true,
  events boolean default true,
  messages boolean default true,
  emergency_alerts boolean default true,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  unique(school_id, user_id)
);

create index if not exists idx_notification_preferences_school on public.notification_preferences(school_id);
create index if not exists idx_notification_preferences_user on public.notification_preferences(user_id);

-- notification_subscriptions: Topic-based subscriptions
create table if not exists public.notification_subscriptions (
  id uuid default gen_random_uuid() primary key,
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  channel_id text not null,
  subscribed_at timestamp with time zone default now(),
  unique(school_id, user_id, channel_id)
);

create index if not exists idx_notification_subscriptions_school on public.notification_subscriptions(school_id);
create index if not exists idx_notification_subscriptions_user on public.notification_subscriptions(user_id);
create index if not exists idx_notification_subscriptions_channel on public.notification_subscriptions(channel_id);

-- Enable RLS
alter table public.notification_devices enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notification_subscriptions enable row level security;

-- RLS Policies: Users can only see their own notification settings
create policy "Users can see own notification devices" on public.notification_devices
  for select using (auth.uid() = user_id);

create policy "Users can manage own notification devices" on public.notification_devices
  for all using (auth.uid() = user_id);

create policy "Users can see own notification preferences" on public.notification_preferences
  for select using (auth.uid() = user_id);

create policy "Users can manage own notification preferences" on public.notification_preferences
  for all using (auth.uid() = user_id);

create policy "Users can see own notification subscriptions" on public.notification_subscriptions
  for select using (auth.uid() = user_id);

create policy "Users can manage own notification subscriptions" on public.notification_subscriptions
  for all using (auth.uid() = user_id);

-- Admin/Principal can see all notification devices for their school
create policy "Admins can see school notification devices" on public.notification_devices
  for select using (
    auth.uid() in (
      select id from public.users 
      where school_id = notification_devices.school_id 
      and role_name in ('admin', 'principal', 'super_admin')
    )
  );

-- Trigger to update updated_at timestamp
create or replace function update_notification_devices_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger notification_devices_updated_at before update
  on public.notification_devices for each row
  execute function update_notification_devices_updated_at();

create or replace function update_notification_preferences_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger notification_preferences_updated_at before update
  on public.notification_preferences for each row
  execute function update_notification_preferences_updated_at();
