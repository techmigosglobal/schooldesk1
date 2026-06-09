# Parent Role Module Analysis And Implementation Plan

## Purpose

This document is the code-grounded implementation plan for the SchoolDesk Parent role module. It maps every active Parent portal screen to its current Flutter route, backend contract, cross-role workflow ownership, known gaps, and the tasks needed before treating the Parent module as production-ready.

The Parent role must remain a family portal: it can only see linked children and can only perform parent-owned actions such as homework submission, payment requests, student leave requests, PTM booking, notice acknowledgement, direct replies, document/certificate requests, profile updates, and notification read state.

## Source Map

| Area | Current source of truth |
| --- | --- |
| Parent routes | `lib/routes/app_routes.dart` |
| Route RBAC | `lib/routes/route_access_guard.dart` |
| Parent drawer/navigation | `lib/core/widgets/parent_navigation.dart` |
| Screen registry | `lib/routes/schooldesk_screen_registry.dart` |
| Flutter API facade | `lib/core/network/backend_api_client.dart`, `lib/core/network/api_modules/*` |
| Parent child linkage | `school-backend/internal/handlers/parent_link.go`, `school-backend/internal/handlers/student.go` |
| Backend route ownership | `school-backend/internal/routes/routes.go` |
| Parent scoping policies | `school-backend/internal/handlers/policy.go`, `school-backend/internal/handlers/crud.go` |
| Current parent tests | `test/unit/parent_module_ui_backend_contract_test.dart`, `test/unit/role_module_coordination_contract_test.dart`, `school-backend/internal/handlers/relationship_policy_test.go`, `school-backend/tests/api_suite_test.go` |

## Parent Role Principles

1. Parent data starts from `GET /api/v1/me/students`.
2. Every child-specific read must be scoped to a linked student.
3. Parent screens must not invent attendance, marks, fees, homework, documents, or teacher labels when backend fields are missing.
4. Parent write actions must be narrowly allowed and auditable.
5. Admin, Principal, and Teacher workflows must publish data that the Parent module reads; Parent should not become the owner of school records.
6. Empty states are acceptable only when they reflect true backend empty responses.

## Active Parent Route Inventory

| Screen | Route | Flutter screen |
| --- | --- | --- |
| Parent Dashboard | `/parent-dashboard-screen` | `ParentDashboardScreen` |
| Academic Progress | `/parent-academic-progress-screen` | `ParentAcademicProgressScreen` |
| Attendance | `/parent-attendance-screen` | `ParentAttendanceScreen` |
| Homework | `/parent-homework-screen` | `ParentHomeworkScreen` |
| Submit Homework | `/parent-homework-screen/submit` | `ParentHomeworkSubmissionScreen` |
| School Notices | `/parent-notices-screen` | `ParentNoticesScreen` |
| Teacher Chat / PTM | `/parent-teacher-chat-screen` | `ParentTeacherChatScreen` |
| Fees | `/parent-fees-screen` | `ParentFeesScreen` |
| Payment Request | `/parent-fees-screen/payment` | `ParentPaymentRequestFormScreen` |
| Pay & Receipts | `/fee-payment-receipt-screen` | `FeePaymentReceiptScreen` |
| Leave Requests | `/parent-leave-screen` | `ParentLeaveScreen` |
| Leave Request Form | `/parent-leave-screen/request` | `ParentLeaveRequestFormScreen` |
| Calendar | `/parent-calendar-screen` | `ParentCalendarScreen` |
| Documents | `/parent-documents-screen` | `ParentDocumentsScreen` |
| Class Diary | `/parent-diary-screen` | `ParentDiaryScreen` |
| Academic Info | `/parent-academic-info-screen` | `AcademicInfoScreen(role: parent)` |
| Notifications | `/notification-center-screen` | `NotificationCenterScreen(role: parent)` |
| Profile | `/profile-screen` | `ProfileManagementScreen(role: parent)` |
| Settings | `/settings-screen` | Shared settings |
| Global Search | `/global-search-screen` | Shared search |
| Homework Feedback | `/homework-messaging-screen` | Shared homework messaging with parent arguments |

## Cross-Role Workflow Matrix

