# Teacher & Parent Role Modules — Backend Integration Audit

**Date:** 2026-06-09
**Scope:** Flutter app (`lib/`), Go backend (`school-backend/`)
**Method:** Static code audit — no runtime testing performed

---

## 1. Executive Summary

Both the **Teacher** and **Parent** modules have strong backend integration foundations. Every major screen maps to real Go API endpoints, RBAC middleware is present, and row-level data scoping is enforced for most domains via `school-backend/internal/handlers/crud.go` and `policy.go`.

The largest risks are:
1. **Teacher Reports** — the Flutter screen calls a report-export endpoint that is **Admin/Principal-only** (`403 Forbidden` for teachers).
2. **Discipline incidents** — no teacher row-level scoping; any teacher in the school can read/write all incidents.
3. **Teacher Performance** — uses raw endpoints whose RBAC and scoping for teachers is unverified.
4. **Attendance Sessions** — `GET /attendance/sessions` is not scoped to teacher-assigned sections; any teacher sees all sessions.

---

## 2. Issues Inventory

### P0 — Blockers
*None identified. No data-loss or full-access breaches were found.*

### P1 — Functional Gaps

#### P1-1: Teacher Reports screen calls Admin/Principal-only export endpoint
- **Flutter file:** `lib/features/reports/presentation/screens/teacher_reports_screen/teacher_reports_screen.dart:~285`
- **Flutter API call:** `BackendApiClient.instance.createReportExport(...)`
- **Backend file:** `school-backend/internal/routes/routes.go:362-363`
- **Backend route:** `POST /api/v1/reports/exports` → `RBACMiddleware("Admin", "Principal")`
- **Impact:** Teacher sees a Reports UI with export buttons. Tapping them triggers a `403 Forbidden`.
- **Fix:** Either (a) add `"Teacher"` to the `/reports/exports` RBAC list and add category-level row scoping, or (b) remove Reports from the Teacher navigation until fixed.

#### P1-2: Teacher Performance screen uses raw report-card endpoint without RBAC verification
- **Flutter file:** `lib/features/academics/presentation/screens/teacher_performance_screen/teacher_performance_screen.dart:~63`
- **Flutter API call:** `getRawList('/exams/report-cards')`
- **Backend file:** `school-backend/internal/routes/routes.go` (exam report exports)
- **Backend route:** `/exams/report-cards/exports` is `RBACMiddleware("Admin", "Principal")`
- **Impact:** If the `report-cards` raw route also inherits this RBAC, teachers cannot access it. If a different raw route exists, it may leak report cards across sections.
- **Fix:** Verify the exact endpoint registration and either add Teacher RBAC or create a teacher-scoped marks endpoint.

#### P1-3: Teacher Attendance Sessions list is not scoped to assigned sections
- **Flutter file:** `lib/features/attendance/presentation/screens/teacher_attendance_screen/teacher_attendance_screen.dart:~78`
- **Flutter API call:** `api.getAttendanceSessions()`
- **Backend file:** `school-backend/internal/handlers/attendance.go:~52`
- **Backend route:** `GET /api/v1/attendance/sessions`
- **Impact:** The handler reads `section_id`, `academic_year_id`, and `date` from query params. It does **not** verify that the requesting teacher is assigned to the requested `section_id`. Because `session_id` accepts any section, a teacher could enumerate sessions for sections they do not teach.
- **Gap evidence:** `GetAttendanceSessions` calls `database.DB.Where` with the query params but does **not** call `canAccessSection(c, sectionID)` before listing.
- **Fix:** Add `canAccessSection` validation when `role == "teacher"` and `section_id` is provided.

