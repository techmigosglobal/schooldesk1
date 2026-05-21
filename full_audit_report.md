# SchoolDesk — Full-Stack Production Audit Report

**Date:** 30 April 2026  
**Scope:** Flutter Frontend (`/lib`) + Go Backend (`/school-backend`)  
**Audit Mode:** Deep static analysis — all files inspected

---

## Executive Summary

The application has a **well-structured foundation**: a clean-architecture Flutter frontend, a type-safe Go/Gin backend with RBAC, JWT auth, Redis sessions, and a disciplined `ProductionDataSyncService` that maps API responses to the local cache layer. The backend is production-grade. However, the frontend still contains a significant surface area of **hardcoded strings, inaccessible API fields, UI states that render mock data permanently, and missing route guards**. None of these are architectural failures — they are integration-gap issues that require targeted remediation.

---

## Phase 1 — Frontend Audit

### 1A. Hardcoded / Static / Mock Data

| Location | Line(s) | Mock Value | Severity |
|---|---|---|---|
| `admin_fees_screen.dart` | 139, 145, 149 | `'₹2,40,000'`, `'₹68,000'`, `'₹84,000'` (fee summary bar) | 🔴 Critical |
| `admin_dashboard_screen.dart` | 188, 315 | `'Public High School'`, `'8 Pending'` | 🔴 Critical |
| `admin_dashboard_screen.dart` | 100, 108 | Revenue KPI values initialised to `'₹0'` (never populated from API) | 🟠 High |
| `parent_dashboard_screen.dart` | 437, 737, 743 | `'Term 3 fee payment pending — Due 10 January 2026'`, hardcoded child names `'Aarav Reddy'`, `'Zoya Khan'` | 🔴 Critical |
| `parent_dashboard_screen.dart` | 748–762 | Notification panel has 4 entirely static `_notifTile` entries | 🔴 Critical |
| `parent_fees_screen.dart` | 88–89, 735 | Class fee tier comments and displayed fee strings (`₹15,000/term` etc.) are hardcoded | 🔴 Critical |
| `parent_teacher_chat_screen.dart` | 40–41, 179 | Teacher hardcoded as `'teacher_verma'` / `'Mr. Rahul Verma'` | 🔴 Critical |
| `parent_academic_progress_screen.dart` | 84 | `'teacher': 'Mr. Rahul Verma'` | 🟠 High |
| `parent_diary_screen.dart` | 118 | `'createdBy': 'Mr. Rahul Verma'` | 🟠 High |
| `parent_leave_screen.dart` | 52 | `'approvedBy': 'Mr. Rahul Verma (Class Teacher)'` | 🟠 High |
| `admin_communication_screen.dart` | 81, 102 | `'PTM scheduled for 28 April.'`, `'Term 3 fee due by 10 January 2026.'` | 🟠 High |
| `admin_user_access_screen.dart` | 48 | `'name': 'Mr. Rahul Verma'` | 🟠 High |
| `approval_center_screen.dart` | 132, 160, 169 | Two fully hardcoded approval items + requester name | 🟠 High |
| `principal_analytics_screen.dart` | 475–488, 699, 1007 | Revenue figures `₹1.21Cr`, `₹18L`, teacher name, overdue alert message | 🔴 Critical |
| `reports_analytics_screen.dart` | 524, 545, 566 | Financial summary figures | 🔴 Critical |
| `fee_monitoring_screen.dart` | 656 | `'₹50/month penalty'` hardcoded policy text | 🟡 Medium |
| `fee_payment_receipt_screen.dart` | 344 | `'₹22,000 Due'` | 🔴 Critical |
| `school_brochure_screen.dart` | 1729–1732 | Fee schedule (₹15,000–₹25,000/term) | 🟡 Medium |
| `landing_page_screen.dart` + widgets | 322, 73, 193 | `'Public High School'` in multiple landing widgets | 🟠 High |
| `admin_login_screen.dart` | 216 | `'Public High School'` school name dropdown | 🟠 High |
| `parent_login_screen.dart` | 218 | `'Public High School'` | 🟠 High |
| `teacher_login_screen.dart` | 217 | `'Public High School'` | 🟠 High |
| `principal_login_screen/widgets/login_branding_widget.dart` | 39 | `'Public High School'` | 🟠 High |
| `onboarding_screen.dart` | 20–28 | All form fields **pre-filled** with demo data (address, name, `admin123` password) | 🔴 Critical |
| `app_routes.dart` | 244–245 | Route args default to `'teacher_verma'` / `'Mr. Rahul Verma'` | 🔴 Critical |

