# SchoolDesk Role Feature and Backend Call Matrix

Generated from the current Flutter routes, role drawers, and `BackendApiClient` contract.

Date: 2026-05-05

## Legend

| Status | Meaning |
|---|---|
| Complete | Screen is routed, uses backend calls for primary data, and supports expected read/write flow. |
| Partial | Screen exists and at least some backend calls are wired, but one or more actions are placeholder, raw/generic, locally simulated, or need deeper QA. |
| UI-only / Needs API | Screen exists but the main workflow is not clearly backed by a dedicated API call yet. |
| Shared | Cross-role function used by multiple modules. |

## Shared Authentication and Session

| Area | Required functionality | Frontend files | Backend calls | Roles | Current status | Notes / verification focus |
|---|---|---|---|---|---|---|
| Login | Authenticate user, resolve actual role, route to correct dashboard | `lib/presentation/auth_login_screen/auth_login_screen.dart`, `lib/features/auth/presentation/controllers/auth_controller.dart`, `lib/services/backend_api_client.dart` | `POST /api/auth/login` | Principal, Admin, Teacher, Parent | Complete | Principal API smoke was verified. Continue role-wise login QA with real created users. |
| Refresh token | Refresh expired JWT and retry failed request | `lib/services/backend_api_client.dart` | `POST /api/auth/refresh` | All | Complete | `_ErrorInterceptor` retries 401 except auth routes. Verify with expired token test. |
| Logout | Server logout, clear local tokens, clear role access, return to landing | `lib/services/logout_service.dart`, role drawers, settings | `POST /api/auth/logout` | All | Complete | Fixed to use root navigator and shared confirmation. Needs manual tap QA after next app run. |
| Current profile | Load authenticated user profile | `lib/services/backend_api_client.dart`, settings/profile screens | `GET /api/auth/profile` | All | Complete | Used for authenticated account context. |
| Notifications | List and mark notifications | `lib/presentation/notification_center_screen`, `lib/services/backend_api_client.dart` | `GET /api/notifications`, `PUT /api/notifications/:id/read` | All | Partial | Backend list/read calls exist. Verify per-role notification visibility and creation source. |
| Settings | Profile, password, logout, app settings | `lib/presentation/settings_screen/settings_screen.dart` | Logout via `POST /api/auth/logout`; profile through profile routes/client | All | Partial | Logout fixed. Password/profile edit should be separately verified. |

## Principal Module

