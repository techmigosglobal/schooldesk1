-- Fix super_admin users whose role_name was incorrectly stored.
-- Ensures any user with role_name='super_admin' in auth.users app_metadata
-- also has role_name='super_admin' in public.users.
update public.users u
set role_name = 'super_admin'
from auth.users au
where u.id = au.id
  and au.raw_app_meta_data->>'role_name' = 'super_admin'
  and u.role_name != 'super_admin';
