# SchoolDesk V1 — Project Analysis Report
_Generated: June 16, 2026_

---

## 1. Project Overview

**SchoolDesk** is a full-stack school management ERP with:
- **Frontend**: Flutter (v3.9 SDK, Material 3) targeting Android, iOS, and Web
- **Backend**: Go (Gin + GORM) with PostgreSQL (prod) / SQLite (dev)
- **Infrastructure**: Docker Compose, Redis (caching + rate-limit), Firebase FCM (push notifications), Razorpay (payments)
- **Roles**: Principal, Admin, Teacher, Parent, Kiosk (5 distinct actors)
- **Feature surface**: Auth, Academics, Attendance, Finance/Fees, Homework, Timetable, Leave, Events/Gallery, Communication, Reports, Documents, Profile, Notifications

---

## 2. Strengths (What's Working Well)

| Area | Observations |
|---|---|
| Clean architecture | Frontend follows data / domain / presentation layering per module; all 16 modules are consistently structured. |
| Security fundamentals | JWT with JTI revocation, `auth_invalidated_at` guard, school-scope middleware, RBAC on every route. |
| Token rotation | Refresh-token rotation with Redis-backed revocation is implemented correctly in `auth.go`. |
| DB resilience | Startup retry logic, connection pooling config, phased AutoMigrate, supplemental schema, and relationship constraints. |
| Rate limiting | Applied granularly per operation category (`staff_write`, `fee_write`, `attendance_write`, etc.). |
| Route access guard | Client-side RBAC (`RouteAccessGuard`) consistently mirrors server RBAC — good defence-in-depth. |
| Approval flows | Principal → Admin approval workflows for accounts, classes, students, and general operations all wired end-to-end. |
| Payment flow | Razorpay order-create → verify-payment → webhook loop correctly implemented with idempotency checks. |
| Smart timetable | Constraint-based generation with day-staff reuse and conflict detection is non-trivial and present. |
| Bulk import | CSV import with dry-run preview and history tracking is complete. |

---

## 3. Gaps & Issues Identified

### 3.1 🔴 Critical — Security / Data Integrity

**Issue 1 — Kiosk default password in code**
`school-backend/internal/database/database.go:948`
```go
password = "Kiosk@12345"
```
The fallback kiosk password is hardcoded. If `SCHOOLDESK_KIOSK_PASSWORD` is not set in production `.env`, every school gets the same well-known password. This is a credential leak risk.

**Fix**: Make the env var mandatory in production; throw a fatal error if absent when `cfg.Environment == "production"`.

---

**Issue 2 — `DisableForeignKeyConstraintWhenMigrating: true`**
`database.go:32`
GORM is configured to skip FK constraints during migration. Combined with `EnableRelationshipConstraints` being a config-gated feature (off by default in many envs), the database can accumulate orphaned rows silently.

**Fix**: Enable `EnableRelationshipConstraints` in all non-dev environments and add a startup data-integrity check.

---

**Issue 3 — `/api/v1/payments/razorpay/webhook` is unauthenticated**
`routes.go:777`
```go
api.POST("/webhooks/razorpay", feeHandler.RazorpayWebhook)
```
This endpoint sits **outside** the `AuthMiddleware` and `SchoolScopeMiddleware` chain. The handler must verify the Razorpay `X-Razorpay-Signature` header. If it does not (or inconsistently), malicious actors can forge payment confirmations.

**Fix**: Confirm `feeHandler.RazorpayWebhook` validates the HMAC signature on every call; add an integration test for forged payloads.

---

**Issue 4 — Supabase env vars declared but unused [RESOLVED]**
`lib/core/config/env_config.dart:42–44`
```dart
static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
```
These are defined but never consumed anywhere in the codebase. This suggests an incomplete migration away from Supabase, dead config, or a future integration stub left without a guard. They add confusion and a potential mis-use surface.

**Fix**: Remove if unused, or document clearly and add a `validate()` guard.

---

### 3.2 🟠 High — Route / Access Control Gaps

**Issue 5 — New parent & teacher routes missing from `RouteAccessGuard._routeRoles`**