| Module / screen | Required functionality | Frontend route / files | Backend calls | Current status | Notes / gaps |
|---|---|---|---|---|---|
| Dashboard | School-level KPIs, staff/student/fee/attendance overview | `/principal-dashboard-screen`, `lib/presentation/principal_dashboard_screen` | `GET /api/dashboard/principal` | Complete | Should show aggregated metrics scoped to principal school. |
| Staff Management | Create staff, edit staff, delete staff, custom department, create login credentials, account role | `/staff-management-screen`, `lib/presentation/staff_management_screen/*` | `GET /api/staff`, `POST /api/staff`, `PUT /api/staff/:id`, `DELETE /api/staff/:id` | Complete | Strongest staff flow. Supports password/login role on create. Department name is resolved/created by backend. |
| Student Oversight | Search/filter students, view student detail, export request, add note, send parent alert | `/student-oversight-screen`, `lib/presentation/student_oversight_screen/*` | `GET /api/students`, `GET /api/sections`, `GET /api/grades`, raw `POST /api/student-reports/exports`, raw `POST /api/student-notes`, raw `POST /api/student-alerts` | Partial | Read path is real. Note/export/alert use generic raw APIs and need dedicated backend verification. |
| Approval Center | Review pending approvals | `/approval-center-screen` | Likely leave/approval endpoints | Partial | Need inspect each action and verify writes against backend. |
| Access & Permissions | Review/manage Admin and Teacher login accounts | `/principal-user-management-screen`, `AdminUserAccessScreen(ownerRole: principal)` | `GET /api/users`, `POST /api/users`, `PATCH /api/users/:id`, `DELETE /api/users/:id`, optional `POST /api/parents/:id/students` | Complete | Principal view is constrained to Admin/Teacher. UI clarified staff vs user account workflows. |
| Timetable | Manage class/teacher timetable | `/timetable-management-screen` | `GET /api/timetable/slots`, raw/timetable CRUD helpers as implemented | Partial | Backend client has slot/substitution reads. Full create/update/delete must be verified screen-by-screen. |
| Syllabus Monitor | Track syllabus coverage | `/syllabus-monitoring-screen` | Not clearly dedicated in `BackendApiClient` | UI-only / Needs API | Add/verify syllabus endpoints if this must be production-grade. |
| Exams & Results | Manage exam schedules/results | `/exams-results-screen` | `GET /api/exams`, `GET /api/exams/types`, `POST /api/exams` | Partial | Core exam calls exist. Result entry and publishing need dedicated verification. |
| Academic Management | Academic years, grades, sections, terms, subjects | `/academic-management-screen` | `GET /api/academic-years`, `GET /api/grades`, `GET /api/sections`, `GET /api/academic-years/:id/terms` | Partial | Read calls exist. Confirm create/update/delete coverage in screen. |
| Fee Monitoring | Fee KPIs and invoice tracking | `/fee-monitoring-screen` | `GET /api/fee-structures`, `GET /api/invoices`, `GET /api/students/:id/fees` | Partial | Verify fee assignment/payment workflows separately. |
| Communication | Announcements/events/circulars | `/communication-center-screen` | `GET /api/announcements`, `POST /api/announcements`, `POST /api/events`, `GET /api/events` | Partial | Core create/list exists. Verify audience targeting and role visibility. |
| Complaints | Complaint/helpdesk review | `/complaint-management-screen` | Raw/generic or screen-local calls to verify | Partial | Needs backend endpoint trace for complaint create/update/status. |
| Events & Calendar | Calendar/event listing and creation | `/events-calendar-screen` | `GET /api/events`, `POST /api/events` | Partial | Event calls exist. Verify create/edit/delete and audience visibility. |
| Reports | Reports and analytics | `/reports-analytics-screen` | Dashboard/report/raw endpoints depending on screen | Partial | Needs per-report backend trace and export behavior QA. |
| Analytics Dashboard | Higher-level analytics | `/principal-analytics-screen` | `GET /api/dashboard/principal` and/or raw analytics calls | Partial | Confirm no mock-only metrics remain. |

## Admin Module

| Module / screen | Required functionality | Frontend route / files | Backend calls | Current status | Notes / gaps |
|---|---|---|---|---|---|
| Dashboard | Admin KPIs, quick access modules | `/admin-dashboard-screen` | `GET /api/dashboard/admin` | Complete | Dashboard call is available through `getDashboard('admin')`. |
| Student Administration | List/search/filter students, add/edit/delete, transfer, promote, TC workflow | `/admin-students-screen`, `lib/presentation/admin_students_screen/admin_students_screen.dart` | `GET /api/students`, `POST /api/students`, `PUT /api/students/:id`, `DELETE /api/students/:id`, `GET /api/grades`, `GET /api/sections` | Complete | Recently fixed section labels, update persistence, transfer/promote/TC status writes. |
| Teacher & Staff | Staff list, create staff with login/password, edit, remove, custom department | `/admin-teachers-screen` now routes to `StaffManagementScreen(ownerRole: admin)` | `GET /api/staff`, `POST /api/staff`, `PUT /api/staff/:id`, `DELETE /api/staff/:id` | Complete | Admin no longer uses older shallow teacher screen. |
| Attendance | Class attendance sessions and marking | `/admin-attendance-screen` | `GET /api/attendance/sessions`, `POST /api/attendance/sessions`, `POST /api/attendance/mark`, `GET /api/attendance/summary` | Partial | Backend client supports sessions/marking/summary. Verify screen payloads and class/date filters. |
| Fees & Finance | Fee structures, invoices, payment recording | `/admin-fees-screen` | `GET /api/fee-structures`, `GET /api/invoices`, `POST /api/payments`, `GET /api/students/:id/fees` | Partial | Confirm assignment, overdue, stats, payment marking UI. |
| Timetable | Manage slots and substitutions | `/admin-timetable-screen` | `GET /api/timetable/slots`, `GET /api/timetable/substitutions`, timetable raw writes if used | Partial | Verify create/update/delete slot writes. |
| Exam Administration | Exam schedule and types | `/admin-exams-screen` | `GET /api/exams`, `GET /api/exams/types`, `POST /api/exams` | Partial | Bulk marks/results flow needs endpoint confirmation. |
| Communication | Announcements, circulars, audience messaging | `/admin-communication-screen` | `GET /api/announcements`, `POST /api/announcements`, `GET /api/events`, `POST /api/events` | Partial | Verify target role delivery. |
| Parent Helpdesk | Parent tickets/complaints | `/admin-helpdesk-screen` | Not clearly dedicated in `BackendApiClient` | UI-only / Needs API | Needs explicit helpdesk endpoints or raw mapping verification. |
| Documents & Certs | Student/staff certificates and document workflows | `/admin-documents-screen` | Not clearly dedicated in `BackendApiClient` | UI-only / Needs API | Confirm whether docs are local placeholders or persisted. |
| User & Access | Create/manage Parent accounts, assign linked students | `/admin-user-access-screen` | `GET /api/users`, `POST /api/users`, `PATCH /api/users/:id`, `DELETE /api/users/:id`, `POST /api/parents/:parent_user_id/students` | Complete | Admin view handles Parent accounts and student linkage. |
| Reports & Compliance | Reports, exports, compliance data | `/admin-reports-screen` | Mixed dashboard/raw calls depending on report | Partial | Needs per-report backend endpoint trace. |
| Academic Info | Read academic/school information | `/admin-academic-info-screen` | Shared academic/school reads | Partial | Confirm all displayed blocks are backend-sourced. |
| ID Card Generation | Generate student/staff ID cards | `/id-card-generation-screen` | Likely student/staff reads; generation output may be client-side | Partial | Verify save/export behavior. |

