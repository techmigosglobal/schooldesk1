---
name: End-to-end integration fix
overview: Replace cache/mock-driven Flutter flows with real backend APIs, complete backend CRUD coverage for all migrated tables, fix broken handler persistence, and enforce parent↔student scoping via admission numbers mapped to parent logins.
todos:
  - id: backend-fix-dates
    content: Fix attendance session/staff attendance/substitution date persistence in handlers
    status: pending
  - id: backend-crud-all
    content: Implement full CRUD + list APIs for all migrated domains and register routes
    status: pending
  - id: backend-parent-link
    content: Add parent-student linkage by admission number and enforce parent scoping APIs
    status: pending
  - id: flutter-repos
    content: Add repositories and expand BackendApiClient for new endpoints
    status: pending
  - id: flutter-migrate-screens
    content: Migrate all screens from LocalStorageService mock keys to real APIs (hybrid caching where appropriate)
    status: pending
  - id: hardening
    content: Improve validation, error handling, and basic performance (pagination, incremental sync)
    status: pending
isProject: false
---

## Goal
Make the app fully functional end-to-end (UI → API → backend → DB → response → UI) across **all screens/modules**, removing mock/local-only domain data where backend tables exist, fixing known backend persistence bugs, and adding missing backend APIs. Use a **hybrid** Flutter data approach: API-first for critical/interactive screens, with optional caching for read-heavy lists.

## Current reality (source of truth)
- **Backend routes** are in `school-backend/main.go`.
- **DB tables** are migrated via `school-backend/internal/database/database.go` (`AutoMigrate`).
- **Many screens** read `SharedPreferences` domain keys via `lib/services/local_storage_service.dart` + bulk hydrator `lib/services/production_data_sync_service.dart`.
- **Known backend bugs**: attendance/session dates, staff attendance times, substitutions date not persisted.

## Key design decisions (based on your answers)
- **Scope**: all screens/modules become real.
- **Flutter strategy**: **hybrid** (API-first for key workflows; caching allowed but must be consistent).
- **Parent scoping**: Admin assigns children to parent login using **student admission number**; a parent can have multiple students.
- **Backend approach**: implement **full-domain** API surface for all migrated tables.

## Implementation plan

### 1) Backend: fix correctness bugs blocking integrations
Update handlers to persist and query correctly.
- `school-backend/internal/handlers/attendance.go`
  - **CreateAttendanceSession**: parse and set `Date` from request (`yyyy-mm-dd`), persist `TimetableSlotID` only if non-empty.
  - **MarkStaffAttendance**: parse and set `Date`, `CheckIn`, `CheckOut` (and validate ordering).
- `school-backend/internal/handlers/timetable.go`
  - **CreateSubstitution**: parse and set `Date`.

Acceptance check: creating attendance sessions/substitutions and re-querying by date returns the same records.

### 2) Backend: introduce explicit “table-level” REST APIs for all migrated domains
Create/extend handlers to support **CRUD + list (pagination/filtering)** for each domain, matching DB models in `school-backend/internal/models/*`.

Files (new or expanded):
- `school-backend/internal/handlers/*` (add missing domain handlers: library, transport, payroll, ptm, docs, complaints/helpdesk, curriculum/syllabus, etc.)
- `school-backend/main.go` (register routes, apply `AuthMiddleware`, `SchoolScopeMiddleware`, RBAC)

Minimum contract (per table group):
- **List**: `GET /<resource>?page=&page_size=&filters...`
- **Get**: `GET /<resource>/:id`
- **Create**: `POST /<resource>`
- **Update**: `PUT /<resource>/:id`
- **Delete**: `DELETE /<resource>/:id` (soft-delete where needed, similar to students)

Also add safe multi-tenant filtering: every list/get/write must be scoped by `school_id` (either column itself or via join, as already done in `GetInvoices`).

### 3) Backend: implement parent↔student linkage using admission numbers
Add a durable mapping so a Parent login only sees assigned children.
- **DB model**: add a new join model (e.g. `ParentStudentLink`):
  - `school_id`, `parent_user_id`, `student_id`, `student_admission_number` (store for audit/debug), timestamps.
- **Admin APIs**:
  - create parent account (if not already): `POST /users` or `POST /auth/register-by-admin`
  - assign children: `POST /parents/:parent_user_id/students` with list of admission numbers
  - list assignments: `GET /parents/:parent_user_id/students`
