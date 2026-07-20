-- Public buckets can serve known object URLs without granting a broad list/read
-- policy on storage.objects. The website API is the only gallery index.
drop policy if exists "public_site_media_read" on storage.objects;
