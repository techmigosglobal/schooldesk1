-- Keep notification delivery durable across overlapping workers and crashes.
-- `processed` remains for compatibility with existing producers and queries;
-- processing_state is the authoritative delivery state for new workers.

alter table public.notification_events
  add column if not exists processing_state text not null default 'pending',
  add column if not exists processing_started_at timestamptz,
  add column if not exists processing_lease_until timestamptz,
  add column if not exists delivery_status text,
  add column if not exists delivery_result jsonb;

alter table public.notification_events
  drop constraint if exists notification_events_processing_state_check,
  add constraint notification_events_processing_state_check
    check (processing_state in ('pending', 'processing', 'completed', 'deferred', 'dead_letter'));

-- Existing processed rows are historical completions. New and retryable rows
-- remain pending; this is idempotent for local resets and hosted promotion.
update public.notification_events
set processing_state = case
  when processed = true and coalesce(event_data ->> '_push_deferred_no_device', '') = 'true'
    then 'deferred'
  when processed = true and coalesce(event_data ->> '_push_dead_letter', '') = 'true'
    then 'dead_letter'
  when processed = true then 'completed'
  else 'pending'
end
where processing_state is null or processing_state = 'pending';

create index if not exists idx_notification_events_processing_queue
  on public.notification_events(processing_state, processing_lease_until, retry_count, created_at);

notify pgrst, 'reload schema';