| Workflow | Parent responsibility | Teacher responsibility | Admin responsibility | Principal responsibility |
| --- | --- | --- | --- | --- |
| Parent account and child links | Sign in and view linked children only | Read guardian context when assigned | Create/manage parent accounts and assign children | Supervise guardian directory and may assign/review links |
| Dashboard | Read child rollups and quick actions | Publish operational data through attendance/homework/diary/messages | Maintain student, fee, timetable, exam records | Monitor school-wide data health |
| Attendance | Read summaries and history | Create sessions and mark attendance | Operate attendance records and exports | Monitor attendance and interventions |
| Homework | View assignments, submit/resubmit, read review | Create/update assignments and review submissions | Audit/manage homework records | Monitor homework workflow health |
| Academic progress | View marks, report cards, remarks, request exports | Enter marks, diary remarks, academic feedback | Configure exams, schedules, marks, report cards | Review results and report workflow |
| Fees | View child invoices, submit payment request, download receipts | No direct fee ownership | Own fee structures, invoices, payments, request decisions | Monitor/decide fee requests where enabled |
| Notices | Read and acknowledge notices | Create teacher notices where allowed | Create school notices/circulars | Create leadership notices/circulars |
| Direct communication | Chat with teachers, reply to Principal direct messages | Reply to parent chats and Principal messages | May view/administer communication records | Send direct messages to parents/teachers and manage circulars |
| PTM | View/book available linked-child PTM slots | Create/manage parent meeting slots | Operational oversight | School-wide oversight |
| Student leave | Submit child leave requests | Decide linked/assigned child leave where allowed | Decide requests | Decide requests and monitor approvals |
| Calendar | Read events, holidays, exams, PTM | Publish PTM/class events where allowed | Manage events/exams/holidays | Manage events/exams/holidays |
| Documents | View student documents, request certificates/access | Upload/share academic documents where workflow allows | Manage official documents/certificates | Approve/monitor official documents |

## Screen-By-Screen Analysis And Tasks

### 1. Parent Dashboard

Current behavior:
- Route: `/parent-dashboard-screen`.
- Loads `getMyStudents()`, `getAnnouncements()`, and `getDashboard('parent')`.
- Backend dashboard returns linked child count, pending fee balance, pending invoices, open homework, unread teacher messages, attendance summary, and child fee summaries.
- Child cards are switched with a child selector.

Connected roles:
- Admin/Principal maintain student records, parent links, fees, and announcements.
- Teacher publishes homework, attendance, diary entries, and messages.

Gaps and tasks:
- Add a typed Parent dashboard adapter so the widget does not depend on raw map keys.
- Align all dashboard cards to backend fields from `/dashboard/parent` and `/me/students`; remove any UI field that cannot be explained by those responses.
- Add unread direct Principal message counts from `/communications` or explicitly label them separate from teacher chat unread messages.
- Add tests that assert the dashboard does not show synthetic attendance, homework, class teacher, or fee values.

### 2. Child Linkage And Student Identity

Current behavior:
- Parent screen data starts from `getMyStudents()`.
- Backend `/me/students` is Parent-only and uses parent-student links.
- Admin/Principal can assign parent-student links through `/parents/:parent_user_id/students`.
- Student reads such as `/students/:id`, `/students/:id/attendance`, `/students/:id/fees`, and `/students/:id/marks` use backend access checks.

Connected roles:
- Admin and Principal own student/account setup and links.
- Parent consumes linked records only.

Gaps and tasks:
- Create one reusable Flutter `ParentStudentSelector` model/widget used by dashboard, progress, attendance, homework, fees, leave, documents, and diary.
- Add a small typed `ParentStudentSummary` mapper for `name`, `class`, `section`, `rollNo`, `photo`, `classTeacher`, `attendance`, and `feesDue`.
- Add a focused backend test for `GET /students/:id` denying unlinked Parent access if not already covered by relationship tests.
- Add a Flutter source contract that every Parent child-scoped screen calls `getMyStudents()` or receives a verified linked student argument.

### 3. Academic Progress

Current behavior:
- Route: `/parent-academic-progress-screen`.
- Loads linked students, then for each student:
  - `/students/{studentId}/marks`
  - `/exams/report-cards?student_id={studentId}`
  - `/diary-entries?student_id={studentId}`
- Supports report card export via `/exams/report-cards/exports`.
- Tabs show Marks, Report Cards, and Remarks.