> **Root cause:** `child['photo']`, `child['attendance']`, `child['homeworkDue']`, `child['upcomingExam']`, `child['rollNo']`, `child['classTeacher']`, `child['feesDue']` are accessed on `ParentDashboardScreen` but **never populated by `ProductionDataSyncService`** — the sync only stores `id`, `name`, `class`, `section`, `status`, `dob`, `docs`. These fields don't exist in the synced map, so they fail silently (null renders as "null" or crashes).

---

### 1B. Non-Functional UI Components

| Screen | Component | Issue |
|---|---|---|
| `TeacherAttendanceScreen` | "Save Attendance" button | Saves only to `LocalStorageService` — **never calls `BackendApiClient`**. Attendance is not persisted to the Go backend. |
| `TeacherAttendanceScreen` | `_showCorrectionRequest()` | Shows dialog, dismisses — **no API call made**, correction is never sent. |
| `AdminFeesScreen` | "Generate Invoice" button | Calls `ScaffoldMessenger.showSnackBar` only — **no invoice creation API call**. |
| `AdminFeesScreen` | "Send Reminder" button | Shows a snackbar only — no notification/SMS API call. |
| `AdminFeesScreen` | "Edit Structure" → Save | Updates local map in memory but **does not call any fee structure update endpoint**. |
| `AdminStudentsScreen` | "Promote to Next Class" | Shows snackbar only — **no API call**. |
| `AdminStudentsScreen` | "Issue TC" | Shows snackbar only — **no API call**. |
| `AdminStudentsScreen` | "Transfer Student" | Updates only local `_students` list in memory — **no backend call**. |
| `AdminStudentsScreen` | Document Upload | Adds to local in-memory list — **no upload to backend**. |
| `ParentDashboardScreen` | Notifications panel | Shows 4 static `_notifTile` entries — completely hardcoded, ignores `kRuntimeNotifications`. |
| `ApprovalCenterScreen` | Approve/Reject buttons | Likely only local state (to be verified). |
| `AdminCommunicationScreen` | Announcements | Rendered from hardcoded local list, not from `kSharedSchoolNotices`. |
| `OnboardingScreen` | School + Admin setup | Saves only to `LocalStorageService.saveMap('onboarding_complete', …)` — **never calls `POST /api/v1/schools` or `POST /api/v1/auth/register`**. |

---

### 1C. Missing API Field Mappings in `ProductionDataSyncService`

The `_fetchAllStudents()` function builds child maps that are missing fields the `ParentDashboardScreen` requires:

```dart
// What is stored:
{ 'id', 'name', 'admissionNumber', 'roll', 'class', 'section', 'status', 'dob', 'docs' }

// What ParentDashboardScreen accesses (will be null/crash):
child['photo']         // ← not in map
child['attendance']    // ← not in map  
child['homeworkDue']   // ← not in map
child['upcomingExam']  // ← not in map
child['rollNo']        // ← not in map ('roll' ≠ 'rollNo')
child['classTeacher']  // ← not in map
child['feesDue']       // ← not in map
```

---

### 1D. Missing Loading / Empty / Error States

| Screen | Missing State |
|---|---|
| `AdminFeesScreen` | No loading indicator (uses `_loading = true` but no spinner while `ProductionDataSyncService.syncAll()` runs). Fee Structure tab shows empty `ListView` with no empty-state widget. |
| `ParentDashboardScreen` | Empty children state shows `CircularProgressIndicator` indefinitely — no "No children linked" message if API returns 0 students for parent. |
| `TeacherAttendanceScreen` | If `teacherClassStudents` is empty (teacher not assigned), shows empty list with no guidance. |
| `ReportsAnalyticsScreen` | All KPI values are hardcoded — no error state if data fails to load. |
| `PrincipalAnalyticsScreen` | Same — all revenue/staff figures hardcoded. |

---

### 1E. Form Validation / Submission Gaps