The following routes are declared in `AppRoutes`, registered in `_roleWorkflowVisibleRoutes`, and navigated to from drawer menus — but are **absent from `_routeRoles`**:

| Route constant | Expected role |
|---|---|
| `AppRoutes.parentTimetable` | parent |
| `AppRoutes.parentExamSchedule` | parent |
| `AppRoutes.parentReportCards` | parent |
| `AppRoutes.parentPTMBooking` | parent |
| `AppRoutes.parentDiscipline` | parent |
| `AppRoutes.teacherEventPosts` | teacher |
| `AppRoutes.teacherLessonPlanner` | teacher |
| `AppRoutes.schoolGallery` | teacher, parent, principal, admin |
| `AppRoutes.principalEventApprovals` | principal |

Because `_routeRoles[routeName]` returns `null`, `redirectFor()` falls through to `return null` (no redirect), meaning **any authenticated role can reach these screens** without a guard. A parent logged in could attempt to navigate to `principalEventApprovals` if they knew the route string.

**Fix**: Add all routes above to `_routeRoles` with correct role sets.

---

**Issue 6 — `homeworkMessaging` route allows default role `'admin'`**
`app_routes.dart:386–387`
```dart
final role = ModalRoute.of(context)?.settings.arguments as String? ?? 'admin';
```
If `homeworkMessaging` is opened without args (e.g., from a push notification deep-link), it silently defaults to `'admin'` role — potentially exposing admin-level data to the wrong user.

**Fix**: Default to `BackendApiClient.instance.currentRoleName` instead of a hard-coded string.

---

**Issue 7 — `notificationCenter`, `settingsScreen`, `profileScreen` default args to `'admin'`**
`app_routes.dart:386, 391, 396`
Same pattern — role defaults to `'admin'` when arguments are null. These screens make role-conditional UI decisions; incorrect role produces wrong UI for teachers and parents arriving via push notification tap.

**Fix**: Resolve role from `BackendApiClient.instance.currentRoleName` as the default.

---

### 3.3 🟠 High — Architecture / State Management

**Issue 8 — Mixed state management (`Provider` + `Riverpod` + local `setState`)**
`pubspec.yaml` declares both `provider: ^6.1.5+1` and `flutter_riverpod: ^3.3.1`. Only `ProviderScope` is used in `main.dart` and `schooldesk_providers.dart`; the rest of the app uses `Provider` and raw `setState`. Riverpod is effectively a dead dependency for most features.

**Impact**: Cognitive overhead; unclear which pattern should be used for new screens; `ProviderScope` wrapping adds widget tree depth with no real benefit if not used.

**Fix**: Either commit to one state management solution (Provider or Riverpod), or at minimum document the intentional coexistence and scope.

---

**Issue 9 — `ServiceLocator` comment acknowledges missing DI framework**
`service_locator.dart:21`
```dart
/// Replace with proper DI framework (get_it) when scaling to production.
```
The comment is a known tech-debt marker. The current implementation uses static singletons that are impossible to mock in unit tests, and `assert()` guards that crash in debug mode if order is wrong. This makes testing difficult as the project grows.

**Fix**: Migrate to `get_it` or `Riverpod` providers for testability.

---

### 3.4 🟡 Medium — Feature Completeness Gaps

**Issue 10 — Library & Transport modules in DB schema but completely absent from API and UI**
`routes.go:647–649`
```go
// Library and transport route groups are intentionally not registered in
// the current product scope.
```
`models/library_transport.go` defines `BookCategory`, `Book`, `BookIssue`, `Vehicle`, `Route`, `RouteStop`, `StudentTransport`. These are migrated to the DB on every startup but have zero API surface, no RBAC, no UI screens, and no routes registered. They consume schema space and create migration time for no current value.

**Fix**: Either build the feature end-to-end, or remove the models from AutoMigrate until ready (use a feature flag or a separate migration phase).

---

**Issue 11 — `BackendAttachmentGapPage` acknowledged in parent-teacher chat**
`parent_teacher_chat_screen.dart:1154`
```dart
MaterialPageRoute(builder: (_) => const _AttachmentBackendGapPage()),
```
This is a known stub — parents cannot send attachments in chat because the backend endpoint is not wired. The UI shows the action but leads to a placeholder page.