Connected roles:
- Admin/Principal configure exams, schedules, report cards, and publishing.
- Teacher enters marks and diary remarks.
- Principal reviews results and report workflows.

Gaps and tasks:
- Ensure `/students/{id}/marks` and `/exams/report-cards` are strictly linked-student scoped for Parent, including query parameter filtering.
- Replace raw per-child sequential loading with a typed service that can fail per child without breaking the whole screen.
- Add explicit published/unpublished handling so Parent only sees released exam/report data.
- Add report export lifecycle state: requested, processing, ready, failed, downloaded.
- Add tests for unlinked student marks/report-card access and Parent export scope.

### 4. Attendance

Current behavior:
- Route: `/parent-attendance-screen`.
- Loads linked students, `getStudentAttendanceSummary(studentId:)`, and `getStudentLeaveApplications(studentId:)`.
- Current calendar day markers depend on summary/detail availability and intentionally avoid hardcoded present/absent dates.

Connected roles:
- Teacher/Admin/Principal can create sessions and mark attendance.
- Admin/Principal can export attendance reports.
- Parent reads only linked child attendance.

Gaps and tasks:
- Replace summary-only monthly UI with `getStudentAttendanceRecords(studentId, month, year)` once the backend provides day-wise rows consistently.
- Show source labels: total marked days, present, absent, late, and last marked date.
- Keep leave request creation in the dedicated routed leave form; remove duplicate dialog-style leave submission if it still exists in the attendance screen.
- Add regression tests that forbid synthetic `statusMap`/fixed calendar status data.

### 5. Homework And Submission

Current behavior:
- Route: `/parent-homework-screen`.
- Loads linked students and `getHomework(studentId:)`.
- Reads submission state through `getHomeworkSubmissions(homeworkId, studentId:)`.
- Submit route `/parent-homework-screen/submit` uses `submitHomework(homeworkId, studentId, answerText, attachmentUrl)`.
- Backend only allows Parent to submit homework; Teacher/Admin/Principal review.

Connected roles:
- Teacher owns assignment creation and review.
- Parent submits/resubmits until review rules prevent it.
- Admin/Principal can monitor and review where allowed.

Gaps and tasks:
- Make homework status derive from assignment plus submission status rather than assignment `status` alone.
- Add attachment upload/request flow that is backend-backed end to end, not a placeholder attachment page.
- Show teacher review fields: reviewed/needs revision, grade, remarks, reviewed date.
- Add notification coverage: Teacher-created homework should notify linked parents; review should notify the submitting parent.
- Add backend tests for resubmission blocked after reviewed and allowed after needs revision if that is the intended policy.

### 6. School Notices

Current behavior:
- Route: `/parent-notices-screen`.
- Loads `getAnnouncements()` and `/notice-acknowledgements`.
- Parent can acknowledge a notice via frontend record creation.
- Filters are derived from notice title/body/audience/urgent flags.

Connected roles:
- Admin, Principal, and Teacher can create announcements depending on route permissions.
- Parent reads and acknowledges.

Gaps and tasks:
- Filter announcements by target audience and parent visibility on the backend, not only the UI.
- Prevent duplicate acknowledgements for the same parent and notice.
- Add typed notice acknowledgement helper to `BackendApiClient`.
- Add backend validation that acknowledgement `notice_id` exists in the same school and is visible to Parent.
- Add tests for parent-scoped acknowledgement list and duplicate prevention.

### 7. Teacher Chat, PTM, And Principal Direct Messages

Current behavior:
- Route: `/parent-teacher-chat-screen`.
- Loads:
  - `getProfile()`
  - `getMyStudents()`
  - `/message-conversations`
  - `/messages`
  - `/communications`
  - `/parent-teacher-meetings`
  - timetable slots for linked child sections to infer teacher contacts
- Parent can create message conversations, send messages, mark chat messages read, book PTM slots, read/reply to Principal direct messages, and mark direct messages read.

Connected roles:
- Teacher owns parent chat and PTM slot flow.
- Principal can send direct one-to-one communications to Parent and Teacher.
- Admin/Principal can supervise message records.

