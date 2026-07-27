-- A short, school-scoped public notice controlled by leadership.
alter table public.school_website_content
  add column if not exists breaking_news_text text not null default '',
  add column if not exists breaking_news_enabled boolean not null default false;