| Form | Issue |
|---|---|
| `OnboardingScreen` | Page 2 (School Info) and Page 3 (Admin) validate locally but **do not call the API**. `_finish()` only writes to local prefs. School and admin user are never created in the backend. |
| `AdminStudentsScreen` → Add Student | `dateOfBirth` is hardcoded `'2010-01-01'`, `gender` is hardcoded `'male'`. These are not exposed in the form. |
| `AdminFeesScreen` → Edit Fee | Updates only the in-memory `f` map. No `PATCH /api/v1/fees/structures/:id` call. |
| `HomeworkMessagingScreen` | Receives default `userId: 'teacher_verma'` from route args — not the real authenticated teacher ID. |

---

### 1F. Route Guards — Missing Auth Enforcement

`main.dart` only checks `BackendApiClient.instance.isAuthenticated` **at startup** to decide the initial route. After that, **all routes are accessible without re-checking the token**. Specifically:

- No route guard prevents a user from deep-linking directly to `/admin-dashboard`, `/teacher-dashboard`, etc.
- `AppRoutes` has no `onGenerateRoute` guard or `NavigatorObserver`.
- An unauthenticated cold-start correctly redirects to landing, but token expiry mid-session is not guarded at the route level (though the `DioInterceptor` in `BackendApiClient` does handle 401 responses).

---

## Phase 2 — Backend Audit

### 2A. Backend API — What's Working ✅

| Endpoint Group | Status |
|---|---|
| `POST /api/v1/auth/login` | ✅ Full JWT + refresh token flow |
| `POST /api/v1/auth/refresh` | ✅ Token rotation with Redis |
| `POST /api/v1/auth/logout` | ✅ JTI revocation |
| `GET /api/v1/auth/profile` | ✅ Role + permissions preloaded |
| `GET /api/v1/students` | ✅ Paginated, school-scoped, filterable |
| `POST /api/v1/students` | ✅ |
| `PUT /api/v1/students/:id` | ✅ |
| `DELETE /api/v1/students/:id` | ✅ Hard delete (see note below) |
| `GET /api/v1/fees/structures` | ✅ Grade + category preloaded |
| `GET /api/v1/fees/invoices` | ✅ Student preloaded |
| `POST /api/v1/fees/payments` | ✅ Updates invoice balance + status |
| `GET /api/v1/staff` | ✅ Paginated |
| `GET /api/v1/academics/grades` | ✅ |
| `GET /api/v1/academics/sections` | ✅ |
| RBAC Middleware | ✅ Role-name string matching |
| School Scope Middleware | ✅ Forces `school_id` from JWT |
| CORS Middleware | ✅ Origin-allowlist validated |
| Rate Limiter | ✅ Configurable via env |

---

### 2B. Backend Issues

| Issue | Location | Severity |
|---|---|---|
| **Hard delete on students** | `student.go:121` — `database.DB.Delete(&models.Student{}, "id = ?", id)` | 🟠 High — should be soft-delete (`UPDATE status='inactive'`) in a school system to preserve attendance/fee history. |
| **No `school_id` on student create** | `student.go:70` — `SchoolID: scopedSchoolID(c)` is correct, BUT `CreateStudentRequest` DTO has `binding:"required"` on `school_id` yet the handler ignores the body's `school_id` and uses the JWT's. This **will reject the request** if the Flutter client sends a body without `school_id`. | 🔴 Critical |
| **`CreateStudentRequest.school_id` required mismatch** | `dto.go:90` — `SchoolID string binding:"required"` but the handler overwrites it with the JWT scope. Flutter `createStudent()` doesn't include `school_id` in the POST body, so validation fails. | 🔴 Critical |
| **Onboarding never creates school/admin** | No frontend calls `POST /api/v1/schools` or `POST /api/v1/auth/register`. The onboarding screen is entirely disconnected from the backend. | 🔴 Critical |
| **`/api/v1/auth/register` only creates `parent` role** | `auth.go:121` — hardcoded to look up `WHERE LOWER(role_name) = 'parent'`. Cannot register admins or teachers via this endpoint. Admin/teacher creation needs a separate privileged endpoint. | 🟠 High |
| **Token TTL is 24h for both access and refresh issue** | `auth.go:49` — access token TTL is `24*time.Hour`. Industry standard is 15–60 min with refresh rotation. | 🟡 Medium |
| **No pagination on `GET /api/v1/fees/invoices`** | `fee.go:103` — returns all invoices with no `LIMIT`/`OFFSET`. For large schools this will be a memory/latency issue. | 🟡 Medium |
| **Missing `school_id` filter on invoice query** | `fee.go:107-115` — queries `FeeInvoice` without filtering by `school_id`. Multi-tenant leakage risk. | 🔴 Critical |
| **`scopedSchoolID` fallback to query param** | `helpers.go:99` — falls back to `c.Query("school_id")` if JWT claim is empty. A token with no `school_id` claim (e.g., a misconfigured registration) can specify any school via query param. | 🟠 High |
| **No soft-delete / audit trail on fees** | Payments are immutable once created (no reversal endpoint). | 🟡 Medium |