Gaps and tasks:
- Split the UI into clear tabs: Teacher Chats, PTM Slots, Principal Messages.
- Add a typed conversation service for `/message-conversations` and `/messages`.
- Normalize sender roles to lowercase consistently before backend writes.
- Do not rely only on timetable slots to discover teachers; prefer backend conversation/teacher participant APIs and use timetable only as an optional source.
- Add direct Principal message reply tests for Parent using `/communications`.
- Add read-receipt tests for both `/messages` and `/communications`.
- Add attachment upload support for chat if product scope requires file/image messages.

### 8. Fees

Current behavior:
- Route: `/parent-fees-screen`.
- Loads linked students, `getInvoices(studentId:)`, and `getParentPaymentRequests(studentId:)`.
- Shows due fees, payment history, and payment requests.
- Payment request form uses `submitParentPaymentRequest`.
- Backend scopes Parent invoice reads through parent-student links and allows Parent to create payment requests.

Connected roles:
- Admin/Principal currently own fee structures, invoices, payment recording, payment request decisions, concessions, reminders, and reports.
- Parent submits payment proof/request only.

Gaps and tasks:
- Confirm product ownership for Principal fee writes. Current backend permits Admin and Principal for many fee writes, while Parent must stay read/request-only.
- Unify `ParentFeesScreen` and `FeePaymentReceiptScreen` so there is one source of truth for invoices, requests, and receipts.
- Replace static fee type/payment method options in `FeePaymentReceiptScreen` with actual open invoices and configured payment modes.
- Add receipt download only from backend payment/request records; do not generate official receipts from incomplete local fields.
- Add backend tests that Parent cannot request payment against an unlinked invoice and cannot exceed invoice balance after pending requests.

### 9. Pay & Receipts

Current behavior:
- Route: `/fee-payment-receipt-screen`.
- Loads Parent-linked invoices and payment requests.
- Provides a payment-like UI and receipt history.

Connected roles:
- Admin/Principal decide whether payment requests become official payments.
- Parent should not directly record payments.

Gaps and tasks:
- Decide whether this screen remains separate or is folded into Parent Fees.
- If retained, rename the action from "Make Payment" to "Submit Payment Request" unless a real payment gateway is implemented.
- Route submission through `ParentPaymentRequestFormScreen`.
- Disable any local-only payment success state.
- Add tests that Parent cannot call `recordPayment`.

### 10. Student Leave

Current behavior:
- Route: `/parent-leave-screen`.
- Loads linked students and `getStudentLeaveApplications()`.
- Routed form `/parent-leave-screen/request` submits through `submitStudentLeaveApplication`.
- Backend permits only Parent to create student leave applications and Admin/Principal/Teacher to decide.
- Backend validates linked student, required fields, date order, and half-day rules.

Connected roles:
- Parent creates leave.
- Teacher/Admin/Principal decide leave.
- Admin/Principal receive approval notifications.

Gaps and tasks:
- Ensure the attendance screen routes to the leave form instead of maintaining a second leave dialog workflow.
- Add leave type filtering for student-applicable leave types if backend supports it.
- Show decision role/name and rejection reason clearly.
- Add tests that Parent cannot create leave for an unlinked student and cannot decide leave.
- Add notifications for status decision into Parent Notification Center.

### 11. Calendar

Current behavior:
- Route: `/parent-calendar-screen`.
- Loads academic years, events, PTM rows, exams, and current-year holidays.
- Tabs show Events, Holidays, and Exams.
- Parent is read-only for events and holidays.

Connected roles:
- Admin/Principal create events and holidays.
- Admin/Principal/Teacher configure exams depending on backend route.
- Teacher/Admin/Principal publish PTM slots.
- Parent reads and books PTM from chat/PTM screen.

Gaps and tasks:
- Filter exam/event visibility so unpublished exams or staff-only events do not leak to Parent.
- Make PTM rows child-linked only, matching parent-student scope.
- Cache current academic year once instead of fetching each time a parent opens the screen.
- Add calendar regression tests for events, holidays, exams, and PTM scoping.

### 12. Documents And Certificates

Current behavior:
- Route: `/parent-documents-screen`.
- Loads linked students and `/student-documents?student_id={id}`.
- Parent can create `/documents/access-requests` and `/certificates/requests`.
- Frontend record handler scopes Parent-owned certificate/access records by `created_by`.
- Some PDF generation helpers still use incomplete local values when the source document does not include official report-card or receipt payloads.

Connected roles:
- Admin/Principal upload/approve official documents and certificates.
- Teacher may contribute academic records where configured.
- Parent requests and downloads visible documents.

