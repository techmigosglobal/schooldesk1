-- Private operational files are accessed through SchoolDesk API handlers.
-- Document handlers must authorize the relevant record before returning a
-- short-lived signed URL; clients must not access this bucket directly. API
-- writes use the service role. With no authenticated Storage policies,
-- Supabase RLS denies direct access while preserving service-role operations.

drop policy if exists "school_private_files_authenticated_read" on storage.objects;
drop policy if exists "school_private_files_authenticated_insert" on storage.objects;
drop policy if exists "school_private_files_authenticated_update" on storage.objects;
drop policy if exists "school_private_files_authenticated_delete" on storage.objects;
