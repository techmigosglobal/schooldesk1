# SchoolDesk self-hosted Supabase restore

Target: Supabase Docker stack deployed through Bluehost Coolify.

SchoolDesk keeps PostgreSQL, Supabase Auth, RLS, audit, Realtime, and FCM in
Supabase. School post media uses Cloudflare R2. Supabase Storage objects are
not part of this migration target.

## 1. Create platform dump

Run from repository root. Use a protected shell variable. Do not put database
password in repository files, Coolify build arguments, or command history.

```sh
export SUPABASE_PLATFORM_DB_URL='postgres://...'
scripts/prepare_platform_restore.sh
```

Script uses pinned Supabase CLI `2.116.0` and produces local, ignored files:

```text
.local/platform-restore/roles.sql
.local/platform-restore/schema.sql
.local/platform-restore/data.sql
```

The connection string must be percent-encoded. Use Supabase Dashboard Connect
with session pooler or direct connection. CLI runs `pg_dump` in Docker and
filters Supabase internal schemas.

## 2. Deploy fresh self-hosted Supabase in Coolify

Use Supabase self-hosted Docker release. Do not deploy this repository's
`supabase/config.toml` as production Compose configuration; that file targets
Docker-local project `schooldesk-local`.

Configure Coolify secrets before first start:

- `SUPABASE_PUBLIC_URL`, `API_EXTERNAL_URL`, `SITE_URL`
- `POSTGRES_PASSWORD`, `DASHBOARD_PASSWORD`
- generated self-hosted JWT/API secrets and encryption keys
- SMTP settings
- OAuth provider settings and redirect URLs, if used
- Edge API `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY`,
  `SUPABASE_DB_URL`
- R2 settings listed below

Expose only HTTPS gateway URL. Do not expose Postgres publicly after restore;
use Coolify private network or temporary restricted access for `psql`.

Recommended minimum: 4 GB RAM, 2 CPU cores, 40 GB SSD. Use Postgres 17
compatible self-hosted release because current SchoolDesk migrations and
managed project target Postgres 17.

## 3. Restore database

Copy dump files to a protected operator machine or temporary private volume.
Restore into a fresh database only:

```sh
psql \
  --single-transaction \
  --variable ON_ERROR_STOP=1 \
  --file roles.sql \
  --file schema.sql \
  --command 'SET session_replication_role = replica' \
  --file data.sql \
  --dbname "$SELF_HOSTED_POSTGRES_URL"
```

Do not run restore against an existing production database. Take a database
backup before any retry. Existing platform JWTs stop working because
self-hosted JWT secrets differ. Users must authenticate again.

## 4. Configure R2 for School post media

Set these as Edge Function secrets. Never expose them to Flutter or browser:

```text
R2_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
R2_PRIVATE_BUCKET=schooldesk-private-files
R2_PUBLIC_BUCKET=schooldesk-public-media
R2_ACCESS_KEY_ID=<secret>
R2_SECRET_ACCESS_KEY=<secret>
R2_REGION=auto
R2_PUBLIC_BASE_URL=https://<public-r2-domain>
STORAGE_WRITE_PROVIDER=r2
STORAGE_READ_ORDER=r2,supabase
STORAGE_LEGACY_READ=true
STORAGE_LEGACY_WRITE=false
```

Keep `STORAGE_LEGACY_READ=true` during cutover. Do not copy or delete R2
objects as part of Supabase database restore. Existing `r2://private/...`
and `r2://public/...` references remain database data. School post media is
public only after approval and configured public R2 domain.

## 5. Copy Edge Functions

Deploy `supabase/functions/api` and
`supabase/functions/notification-processor` into the self-hosted Functions
runtime. Configure function secrets. Verify API code can reach restored
Postgres and R2 before switching application URLs.

## 6. Verify before DNS cutover

Run all checks against isolated self-hosted hostname:

```sql
select count(*) from auth.users;
select extname from pg_extension order by extname;
select count(*) from public.schools;
select count(*) from public.event_posts;
```

Also verify:

- Auth login and refresh.
- RLS for Principal, Teacher, Parent, and second-school isolation.
- Edge API `/health` and authenticated API calls.
- Realtime subscription.
- School post list with R2 public media.
- Parent-only media with R2 signed URL.
- R2 upload, read, and delete using isolated test object.
- Notification processor and SMTP.
- Backup and restore of new self-hosted database.

Keep old Supabase platform project and R2 objects unchanged until full
production soak passes. DNS cutover is separate approval.

## Known limits

Supabase restore guide covers database only. It does not copy Storage objects,
Edge Functions, SMTP, OAuth, custom domains, or DNS. This plan keeps School
post media in R2 and requires separate function and secret deployment.