#### P1-4: Discipline incidents lack teacher row-level scoping
- **Frontend file:** `lib/features/academics/presentation/screens/teacher_discipline_screen/teacher_discipline_screen.dart` (reads/writes via `getRawList('/discipline-incidents')` and `createRaw('/discipline-incidents')`)
- **Backend file:** `school-backend/internal/routes/routes.go:689`
- **Backend route:** `frontendResource("/discipline-incidents", "Admin", "Principal", "Teacher", "Parent")`
- **Impact:** Any authenticated Teacher or Parent in the school can read/write **all** discipline incidents because the generic `frontendResource` CRUD only enforces `school_id` scope. `crud.go` has **no `discipline_incidents` case** in `applyRoleRelationshipScope`.
- **Fix:** Add a `discipline_incidents` case to `applyRoleRelationshipScope` in `crud.go` (e.g., `reporter_id = currentStaffID(c)` for teachers, `student_id IN linkedStudentSubquery(c)` for parents).

#### P1-5: Parent Fees screen may call unscoped invoice endpoints
- **Flutter file:** `lib/features/finance/presentation/screens/parent_fees_screen/parent_fees_screen.dart`
- **Flutter API call:** `getInvoices(studentId: studentId)`
- **Backend file:** `school-backend/internal/routes/routes.go` (fees group)
- **Backend route:** `GET /api/v1/fees` (`feeTable.List`) with `RBACMiddleware("Admin", "Principal", "Parent")`
- **Impact:** The generic CRUD `applyRoleRelationshipScope` has **no `fees` case**. Parents querying `/api/v1/fees` would see all fee records in the school, not just invoices for their linked children.
- **Fix:** Add `fees` row-level scoping to `applyRoleRelationshipScope` (e.g., `student_id IN linkedStudentSubquery(c)` for parents).

### P2 — Warnings

#### P2-1: Teacher Academic Info screen has no live API refresh
- **Flutter file:** `lib/features/academics/presentation/screens/academic_info_screen/academic_info_screen.dart`
- **Impact:** Screen displays static data passed via `constructor`. If the backend academic year or curriculum changes, the teacher sees stale data until the entire app restarts and `RoleAccessService` re-initializes.
- **Fix:** Add an explicit `api.getAcademicYears()` call in the screen's `initState` to refresh data.

#### P2-2: Teacher Dashboard relies on `RoleAccessService` init success but has no retry on error
- **Flutter file:** `lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart:~57`
- **Impact:** If `getDashboard('teacher')` or `getAnnouncements()` fails during `initState`, the screen shows an empty state with no pull-to-refresh or retry CTA.
- **Fix:** Wrap the `FutureBuilder` with an error state that includes a retry button.

#### P2-3: Parent Teacher Chat screen fetches broad data sets without pagination guards
- **Flutter file:** `lib/features/communication/presentation/screens/parent_teacher_chat_screen/parent_teacher_chat_screen.dart:~55`
- **Impact:** Calls `getRawList('/message-conversations')` and `getRawList('/messages')` without explicit `pageSize` limits in the raw API wrapper. For parents with many children, this could load thousands of records.
- **Fix:** Add pagination query parameters or lazy-load conversations in chunks.

#### P2-4: Generic `frontendResource` routes lack fine-grained row scoping for parents
- **Backend file:** `school-backend/internal/routes/routes.go:669-689`
- **Routes:** `/student-documents`, `/documents/access-requests`, `/certificates/requests`, `/student-notes`, `/student-alerts`, `/notice-acknowledgements`, `/discipline-incidents`
- **Impact:** All of these use `frontendResource`, which creates a generic CRUD handler. The CRUD handler applies `school_id` scoping and RBAC, but for parents it only has `applyRoleRelationshipScope` cases for `parent_student_links`, `homework`, `diary_entries`, `message_conversations`, `messages`, and `parent_teacher_meetings`. Any table **not** in that list returns **all school rows** for the parent role.
- **Fix:** Audit every `frontendResource` that includes `"Parent"` and add a corresponding case in `applyRoleRelationshipScope`.

### P3 — Polish