## Teacher Module

| Module / screen | Required functionality | Frontend route / files | Backend calls | Current status | Notes / gaps |
|---|---|---|---|---|---|
| Dashboard | Teacher scoped KPIs, assigned classes/students | `/teacher-dashboard-screen` | `GET /api/dashboard/teacher`, `GET /api/students`, timetable reads | Complete | Prior fixes normalized teacher dashboard role/data. |
| My Classes | Assigned classes and roster | `/teacher-classes-screen` | `GET /api/sections`, `GET /api/students`, `GET /api/timetable/slots` | Partial | Verify teacher scoping by linked staff ID. |
| Attendance | Load class students, mark attendance, correction requests | `/teacher-attendance-screen` | `GET /api/students`, `POST /api/attendance/mark`, `GET /api/attendance/sessions` | Complete / Partial | Core marking exists. Correction request path should be verified. |
| Homework | Create/update homework for class/students | `/teacher-homework-screen` | Raw/generic homework endpoints if used | Partial | Needs dedicated backend trace for homework CRUD and parent visibility. |
| Lesson Planner | Lesson plan creation and tracking | `/teacher-lesson-planner-screen` | Not clearly dedicated in `BackendApiClient` | UI-only / Needs API | Add/verify lesson plan endpoints. |
| Student Performance | Marks/grades/performance review | `/teacher-performance-screen` | `GET /api/exams`, `GET /api/students/:id/marks`, possible raw grades calls | Partial | Verify grade write/bulk entry endpoints. |
| Student Notes | Notes for student observations | `/teacher-student-notes-screen` | Raw/generic student-note endpoints if used | Partial | Confirm notes persist and are scoped. |
| Resources | Teaching resources/files | `/teacher-resources-screen` | Not clearly dedicated in `BackendApiClient` | UI-only / Needs API | Needs backend storage/document endpoints. |
| Communication | Teacher announcements/messages | `/teacher-communication-screen` | `GET /api/announcements`, message raw endpoints if used | Partial | Verify teacher-created messages and inbox. |
| Parent Interaction | Parent messaging / PTM | `/teacher-parent-interaction-screen` | PTM/message endpoints likely raw or HR comms | Partial | Needs endpoint trace and parent-side confirmation. |
| Leave | Submit and view leave | `/teacher-leave-screen` | `GET /api/leave/applications`, `POST /api/leave/applications` | Partial | Submit/list calls exist. Approver flow is principal/admin. |
| Discipline / Incidents | Record and escalate incidents | `/teacher-discipline-screen` | Raw complaint/incident endpoints if used | Partial | Verify escalation writes to complaints/approval backend. |
| Reports | Teacher reports | `/teacher-reports-screen` | Dashboard/report/raw endpoints | Partial | Verify report generation and data source. |
| Class Diary | Diary entries for class/parents | `/teacher-diary-screen` | Diary/message raw endpoints if used | Partial | Backend permissions mention diary, but screen calls need trace. |
| Academic Info | Read academic information | `/teacher-academic-info-screen` | Shared academic/school reads | Partial | Confirm backend source for all visible content. |

