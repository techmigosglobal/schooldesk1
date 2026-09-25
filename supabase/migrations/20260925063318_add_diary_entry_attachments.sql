alter table public.diary_entries
  add column if not exists attachments jsonb not null default '[]'::jsonb;

alter table public.diary_entries
  add constraint diary_entries_attachments_array_check
  check (jsonb_typeof(attachments) = 'array');
