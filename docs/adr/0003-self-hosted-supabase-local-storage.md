# ADR-0003: Hostinger self-hosted Supabase and VPS-backed Storage

## Status

Accepted for the Hostinger migration; production cutover remains gated.

## Decision

SchoolDesk's production backend target is the official self-hosted Supabase
Docker stack managed by Coolify on the Hostinger VPS. The `api` and
`notification-processor` Edge Functions run in the self-hosted Functions
runtime. PostgreSQL and Supabase Storage persist on explicit VPS bind mounts;
application code accesses files only through the Supabase Storage API.

Cloudflare R2 is not configured on the target. During restore and verification,
the Edge API uses:

```text
STORAGE_WRITE_PROVIDER=supabase
STORAGE_READ_ORDER=supabase
STORAGE_LEGACY_READ=true
STORAGE_LEGACY_WRITE=true
```

The legacy flags remain enabled until every restored object and database
reference is verified. They are then disabled and all `R2_*` target secrets are
removed. The managed Supabase project and R2 buckets remain rollback sources
until a separately approved retirement action.

## Consequences

- Self-hosting owns platform upgrades, SMTP, OAuth, FCM, Realtime, backups,
  monitoring, firewalling, and restore drills.
- Existing sessions are invalid after the JWT configuration changes; users must
  sign in again and password recovery must be verified.
- The KVM 2 VPS is a rehearsal/low-traffic target until resource and restore
  evidence supports production use.
- `supabase/config.toml` remains local-only and must not be used as the
  production Compose definition.

## Migration boundary

Supabase-managed Storage metadata is never restored by direct SQL insertion.
The importer recreates source bucket policies and the two consolidated media
buckets through the Storage API, uploads object bytes, verifies SHA-256, and
only then permits the guarded database-reference rewrite.