## Parent Module

| Module / screen | Required functionality | Frontend route / files | Backend calls | Current status | Notes / gaps |
|---|---|---|---|---|---|
| Dashboard | Linked children summary, fees, attendance, homework | `/parent-dashboard-screen` | `GET /api/me/students`, `GET /api/dashboard/parent` if used | Complete / Partial | Linked child normalization exists. Verify dashboard endpoint usage in screen. |
| Academic Progress | Child marks/progress | `/parent-academic-progress-screen` | `GET /api/me/students`, `GET /api/students/:id/marks` | Partial | Verify marks and report-card data. |
| Attendance | Child attendance | `/parent-attendance-screen` | `GET /api/me/students`, `GET /api/students/:id/attendance`, `GET /api/attendance/summary` | Complete / Partial | Read calls exist. Verify month/year filters. |
| Homework | Child homework | `/parent-homework-screen` | Homework raw/dedicated endpoints if used | Partial | Must match teacher-created homework. |
| Class Diary | Diary entries | `/parent-diary-screen` | `GET /api/me/students`, diary endpoints if used | Partial | Verify teacher diary visibility. |
| School Notices | Announcements/notices | `/parent-notices-screen` | `GET /api/announcements`, notifications | Partial | Verify target audience filtering. |
| Teacher Chat / PTM | Parent-teacher chat and meeting booking | `/parent-teacher-chat-screen` | PTM/message endpoints likely raw or HR comms | Partial | Needs end-to-end teacher/parent verification. |
| Fee Management | Fee invoices/status | `/parent-fees-screen` | `GET /api/me/students`, `GET /api/students/:id/fees` | Complete / Partial | Fee read path exists. Payment flow separate. |
| Pay & Receipts | Payment and receipt view | `/fee-payment-receipt-screen` | `POST /api/payments`, `GET /api/invoices` or student fees | Partial | Verify payment posting, receipt status, and backend balance update. |
| Leave Requests | Student leave requests | `/parent-leave-screen` | Raw/dedicated leave endpoints if used | Partial | Teacher leave API exists; student leave needs trace. |
| Events & Calendar | School events | `/parent-calendar-screen` | `GET /api/events` | Partial | Verify parent target filtering. |
| Documents & Certs | Child documents/certificates | `/parent-documents-screen` | `GET /api/me/students`, document endpoints if used | Partial | Needs storage/backend persistence verification. |
| Academic Info | Read academic/school information | `/parent-academic-info-screen` | Shared academic/school reads | Partial | Confirm backend source for all visible content. |

## Core Backend Endpoint Inventory Used by Flutter

