# Four-role chat release — 18 October 2026

The approved chat presentation is implemented for principal, coordinator,
teacher/co-teacher and parent accounts. Super Admin and kiosk retain their
existing presentation. Existing website, attendance, fee, receipt and
notification work remains in the working checkout.

## App behavior

The new workspace provides child-scoped parent conversations, class/role/unread
filters, new-message contacts, leadership Direct and Monitor views, readable
light/dark surfaces and a split layout on wider displays. Phone conversation
views have a dedicated back action and composer, with global navigation on the
inbox. Back returns to the prior inbox/filter state; monitored conversations can
open a participant's direct conversation and return to the monitor context.

Available account/staff photos appear in contacts, lists, headers and monitored
message sender labels. Signed private image references are resolved through the
existing media URL helper; missing/failed images fall back to initials.

Drafts persist per account, branch, role and conversation in Drift schema 6.
Sending first saves the same UUID and payload to the existing durable outbox.
Acknowledgements reconcile by identity, rather than message text. Transient
failures remain queued and retry with the existing backoff through a single
foreground timer; background/resume/connectivity triggers remain available.
Account changes cancel stale work before dispatch and discard stale responses.

Realtime invalidations coalesce, refresh after reconnect/resume and retain a
foreground fallback. Reconnection catches up all missing cursor pages before
reconciling the latest page. Older-history loading preserves the scroll anchor;
incoming messages only auto-scroll when the reader is near the bottom. Read
receipts reflect actual recipients, excluding leadership's oversight-only reads.

## Additive backend contracts

- `POST /chat/messages`: immutable `client_message_id`, body and existing
  conversation ID or validated participant tuple. Message, preview, inbox notice
  and push event creation commit together. Identical retries acknowledge the
  existing message; changed body/context returns 409.
- `GET /chat/conversations/:id`: authorized direct lookup for deep links.
- `GET /chat/conversations/:id/messages`: optional `latest`, `before` and `after`
  modes with `(sent_at,id)` cursors, plus `has_more` and `next_cursor`.
- `POST /chat/conversations/:id/read`: optional tuple boundary. Legacy full-read
  requests remain compatible.
- `GET /chat/unread-count`: exact aggregate across all authorized pages, including
  the leadership monitor mode. Contact, conversation and message DTOs add scoped
  photos and recipient read state.

Existing endpoints remain available for the legacy clients. Only the service
role can execute the database helper functions; the Edge handler checks the
authenticated school, participant and student/class assignment.

## Verification and production

The local synthetic database replayed the migration chain through the first
three chat migrations. The final retry conflict correction was then dry-run and
applied locally as a separate forward migration. Earlier migration files were
preserved.

Behavioral checks cover persistent drafts and schema upgrade, account switching,
overlapping refreshes, history/reconnect catchup beyond 50 messages, queued
first-contact reconciliation, unread filters beyond the first inbox page,
phone/wide layouts, enlarged text, dark mode and back navigation. Fixture
captures use real fonts/icons and contain no real school data.

The Docker API smoke passed concurrent first sends, identical and conflicting
retries, forced transaction rollback, tied cursor boundaries, bounded reads,
1,100-message unread counts, Direct/Monitor ownership, both-recipient receipts,
co-teacher access, scoped signed photos and foreign child/class/school rejection.
The existing issue/diary/health/highlights, historical-attendance, notification,
payment and reversal regressions also passed. The backend passed Deno 2.5.6
type checking.

Production received only the reviewed communications handler and these forward
migrations. The first four committed in one transaction; the final Realtime
scope correction was promoted separately after its revocation checks passed:

- `20261017153517_atomic_chat_delivery.sql`
- `20261017153826_chat_transaction_scope_guards.sql`
- `20261017153948_chat_thread_notice_identity.sql`
- `20261018045249_chat_retry_payload_conflicts.sql`
- `20261018050859_chat_realtime_current_scope.sql`
- `20261018052815_chat_realtime_publication_membership.sql`

