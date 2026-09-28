# Selective hosted restore

This is the controlled restore path for target project `qzdhymlabzqjeocetqqv`.
It never imports Supabase-managed schemas, source Storage metadata, Realtime
state, cron history, demo credentials, idempotency state, or error-event data.

All generated files must live in a private directory outside the repository. Use
a `0600` environment file such as
`/home/vinay/.config/schooldesk/restore-target.env` with these values:

```dotenv
TARGET_DB_URL=postgresql://...
TARGET_SERVICE_ROLE_KEY=sb_secret_...
TARGET_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
R2_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
R2_PRIVATE_BUCKET=schooldesk-private-files
R2_PUBLIC_BUCKET=schooldesk-public-media
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_REGION=auto
R2_PUBLIC_BASE_URL=https://...
NOTIFICATION_PROCESSOR_SECRET=<fresh random value>
BIRTHDAY_ALERT_JOB_SECRET=<fresh random value>
HEALTH_REMINDER_JOB_SECRET=<fresh random value>
```

Do not place the source project URL, source credentials, old job secrets, or the
target database URL in a repository file. The three job-secret values must be
newly generated for this target.

## Execution order

Run from the repository after exporting the file into the process environment.
The output directory below is only an example and must have mode `0700`.

```bash
set -a
. /home/vinay/.config/schooldesk/restore-target.env
set +a

restore_dir=/home/vinay/Documents/SchoolDesk-Backup/restore-qzdhymlabzqjeocetqqv-<timestamp>
dump=/home/vinay/Documents/SchoolDesk-Backup/db_cluster-24-09-2026@08-24-07.backup.gz
archive=/home/vinay/Documents/SchoolDesk-Backup/ouvwogguttybmpgfgctc.storage.zip

npx --yes deno@2.6.1 run --allow-read --allow-write --allow-run \
  scripts/restore/selective_restore.ts ledger --dump "$dump" --output "$restore_dir"

npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write --allow-run \
  scripts/restore/selective_restore.ts preflight --dump "$dump" --output "$restore_dir"

npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write \
  scripts/restore/backup_target_storage.ts --output "$restore_dir/target-storage-backup"

npx --yes deno@2.6.1 run --allow-env --allow-read --allow-write --allow-run \
  scripts/storage_migration/r2_migrate.ts zip-inventory \
  --archive "$archive" --source-dump "$dump" --state "$restore_dir/r2-state.json"

npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write --allow-run \
  scripts/storage_migration/r2_migrate.ts zip-copy \
  --archive "$archive" --state "$restore_dir/r2-state.json"

npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write --allow-run \
  scripts/storage_migration/r2_migrate.ts zip-verify \
  --archive "$archive" --state "$restore_dir/r2-state.json"
```

Only after the backup, preflight, and R2 verification succeed, apply the new
reviewed migration, deploy the two functions into maintenance mode, restore
the selected rows, and rewrite storage references. The dry-run must show only
`20260927055949_install_restore_scheduler_secret_resolver.sql` before it is
applied:

```bash
npx --yes --package=supabase@2.116.0 supabase db push --dry-run --linked
npx --yes --package=supabase@2.116.0 supabase db push --linked
npx --yes deno@2.6.1 run --allow-env --allow-read --allow-write \
  scripts/restore/prepare_function_secrets.ts --output "$restore_dir/target-function-secrets.env"
npx --yes --package=supabase@2.116.0 supabase secrets set --project-ref qzdhymlabzqjeocetqqv --env-file "$restore_dir/target-function-secrets.env"
npx --yes --package=supabase@2.116.0 supabase functions deploy api notification-processor --project-ref qzdhymlabzqjeocetqqv --use-api --no-verify-jwt

npx --yes deno@2.6.1 run --allow-read --allow-write \
  scripts/restore/prepare_maintenance_secret.ts --enabled --output "$restore_dir/maintenance-on.env"
npx --yes --package=supabase@2.116.0 supabase secrets set --project-ref qzdhymlabzqjeocetqqv --env-file "$restore_dir/maintenance-on.env"
npx --yes deno@2.6.1 run --allow-env --allow-net \
  scripts/restore/set_maintenance.ts --enable

npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write --allow-run \
  scripts/restore/selective_restore.ts restore --execute --dump "$dump" --output "$restore_dir"

DATABASE_URL="$TARGET_DB_URL" npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/r2_migrate.ts zip-sync --state "$restore_dir/r2-state.json"

DATABASE_URL="$TARGET_DB_URL" npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/r2_migrate.ts rewrite --execute --state "$restore_dir/r2-state.json"

npx --yes deno@2.6.1 run --allow-env --allow-net \
  scripts/restore/configure_cutover.ts

npx --yes deno@2.6.1 run --allow-env --allow-net \
  scripts/restore/set_maintenance.ts --disable
npx --yes deno@2.6.1 run --allow-read --allow-write \
  scripts/restore/prepare_maintenance_secret.ts --disabled --output "$restore_dir/maintenance-off.env"
npx --yes --package=supabase@2.116.0 supabase secrets set --project-ref qzdhymlabzqjeocetqqv --env-file "$restore_dir/maintenance-off.env"
```

Before reopening the application, update `env.supabase.json` using the target
URL and its target publishable key. The function-secret preparation command sets
the required R2-only flags and never includes the database URL or API key.

The final evidence is `restore-manifest.json`, `row-ledger.ndjson`,
`database-restore-report.json`, `r2-state.json`, the target database dump, and
the target Storage-backup manifest. Keep all of them, as well as the source
archives, for the soak/rollback period. Do not use the cleanup command.

`/health` and `/ready` remain available while maintenance is enabled; all
other API requests receive a temporary `503`. The five retained schedules are
paused without being removed, and the nine intended schedules are reactivated
only after final verification. If a gate fails after database replacement,
leave maintenance on, restore the target backup, and do not reopen service.
