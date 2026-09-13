# Architecture decisions

## State management

Provider is the single application state-management system. Theme, settings,
and authentication are `ChangeNotifier`s provided from the application root.
Riverpod was removed because its provider definitions were not consumed by any
screen; retaining an unused second container made ownership unclear.

## Network API boundary

`BackendApiClient` remains the stable, testable HTTP facade. Its domain methods
live in `lib/core/network/api_modules/`; repositories are the domain-facing
adapters. New endpoints belong in the relevant existing module rather than in
the facade file.

## Offline-first data flow

`OfflineSyncEngine` is attached below both the primary `BackendApiClient` Dio
and the legacy Retrofit `SchoolDeskApi` Dio, so existing feature screens do
not choose between local and remote data sources. Successful,
authenticated GET responses are copied into the account/branch/role-scoped
Drift database and are used as stale fallbacks when the Edge API cannot be
reached. The legacy Hive cache is only a successful-response optimization;
authenticated reads remain network-first and never let Hive hide the transport
failure from Drift. `ApiAttendanceRepository` additionally maintains a typed local
attendance table for the teacher workflow, while draft homework writes are
kept in a typed local draft table and merged into the teacher's offline list.

Transport-failed writes are queued only for explicitly safe operations:
attendance session creation/marking, attendance submissions/updates, homework
drafts, teacher notes, and chat message composition. Attendance session
creation uses a durable local ID and a replay reference so a dependent mark
request cannot run until the real server session ID is available. Each outbox
row carries a stable `Idempotency-Key` and is replayed oldest-first with
bounded exponential retry.
Binary homework/profile uploads have a separate durable file queue. It stores
bytes on native source paths, replays the upload before dependent JSON
mutations, and replaces the local placeholder with the returned remote URL.

Object storage is migrating from Supabase Storage to Cloudflare R2 while
Supabase Auth, PostgreSQL, RLS, audit, Realtime, and FCM remain authoritative.
The Edge API uses two R2 buckets: `schooldesk-private-files` and
`schooldesk-public-media`. Its required configuration is
`R2_ENDPOINT`, `R2_PRIVATE_BUCKET`, `R2_PUBLIC_BUCKET`, `R2_ACCESS_KEY_ID`,
`R2_SECRET_ACCESS_KEY`, `R2_REGION`, and `R2_PUBLIC_BASE_URL`. The staged
cutover flags are `STORAGE_WRITE_PROVIDER=r2`,
`STORAGE_READ_ORDER=r2,supabase`, `STORAGE_LEGACY_READ=true`, and
`STORAGE_LEGACY_WRITE=false`.

R2 references are visibility-aware (`r2://private/...` or
`r2://public/...`). Private responses are short-lived signed S3 URLs; public
responses use the configured public custom domain. Private SchoolPost media is
promoted to the public bucket only after an approved `SCHOOL_LANDING` or
explicit `public_gallery_visible` decision, and parent-only media remains
private. The public custom domain is required before promotion succeeds.

The `scripts/storage_migration/` runner inventories all legacy buckets,
copies with bounded retries and multipart support, verifies SHA-256, and
resumes from a state file. It never deletes source objects. Service-only
tracking tables live under `schooldesk_internal`; the source is retained until
the dual-read soak and rollback window are complete. School wipe cleanup keeps
provider-aware R2 references and legacy Supabase paths separate.
R2 credentials are Edge Function secrets only; they are never shipped in
Flutter `dart-define` files or mobile artifacts.
Approvals, payment decisions/reversals, role and user administration, branch
changes, password changes, and destructive operations remain online-required
and continue through the normal API error path.

The Edge API stores keyed authenticated mutation responses in
`api_idempotency_keys`, scoped to user and school, and rejects reuse of a key
with a different method, path, or body. The migration must be applied before
deploying the API change; it is intentionally service-role-only under RLS.

Sync starts at app startup, resume, connectivity recovery, after an
offline-capable write, an FCM `schooldesk_sync`/`data_stale` data message, and
a best-effort WorkManager periodic task; explicit refresh actions can call the
same `syncNow()` entrypoint.
The iOS target declares `schooldesk-periodic-offline-sync` under
`BGTaskSchedulerPermittedIdentifiers`. Mobile background scheduling is treated
as an opportunity rather than a correctness dependency; the Edge API remains
authoritative.

## Navigation

Named routes remain the production navigation contract. The route boundary now
throws a diagnostic error when a route has neither a widget nor a builder,
instead of silently rendering a blank screen. A `go_router` migration is a
separate compatibility project: it must first replace the existing dynamic
argument maps with typed route argument objects and include deep-link and
role-guard regression tests.

## Native build dependencies

iOS uses Flutter's generated Swift Package integration. Do not add a Podfile:
the project has no CocoaPods plugins, and adding CocoaPods would reintroduce a
second native dependency manager. Android release builds enable R8 and resource
shrinking; every signed release must complete the device smoke checks below.
Release build scripts and Codemagic also use Flutter's `--obfuscate` and
`--split-debug-info` flags. The generated symbol directory is a required
release artifact, not disposable build output.
