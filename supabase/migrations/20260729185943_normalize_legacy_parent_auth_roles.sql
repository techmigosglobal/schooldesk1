-- Legacy CSV imports stored the parent Auth claim as `Parent`, while the API
-- and route policies use canonical lowercase roles. Normalize only existing
-- parent claims, preserving every other Auth metadata field and all accounts.
update auth.users au
set
  raw_app_meta_data = jsonb_set(
    coalesce(au.raw_app_meta_data, '{}'::jsonb),
    '{role_name}',
    '"parent"'::jsonb,
    true
  ),
  updated_at = now()
from public.users u
where u.id = au.id
  and lower(coalesce(u.role_name, '')) = 'parent'
  and lower(coalesce(au.raw_app_meta_data ->> 'role_name', '')) = 'parent'
  and coalesce(au.raw_app_meta_data ->> 'role_name', '') <> 'parent';