- **Parent APIs**:
  - `GET /me/students` returns only assigned students (resolved from admission numbers)

Update auth/profile payloads if needed so Flutter can quickly resolve “my children” without downloading all students.

### 4) Backend: authorization and security hardening while expanding APIs
- Keep role allowlists (`RBACMiddleware`) but ensure they’re applied consistently for write endpoints.
- Add resource-level checks for parent/student reads using the mapping in step 3.
- Make CORS and JWT secret requirements explicit for production (`school-backend/internal/config/config.go`).

### 5) Flutter: replace mock/cache-only domain data with real APIs
Refactor screen data flows to stop relying on `LocalStorageService` domain keys as the primary source.

Approach (hybrid):
- **API-first** (must): login flows, student/staff CRUD, attendance marking, timetable CRUD, fees payments/invoices, exams schedule/marks, announcements/events CRUD, approvals, notifications.
- **Cached read** (allowed): read-heavy lists (students/staff/announcements/events) using a repository that caches last-good results and revalidates.

Concrete work:
- Expand `lib/services/backend_api_client.dart` to include the new REST endpoints created in step 2.
- Introduce a thin domain layer:
  - `lib/features/<domain>/data/<domain>_repository.dart` (API + cache)
  - normalize models so UI doesn’t treat IDs as names (e.g., department lookups).
- Update screens in `lib/presentation/**` to:
  - load from repositories instead of `LocalStorageService` keys
  - pass correct identifiers (SectionID, EnrollmentID) rather than labels
  - show consistent loading + retry UX.

### 6) Flutter: fix attendance + timetable flows end-to-end
- Teacher attendance:
  - fetch the teacher’s **SectionID + EnrollmentIDs** from backend (new endpoints if needed)
  - create/find the day’s `AttendanceSession` properly (no placeholder session IDs)
  - post `student_id + enrollment_id` from real data
- Timetable:
  - back the timetable screen with `/timetable/slots` and `/timetable/substitutions` rather than local maps

### 7) Error handling improvements (backend + Flutter)
- Backend:
  - standardize error responses (already uses `models.APIResponse` in many places)
  - add validation errors with fields
  - ensure DB errors are surfaced with request_id
- Flutter:
  - centralize Dio error mapping (extend existing `_handleError` patterns)
  - per-screen: empty/error states with “Retry” that re-calls repositories

### 8) Performance improvements
- Replace “sync everything” patterns:
  - either remove `ProductionDataSyncService.syncAll()` from critical paths, or make it incremental and domain-scoped.
- Backend:
  - add pagination and filtering everywhere
  - ensure joins for school scoping are indexed (as follow-up)

### 9) Verification: end-to-end checklist by role
After implementation, validate flows:
- Admin: create parent, assign children by admission number, create student/staff, fees, exams, timetable.
- Teacher: attendance sessions + marking, marks entry, announcements.
- Parent: `GET /me/students`, view each child’s attendance/fees/marks/notices.
- Principal: approvals, reports/analytics backed by APIs.

## Architecture diagram (target)
```mermaid
flowchart TD
  ui[FlutterScreens] --> repo[DomainRepositories]
  repo --> api[BackendApiClient(Dio)]
  api --> gin[GinRoutesHandlers]
  gin --> gorm[GORMModels]
  gorm --> db[(PostgresOrSQLite)]
  db --> gorm --> gin --> api --> repo --> ui

  gin --> authz[Auth+SchoolScope+RBAC]
  authz --> gin
  gin --> parentLink[ParentStudentLinkChecks]
  parentLink --> gin
```

## Files most impacted
- Backend
  - `school-backend/main.go`
  - `school-backend/internal/handlers/*.go`
  - `school-backend/internal/models/*.go`
  - `school-backend/internal/database/database.go`
  - `school-backend/internal/middleware/auth.go`
- Flutter
  - `lib/services/backend_api_client.dart`
  - `lib/services/production_data_sync_service.dart`
  - `lib/services/local_storage_service.dart`
  - `lib/presentation/**/*screen.dart`
  - `lib/features/**` (new repositories/models)

## Rollout strategy (to keep it safe)
- Do backend correctness fixes first (attendance/substitution).
- Add parent-student linkage + `/me/students` next (unblocks Parent role).
- Implement domain CRUD APIs in batches (library/transport/payroll/ptm/etc.).
- Migrate Flutter screens domain-by-domain, keeping feature flags where needed.