#### P3-1: Teacher navigation badge `teacherHomeworkDue` may be stale
- **Flutter file:** `lib/core/widgets/teacher_navigation.dart:~135`
- **Impact:** `RoleAccessService.teacherHomeworkDue` is populated once at app initialization. If a new homework assignment is created by the same or another teacher, the badge won't update until app restart.
- **Fix:** Refresh the count in `didChangeDependencies` or on drawer open.

#### P3-2: Leave application list for Teacher does not filter by current staff
- **Backend file:** `school-backend/internal/handlers/leave.go:~65`
- **Backend route:** `GET /api/v1/leave/applications` with `RBACMiddleware("Admin", "Principal", "Teacher")`
- **Impact:** The handler reads `staff_id` from the query parameter. A teacher could omit `staff_id` and see leave applications for all staff.
- **Fix:** When `role == "teacher"` and `staff_id` is empty, default `staff_id` to `currentStaffID(c)`.

#### P3-3: Parent Academic Progress screen falls back to empty strings gracefully but does not surface backend errors
- **Flutter file:** `lib/features/reports/presentation/screens/parent_academic_progress_screen/parent_academic_progress_screen.dart`
- **Impact:** API failures are silently swallowed; parent sees "No marks published" instead of an error/retry message.
- **Fix:** Surface API errors with a `try/catch` + `setState(() => _error = ...)` pattern.

---

## 3. Backend Policy & Row-Level Scoping Audit

### 3.1 Middleware Chain

| Layer | File | What it enforces |
|-------|------|-----------------|
| Auth | `internal/middleware/auth.go` | JWT validation, session revocation check, user active status, claims extraction (`user_id`, `role_name`, `school_id`, `linked_type`, `linked_id`) |
| School Scope | `internal/middleware/auth.go:SchoolScopeMiddleware` | Forces `school_id` query param to match token `school_id`; blocks cross-school access |
| RBAC | `internal/middleware/auth.go:RBACMiddleware` | Role string matching (exact) against allowed roles list |
| Permission | `internal/middleware/auth.go:PermissionMiddleware` | Module-level CRUD permissions seeded from `permissions` table. Admin bypasses. Falls back to 403 if no permission row. |

### 3.2 Policy Helpers (`internal/handlers/policy.go`)

| Function | Teacher scoping | Parent scoping |
|----------|----------------|---------------|
| `canAccessStudent` | ✅ `current_section_id IN teacherSectionSubquery` OR enrollment section match | ✅ `parent_user_id = currentUserID` via `ParentStudentLink` |
| `canAccessSection` | ✅ `class_teacher_id = staffID` OR timetable slot match OR staff_subject match | ✅ linked student's section or enrollment |
| `canAccessGrade` | ✅ Same as section, joined to grade | ✅ Same via linked student enrollments |
| `canAccessConversation` | ✅ `teacher_id = staffID` | ✅ `parent_id = currentUserID` AND `student_id IN linkedStudentSubquery` |
| `canAccessParentStudentLink` | ❌ Admin/Principal only | ✅ `parent_user_id == currentUserID` |
| `teacherSectionSubquery` | ✅ Captures class teacher, timetable, and subject assignments | N/A |
| `linkedStudentSubquery` | N/A | ✅ Returns all student IDs linked to the authenticated parent |

### 3.3 CRUD Role Scoping (`internal/handlers/crud.go:applyRoleRelationshipScope`)