**Fix**: Either implement the backend attachment endpoint for messages, or hide the UI action entirely until implemented.

---

**Issue 12 — `teacherHomework` route maps to `TeacherDiaryScreen`**
`app_routes.dart:314`
```dart
teacherHomework: (context) => const TeacherDiaryScreen(),
```
`/teacher-homework-screen` resolves to `TeacherDiaryScreen`, not a homework screen. This aliasing is either intentional (diary = homework diary) or a routing bug. If intentional, the route naming is misleading and the module registry doesn't reflect it.

**Fix**: Clarify intent. If diary and homework are the same screen, rename the route constant. If they should be separate, create `TeacherHomeworkScreen`.

---

**Issue 13 — `teacherPTM` route aliases to `TeacherParentInteractionScreen`**
`app_routes.dart:377`
```dart
teacherPTM: (context) => const TeacherParentInteractionScreen(),
```
Two different route constants (`teacherParentInteraction` and `teacherPTM`) both map to the same screen. The `teacherParentInteraction` route is in `deprecatedProtectedRoutes` — meaning it redirects any authenticated user to their dashboard instead of serving content. The routes need consolidation.

---

### 3.5 🟡 Medium — Production Readiness

**Issue 14 — `env.json` and `env.local.json` committed to version control**
`env.json` contains `http://127.0.0.1:8080/api` (development). `env.local.json` and `env.hostinger.json` also exist in the repo root. These files should be gitignored; sensitive production values must never be in source control.

**Fix**: Add `env.json`, `env.local.json`, `env.hostinger.json` to `.gitignore`; document required env vars in a `env.example.json`.

---

**Issue 15 — `school.db` SQLite file committed to repo**
`school-backend/school.db` is a live SQLite database file committed to source control. This contains real or seed data and should never be in version control.

**Fix**: Add `*.db` and `school.db` to `.gitignore` immediately.

---

**Issue 16 — Production API URL placeholder in `EnvConfig`**
`env_config.dart:18`
```dart
defaultValue: 'https://api.yourschool.com/api',
```
The production fallback URL is a placeholder. If `API_BASE_URL` is not supplied at build time and the app happens to be in release mode, it will attempt to contact a non-existent domain rather than failing fast.

**Fix**: The existing `validate()` method catches this in release mode — confirm it is called before Firebase initializes (it is, in `main()`). Consider making the default value empty to ensure a hard failure rather than a silent wrong URL.

---

**Issue 17 — `go 1.26` in `go.mod` (future version)**
`go.mod:3`
```
go 1.26
```
Go 1.26 has not been released as of mid-2026. This could cause CI/CD pipelines and Docker builds to fail if the toolchain does not match or if this is a typo for `go 1.22` or `go 1.23`.

**Fix**: Verify the actual Go version in use (`go version`) and align `go.mod`.

---

**Issue 18 — Port mismatch between `docker-compose.yml` and `env.json`**

| Location | Port |
|---|---|
| `docker-compose.yml` go-api service | `8080:8080` |
| `env.json` API_BASE_URL | `http://127.0.0.1:8080/api` |
| `EnvConfig._legacyBaseUrl` (dev/web) | `localhost:8090` |

The Flutter dev default is port `8090` but Docker exposes `8080`. A developer running the app without `env.json` on web/desktop will hit connection errors.

**Fix**: Standardise on one port across all config files, or update `_legacyBaseUrl` defaults.

---

### 3.6 🔵 Low — Code Quality / Maintainability

**Issue 19 — `blankRoleModuleScreens = false` flag is dead code**
`app_routes.dart:187`
```dart
static const bool blankRoleModuleScreens = false;
```
This flag and its associated `_buildRouteChild` branch exist to show stub screens for unfinished modules, but it is permanently `false`. The dead branch and `_roleWorkflowVisibleRoutes` set add ~80 lines of maintenance burden.

**Fix**: Remove the flag and the entire blank-screen branch once the feature is stable.

---

