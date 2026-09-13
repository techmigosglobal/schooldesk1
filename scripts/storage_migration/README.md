# SchoolDesk object-storage migration

This runner copies Supabase Storage objects into the private/public R2 buckets
without deleting the source. It is resumable through the state JSON file and
verifies every copied object with SHA-256. ETags are not used as an integrity
check.

Set the source S3-compatible credentials and the R2 S3 credentials in the
shell or deployment secret manager. Never commit them or put them in Flutter
`--dart-define` values.

```bash
export SOURCE_S3_ENDPOINT="https://<supabase-storage-host>/storage/v1/s3"
export SOURCE_S3_ACCESS_KEY_ID="..."
export SOURCE_S3_SECRET_ACCESS_KEY="..."
export SOURCE_BUCKETS="school-assets:private,school-private-files:private,finance-documents:private,payment-proofs:private,issue-attachments:private,help-tutorial-videos:private,school-signatures:private,school-public-media:public"

export R2_ENDPOINT="https://<account-id>.r2.cloudflarestorage.com"
export R2_PRIVATE_BUCKET="schooldesk-private-files"
export R2_PUBLIC_BUCKET="schooldesk-public-media"
export R2_ACCESS_KEY_ID="..."
export R2_SECRET_ACCESS_KEY="..."
export R2_REGION="auto"
export MIGRATION_CONCURRENCY="4"
```

Run the migration in this order:

```bash
npx -y deno run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/r2_migrate.ts inventory \
  --state ./storage-migration.json

npx -y deno run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/r2_migrate.ts copy \
  --state ./storage-migration.json

npx -y deno run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/r2_migrate.ts verify \
  --state ./storage-migration.json

npx -y deno run --allow-env --allow-net --allow-read \
  scripts/storage_migration/r2_migrate.ts report \
  --state ./storage-migration.json
```

The source remains untouched. Re-running `copy` retries failed items and skips
items already marked `verified`. Large-object multipart transfer should be
enabled before production migration if the source inventory contains objects
over the single-request threshold; the Edge API upload path remains bounded by
its existing multipart/request limits.