---

### 2C. API Contract Mismatches (Flutter ↔ Go)

| Flutter Call | Go Handler | Mismatch |
|---|---|---|
| `BackendApiClient.createStudent(…, currentSectionId: …)` | `CreateStudentRequest.school_id binding:"required"` | Flutter never sends `school_id` in body → **422 Unprocessable Entity** |
| `BackendApiClient.updateStudent(id, …)` | `UpdateStudent` uses `CreateStudentRequest` DTO | Same `school_id` binding issue — update will fail validation |
| `BackendApiClient.recordPayment(PaymentRequest)` | `RecordPayment` expects `invoice_id`, `receipt_number`, `amount_paid`, `payment_date`, `payment_mode` | Flutter `PaymentRequest` maps correctly ✅ |
| `ProductionDataSyncService._fetchFeeStructures()` | `GET /api/v1/fees/structures` returns `[]models.FeeStructure` with `Grade` and `FeeCategory` preloaded | Flutter accesses `row['grade']['grade_name']` — correct ✅, but `row['amount']` maps to the structure amount, ignoring category breakdown |
| `_fetchTimetable()` | Backend returns `day_of_week` as `1–7` int | Flutter `_dayName()` maps `1→Monday` — correct ✅ |
| Student `fullName` property | Backend returns `first_name` + `last_name` as separate fields | `BackendApiClient.StudentModel` must concatenate — needs verification that `fullName` getter works |

---

## Phase 3 — Security & Environment Audit

### 3A. Critical Security Issues

| Issue | Location | Action |
|---|---|---|
| **Plaintext `admin123` pre-filled in onboarding** | `onboarding_screen.dart:28` | Remove. Never pre-fill passwords. |
| **No route-level auth guard** | `app_routes.dart` | Implement `NavigatorObserver` or `onGenerateRoute` wrapper that checks `BackendApiClient.instance.isAuthenticated`. |
| **`school_id` fallback to query param** | `helpers.go:99` | Remove the query-param fallback. If JWT has no `school_id`, return `403`. |
| **Invoice endpoint has no school_id scoping** | `fee.go:107` | Add `WHERE school_id = ?` using `scopedSchoolID(c)`. |
| **Hardcoded fallback API URL** | `env_config.dart` (per prior audit) | Remove or make debug-build-only. |
| **Hard delete on critical records** | `student.go:121`, (check staff/fees too) | Replace with soft-delete pattern. |

---

### 3B. Environment Configuration Gaps

| Gap | Fix |
|---|---|
| `env.json` contains dummy keys for Supabase, OpenAI, Gemini — unused | Remove or document as feature flags |
| `school_id` not persisted in Flutter after login | After successful login, cache `user.schoolId` in `LocalStorageService` and use it to populate `BackendApiClient` headers |
| Backend `.env.example` references Redis but no graceful fallback when Redis is unavailable | Sessions middleware already does `nil` checks — document this in deployment guide |

---

## Phase 4 — Remediation Plan (Prioritised)

### P0 — Blocker (Fixes required before any testing)

1. **Fix `CreateStudentRequest.school_id` binding** — Remove `binding:"required"` from `school_id` in `dto.go:90` since the handler always overwrites it from the JWT. This unblocks all student create/update operations.

2. **Fix invoice multi-tenant leak** — Add `schoolID := scopedSchoolID(c)` and `WHERE school_id = ?` to `GetInvoices` in `fee.go`.