| Table | Teacher scoping | Parent scoping |
|-------|----------------|---------------|
| `homework` | ✅ `teacher_id = staffID OR section_id IN teacherSectionSubquery` | ✅ `student_id IN linkedStudentSubquery OR section_id IN linkedSectionSubquery` |
| `diary_entries` | ✅ Same as homework | ✅ Same as homework |
| `message_conversations` | ✅ `teacher_id = staffID` | ✅ `parent_id = currentUserID AND (student_id = '' OR student_id IN linkedStudentSubquery)` |
| `messages` | ✅ Conversation `teacher_id = staffID` | ✅ Conversation `parent_id = currentUserID AND (student_id = '' OR student_id IN linkedStudentSubquery)` |
| `parent_teacher_meetings` | ✅ `teacher_id = staffID` | ✅ `student_id IN linkedStudentSubquery` |
| `parent_student_links` | ❌ Blocked for teachers | ✅ `parent_user_id = currentUserID` |
| `staff_subjects` | ✅ `staff_id = staffID` | ❌ Blocked |
| `grade_subjects` | ❌ Blocked for teachers | ❌ Blocked |
| `terms` | ✅ School-scoped via academic year join | ✅ School-scoped via academic year join |
| `discipline_incidents` | ❌ **Missing** — any teacher sees all | ❌ **Missing** — any parent sees all |
| `fees` | ❌ **Missing** — any teacher sees all | ❌ **Missing** — any parent sees all |
| `student_documents` | ❌ **Missing** | ❌ **Missing** |

**Key security finding:** Tables exposed through `frontendResource` that include `"Parent"` or `"Teacher"` but lack a case in `applyRoleRelationshipScope` default to **school-wide visibility**. This is acceptable for Admin/Principal but incorrect for Teacher and Parent.

---

## 4. Cross-Role Workflow Matrix (Teacher Role)

| Teacher Screen | Reads from | Writes to | Owned by | Verified |
|---------------|-----------|----------|----------|----------|
| Dashboard | `dashboard/teacher`, `announcements` | — | Backend/Admin | ✅ |
| My Attendance | `attendance/staff/me/today` | `attendance/staff/qr-scan` | Backend/Self | ✅ |
| My Classes | `RoleAccessService` cached data | — | Backend/Admin | ⚠️ Cached only |
| Student Attendance | `timetable-slots`, `students`, `attendance/sessions` | `attendance/sessions/:id/mark` | Backend/Admin | ⚠️ Session list unscoped |
| Homework | `homework`, `homework/:id/submissions` | `homework`, `diary-entries` | Teacher/Backend | ✅ (scoped) |
| Performance | `exams/report-cards`, `students/:id/marks` | — | Backend/Admin | ⚠️ RBAC unclear |
| Student Notes | `student-notes` | `student-notes` | Teacher | ✅ |
| Communication | `messages`, `communications`, `conversations` | `messages` | Teacher/Parent | ✅ (scoped) |
| Parent Interaction | `parent-teacher-meetings` | `parent-teacher-meetings` | Teacher/Parent | ✅ (scoped) |
| Leave | `leave/applications`, `leave/balances` | `leave/applications` | Backend/Self | ⚠️ List unscoped |
| Discipline | `discipline-incidents` | `discipline-incidents`, `complaints` | Teacher | ❌ Unscoped |
| Reports | Raw data sources | `reports/exports` | Teacher | ❌ 403 for teachers |
| Diary | `diary-entries` | `diary-entries` | Teacher | ✅ (scoped) |

---

## 5. Recommendations (Prioritized)

1. **[P1-1]** Add Teacher RBAC to `/reports/exports` OR remove Reports from teacher navigation.
2. **[P1-2]** Verify Teacher RBAC on exam report-card endpoints OR provide teacher-scoped marks.
3. **[P1-3]** Add `canAccessSection` gate to `GetAttendanceSessions` when `role == "teacher"`.
4. **[P1-4]** Add `discipline_incidents` case to `applyRoleRelationshipScope` in `crud.go`.
5. **[P1-5]** Add `fees` row scoping in `applyRoleRelationshipScope` for parents.
6. **[P2-4]** Comprehensive audit of all `frontendResource` routes that include `"Parent"` or `"Teacher"` to ensure each has a matching scope case.
7. **[P3-2]** Default `staff_id` to `currentStaffID(c)` in `GetLeaveApplications` when `role == "teacher"`.
