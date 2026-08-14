# SchoolDesk — Backend Implementation & Performance Reference

**Version:** 1.0  
**Status:** Canonical backend specification  
**Product:** SchoolDesk  
**Backend stack:** Supabase (PostgreSQL + Edge Functions + Realtime + Storage)  
**Flutter client network layer:** Dio + dio_cache_interceptor (Hive persistent store)  
**Last updated:** August 2026  

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Request Lifecycle](#2-request-lifecycle)
3. [API Base URL & Environment Config](#3-api-base-url--environment-config)
4. [Authentication & Session Management](#4-authentication--session-management)
5. [Edge Function API — Handler Inventory](#5-edge-function-api--handler-inventory)
6. [Flutter API Client — Module Inventory](#6-flutter-api-client--module-inventory)
7. [Caching Strategy](#7-caching-strategy)
8. [Request Coalescing](#8-request-coalescing)
9. [Performance Targets & Optimization](#9-performance-targets--optimization)
10. [Realtime & Invalidation](#10-realtime--invalidation)
11. [Branch Isolation in the Network Layer](#11-branch-isolation-in-the-network-layer)
12. [Role-Based API Enforcement](#12-role-based-api-enforcement)
13. [Finance API — Safety & Atomicity](#13-finance-api--safety--atomicity)
14. [File Uploads & Storage](#14-file-uploads--storage)
15. [Notification Pipeline](#15-notification-pipeline)
16. [Database Schema Overview](#16-database-schema-overview)
17. [RLS Policies & Security](#17-rls-policies--security)
18. [Error Handling & Retry Strategy](#18-error-handling--retry-strategy)
19. [Audit Logging](#19-audit-logging)
20. [Manual Student Spreadsheet Exchange (Sheets API)](#20-manual-student-spreadsheet-exchange-sheets-api)
21. [Backend Verification Checklist](#21-backend-verification-checklist)
22. [Performance Monitoring & Observability](#22-performance-monitoring--observability)
23. [Known Backend Issues & Remediation Plan](#23-known-backend-issues--remediation-plan)

---

## 1. Architecture Overview

```
Flutter Mobile App (Dart / Dio)
         |
         | HTTPS — Bearer token + x-schooldesk-branch-id header
         |
Supabase Edge Function  ← supabase/functions/api/index.ts
         |
         |— PostgreSQL (Supabase Postgres) — RLS enforced
         |— Supabase Auth (JWT validation)
         |— Supabase Storage (signed URLs for private assets)
         |— Supabase Realtime (invalidation signals only)
         |— Notification Processor (separate Edge Function + pg_cron)
```

### Component Roles

| Component | Role |
|-----------|------|
| **Flutter app** | UI layer, local caching, request orchestration |
| **BackendApiClient** | Singleton Dio client, interceptor stack, cache management |
| **Supabase Edge Function (`api`)** | Single API gateway; routes all requests; enforces auth + branch |
| **Supabase Postgres** | System of record; all writes; RLS enforces row-level isolation |
| **Supabase Auth** | JWT issuance and validation; role and branch membership |
| **Supabase Storage** | Private and public object storage; signed URL generation |
| **Supabase Realtime** | Pushes invalidation signals; never raw data payloads |
| **notification-processor** | Separate Edge Function for FCM push delivery via pg_cron |

---

## 2. Request Lifecycle

A typical authenticated Flutter API call flows as follows:

```
1. Flutter UI calls BackendApiClient method
2. _DemoLocalApiInterceptor — resolves locally for demo session; skips network
3. _AuthInterceptor — attaches Bearer token to Authorization header
4. _ReadCacheOptionsInterceptor — assigns TTL and cache policy for GET requests
5. _WriteCacheInvalidationInterceptor — clears relevant cache keys on mutations
6. _LoggingInterceptor — logs in debug/dev mode
7. _ErrorInterceptor — normalizes Dio errors to ServerException; triggers token refresh
8. DioCacheInterceptor — serves cached response if fresh; else passes to network
9. HTTPS to Supabase Edge Function
10. Edge Function: validates JWT, resolves role + branch from Supabase Auth
11. Edge Function: routes to the appropriate handler (e.g., fees.ts, attendance.ts)
12. Handler: queries PostgreSQL; RLS policies enforce user/role/branch access
13. Handler: builds JSON response
14. Response travels back through interceptors
15. DioCacheInterceptor stores fresh GET response in Hive
16. Flutter UI receives typed model
```

---

## 3. API Base URL & Environment Config

### Base URL

```
https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api
```

### URL Resolution Rules (`EnvConfig.v1BaseUrlFrom`)

- Accepts exact Supabase Edge Function API URLs
- Accepts bare Supabase project URLs, auto-converted to `/functions/v1/api`
- Non-Supabase backend URLs fall back to the default Supabase Edge URL to prevent accidentally attaching builds to retired backends

### Environment Configuration

| Config Key | Default | Notes |
|-----------|---------|-------|
| `apiBaseUrl` | `https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api` | Pinned to Supabase Edge |
| `apiTimeoutSeconds` | `30` | Connect + receive timeout |
| `enableLogging` | `false` (prod) | Debug logging flag |

### Request Headers (Every Authenticated Request)

| Header | Value |
|--------|-------|
| `Authorization` | `Bearer <supabase_access_token>` |
| `Content-Type` | `application/json` |
| `Accept` | `application/json` |
| `x-schooldesk-branch-id` | Active branch UUID (set on login or branch switch) |

---

## 4. Authentication & Session Management

### Sign-In Flow

1. Client sends credentials to `/auth/login`
2. Edge Function validates against Supabase Auth
3. Returns: `access_token`, `refresh_token`, `user_id`, `role`, `branch_id`
4. Flutter stores tokens in `TokenStorageService` (secure storage)
5. `BackendApiClient.initialize()` restores token, role, user ID, and branch from storage on app start

### Token Refresh

- `_AuthInterceptor` attaches the current Bearer token to every request
- On 401 response, `_ErrorInterceptor` triggers a token refresh via Supabase Auth
- A `Completer<bool>` (`_refreshCompleter`) prevents parallel refresh attempts
- On successful refresh, the original request is retried with the new token
- On failed refresh, the user is logged out and routed to sign-in

### Session Isolation Rules

- `setCurrentUserId` clears all in-memory cached data (profile, dashboards, school) when the user changes
- `clearAuthToken` removes all session data from memory and the branch header
- The persistent Hive cache is user-scoped via the `_authenticatedCacheKey` builder (user ID + branch ID + role as fragment)
- Demo sessions use a local-only `local-demo-session` token; they must not write to `TokenStorageService`

### Branch Switching (Principal Only)

```dart
await client.setActiveBranchId(newBranchId);
// Effect:
// 1. Updates x-schooldesk-branch-id header
// 2. Persists new branch ID to TokenStorageService
// 3. Clears all in-memory caches (school, dashboards, coalesced GETs)
// 4. Clears entire Hive persistent cache
```

---

## 5. Edge Function API — Handler Inventory

All handlers are in `supabase/functions/api/handlers/`. The entry point is `supabase/functions/api/index.ts`.

### Handler Files and Responsibilities

| Handler File | Routes Served | Role Access | Notes |
|-------------|---------------|-------------|-------|
| `auth.ts` | `/auth/*` | All (pre-auth) | Login, logout, session, profile |
| `dashboard.ts` | `/dashboard/*` | Principal, Coordinator, Teacher, Parent | Role-branched dashboard queries |
| `students.ts` | `/students/*` | Principal, Coordinator | CRUD + search + lifecycle |
| `staff.ts` | `/staff/*` | Principal, Coordinator | Staff directory, profiles, documents |
| `users.ts` | `/users/*` | Principal, Coordinator | Account management, user creation |
| `access.ts` | `/access/*` | Principal | Role assignments, permissions |
| `principal.ts` | `/principal/*` | Principal, Coordinator | Governance, student oversight, guardians |
| `academics.ts` | `/academic-years/*`, `/grades/*`, `/sections/*`, `/subjects/*`, `/curriculum/*` | Principal, Coordinator | Full academics management |
| `timetable.ts` | `/timetable/*` | Principal, Coordinator (write); Teacher, Parent (read) | Slot CRUD, copy-day, publish |
| `attendance.ts` | `/attendance/*` | All roles (scoped) | Sessions, marks, corrections, exports |
| `fees.ts` | `/fees/*` | Principal only | Structures, invoices, payments, concessions, receipts |
| `fee_payments_api` (client) | `/payments/*` | Principal only | Payment recording, history |
| `leave.ts` | `/leave/*` | Teacher (staff leave), Parent (student leave) | Leave requests, approvals |
| `homework.ts` | `/homework/*`, `/diary/*` | Teacher (write), Parent (read/submit) | Diary CRUD, submissions, feedback |
| `communications.ts` | `/communications/*`, `/chat/*`, `/complaints/*`, `/posts/*` | All roles (scoped) | Chat, announcements, complaints, event posts |
| `calendar.ts` | `/calendar/*` | All roles (read); Principal, Coordinator (write) | Events, holidays, PTM |
| `notifications.ts` | `/notifications/*` | All roles | In-app list, read, device token registration |
| `health_reminders.ts` | `/health-reminders/*` | Principal, Coordinator (write); Parent (read) | Health records, birthday alerts |
| `health.ts` | `/health`, `/ready` | Public | Health check and readiness probe |
| `monitoring.ts` | `/monitoring/*` | Principal, Super Admin | System health, error events, retention |
| `reports.ts` | `/reports/*` | Principal, Coordinator | Report data, exports |
| `activity.ts` | `/activity/*` | Principal, Coordinator | Audit log queries |
| `approvals.ts` | `/approvals/*` | Principal, Coordinator | Approval center |
| `schools.ts` | `/schools/*` | All (scoped) | Branch info, school profile |
| `branches.ts` | `/branches/*` | Principal | Branch list and selection |
| `website.ts` | `/website/*` | Principal, Coordinator (write); Public (read) | Public website content |
| `uploads.ts` | `/uploads/*` | All roles (scoped) | File uploads, document management, signed URLs |
| `sheets_pull.ts` | `/sheets/pull` | Principal, Coordinator | Student data export for Sheets |
| `sheets_sync.ts` | `/sheets/sync` | Principal, Coordinator | Student data push from Sheets |
| `teacher_scope.ts` | `/teacher/*` | Teacher | Teacher-scoped class, roster, timetable |
| `issues.ts` | `/issues/*` | All roles | Issue reporting |
| `help.ts` | `/help/*` | All roles | Help & tutorial content |
| `demo.ts` | `/demo/*` | QA only | Demo credential management; must not bypass production auth |
| `daily_claims.ts` | `/claims/*` | Internal | Daily JWT claims refresh |
| `birthday_alerts.ts` | `/birthday-alerts/*` | Internal + Principal | Birthday push delivery |
| `events.ts` | `/events/*` | All roles | Calendar events |
| `medical.ts` | `/medical/*` | Parent, Principal | Medical record access |
| `authorization.ts` | Internal utility | All | Role/branch resolution helper |
| `parent.ts` | `/parent/*` | Parent | Parent-specific workflows |

### Handler Authorization Pattern

Every handler follows this pattern:

```typescript
// 1. Validate JWT from Authorization header
const { user, error } = await supabase.auth.getUser(token);
if (error || !user) return unauthorizedResponse();

// 2. Resolve role and branch from server-controlled metadata
const { role, branchId } = await resolveRoleAndBranch(user.id, requestBranchId);

// 3. Enforce access
if (!isAllowedRole(role, allowedRoles)) return forbiddenResponse();

// 4. Execute scoped query (RLS enforces further isolation)
```

---

## 6. Flutter API Client — Module Inventory

All modules are `part` files of `BackendApiClient` in `lib/core/network/`.

| Module File | Coverage |
|------------|----------|
| `auth_api.dart` | Login, logout, token refresh, profile fetch |
| `branches_api.dart` | Branch list, branch switch |
| `principal_api.dart` | Governance, student oversight, guardian directory, admissions |
| `school_api.dart` | School profile, settings, gallery, public posts |
| `staff_api.dart` | Staff directory, profiles, documents |
| `users_api.dart` | User account CRUD, role assignments |
| `students_api.dart` | Student CRUD, search, CSV import |
| `attendance_api.dart` | Sessions, marks, corrections, exports |
| `events_api.dart` | Calendar events, school feed posts |
| `fees_api.dart` | Fee structures, invoices, ledger, concessions |
| `fee_payments_api.dart` | Payment recording, requests, receipts, history |
| `leave_api.dart` | Leave requests, approvals, balances |
| `communications_api.dart` | Chat, complaints, announcements, event posts |
| `timetable_api.dart` | Timetable CRUD, publish, copy-day, export |
| `homework_api.dart` | Diary CRUD, submissions, feedback |
| `tables_raw_api.dart` | Raw table queries (academic years, grades, sections, subjects) |
| `approval_requests_api.dart` | Approval center queries and actions |
| `monitoring_api.dart` | System health, error event list and management |
| `notifications_api.dart` | Notification list, mark-read, device token registration |
| `help_api.dart` | Help content by role |
| `issues_api.dart` | Issue reporting |
| `demo_api.dart` | Demo credential fetch and validation |
| `request_coalescing.dart` | Deduplication of concurrent identical GET calls |
| `client_interceptors.dart` | All Dio interceptors (Auth, Cache, Error, Logging, Demo) |

---

## 7. Caching Strategy

### Cache Store

- **Type:** Hive-backed persistent disk cache (`dio_cache_interceptor_hive_store`)
- **Location:** `<ApplicationSupportDirectory>/schooldesk_http_cache`
- **Scope key:** `user_id | branch_id | role` encoded as a URI fragment — ensures cache isolation per user per branch per role

### Cacheable Paths

Only GET requests to these paths are cached:

| Path Pattern | TTL | Notes |
|-------------|-----|-------|
| `/dashboard/` | 3 minutes | Refreshed by Realtime invalidation |
| `/students` | 5 minutes | Invalidated on student write |
| `/staff` | 5 minutes | |
| `/schools` | 10 minutes | School profile rarely changes |
| `/academic-years` | 10 minutes | |
| `/grades` | 10 minutes | |
| `/sections` | 10 minutes | |
| `/timetable` | 5 minutes | |
| `/subjects` | 10 minutes | |
| `/homework` | 3 minutes | |
| `/calendar` | 5 minutes | |
| `/notifications` | 2 minutes | |
| `/help` | 30 minutes | Rarely changes |

### Non-Cacheable Paths (Always Fresh)

- `/auth/*` — session data must always be live
- `/uploads` — upload operations are always real-time
- `/payment-requests` — payment state must be live
- `/payments` — payment state must be live
- `/attendance/sessions` — attendance must be live
- `/attendance/staff/qr-token` — QR tokens are ephemeral

### Cache Invalidation

**On write (mutation):**
- `_WriteCacheInvalidationInterceptor` intercepts all non-GET requests
- Specific patterns are deleted from Hive cache:
  - Student mutations: `/students`, `/dashboard/`
  - Academic year mutations: `/academic-years`, `/dashboard/`
  - Branch switch: entire Hive cache is wiped

**On Realtime invalidation signal:**
- Supabase Realtime pushes an invalidation channel event
- Client receives the signal and calls `client.invalidateCachedReads()`
- This clears in-memory dashboards + Hive cache; next request is always a fresh network call

**On user switch:**
- `setCurrentUserId` clears all in-memory caches
- The Hive cache is per-user-scoped by key, so stale data from a previous user is never served

### Force Refresh

- Pass `extra: {_forceRefreshCacheExtraKey: true}` on any GET request to bypass cache
- Used for pull-to-refresh patterns and after critical mutations

---

## 8. Request Coalescing

**File:** `lib/core/network/api_modules/request_coalescing.dart`

When multiple widgets or providers simultaneously request the same endpoint (e.g., dashboard data on initial load), request coalescing deduplicates them:

- Concurrent identical GET requests to the same URL + query + scope are collapsed into a single in-flight request
- All callers receive the same response
- Coalesced GETs are cleared on user change, branch change, or full cache invalidation
- This prevents N identical HTTP requests on a multi-widget dashboard load

---

## 9. Performance Targets & Optimization

### API Response Time Targets

| Endpoint Class | Target (p95) | Notes |
|----------------|--------------|-------|
| Dashboard (cached) | < 100 ms | Served from Hive |
| Dashboard (cold) | < 800 ms | Single PostgreSQL aggregate query |
| Student list (cached) | < 100 ms | |
| Student list (cold, 500 students) | < 1.2 s | Paginated; RLS-scoped |
| Timetable load | < 600 ms | Preloaded on class selection |
| Attendance session create | < 400 ms | |
| Fee ledger (student) | < 700 ms | Balance computed server-side |
| Payment record | < 500 ms | Atomic; receipt generated |
| File upload (1 MB) | < 3 s | Direct-to-Supabase Storage |
| Push notification delivery | < 5 s | Via notification-processor + FCM |

### Known Performance Optimizations Already Applied

1. **Request coalescing** — prevents N dashboard requests on boot
2. **Dio cache with Hive** — eliminates repeat GETs for stable data
3. **User+branch-scoped cache keys** — prevents cross-user cache pollution
4. **Timetable slot type alignment migration** — `slot_type` column + index for fast slot queries (`0014_timetable_slot_type_alignment.sql`)
5. **Targeted RLS performance hardening** — `20260813043653_targeted_performance_rls_security_hardening.sql` adds partial indexes and reduces RLS plan cost for high-traffic tables
6. **Fee category hydration** — `fees.ts` loads categories separately to avoid ambiguous PostgREST embed join that caused runtime errors
7. **Paginated student queries** — student list uses cursor-based pagination to cap response size
8. **Sections sort order** — `20260711113716_sections_sort_order.sql` adds a sort column to avoid in-app sort on load
9. **Student attendance marked_at index** — `20260705142256_add_student_attendance_marked_at.sql` indexes `marked_at` for session queries
10. **Chat Realtime scope** — `20260706180000_chat_realtime_scope.sql` scopes Realtime to branch/conversation to reduce noise

### Performance Implementation Requirements (Pending / To Implement)

| # | Requirement | Priority | Notes |
|---|-------------|----------|-------|
| P1 | Add database-level composite indexes on (branch_id, status, created_at) for fees, students, and attendance tables | HIGH | Missing on high-traffic tables |
| P2 | Add `pg_stat_statements` monitoring query to the monitoring handler | HIGH | Needed to identify slow queries in production |
| P3 | Implement response streaming for large PDF report generation | MEDIUM | `report_pdf.ts` currently buffers entire PDF before responding |
| P4 | Add request timing logs to Edge Function handlers (per-handler latency) | HIGH | Currently no per-handler timing instrumentation |
| P5 | Implement stale-while-revalidate TTL for dashboard (serve cache, refresh in background) | MEDIUM | Currently cache-or-network; no background refresh |
| P6 | Add Dart Isolate for large JSON deserialization (>500KB payloads) | MEDIUM | Communication handler returns large payloads |
| P7 | Implement partial cache invalidation for timetable (slot-level, not full wipe) | LOW | Currently wipes all timetable cache on any slot mutation |
| P8 | Add image compression before upload in `image_upload_optimizer.dart` | HIGH | Already has the file; confirm it is invoked for all photo uploads |
| P9 | Add loading timeout UI (show skeleton for max 3s, then show error + retry) | HIGH | Currently unlimited skeleton; must not block users indefinitely |
| P10 | Add ETags / If-None-Match support for frequently-polling endpoints | LOW | Future optimization; Hive cache is sufficient for now |

---

## 10. Realtime & Invalidation

### Realtime Architecture Principle

Supabase Realtime in SchoolDesk carries **invalidation signals only** — it never delivers raw data payloads. When a signal arrives, the client discards its cache and issues a fresh scoped API request.

This avoids:
- Broadcasting sensitive data over Realtime channels
- Stale client-side state from missed Realtime events
- Complex client-side merge logic

### Realtime Channels

| Channel | Scope | Invalidates |
|---------|-------|-------------|
| Attendance invalidation | Branch | Dashboard attendance widget, session list |
| Fee update | Branch (Principal only) | Fee ledger, dashboard fee tile |
| Announcement / post | Branch | School feed, gallery |
| Chat message | Conversation | Chat message list |
| Notification | User | Notification center badge |
| Error event | Super Admin | Monitoring error list |

### Realtime Subscription Management

- Subscriptions are established after successful login
- Subscriptions are torn down on logout
- Demo sessions must not subscribe to production Realtime channels
- Chat Realtime is scoped per branch and per conversation to limit noise (`20260706180000_chat_realtime_scope.sql`, `20260804120000_chat_scope_and_realtime_rls.sql`)

---

## 11. Branch Isolation in the Network Layer

### Header Enforcement

Every authenticated request carries:

```
x-schooldesk-branch-id: <uuid>
```

This header is:
- Set by `BackendApiClient.setActiveBranchId()`
- Validated server-side by the Edge Function against the authenticated user's branch memberships
- Never trusted as the sole authorization signal — it is a hint; the JWT and RLS policies are authoritative

### Branch Switch Sequence

```
1. Principal selects new branch in UI
2. BackendApiClient.setActiveBranchId(newId) is called
3. In-memory caches cleared (school, dashboards, coalesced GETs)
4. Persistent Hive cache fully wiped
5. New branch ID written to secure storage (TokenStorageService)
6. x-schooldesk-branch-id header updated
7. Dashboard re-fetched with new branch context
8. If fetch fails: actionable error shown (not silent fallback to old branch)
```

### Coordinator Branch Lock

- Coordinator has no branch selector in UI
- Branch ID is read from the server-resolved membership on login and is immutable for the session
- Any API call that the Coordinator makes with a forged branch ID is rejected server-side by RLS

---

## 12. Role-Based API Enforcement

### Server-Side Role Resolution

The Edge Function resolves role from the authenticated JWT metadata, not from any client-supplied header or query param. The handler pattern is:

```typescript
const role = await resolveUserRole(supabase, userId);
// role is: 'principal' | 'coordinator' | 'teacher' | 'parent' | 'super_admin' | 'kiosk'
```

### Fees Enforcement (Principal Only)

The `fees.ts` handler enforces at entry:

```typescript
if (role !== 'principal') {
  return new Response(JSON.stringify({ error: 'Forbidden' }), { status: 403 });
}
```

This is the server-side enforcement. The Flutter client also hides all fee navigation for non-principal roles, but this is defense-in-depth only — the server rejects any unauthorized request regardless of what the client sends.

### Teacher Scope Enforcement

`teacher_scope.ts` uses `resolveTeacherClassScope()` to ensure teachers can only query data for classes they are explicitly assigned to. A teacher cannot query another class's attendance, roster, or timetable.

### Parent Scope Enforcement

`parent.ts` and related handlers use `resolveParentChildScope()` to restrict all parent queries to the parent's explicitly linked children. A parent cannot query another child's data.

### Role Name Normalization

Legacy data may contain `admin` as a role name. The Edge Function normalizes `admin` → `coordinator` in `20260711051214_fix_role_name_casing_and_super_admin.sql` and in the authorization helper to ensure consistent enforcement.

---

## 13. Finance API — Safety & Atomicity

### Core Safety Requirements

All payment-recording operations must satisfy:

| Property | Implementation |
|----------|---------------|
| **Idempotent** | Payment requests carry an idempotency key; duplicate submissions return the existing result |
| **Atomic** | Payment creation + invoice update + receipt snapshot happen in a single database transaction |
| **Auditable** | Every payment is logged in the audit table with user, branch, amount, method, and timestamp |
| **Immutable** | No DELETE or UPDATE on payment rows; corrections are additive reversal records |

### Fee Category Hydration Fix

PostgREST cannot resolve an ambiguous embed when `fee_structures` has more than one relationship to `fee_categories`. The `fees.ts` handler:

```typescript
// DO NOT use: fee_structures?select=*,category:fee_categories(*)
// USE: load fee_categories separately, then hydrate
const structures = await supabase.from('fee_structures').select('*').eq('branch_id', branchId);
const categories = await supabase.from('fee_categories').select('*').eq('branch_id', branchId);
// Hydrate: structures[].category and structures[].fee_category both populated
```

This preserves the Flutter contract while avoiding the runtime `Could not embed because more than one relationship was found` error.

### Orphaned Fee Cleanup

`20260706180300_orphaned_fee_cleanup.sql` — A scheduled cleanup function removes fee structures that are no longer linked to any active academic year. This prevents phantom fee obligations on the ledger.

### Receipt Snapshots

`20260729173723_automatic_payment_receipt_snapshots.sql` — A PostgreSQL trigger automatically creates a receipt snapshot row every time a payment is finalized. Receipt data is immutable from creation.

### Known Finance Issue — Critical

The current worktree contains a payment-delete code path that physically deletes payment-related rows through separate operations. This violates the immutable financial history requirement. This path must be replaced with an audited atomic reversal before any production finance release.

---

## 14. File Uploads & Storage

### Upload Pipeline

```
Flutter client
  → compress image (image_upload_optimizer.dart, if image)
  → _multipartUpload() creates MultipartFile from path or bytes
  → POST /uploads with multipart/form-data
  → uploads.ts handler receives file
  → uploads.ts uploads to Supabase Storage (signed upload URL or service-role upload)
  → returns public or signed URL
```

### Storage Buckets

| Bucket | Access | Contents |
|--------|--------|---------|
| `school-assets` | Mixed (being migrated to private) | Student documents, avatars, exports — CRITICAL: private records must move to private bucket |
| `school-media` | Public (curated) | Approved gallery photos, event post media |
| `private-documents` | Private + signed URL | Finance documents, payslips, signed receipts |
| `website-media` | Public | Public school website images and videos |

### Private Document Access

All private documents are accessed via signed, time-limited URLs generated by `storage_helpers.ts`:

```typescript
const { data } = await supabase.storage
  .from('private-documents')
  .createSignedUrl(path, 3600); // 1-hour expiry
```

Clients must never receive a raw storage path for private assets — only signed URLs with expiry.

### Upload Security

- File type validation is enforced server-side in `uploads.ts` (allowed MIME types, max file size)
- Storage policies in `20260810132041_media_egress_and_private_files.sql` enforce bucket-level access rules
- Public bucket listing is disabled via `20260720093000_prevent_public_website_media_listing.sql`

---

## 15. Notification Pipeline

### FCM Push Delivery

```
Event occurs (payment, attendance, leave approval, etc.)
  → PostgreSQL trigger fires
  → Inserts row into notifications table
  → notification-processor Edge Function runs on pg_cron schedule
  → Queries pending notifications grouped by user
  → Calls FCM API with device token
  → Updates notification delivery status
  → Failed tokens are logged; no silent drops
```

### Notification Types

| Type | Recipients | Trigger |
|------|-----------|---------|
| Attendance reminder | Teacher | Session not marked by threshold time |
| Attendance marked | Parent | Child marked present/absent |
| Leave request | Principal, Coordinator | Parent or Teacher submits leave |
| Leave decision | Parent / Teacher | Leave approved or rejected |
| Payment request | Principal | Parent submits payment proof |
| Payment approved | Parent | Principal approves payment |
| Event post approved | Teacher | Post approved by leadership |
| New chat message | Recipient | Message sent in conversation |
| Birthday alert | Parent, Class Teacher | Student birthday (1 day prior) |
| Health reminder | Parent | Scheduled health reminder |
| Announcement | Branch (all roles) | Leadership posts announcement |

### Device Token Management

- FCM tokens are stored in `device_tokens` table (unique per user per device)
- Duplicate active token prevention: `20260706210000_unique_active_fcm_token_index.sql`
- Token sharing fix (multi-device): `20260706200000_fix_fcm_token_sharing.sql`
- Production hardening: `20260802044553_notification_production_hardening.sql`
- Push delivery scope: birthday and health reminders limited to target users `20260712191838_limit_birthday_health_push_delivery.sql`

### Cron Schedule

`20260705133149_configure_notification_processor_cron.sql` — Configures the notification processor to run on a pg_cron schedule (every minute) to batch and deliver pending push notifications.

---

## 16. Database Schema Overview

### Core Schema Migrations

| Migration | Contents |
|-----------|---------|
| `0001_core_academic_schema.sql` | Academic years, terms, grades, sections, subjects, curriculum |
| `0002_people_auth_schema.sql` | Users, staff, students, parents, guardians, memberships |
| `0003_attendance_fees_leave_timetable.sql` | Attendance sessions/marks, fee structures/invoices/payments, leave, timetable slots |
| `0004_communications_operations.sql` | Chat, announcements, complaints, event posts, notifications |
| `0005_rls_policies.sql` | Base RLS policies for all tables |
| `0006_calendar_ptm_schema.sql` | Calendar events, PTM scheduling |
| `0011_fee_workflow_alignment.sql` | Fee receipt, installment, and concession workflow |
| `0014_timetable_slot_type_alignment.sql` | `slot_type` enum: regular, teaching, break, free |
| `0015_storage_bucket.sql` | Storage bucket configuration |
| `0019_unified_chat.sql` | Unified chat model |
| `0021_notification_push_support.sql` | FCM push token and notification delivery tables |

### Key Tables

| Table | Purpose | Branch-scoped |
|-------|---------|---------------|
| `academic_years` | Academic year definitions | YES |
| `grades` | Grade levels | YES |
| `sections` | Class sections with teacher assignments | YES |
| `subjects` | Subject definitions | YES |
| `timetable_slots` | Class timetable entries | YES |
| `students` | Student records | YES |
| `staff` | Staff/teacher records | YES |
| `users` | All user accounts | YES |
| `attendance_sessions` | Daily attendance sessions per class | YES |
| `attendance_marks` | Individual attendance records | YES |
| `fee_categories` | Fee type definitions | YES |
| `fee_structures` | Fee amount and schedule definitions | YES |
| `fee_invoices` | Student fee obligations | YES |
| `payments` | Payment records (immutable) | YES |
| `payment_receipts` | Snapshot receipts (immutable) | YES |
| `conversations` | Chat conversations | YES |
| `messages` | Chat messages | YES |
| `notifications` | In-app notification queue | Per user |
| `device_tokens` | FCM device tokens | Per user |
| `audit_logs` | Audit trail | YES |
| `school_website` | Public website content | YES |
| `admission_inquiries` | Public inquiry submissions | YES |
| `leave_requests` | Teacher and student leave | YES |
| `homework_entries` | Diary/homework entries | YES |
| `homework_submissions` | Parent/student diary submissions | YES |
| `health_reminders` | Health reminder records | YES |
| `issues` | User-reported issues | Per user |

---

## 17. RLS Policies & Security

### RLS Policy Design Principles

Every table with school data has RLS enabled. Policies follow this pattern:

```sql
-- Example: Students are only visible to users in the same branch
CREATE POLICY "students_branch_isolation" ON students
  FOR SELECT
  USING (
    branch_id = get_active_branch_id()  -- server-resolved from JWT metadata
    AND is_member_of_branch(auth.uid(), branch_id)
  );
```

### Key RLS Migrations

| Migration | Purpose |
|-----------|---------|
| `0005_rls_policies.sql` | Base RLS for all core tables |
| `20260711120000_secure_rls_policies.sql` | Security hardening pass |
| `20260728163519_finance_balance_first_security_and_documents.sql` | Finance document security |
| `20260804120000_chat_scope_and_realtime_rls.sql` | Chat Realtime RLS |
| `20260810132041_media_egress_and_private_files.sql` | Storage egress policies |
| `20260813043653_targeted_performance_rls_security_hardening.sql` | RLS performance + security |
| `20260811161601_isolate_teacher_parent_leave_rows.sql` | Leave row isolation by role |
| `20260813100000_principal_workflow_hardening.sql` | Principal-only route hardening |

### SECURITY DEFINER Functions

Several functions use `SECURITY DEFINER` to run with elevated privileges. Each must:
- Have a fixed `search_path` to prevent schema injection
- Be granted only to the roles that require it
- Be documented with the reason for elevated privileges

All SECURITY DEFINER functions must be audited per the advisor findings (Known Issue #3).

### RLS Initialization Plan Warning

Some RLS policies trigger a plan-time initialization cost because the policy expressions call functions that cannot be inlined. `20260813043653_targeted_performance_rls_security_hardening.sql` adds materialized CTEs and partial indexes to reduce this overhead on high-traffic tables (attendance, fees, students).

---

## 18. Error Handling & Retry Strategy

### Flutter Client Error Handling

The `_ErrorInterceptor` normalizes all Dio errors:

| HTTP Status | Behavior |
|-------------|----------|
| 401 | Trigger token refresh; retry once; logout on failure |
| 403 | Return `PermissionDeniedException`; show permission-denied UI |
| 404 | Return `NotFoundException`; show empty state or not-found UI |
| 409 | Return `ConflictException`; show conflict state with user action required |
| 422 | Return `ValidationException` with field errors; show inline form errors |
| 429 | Return `RateLimitException`; show retry-with-backoff UI |
| 500+ | Return `ServerException`; show error + retry button |
| Network timeout | Return `NetworkException`; show offline/retry UI |
| Connection refused | Return `NetworkException`; show offline/retry UI |

### Visible Error States (Required on Every Surface)

Every data-loading surface must implement these states explicitly:
- **Loading skeleton** — shown immediately on first load
- **Error with retry** — shown when API fails; includes retry button and error message
- **Empty state** — shown when API succeeds but returns zero items; distinct from error
- **Permission denied** — shown when the server returns 403; must not show as empty
- **Stale data warning** — shown when serving cached data while network request is in-flight (optional but recommended)

### Retry Policy

- Network errors: up to 3 automatic retries with exponential backoff (500ms, 1s, 2s)
- 401: 1 token-refresh-and-retry; no loop
- 403/404: no retry; immediate error state
- 5xx: 1 automatic retry after 1s; then error state shown

---

## 19. Audit Logging

### Audit-Logged Operations

| Operation | Table | Required Fields |
|-----------|-------|----------------|
| Account creation/edit/deactivation | `audit_logs` | user_id, target_user_id, action, branch_id, timestamp |
| Role assignment change | `audit_logs` | user_id, target_user_id, old_role, new_role, branch_id, timestamp |
| Fee payment recorded | `audit_logs` | user_id, student_id, amount, method, invoice_id, branch_id, timestamp |
| Fee concession applied | `audit_logs` | user_id, student_id, concession_amount, reason, branch_id, timestamp |
| Payment reversal | `audit_logs` | user_id, original_payment_id, reason, branch_id, timestamp |
| Student import (Sheets) | `audit_logs` | user_id, branch_id, rows_attempted, rows_succeeded, rows_failed, timestamp |
| Student export (Sheets) | `audit_logs` | user_id, branch_id, rows_exported, timestamp |
| Branch switch | `audit_logs` | user_id, old_branch_id, new_branch_id, timestamp |
| Attendance correction | `audit_logs` | user_id, session_id, student_id, old_status, new_status, branch_id, timestamp |
| Approval decision | `audit_logs` | user_id, request_id, decision, reason, branch_id, timestamp |
| Document upload/delete | `audit_logs` | user_id, document_type, action, branch_id, timestamp |
| Error event manual cleanup | `audit_logs` | super_admin_user_id, event_ids, confirmation_code, timestamp |

---

## 20. Manual Student Spreadsheet Exchange (Sheets API)

### Required Sequence

```
1. Principal/Coordinator selects exactly one active branch
2. POST /sheets/pull — exports current student data for that branch
3. User edits the exported sheet using the supported template
4. POST /sheets/sync — submits edited data for import
5. Server validates: branch, student identifiers, baseline version, required fields, relationships
6. Successful rows are created or updated; failed rows returned with actionable errors
7. Audit record created for the entire import operation
```

### Conflict Safety Rules

- **SchoolDesk wins conflicts:** if a student record was modified after the pull, the push for that row is rejected with a stale-conflict error
- **No auto-delete:** a missing or blank row in the sheet does not delete the student; only explicit delete operations (outside Sheets) can remove students
- **One branch per operation:** a push must specify exactly one branch; cross-branch pushes are rejected
- **Baseline version required:** the push must include the version/fingerprint captured during the pull; a stale baseline triggers a stale-conflict rejection
- **Explicit identifiers:** student and branch are matched by UUID, never by name or ambiguous section label

### Handler Files

| File | Purpose |
|------|---------|
| `supabase/functions/api/handlers/sheets_pull.ts` | Export student data for Sheets |
| `supabase/functions/api/handlers/sheets_sync.ts` | Import and validate Sheets data |

### Known Security Issue

A hardcoded privileged fallback token exists in the Sheets route authorization. This must be removed and rotated before production use. See Known Issue #1.

---

## 21. Backend Verification Checklist

Run these checks before every production deployment:

### Type Checks

```bash
# Supabase Edge Function type check
/home/vinay/.deno/bin/deno check supabase/functions/api/index.ts

# Web portal
cd schooldesk-web && bun run typecheck
```

### Static Analysis

```bash
flutter analyze --no-pub
```

### Unit Tests (serial, low-memory)

```bash
flutter test --no-pub --concurrency=1 test/unit/backend_target_switching_test.dart
flutter test --no-pub --concurrency=1 test/unit/timetable_management_contract_test.dart
flutter test --no-pub --concurrency=1 test/unit/timetable_csv_import_contract_test.dart
flutter test --no-pub --concurrency=1 test/unit/admin_run2_backend_contract_test.dart
flutter test --no-pub --concurrency=1 test/unit/error_retention_realtime_contract_test.dart
flutter test --no-pub --concurrency=1 test/unit/demo_branch_website_contract_test.dart
```

### Web Tests

```bash
cd schooldesk-web && bun test
```

### Database Migration Lint

```bash
npx supabase db lint
```

### Health Check (Live)

```
GET https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api/health
GET https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api/ready
# Both must return 200 with success body
```

### Smoke Tests (Live)

| Test | Steps |
|------|-------|
| Principal login | Sign in, resolve branch, load dashboard |
| Coordinator login | Sign in, verify branch lock, verify Fees hidden |
| Teacher login | Sign in, load class roster, mark attendance |
| Parent login | Sign in, view child attendance, view fee balance |
| Branch switch | Principal switches branch, verify cache cleared, verify new data |
| Fees rejection | Coordinator attempts /fees route, verify 403 |
| Timetable publish | Create slot, preview, publish, verify in teacher view |
| Student Sheets pull | Pull student data, verify row count, verify baseline version |
| Student Sheets sync | Push modified row, verify stale-conflict on concurrent edit |
| Payment record | Record cash payment, verify receipt generated, verify audit log |

---

## 22. Performance Monitoring & Observability

### Current Monitoring Surfaces

| Surface | Access | Notes |
|---------|--------|-------|
| `/monitoring/*` Edge API | Principal, Super Admin | Error events, retention metrics, system health |
| `/system-monitor-screen` (mobile) | Principal | Error event list, system status |
| `/super-admin-system-monitor-screen` | Super Admin | Full error retention management |
| Supabase dashboard | Supabase project team | Database metrics, Edge Function logs, storage usage |

### Recommended Additions (Not Yet Implemented)

| # | Recommendation | Implementation |
|---|----------------|----------------|
| M1 | Per-handler latency logging in Edge Functions | Add `console.time`/`console.timeEnd` around DB queries; visible in Supabase function logs |
| M2 | Slow query detection | Enable `pg_stat_statements`; expose top slow queries via monitoring handler |
| M3 | Cache hit rate tracking | Add `cache_hit` field to API response headers; log miss rate in Flutter |
| M4 | API error rate dashboard | Aggregate error events by handler, role, and time in `monitoring.ts` |
| M5 | Storage egress monitoring | Track signed URL generation count and download sizes per branch |
| M6 | FCM delivery failure rate | Log and surface failed FCM sends in monitoring handler |
| M7 | Supabase Advisor automated check | Run advisor checks as part of CI migration lint step |

---

## 23. Known Backend Issues & Remediation Plan

| # | Issue | Severity | Handler / Migration | Remediation |
|---|-------|----------|--------------------|-|
| 1 | Hardcoded privileged fallback token in Sheets route authorization | CRITICAL | `sheets_pull.ts`, `sheets_sync.ts` | Remove token, rotate secret, audit repository history |
| 2 | Dashboard authorization does not reject lower-privileged users requesting a higher role's path | CRITICAL | `dashboard.ts` | Add strict role check at handler entry; return 403 for mismatched role requests |
| 3 | Supabase Advisor warnings: SECURITY DEFINER wrappers, mutable search paths, leaked-password protection disabled, public storage listing, RLS initialization plans, permissive-policy overlap, duplicate index | CRITICAL | Multiple migrations | Disposition each warning: fix search paths, enable leaked-password protection, audit SECURITY DEFINER grants, remove duplicate index |
| 4 | `school-assets` bucket listing is public; private records (student docs, avatars) must be moved to a private bucket with signed URL access | CRITICAL | `0015_storage_bucket.sql`, `uploads.ts` | Create private bucket, migrate existing assets, update all upload and fetch paths to use signed URLs |
| 5 | Shared mobile role-access loading collapses backend failures into empty data | HIGH | Flutter `lib/features/*/` | Separate failure and empty states at every data-loading widget; add retry affordance |
| 6 | Web portal branch-switch failure silently reverts to old branch state | HIGH | `schooldesk-web/` | Show actionable error banner on branch-switch failure; do not silently revert |
| 7 | Integration tests contain manual/TODO stubs; do not prove real login, branch isolation, or finance workflows | HIGH | `integration_test/`, `test/` | Replace stubs with real authenticated integration tests per smoke test checklist |
| 8 | Payment-delete path physically deletes payment rows; violates immutable financial history | CRITICAL | `fee_payments_api.dart`, `fees.ts` | Replace with audited atomic reversal; remove physical DELETE from payment workflow |
| 9 | "Dairy" UI label used instead of "Diary" across teacher and parent screens | MEDIUM | `lib/features/homework/` | Rename all user-visible "Dairy" labels to "Diary" across all routes and screen titles |
| 10 | `pg_stat_statements` not enabled; no per-query latency visibility | HIGH | Supabase project settings | Enable extension; add slow query threshold alert via monitoring handler |
