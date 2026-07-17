update public.notification_logs
set route = '/approval-center-screen'
where target_role = 'principal'
  and entity_type in ('leave', 'student_leave')
  and coalesce(route, '') = '';

update public.notification_events
set event_data = event_data
  || jsonb_build_object(
    'route', '/approval-center-screen',
    'action', 'review',
    'reference_id', coalesce(event_data ->> 'reference_id', event_data ->> 'leave_id', '')
  )
where event_type in ('leave_submitted', 'student_leave_submitted')
  and coalesce(event_data ->> 'route', '') = '';