Gaps and tasks:
- Replace generated report card/fee receipt PDF paths with backend export/download lifecycle or official document rows.
- Load existing certificate requests from `/certificates/requests`; currently only newly submitted local state is shown during the session.
- Add server validation for document access and certificate request `student_id` against linked children.
- Show document status: available, requested, approved, rejected, expired.
- Add tests that Parent can only list/create/update own document requests and only for linked students.

### 13. Class Diary

Current behavior:
- Route: `/parent-diary-screen`.
- Loads linked students and `/diary-entries?student_id={id}`.
- Shows Today and All Entries with subject filtering and pagination.

Connected roles:
- Teacher creates diary entries.
- Admin/Principal can supervise.
- Parent reads only child-linked diary entries.

Gaps and tasks:
- Ensure backend diary scoping includes linked-student filtering for Parent and assigned-section filtering for Teacher.
- Add typed diary mapper and remove widget-level raw map parsing.
- Add empty state wording that distinguishes no diary entries from missing child links.
- Add tests for Parent linked/unlinked diary visibility.

### 14. Academic Info

Current behavior:
- Route: `/parent-academic-info-screen`.
- Uses shared `AcademicInfoScreen(role: 'parent')`.

Connected roles:
- Admin/Principal maintain academic years, grades, sections, subjects, curriculum, syllabus, and school info.
- Parent reads published academic information.

Gaps and tasks:
- Verify the shared screen is read-only for Parent at both UI and backend route level.
- Hide setup/edit controls for Parent.
- Add test coverage that Parent route opens shared academic info with `role: 'parent'` and no write controls.

### 15. Notifications

Current behavior:
- Route: `/notification-center-screen` with role argument `parent`.
- `NotificationService` loads `/notifications`, filters role/all notifications, and marks notifications read through backend.
- Drawer badge uses unread count for Parent.

Connected roles:
- Backend creates notification logs from notices, homework, leave, payment requests, communications, and other workflow events.
- Parent reads and marks own notifications.

Gaps and tasks:
- Verify `/notifications` list is scoped by target role/user/school for Parent.
- Add route resolution tests for Parent notifications: notices, fees, homework, leave, PTM, direct messages, documents.
- Add device token registration checks for Parent login.
- Add read-all batching or endpoint support to avoid N sequential calls for large inboxes.

### 16. Profile, Settings, And Shared Tools

Current behavior:
- Parent profile uses `/auth/profile` update and avatar upload.
- Settings are shared app preferences.
- Global search is shared.
- Parent drawer identity loads current school and profile, plus child names from role access state.

Connected roles:
- All roles use shared auth/profile infrastructure.
- Principal can edit school profile; Parent cannot.

Gaps and tasks:
- Ensure Parent profile cannot edit school details.
- Confirm `RoleAccessService.parentChildNames` refreshes after login/link changes and does not rely on stale cache.
- Add parent-specific search restrictions so global search does not surface unlinked students, staff-only records, or admin/principal modules.
- Add tests for profile update, avatar upload, logout, and route redirection.

## Priority Backlog

### P0 - Scope And Backend Truth

- Build a Parent role contract test matrix covering every route in `RouteAccessGuard`.
- Confirm every Parent screen starts from `/me/students` or a validated linked-student argument.
- Add backend access tests for unlinked student denial across students, marks, attendance, fees, homework submissions, diary, documents, leave, PTM, messages, and communications.
- Remove or route away any Parent UI that writes official school records directly, especially fee payments and official documents.
- Add typed API helpers for notice acknowledgements, certificate requests, document access requests, diary entries, and message conversations.

### P1 - Core Parent Workflows

- Unify child selector behavior and child summary mapping across all Parent screens.
- Harden Academic Progress with published-result visibility and export lifecycle.
- Harden Attendance with day-wise records and no synthetic calendar statuses.
- Harden Homework with submission/review state, revision policy, and notifications.
- Harden Fees and Receipts with payment request-only semantics unless a real payment gateway is added.
- Harden Teacher Chat/PTM/Principal Messages with typed services and read receipts.
- Harden Student Leave with status notifications and single routed create flow.

### P2 - Documents, Calendar, And Shared UX