The final policy checks current parent-child links and teacher class/co/subject
assignments for direct database reads and Realtime delivery. Actual local
WebSockets verified parent/teacher messages, principal/coordinator monitor
updates and foreign-school silence. Unlinking the synthetic parent and
transferring the synthetic student denied HTTP/direct reads and stopped new
payloads on already-open revoked sockets. Authorized co-teacher and subject
assignments retained access. Historical messages and threads were preserved.
Teacher contacts also carry the authenticated teacher ID, so first-contact
queue reconciliation is independent of a cached profile.

Before promotion, the deployed handler and live catalog were compared with the
reviewed baseline. A fresh PostgreSQL custom-format backup and complete prior
Functions archive are retained privately on the VPS under
`/data/schooldesk/repairs/20261017-chat-redesign/` and locally in ignored `.local/`.
The handler hash and service-only RPC grants were verified after promotion.

Final authenticated production reads passed for parent, teacher, coordinator and
principal: contacts/photo fields, role rejection, Direct/Monitor pagination,
unread totals, conversation details and cursor DTOs. Notification subjects,
school/highlights and the unchanged Super Admin inbox also returned correctly.
The scoped database policy was also exercised through authenticated internal
PostgREST reads; the existing public REST gateway restriction was preserved.
All four existing host timers remain active and the latest processor outcome
was successful. Production verification sent no test messages or broadcasts.

Production subscription verification also exposed two existing infrastructure
defects: Kong's WebSocket upstream referred to an unavailable DNS alias, and the
chat tables were missing from `supabase_realtime`. The persistent Kong config
at `/data/schooldesk/stack/volumes/api/kong.yml` now uses
`http://realtime-dev:4000/socket` for `realtime-v1-ws`; only that URL was changed
and only Kong was restarted. Its prior configuration is backed up privately.
The sixth migration adds only the two RLS-protected chat tables to the existing
publication and preserves its prior invalidation-event member.

After those repairs, public authenticated WebSocket joins and replication-ready
acknowledgements passed for parent, teacher, principal and coordinator on both
chat table filters. These read-only probes discarded application event payloads.
This proves production subscription readiness; actual message exchange was
tested in synthetic Docker, without sending production school messages.

For application rollback, restore the prior communications handler from the
Functions archive and restart the Edge runtime. The additive column, indexes
and service-only functions can remain; legacy clients continue using their
existing endpoints. Preserve queued events and user messages. A full database
restore is a disaster-recovery action, not the routine rollback. Retain the
current-scope Realtime policy when rolling the handler back. A client using the
new atomic endpoint needs this release's backend; use the preceding APK if a
full application rollback becomes necessary.

Keep the repaired WebSocket URL and chat publication membership during a handler
rollback: legacy chat also depends on them. The private Kong backup and recorded
publication member list provide infrastructure recovery references; restoring
the broken URL or dropping publication members is not a normal application
rollback. Preserve the reviewed URL if regenerating the Coolify stack config.

## Android handoff

The release version is **1.0.34+47**, targeting the existing production package
and API.

- Artifact: `artifacts/android/SchoolDesk-1.0.34+47-chat.apk`, 145,981,478 bytes.
- Package `com.techmigos.schooldesk1`, version name `1.0.34`, version code `47`.
- APK signature verification passed with the existing production certificate:
  `80141fa2855069e649008f4f8b7cfc1c31bf66bb4a0a97a7e094765b43c6cb08`.
- Compiled production endpoint verified; all three packaged app libraries have
  no DWARF debug sections. Crash symbols/mappings are retained privately.
- All 446 captured release source files matched after compilation.
- SHA-256:
  `2f1707aeec0c7e5d8b33f2bd128f7af428f73451c873049e9432894698b1f298`.
  A checksum sidecar accompanies the APK.

Fresh checks passed: 38 transport/navigation/compatibility tests, 13 workspace
behavior/layout cases plus four capture cases, 10 connection/draft cases, eight
retry cases and 18 existing offline regressions. Whole-project Flutter analysis
reported no issues. The full local migration reset replayed through the fifth
chat migration; the sixth publication migration was then applied locally and
verified. API and actual WebSocket delivery/revocation checks passed after the
reset. Evidence logs and 12 fixture-rendered images remain in ignored `.local/`.

No installation, physical-device visual pass or phone push-delivery acceptance
is claimed. The user will check those on their device, as requested.