**Issue 20 — `deprecatedProtectedRoutes` silently redirects users**
`route_access_guard.dart:33–38`
Four teacher routes (`teacherStudentNotes`, `teacherDiscipline`, `teacherParentInteraction`, `teacherPTM`) are marked deprecated and silently redirect to the dashboard. There is no user-facing message and no removal of the corresponding drawer items — teachers will see the menu item but get bounced back.

**Fix**: Remove the drawer entries for deprecated routes, or provide a "feature coming soon" screen instead of a silent redirect.

---

**Issue 21 — `unawaited(RoleAccessService.initialize())` in `main()`**
`main.dart:23`
```dart
unawaited(RoleAccessService.initialize());
```
Role access data is fetched asynchronously without blocking app startup. If the first screen renders before this completes, role-dependent UI may show incorrect states. This is a known race condition.

**Fix**: Either await the call before `runApp()`, or implement a loading gate that waits for role data before rendering role-sensitive screens.

---

**Issue 22 — Hardcoded `DrawerIndex` integers in route builders**
`app_routes.dart:227–239`
```dart
drawer: AdminDrawer(selectedIndex: 14, onDestinationSelected: (_) {}),
drawerIndex: 14,
```
Drawer indices are magic numbers. If a drawer item is reordered, these will silently highlight the wrong menu item.

**Fix**: Use named constants or derive the index from the route name.

---

## 4. Summary Table

| # | Severity | Area | Issue |
|---|---|---|---|
| 1 | 🔴 Critical | Security | Hardcoded kiosk fallback password |
| 2 | 🔴 Critical | Security | FK constraints disabled by default |
| 3 | 🔴 Critical | Security | Razorpay webhook may lack signature validation |
| 4 | 🔴 Critical | Security | Dead Supabase env vars |
| 5 | 🟠 High | Access Control | 9 new routes missing from `_routeRoles` |
| 6 | 🟠 High | Access Control | `homeworkMessaging` defaults role to `'admin'` |
| 7 | 🟠 High | Access Control | Notification/Settings/Profile routes default role to `'admin'` |
| 8 | 🟠 High | Architecture | Mixed Provider + Riverpod + setState |
| 9 | 🟠 High | Architecture | No proper DI framework (acknowledged tech debt) |
| 10 | 🟡 Medium | Feature | Library & Transport schema exists but no API/UI |
| 11 | 🟡 Medium | Feature | Chat attachment backend is a known stub |
| 12 | 🟡 Medium | Feature | `teacherHomework` route maps to Diary screen |
| 13 | 🟡 Medium | Feature | `teacherPTM` duplicates `teacherParentInteraction` |
| 14 | 🟡 Medium | Prod Readiness | `env.json` / `env.local.json` committed to repo |
| 15 | 🟡 Medium | Prod Readiness | `school.db` SQLite file in version control |
| 16 | 🟡 Medium | Prod Readiness | Production API URL is a placeholder |
| 17 | 🟡 Medium | Prod Readiness | `go 1.26` in `go.mod` (unreleased version) |
| 18 | 🟡 Medium | Prod Readiness | Port mismatch (8080 vs 8090) across config files |
| 19 | 🔵 Low | Code Quality | `blankRoleModuleScreens` dead flag |
| 20 | 🔵 Low | Code Quality | Deprecated routes redirect silently without UX |
| 21 | 🔵 Low | Code Quality | `unawaited(RoleAccessService.initialize())` race condition |
| 22 | 🔵 Low | Code Quality | Magic drawer index numbers |

---

## 5. Recommended Priority Order

1. **Immediate** (before any production deployment):
   - #14, #15 — Remove env/db files from git history
   - #1 — Enforce kiosk password env var in production
   - #3 — Audit Razorpay webhook signature validation
   - #5 — Add missing routes to `_routeRoles`

2. **Next sprint**:
   - #6, #7 — Fix role defaults in route builders
   - #17 — Fix `go.mod` version
   - #18 — Standardise dev port
   - #8 — Decide on one state management approach

3. **Backlog**:
   - #2, #9, #10, #11, #12, #13, #19, #20, #21, #22

---
_End of report._
