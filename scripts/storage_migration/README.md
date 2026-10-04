# SchoolDesk object-storage migration

## Hostinger / self-hosted Supabase target

For the Hostinger migration, use `self_hosted_storage.ts` below. Its source is
the verified Supabase/R2 archive; its target is Supabase Storage on the VPS
NVMe. It does not require R2 credentials, does not delete source objects, and
does not rewrite database references unless the separate guarded rewrite is
explicitly executed. Follow [`docs/SELF_HOSTED_RESTORE.md`](../../docs/SELF_HOSTED_RESTORE.md)
for the full staging, backup, and cutover gates.

The old `r2_migrate.ts` workflow below is for the historical Supabase-to-R2
cutover only. Do not use it to migrate to the Hostinger target.

### Self-hosted import

First verify the archive checksum and extract it outside the repository. The
Oct 1 rehearsal bundle is at
`/home/vinay/Documents/SchoolDesk-Backup/schooldesk-backend-backup-20261001.tar.gz`;
use a fresh database/media snapshot for production. Inventory hashes all
objects and writes a mode-0600 state file under ignored `.local/` storage.

```sh
export STORAGE_SOURCE_DIR=/path/to/extracted/schooldesk-backup-20261001
export TARGET_SUPABASE_URL=https://api.example.org
# Supply TARGET_SUPABASE_SERVICE_ROLE_KEY and DATABASE_URL via a protected
# local secret environment/file; never put secrets in Git or Flutter defines.

npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/self_hosted_storage.ts inventory \
  --source-dir "$STORAGE_SOURCE_DIR" --state .local/self-hosted-storage/state.json

npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/self_hosted_storage.ts copy \
  --state .local/self-hosted-storage/state.json  # dry-run

npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/self_hosted_storage.ts copy --execute \
  --state .local/self-hosted-storage/state.json

npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/self_hosted_storage.ts verify \
  --state .local/self-hosted-storage/state.json

npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/self_hosted_storage.ts rewrite \
  --state .local/self-hosted-storage/state.json  # dry-run
```

`copy --execute` recreates all source Supabase buckets from `storage-data.sql`
through the Storage API, also creates the two R2-consolidation buckets
(`schooldesk-private-files`, `schooldesk-public-media`), and refuses to replace
an existing different bucket policy or object. Import verifies destination
bytes by SHA-256. Database rewrite requires every object verified and a reviewed
dry run; perform it only during the approved maintenance window with a fresh
target database backup and both `--execute` and
`SELF_HOSTED_STORAGE_REWRITE_CONFIRM=schooldesk-self-hosted`.
The rewrite is transactional, idempotent, and leaves the old services intact.

The archive includes Auth/storage metadata and object files, but the final
production pass still requires a fresh DB/media delta, password/login checks,
secret setup, and complete role/RLS verification. The Oct 1 object totals are
rehearsal checks only, never a current production count.

### Recovering live R2 references absent from an archive

If the guarded rewrite reports R2 references that are not in the dated archive,
use the recovery helper with protected R2 read credentials and the target
database URL. Its default mode only reports the gap. `--execute` downloads the
currently referenced source objects into the extracted archive and appends them
as pending items to the self-hosted state; it does not modify or delete R2.

```sh
export R2_ENDPOINT="https://<account-id>.r2.cloudflarestorage.com"
export R2_PRIVATE_BUCKET="schooldesk-private-files"
export R2_PUBLIC_BUCKET="schooldesk-public-media"
export R2_ACCESS_KEY_ID="..."
export R2_SECRET_ACCESS_KEY="..."
export R2_REGION="auto"
export DATABASE_URL="<service-only-target-database-url>"

npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/recover_r2_references.ts \
  --state .local/self-hosted-storage/state.json

npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/recover_r2_references.ts \
  --state .local/self-hosted-storage/state.json --execute

npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/self_hosted_storage.ts copy --execute \
  --state .local/self-hosted-storage/state.json

npx --yes deno@2.6.1 run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/self_hosted_storage.ts verify \
  --state .local/self-hosted-storage/state.json
```

If the source returns 404, stop and obtain a fresh media delta or repair the
orphaned application reference with an approved data decision; do not rewrite
it to a target path whose bytes have not been verified.

## Historical Supabase-to-R2 workflow

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

Reference cutover is a separate, fail-closed operation. Run the dry run first;
it refuses to proceed when an inventory object has no verified R2 mapping or a
live database reference is ambiguous:

```bash
export DATABASE_URL="<service-only-production-database-url>"

npx -y deno run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/r2_migrate.ts rewrite \
  --state ./storage-migration.json

npx -y deno run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/r2_migrate.ts rewrite --execute \
  --state ./storage-migration.json
```

The source cleanup command is also dry-run by default. It inventories every
configured Supabase bucket, protects every live database reference, selects
only verified orphaned source objects needed to reach 900,000,000 bytes, and
stores an auditable batch. It never deletes without both `--execute` and the
explicit `ALLOW_SUPABASE_SOURCE_DELETE=1` guard:

```bash
npx -y deno run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/r2_migrate.ts cleanup \
  --state ./storage-migration.json --target-bytes 900000000

export ALLOW_SUPABASE_SOURCE_DELETE=1
npx -y deno run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/r2_migrate.ts cleanup --execute \
  --batch "<dry-run-batch-id>" --state ./storage-migration.json
```

The locked, exceptional policy for a user-approved referenced-file reduction
is separate from orphan cleanup. It selects the largest verified R2-backed
objects that still have legacy database references and records
`allowReferenced: true` in the batch. Use this only after the application has
been verified to retrieve those references through R2; execution additionally
requires `ALLOW_SUPABASE_REFERENCED_SOURCE_DELETE=1`:

```bash
npx -y deno run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/r2_migrate.ts cleanup \
  --include-referenced --state ./storage-migration.json \
  --target-bytes 900000000

export ALLOW_SUPABASE_SOURCE_DELETE=1
export ALLOW_SUPABASE_REFERENCED_SOURCE_DELETE=1
npx -y deno run --allow-env --allow-net --allow-read --allow-write \
  scripts/storage_migration/r2_migrate.ts cleanup --execute \
  --batch "<referenced-dry-run-batch-id>" --state ./storage-migration.json
```

Both policies re-read the source and R2 objects, compare SHA-256 hashes, issue
the source delete, verify a post-delete `HEAD` returns 404, and update the
audit queue. A database reference is not treated as safe merely because an R2
copy exists; the second policy is intentionally blocked unless the explicit
referenced-delete guard is present.

`inventory`, `copy`, `verify`, and rewrite dry-runs leave the source untouched.
Re-running `copy` retries failed items and skips items already marked
`verified`. `rewrite` is idempotent and records a reverse mapping for rollback.
Cleanup re-checks live references and SHA-256 equality immediately before each
explicitly authorized source deletion. Large-object multipart transfer should be
enabled before production migration if the source inventory contains objects
over the single-request threshold; the Edge API upload path remains bounded by
its existing multipart/request limits.