| Domain | Backend calls from `BackendApiClient` | Main consumers |
|---|---|---|
| Auth | `POST /auth/login`, `POST /auth/logout`, `POST /auth/refresh`, `GET /auth/profile` | All roles |
| Dashboard | `GET /dashboard/:role` | Principal, Admin, Teacher, Parent if enabled |
| School setup | `GET /schools`, `GET /academic-years`, `GET /grades`, `GET /sections`, `GET /academic-years/:id/terms` | Academic, staff/student forms, timetable, exams |
| Staff | `GET /staff`, `GET /staff/:id`, `POST /staff`, `PUT /staff/:id`, `DELETE /staff/:id` | Principal Staff Management, Admin Teacher & Staff |
| Students | `GET /students`, `GET /students/:id`, `POST /students`, `PUT /students/:id`, `DELETE /students/:id`, `GET /students/:id/enrollments` | Admin, Principal, Teacher, Parent-linked flows |
| Parent links | `GET /me/students`, `POST /parents/:parent_user_id/students` | Parent module, Admin user access |
| Users/access | `GET /users`, `POST /users`, `PATCH /users/:id`, `DELETE /users/:id` | Principal user management, Admin user access |
| Attendance | `GET /attendance/sessions`, `POST /attendance/sessions`, `POST /attendance/mark`, `GET /attendance/summary` | Admin and Teacher attendance, Parent attendance |
| Exams | `GET /exams`, `GET /exams/types`, `POST /exams`, `GET /students/:id/marks` | Admin exams, Principal exams, Teacher performance, Parent progress |
| Fees | `GET /students/:id/fees`, `GET /fee-structures`, `GET /invoices`, `POST /payments` | Admin fees, Principal fee monitoring, Parent fees/payment |
| Leave | `GET /leave/applications`, `POST /leave/applications`, decision endpoint | Teacher leave, Staff/approval flows |
| Communication | `GET /announcements`, `POST /announcements`, `GET /events`, `POST /events` | Principal/Admin communication, notices, events |
| Notifications | `GET /notifications`, `PUT /notifications/:id/read` | All role notification center |
| Timetable | `GET /timetable/slots`, `GET /timetable/substitutions` | Principal/Admin timetable, Teacher classes |
| Generic raw helpers | `GET/POST/PUT/DELETE` via `getRawList`, `createRaw`, `updateRaw`, `deleteRaw` | Student notes, alerts, exports, modules still being hardened |

## High-Priority Remaining Backend Integration Checks

| Priority | Area | Why it matters | Expected action |
|---|---|---|---|
| P0 | Role-wise logout manual QA | Code fixed, but user reported failure across modules | On next device run, verify Principal/Admin/Teacher/Parent drawer and settings logout all call `/api/auth/logout` and clear tokens. |
| P0 | Admin Student Administration | Recently fixed backend write persistence | Test add, edit, promote, transfer, delete and confirm DB state after each action. |
| P0 | Admin Teacher & Staff | Admin now routes to production staff management screen | Test add staff with password, login as created staff, edit, custom department, delete/deactivate linked user. |
| P1 | Parent-linked child flows | Parent module depends on `/me/students` and assigned links | Verify Admin-created parent user can be linked to admission number and parent sees only linked children. |
| P1 | Fee payment | Financial data must be exact | Verify payment post updates invoice paid/balance/status and parent/admin views match. |
| P1 | Attendance | Core school workflow | Verify teacher/admin marking, parent readback, dashboard counts, and date filters. |
| P1 | Homework/diary/chat/resources/documents | Several screens appear to use raw or not-yet-dedicated APIs | Trace each screen and replace UI-only placeholders with dedicated backend endpoints where needed. |
| P2 | Reports/exports | Production readiness requires reliable generated artifacts | Confirm exports are persisted, downloadable, and role-scoped. |

## Step 2 RBAC Relationship Policy Update - 2026-05-08

Backend Step 2 is complete for the current Go API contract. The detailed policy
record is saved in `docs/backend-step2-rbac-relationship-policy.md`.

Verified automated status:

- `go test ./internal/handlers -run 'TestTeacherStudentSubresourcesRejectOutsideSection|TestParentStudentLinkListIsScopedToAuthenticatedParent|TestTeacherStudentListIsScopedToAssignedSections|TestTeacherCannotCreateAttendanceSessionForUnassignedSection|TestAttendanceMarkRejectsStudentOutsideSessionSection|TestParentHomeworkAndDiaryListsAreScopedToLinkedStudents|TestParentMessagingAndPTMAreParticipantScoped' -count=1` passes.
- `go test ./...` passes.
- API suite report: 54 total, 54 passed, 0 failed, 100% success.

Policy behaviors now covered by automated backend checks:

- Parent sees only linked children and linked child subresources.
- Teacher sees only assigned-section students and is denied outside-class
  attendance, fees, marks, and transport.
- Attendance session creation and marking validates teacher/section/student
  relationships.
- Homework, diary, messages, conversations, and PTM records are role scoped.
- Critical writes for attendance, marks, leave, fees, messages, and approvals
  continue to produce audit records.

Still pending beyond Step 2:

- Database-level foreign keys/composite unique indexes and integrity probes.
- Manual Flutter role smoke for Principal, Admin, Teacher, and Parent.
- Typed backend hardening for syllabus, helpdesk, documents, resources, student
  leave, reports/exports, and workflows still relying on raw/generic records.