- Replace document PDF generation placeholders with backend-backed official files or export jobs.
- Load certificate request history from backend and support status updates.
- Add Parent calendar visibility filters for events, exams, holidays, and PTM.
- Finish notification routing for every Parent workflow.
- Review mobile overflow, text scaling, empty states, loading states, and refresh behavior screen by screen.

### P3 - Polish And Maintainability

- Move Parent screen map parsing into data adapters/repositories.
- Add common error and empty-state components for linked-child missing, backend unavailable, and unpublished-data cases.
- Add analytics only after backend metrics are available; no local fabricated percentages.
- Add concise handoff docs for Parent QA login, seed data, and expected linked-child scenarios.

## Backend Test Plan

| Area | Required tests |
| --- | --- |
| Parent linkage | Parent sees only linked students; Admin/Principal can assign; Parent cannot manage links |
| Student reads | Parent denied for unlinked student detail, attendance, marks, fees, progress, transport if exposed |
| Homework | Parent reads assigned homework, submits linked child homework, cannot submit unlinked, cannot review |
| Messages | Parent can create linked conversation/reply, mark incoming read, cannot tamper with sender/body on read updates |
| Communications | Parent can read/reply to Principal direct messages, cannot spoof sender or message another Parent |
| Fees | Parent reads linked invoices only, creates payment request only for linked invoice, cannot record official payment |
| Leave | Parent creates linked student leave, cannot decide, staff roles can decide within scope |
| Notices | Parent-visible notices only, acknowledgement scoped to current parent, no duplicate acknowledgements |
| Documents | Parent reads linked student documents only, creates own access/certificate requests only for linked students |
| Calendar/PTM | Parent reads visible events/PTM only, books linked PTM slots only |
| Notifications | Parent list/read state scoped by target role/user/school |

## Flutter Test Plan

- Update `parent_module_ui_backend_contract_test.dart` to cover all Parent routes currently in the drawer and registry.
- Add source tests that forbid mock/static fallback data in Parent dashboard, attendance, homework, fees, progress, documents, diary, and chat.
- Add widget tests for no linked students, backend error, multi-child selector, and empty backend responses.
- Add route guard tests for Parent-only routes and shared protected routes.
- Add contract tests for direct Principal messages in `ParentTeacherChatScreen`.
- Add tests that Pay & Receipts uses payment requests unless a payment gateway is implemented.
- Run:
  - `flutter analyze`
  - `flutter test test/unit/parent_module_ui_backend_contract_test.dart`
  - `flutter test test/unit/role_module_coordination_contract_test.dart`
  - `flutter test test/unit/route_access_guard_test.dart`
  - targeted widget tests added for Parent screens

## Implementation Sequence

1. Freeze Parent route inventory and update contract tests.
2. Add typed Parent API helpers and mappers while preserving existing endpoints.
3. Harden backend Parent scoping tests and fill any route/handler gaps found.
4. Refactor shared child selector and linked-student loading into reusable Parent components.
5. Harden core workflows in this order: Dashboard, Academic Progress, Attendance, Homework, Fees, Chat/PTM/Messages, Leave.
6. Harden secondary workflows: Notices, Calendar, Documents, Diary, Notifications, Profile.
7. Run Go and Flutter focused tests.
8. Perform Android/web manual verification with a Parent account linked to at least two active students and one unlinked control student.

## Acceptance Criteria

- Parent cannot view or mutate any unlinked student data.
- Parent can complete all intended parent-owned workflows without mock/fallback data.
- Teacher, Admin, and Principal workflows publish data that appears correctly in Parent screens.
- Parent screens render honest empty states when backend data is missing.
- Official documents, receipts, report cards, marks, attendance, fees, homework, and messages are backend-backed.
- Route guard, backend RBAC, and data-level scoping agree.
- Focused Go and Flutter Parent tests pass.

## Open Product Decisions

- Should Principal keep fee write powers in production, or should fee writes be Admin-only with Principal monitor/decision rights?
- Should Parent payment become a real gateway flow, or remain proof/request submission for Admin/Principal decision?
- Should Teachers or only Admin/Principal decide student leave?
- Should PTM slot creation be Teacher-owned only, or also Admin/Principal-owned?
- Should official report card and receipt download always be backend export jobs, or can the app generate PDFs from fully signed backend payloads?
- Should direct Parent-to-Principal messages live in Teacher Chat tabs or become a separate Parent Communications screen?
