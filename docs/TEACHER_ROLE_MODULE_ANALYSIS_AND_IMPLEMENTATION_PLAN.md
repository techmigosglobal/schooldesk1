# Teacher Role Module Analysis And Implementation Plan

## Purpose

This document maps every active Teacher portal screen to its current Flutter route, backend contract, cross-role workflow ownership, known gaps, and the tasks needed before treating the Teacher module as production-ready.

The Teacher role is a class-first workspace scoped to assigned staff identity and timetable.

## Source Map

| Area | Current source of truth |
|------|------------------------|
| Teacher routes | `lib/routes/app_routes.dart` |
| Route RBAC | `lib/routes/route_access_guard.dart` |
| Teacher drawer/navigation | `lib/core/widgets/teacher_navigation.dart` |
| Screen registry | `lib/routes/schooldesk_screen_registry.dart` |
| Flutter API facade | `lib/core/network/backend_api_client.dart`, `lib/core/network/api_modules/*` |
| Backend route ownership | `school-backend/internal/routes/routes.go`, `school-backend/internal/routes/dashboard_routes.go` |
| Teacher scoping policies | `school-backend/internal/handlers/policy.go`, `school-backend/internal/handlers/crud.go` |
| Current tests | `school-backend/internal/handlers/relationship_policy_test.go`, `school-backend/tests/api_suite_test.go` |

## Teacher Role Principles

1. Teacher data starts from `GET /api/v1/dashboard/teacher` and `GET /api/v1/me/staff-attendance/today`.
2. Every class-specific read must be scoped to assigned sections (class teacher, timetable slots, or staff_subjects).
3. Teacher screens must not invent student labels, marks, or attendance when backend fields are missing.
4. Teacher write actions (homework, diary, notes, discipline) must be narrowly allowed and auditable.
5. Parent and Admin workflows must publish data that the Teacher module reads; Teacher should not become the owner of school records.

## Active Teacher Route Inventory

| Screen | Route | Flutter screen | Backend contract |
|--------|-------|---------------|------------------|
| Teacher Dashboard | `/teacher-dashboard-screen` | `TeacherDashboardScreen` | `GET /api/v1/dashboard/teacher`, `GET /api/v1/announcements` |
| My Attendance | `/teacher-my-attendance-screen` | `TeacherMyAttendanceScreen` | `GET /api/v1/attendance/staff/me/today`, `POST /api/v1/attendance/staff/qr-scan` |
| My Classes | `/teacher-classes-screen` | `TeacherClassesScreen` | `RoleAccessService.teacherAssignedClasses` (init load) |
| Student Attendance | `/teacher-attendance-screen` | `TeacherAttendanceScreen` | `GET /api/v1/timetable-slots`, `GET /api/v1/students`, `GET /api/v1/attendance/sessions`, `POST /api/v1/attendance/sessions/:id/mark` |
| Homework / Diary | `/teacher-homework-screen` | `TeacherHomeworkScreen` | `GET /api/v1/homework`, `GET /api/v1/homework/:id/submissions`, `POST /api/v1/diary-entries` |
| Homework Form | `/teacher-homework-form-screen` | `TeacherHomeworkFormScreen` | `POST /api/v1/homework`, `PUT /api/v1/homework/:id`, `GET /api/v1/homework/:id/submissions`, `POST /api/v1/homework/:id/submissions/:sid/review` |
| Student Performance | `/teacher-performance-screen` | `TeacherPerformanceScreen` | `GET /api/v1/exams/report-cards`, `GET /api/v1/students/:id/marks` (raw) |
| Student Notes | `/teacher-student-notes-screen` | `TeacherStudentNotesScreen` | `GET /api/v1/student-notes`, `POST /api/v1/student-notes` |
| Communication | `/teacher-communication-screen` | `TeacherCommunicationScreen` | `GET /api/v1/profile`, `GET /api/v1/announcements`, `GET /api/v1/message-conversations`, `GET /api/v1/messages`, `GET /api/v1/communications`, `POST /api/v1/messages`, `PUT /api/v1/messages/:id` |
| Parent Interaction | `/teacher-parent-interaction-screen` | `TeacherParentInteractionScreen` | `GET /api/v1/parent-teacher-meetings`, `POST /api/v1/parent-teacher-meetings`, `PUT /api/v1/parent-teacher-meetings/:id` |
| Leave | `/teacher-leave-screen` | `TeacherLeaveScreen` | `GET /api/v1/dashboard/teacher`, `GET /api/v1/leave/types`, `GET /api/v1/leave/balances`, `GET /api/v1/leave/applications` |
| Apply Leave | `/teacher-leave-request-form-screen` | `TeacherLeaveRequestFormScreen` | `POST /api/v1/leave/applications` |
| Discipline & Incidents | `/teacher-discipline-screen` | `TeacherDisciplineScreen` | `GET /api/v1/discipline-incidents`, `POST /api/v1/discipline-incidents`, `PUT /api/v1/discipline-incidents/:id`, `POST /api/v1/complaints` |
| Reports | `/teacher-reports-screen` | `TeacherReportsScreen` | `GET /api/v1/attendance/sessions`, `GET /api/v1/homework`, `GET /api/v1/raw/*`, `POST /api/v1/reports/exports` ⚠️ |
| Class Diary | `/teacher-diary-screen` | `TeacherDiaryScreen` | `GET /api/v1/diary-entries`, `POST /api/v1/diary-entries` |
| Academic Info | `/teacher-academic-info-screen` | `AcademicInfoScreen(role: teacher)` | Static / pre-loaded data |

