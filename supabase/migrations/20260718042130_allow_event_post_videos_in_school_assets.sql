-- School-feed posts support photos and short videos. The Edge Function already
-- forwards the selected video's MIME type, but Storage rejects it unless the
-- bucket-level allow-list includes the relevant video types.
update storage.buckets
set allowed_mime_types = array[
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/svg+xml',
  'application/pdf',
  'text/csv',
  'video/mp4',
  'video/quicktime',
  'video/x-m4v',
  'video/webm'
]
where id = 'school-assets';