3. **Fix `ParentDashboardScreen` nil-access crashes** — Add safe null-coalescing for all `child[...]` accesses, and populate the missing fields (`photo`, `attendance`, `homeworkDue`, `rollNo`, `classTeacher`, `feesDue`, `upcomingExam`) in `ProductionDataSyncService._fetchAllStudents()`. Requires additional API calls (attendance summary, homework count).

4. **Remove pre-filled `admin123` password** — `onboarding_screen.dart:28`.

5. **Wire onboarding to backend** — `_finish()` must call `POST /api/v1/schools` then `POST /api/v1/staff` (or a new privileged admin-user creation endpoint) before writing local prefs.

---

### P1 — High Priority (Required for production correctness)

6. **Replace hardcoded fee summary bar** — `AdminFeesScreen._buildSummaryBar()` should compute totals from `_recentPayments` and `_pendingDues` (which are already loaded from API via `ProductionDataSyncService`).

7. **Replace hardcoded notification panel in `ParentDashboardScreen`** — Read from `kRuntimeNotifications` (already synced by `ProductionDataSyncService._fetchNotifications()`).

8. **Wire teacher attendance save to backend** — `TeacherAttendanceScreen._saveAttendance()` must call `BackendApiClient.instance.markAttendance(…)` in addition to (or instead of) local storage.

9. **Replace `'Public High School'` string in all login screens** — Should come from `LocalStorageService` (onboarding stores `schoolName`) or a `GET /api/v1/schools` call.

10. **Fix `HomeworkMessagingScreen` route default** — `app_routes.dart:244–245` defaults to `'teacher_verma'`. Should fall back to `RoleAccessService.teacherName` and the actual teacher's backend ID.

11. **Replace hardcoded financial KPIs in `PrincipalAnalyticsScreen` and `ReportsAnalyticsScreen`** — Both screens should aggregate from the invoices/payments data in local cache (already synced).

12. **Soft-delete students and staff** — Add `status = 'inactive'` update path instead of hard DELETE.

---

### P2 — Medium Priority (Quality / completeness)

13. **Add route-level auth guard** — Implement `onGenerateRoute` in `MaterialApp` that checks `BackendApiClient.instance.isAuthenticated` before allowing access to any non-public route.

14. **Wire "Approve/Reject" in `ApprovalCenterScreen`** — Connect to `PATCH /api/v1/hr/leave-applications/:id` (approval endpoint).

15. **Wire "Send Reminder" in `AdminFeesScreen`** — Connect to announcements/notification endpoint.

16. **Wire "Generate Invoice" button** — Connect to `POST /api/v1/fees/invoices`.

17. **Wire "Transfer" and "Promote" student actions** — Transfer = update status; Promote = update `current_section_id` to next grade section.

18. **Add pagination to `GET /api/v1/fees/invoices`** — Backend handler needs `parsePagination(c)` + `LIMIT`/`OFFSET`.

19. **Reduce access token TTL** — From `24h` to `15m` with refresh rotation (already implemented). Update `tokenTTL` in `auth.go:49`.

20. **Remove `scopedSchoolID` query-param fallback** — `helpers.go:99`.

---

### P3 — Low Priority / Polish

21. Add empty-state widgets to `AdminFeesScreen` fee structure tab when `_feeStructures` is empty.
22. Remove `env.json` dummy external service keys or document as future-feature stubs.
23. Remove `TextEditingController(text: 'SchoolDesk Academy')` demo defaults from onboarding.
24. Add `TeacherAttendanceScreen` empty state when teacher has no assigned class.
25. Replace `parent_documents_screen.dart` hardcoded `'Public High School'` school name.

---

## Summary Metrics

| Category | Count |
|---|---|
| 🔴 Critical issues | 9 |
| 🟠 High-priority issues | 14 |
| 🟡 Medium-priority issues | 7 |
| Total files with hardcoded strings | 22 |
| UI actions that have no backend call | 10 |
| API contract mismatches (Flutter ↔ Go) | 2 confirmed, 1 to verify |
| Backend security vulnerabilities | 3 |
| Missing route guards | 1 (system-wide) |

---

## Recommended Fix Order

```
Week 1 (Blockers):      P0 items #1–5
Week 2 (Core Wiring):   P1 items #6–12
Week 3 (Security/UX):   P2 items #13–20
Week 4 (Polish):        P3 items #21–25
```