## Cross-Role Workflow Matrix

| Workflow | Teacher responsibility | Admin responsibility | Principal responsibility | Parent responsibility |
|----------|----------------------|----------------------|-------------------------|----------------------|
| Homework assignment | Create, update, review submissions via `/homework` | Read all; no direct write | Read all; no direct write | View assigned homework; submit via `/homework/:id/submissions` |
| Class Diary | Create diary entries via `/diary-entries` | Read all; no direct write | Read all; no direct write | View diary entries for linked children |
| Student Notes | Create/read notes via `/student-notes` | Read all | Read all | No access |
| Attendance marking | Mark sessions via `/attendance/sessions/:id/mark` | Create sessions; mark all | Monitor summaries | View child's attendance summary |
| Leave (self) | Apply via `/leave/applications` | Approve/reject | Approve/reject | N/A |
| Student Leave | View/decide via `/student-leave/applications/:id/decision` | View/decide | View/decide | Apply via `/student-leave/applications` |
| Communication | Send/receive messages via `/messages`, `/communications` | Monitor; system announcements | Monitor; system announcements | Send/receive messages |
| Parent Interaction | Schedule PTM via `/parent-teacher-meetings` | Read all | Read all | Request/view PTM |
| Discipline | Create incidents via `/discipline-incidents` | Read all | Read all | No access |
| Reports | Attempt to generate via `/reports/exports` ⚠️ | Full access | Full access | No access |

## Known Gaps

### GAP-1: Teacher Reports screen calls restricted report exports endpoint
**File:** `lib/features/reports/presentation/screens/teacher_reports_screen/teacher_reports_screen.dart`
**Line:** ~285
**Issue:** `BackendApiClient.instance.createReportExport(...)` calls `POST /api/v1/reports/exports`, but `routes.go:362-363` restricts this route to `RBACMiddleware("Admin", "Principal")`. Teachers will receive `403 Forbidden`.
**Severity:** P1 — The Reports UI is visible to teachers but the backend rejects the request.

### GAP-2: Teacher Performance screen uses raw endpoints without scoping verification
**File:** `lib/features/academics/presentation/screens/teacher_performance_screen/teacher_performance_screen.dart`
**Line:** ~63
**Issue:** Calls `getRawList('/exams/report-cards')` and `getRawList('/students/$id/marks')`. The backend `report_cards` endpoint only allows `Admin`/`Principal` RBAC (`routes.go` exam report exports). Teachers may not have permission to read all report cards.
**Severity:** P1 — Potential 403 errors or data leakage if raw endpoints bypass teacher-scoped queries.

### GAP-3: Teacher Academic Info screen has no direct API calls
**File:** `lib/features/academics/presentation/screens/academic_info_screen/academic_info_screen.dart`
**Line:** N/A
**Issue:** Displays pre-loaded data passed via constructor. If data is stale or missing, there is no refresh mechanism.
**Severity:** P2 — UX gap; screen is read-only with no live backend refresh.

### GAP-4: Homework list filter for teacher relies on client-side trust
**File:** `lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_screen.dart`
**Line:** ~37
**Issue:** Teacher homework is fetched via `getHomework()` which queries `/api/v1/homework`. The backend CRUD `applyHomeworkListFilters` does enforce `teacher_id` scoping when `teacher_id` query param is present, but if the Flutter client omits it, the generic CRUD `applyRoleRelationshipScope` enforces teacher scope via `(teacher_id = ? OR section_id IN (?))`. This is safe.
**Severity:** P3 — backend scoping is correct; no gap.

## Backend Scoping Verification

### Teacher-scoped domains (verified in `school-backend/internal/handlers/crud.go`)

| Domain | Teacher scoping enforced | Mechanism |
|--------|------------------------|-----------|
| Homework | ✅ Yes | `teacher_id = staffID OR section_id IN teacherSectionSubquery` |
| Diary entries | ✅ Yes | `teacher_id = staffID OR section_id IN teacherSectionSubquery` |
| Message conversations | ✅ Yes | `teacher_id = staffID` |
| Messages | ✅ Yes | Joins `message_conversations` → `teacher_id = staffID` |
| Parent-teacher meetings | ✅ Yes | `teacher_id = staffID` |
| Student notes | ✅ Yes | Via `frontendResource` RBAC (`Admin`, `Principal`, `Teacher`) and school scope |
| Discipline incidents | ✅ Partial | Via `frontendResource` RBAC (`Admin`, `Principal`, `Teacher`, `Parent`) but no row-level teacher_id scoping in CRUD; any teacher in the school can read/write all discipline incidents. |

**Security finding:** `discipline-incidents` (GAP-5) allows any Teacher to read/write all incidents in the school because `frontendResource` only checks RBAC and school scope, but the generic CRUD `applyRoleRelationshipScope` has **no case for `discipline_incidents`**, so teacher-level row filtering is absent.

## Recommendations

1. **Add Teacher role to `/reports/exports`** or create a teacher-scoped report export category, so the Reports screen works end-to-end.
2. **Add `discipline_incidents` teacher scoping** to `crud.go applyRoleRelationshipScope` — filter by `reporter_id` or `staff_id` to match `currentStaffID(c)`.
3. **Verify `teacher_performance_screen` endpoints** grant Teacher read access. Either add Teacher to `/exams/report-cards` RBAC or create a teacher-scoped marks endpoint.
4. **Wire `academic_info_screen` to backend** or add a refresh API call so it loads current academic year/terms on demand.
