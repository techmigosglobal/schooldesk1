# SchoolDesk Role-wise Application Audit

Date: 2026-06-06
Scope: Flutter application in `lib/`, Go backend in `school-backend/`, route guards, role navigation, shared UI scaffolds, backend route ownership, Tables.md CRUD resources, and existing contract tests.

This is a static, repo-grounded audit created while runtime testing is still in progress. It does not claim final device or live backend QA. The recommendations below should be treated as a product, UX, backend, and workflow roadmap for Principal, Admin, Teacher, Parent, and shared modules.

## Evidence Inspected

- App entry and routing: `lib/main.dart`, `lib/routes/app_routes.dart`, `lib/routes/route_access_guard.dart`, `lib/routes/schooldesk_screen_registry.dart`.
- Role navigation: `lib/core/widgets/app_navigation.dart`, `lib/core/widgets/admin_navigation.dart`, `lib/core/widgets/teacher_navigation.dart`, `lib/core/widgets/parent_navigation.dart`.
- Shared chrome and UI foundations: `SchoolDeskModuleScaffold`, `SchoolDeskRouteFrame`, `BlankRoleModuleScreen`, `PrincipalDirectoryScaffold`, `TeacherFlowScaffold`.
- Feature screens under `lib/features/*/presentation/screens`.
- Backend route registration: `school-backend/internal/routes/routes.go`, `school-backend/internal/routes/dashboard_routes.go`.
- Backend permission seed and role scoping: `school-backend/internal/database/database.go`, `school-backend/internal/handlers/tables_md_crud.go`, `school-backend/internal/handlers/helpers.go`.
- Critical workflow tests: route guard tests, parent module backend tests, frontend/backend truth audit, role module coordination tests, design system contract tests, timetable CSV import contract tests.

## Executive Summary

The application has a strong backend foundation and many real role-specific workflows already wired to live APIs. The largest risk is not absence of code; it is inconsistency between route registration, visible navigation, shared UI standards, backend ownership, and the final user workflow each role expects.

The Principal role is the most complete and contains the newest product direction: Class Hub, principal dashboards, attendance oversight, subject records, timetable records, fee monitoring, events, complaints, and chat communications. However, several principal screens are very large and dense, especially `principal_classes_screen.dart` at more than 9,000 lines. This creates UI inconsistency, higher regression risk, and makes future Class Hub work slower.

The Admin role has many screens and backend permissions, but there is a confirmed route availability issue. `blankRoleModuleScreens` is enabled in `AppRoutes`, and every generated route passes through `AppRoutes.buildRoutePage` from `main.dart`. The visible route allowlist includes only a small subset of admin routes, while the Admin drawer and dashboard link to many admin modules such as Students, Staff, Fees, Timetable, Exams, Communication, Helpdesk, Documents, User Access, and Reports. If those registered routes are not in `_roleWorkflowVisibleRoutes`, the user reaches `BlankRoleModuleScreen`. This should be treated as a P0 workflow blocker.

Teacher and Parent modules are more backend-backed than the UI may suggest. Teacher attendance is tied to timetable slots and assigned sections; homework, communication, leave, reports, and QR attendance have contract tests. Parent modules are visible through the route gate and use linked-student scoping. Both roles need stronger UX polish, better empty states, consistent loading/error states, and tighter workflow guidance.

Events are now represented as a real school calendar workflow, backed by the `events` Tables.md resource, with event creation, edit, status changes, holidays, PTM/calendar usage, and notification-related backend code. The next step is to finish the lifecycle UX: event request, approval, publish, audience targeting, notification proof, parent/teacher read views, and cancellation history.

Principal Chat Communications exists as a principal-level view over direct communication, while Teacher and Parent chat screens use message/conversation routes. The backend has raw communication resources and direct-message validation, but chat should be productized into a complete communications center with internal teacher communication, parent-class communication, read receipts, audit trail, moderation, and principal visibility rules.

## Status Legend

- Working: implemented in code and backed by route/API evidence.
- Partial: implemented but has UX, route, scope, or workflow gaps.
- Blocked: likely inaccessible or unsafe until a routing/backend/workflow issue is fixed.
- Needs runtime QA: static evidence exists, but final device/live backend proof is still pending.

## Role Availability Matrix

| Role | Current UI availability | Backend availability | Overall status | Immediate priority |
| --- | --- | --- | --- | --- |
| Principal | Broadest visible feature set. Principal routes are heavily represented in `_roleWorkflowVisibleRoutes`. | Dashboard, approvals, classes, subjects, attendance, timetable, fees, events, messages, reports, and Tables.md resources are present. | Partial to strong. Needs UX simplification and runtime QA. | Make Class Hub the single source for class-level setup and reduce oversized screens. |
| Admin | Many drawer/dashboard links exist, but most admin routes are not in `_roleWorkflowVisibleRoutes`. | Admin has broad seeded permissions and many backend write routes. | Blocked for several modules because route gate can render blank screens. | Fix or remove the temporary blank route gate for completed admin modules. |
| Teacher | Teacher routes are visible in `_roleWorkflowVisibleRoutes`. Dedicated teacher flow UI exists. | Teacher dashboard, timetable-scoped attendance, homework, messages, PTM, leave, reports, and QR attendance are present. | Partial. Functional backbone exists, needs role workflow polish. | Make daily classroom flow faster and more reliable. |
| Parent | Parent routes are visible in `_roleWorkflowVisibleRoutes`. Parent drawer is child-oriented. | Parent dashboard, linked students, homework submissions, fees, leave, notices, chat, calendar, documents are scoped. | Partial to strong. Needs trust-building UX and clearer state transitions. | Improve child switcher, payment/request states, and calendar/attendance detail. |
| Shared | Search, notifications, profile, settings, route frame, module scaffold exist. | Auth, dashboard role routing, notification routes, school scoping, audit helper exist. | Partial. Shared chrome is promising but unevenly applied. | Enforce one role-aware module shell and standard empty/error/loading states. |

## P0 Findings

### 1. Admin Modules Can Navigate To Blank Screens

Evidence:
- `lib/main.dart` routes every named route through `AppRoutes.buildRoutePage`.
- `lib/routes/app_routes.dart` has `blankRoleModuleScreens = true`.
- `_buildRouteChild` returns `BlankRoleModuleScreen` for non-public, non-shared routes not in `_roleWorkflowVisibleRoutes`.
- Admin navigation links to many routes, but `_roleWorkflowVisibleRoutes` only includes `adminDashboard` and `adminAttendance` from the admin-specific route set.

Impact:
- Admin dashboard and drawer can show valid actions that open a blank page.
- This breaks trust and makes functional screens look uncoded even if the screen classes exist.
- It can also hide backend-backed features such as Students, Staff, Fees, Timetable, Exams, Communication, Helpdesk, Documents, User Access, Reports, ID Cards, and related forms.

Recommendation:
- Replace the temporary blank-screen gate with an explicit per-route readiness registry.
- For every admin navigation item, either show the real implemented screen or remove/disable the navigation item with a clear status.
- Add a route availability unit test that compares each role drawer route with `_roleWorkflowVisibleRoutes` and fails if a visible nav item points to a blank route.

### 2. Class-level Operations Need One Ownership Model

The product direction is clear: main home modules like Attendance, Subjects, Timetable, and Fees should be viewable by class, while modifications should redirect to the respective class in Class Hub. The codebase partially supports this direction, but it must become a formal rule.

Recommendation:
- Treat Class Hub as the class setup cockpit:
  - Class details and section setup.
  - Subject mapping and teacher assignment.
  - Timetable setup, smart preview, generation, and publish.
  - Fee setup and class-level fee rules.
  - Attendance setup rules and class drill-down.
- Treat main modules as oversight directories:
  - Attendance Directory: view class status and drill into Class Hub for edits.
  - Subjects Records: view class/teacher/subject coverage and drill into Class Hub for mapping.
  - Timetable Records: view periods, conflicts, and publish status; generate/edit via Class Hub or dedicated Admin timetable config where appropriate.
  - Fee Monitoring: view dues/collections; setup/edit class fee rules through Class Hub.
- Add route arguments such as `source`, `action`, `classId`, `sectionId`, and `academicYearId` consistently for deep links.

### 3. Oversized Screens Increase UI and Regression Risk

The largest screen files are very large:
- `principal_classes_screen.dart`: 9,073 lines.
- `principal_academic_command_screens.dart`: 3,667 lines.
- `staff_management_screen.dart`: 3,398 lines.
- `guided_assistant_screen.dart`: 3,371 lines.
- `student_oversight_screen.dart`: 3,312 lines.
- `academic_management_screen.dart`: 3,222 lines.
- `principal_subjects_screen.dart`: 2,692 lines.
- `guardian_directory_screen.dart`: 2,611 lines.

Impact:
- UI standards drift within a single feature.
- Reuse and testing become harder.
- Fixes to spacing, font size, and navigation require touching very large files.

Recommendation:
- Split each high-risk screen into route shell, data controller, list/table widgets, form panels, detail sheets, empty states, and action handlers.
- Add widget-level tests around the extracted pieces.
- Keep the route contract stable while extracting.

### 4. UI Scale And Typography Are Uneven

The app has a good design foundation, but role screens use different visual systems:
- Principal has `PrincipalDirectoryScaffold`.
- Most role modules use `SchoolDeskModuleScaffold`.
- Teacher uses `TeacherFlowScaffold` with its own colors and larger teacher-specific card typography.
- Older screens still contain bespoke layouts, dense cards, and inconsistent filter/search/action placement.

Recommendation:
- Create one role-aware screen standard:
  - Module title: 20-24 px.
  - Section title: 16-18 px.
  - Card/table title: 14-16 px.
  - Body text: 13-14 px.
  - Helper text: 12-13 px.
  - Avoid hero-sized text inside operational tools.
- Use compact tables/lists for operational data instead of large repeated cards where scanning matters.
- Keep role color accents, but avoid role screens feeling like separate apps.
- Make text scaling and long labels part of widget tests.

## Principal Role Audit

### Dashboard

Current state:
- Principal dashboard loads `/dashboard/principal` and additional optional resources.
- It exposes quick navigation to setup, attendance, subjects, timetable, exams, fees, events, communication, chat, and reports.

UI/UX improvements:
- Reduce dashboard card size and text weight so it behaves like an operational command center, not a landing page.
- Group tasks by urgency: Today, Setup gaps, Approvals, Finance, Communication, Academic health.
- Use one compact KPI row and one actionable inbox rather than many equally loud cards.
- Add skeleton loaders and inline retry for optional panels that fail.

Workflow improvements:
- Prioritize incomplete setup items and route directly to Class Hub with the right step selected.
- Make all "edit/setup" actions explicit and all "view/report" actions separate.

Backend improvements:
- Keep `/dashboard/principal` as the primary aggregate endpoint.
- Move optional list-heavy dashboard loads into server-side compact summary fields.
- Add dashboard contract tests for required keys and permissions.

Priority: P1.

### Classes Hub

Current state:
- Class Hub is the largest and most central principal screen.
- It owns class setup, subject setup, timetable setup/review, fees, and class details.
- Bulk CSV import support exists via `bulk_csv_import_service.dart`, and the open CSV file indicates import compatibility is important.

UI/UX improvements:
- Reduce visual scale and align with the rest of principal screens.
- Replace large card-heavy step layouts with a compact wizard plus class summary side panel.
- Keep the stepper visible but not oversized.
- Use fixed-height action rows to avoid layout jumps.
- Provide explicit statuses: Not started, Incomplete, Ready to generate, Generated, Published.

Workflow improvements:
- Make the flow deterministic:
  1. Create class/section.
  2. Assign subjects.
  3. Assign teachers.
  4. Preview timetable.
  5. Generate timetable.
  6. Set up fees.
  7. Publish class setup.
- Allow CSV import to populate each step without bypassing validation.
- Keep "View timetable" separate from "Generate timetable".
- Route main Timetable/Subjects/Fees screens back to this class context for modifications.

Backend improvements:
- Keep smart timetable preview/generation under Admin/Principal with school and class scope.
- Add a publish endpoint or status field for class setup completion.
- Add transaction boundaries when CSV imports create classes, subjects, teacher assignments, timetable, and fees together.
- Add import job status for large CSV files.

Priority: P0 until runtime confirms timetable setup/generation works end to end.

### Attendance Directory

Current state:
- Principal attendance is view-oriented and contains class/session/student/report modes.
- It already pushes users toward Class Hub for attendance changes.

UI/UX improvements:
- Make the default view a class-wise table with marked/unmarked status, attendance percent, and exception count.
- Add date picker and status chips in a sticky filter area.
- Show "Not marked today" as an actionable state, not just a data absence.

Workflow improvements:
- Principal should review, escalate, or drill down, while teacher/class context handles marking.
- Add correction request and lock/unlock flow for attendance after cutoff.

Backend improvements:
- Add daily class attendance summary endpoint if not already sufficient.
- Add attendance correction and audit trail endpoint.
- Ensure student attendance history returns day-wise rows for parent and principal views.

Priority: P1.

### Subjects Records

Current state:
- Principal Subjects is a substantial records screen and reads subjects/assignments.
- Subject assignment appears connected to class/teacher data.

UI/UX improvements:
- Convert to a class-subject coverage matrix.
- Show missing teacher assignments, overloaded teachers, and unmapped subjects first.
- Keep editing entry points as "Open in Class Hub".

Workflow improvements:
- Main Subjects should be a school-wide view.
- Assignment changes should route into the relevant class setup step.

Backend improvements:
- Add one endpoint for subject coverage by academic year, grade, section, subject, and staff.
- Add uniqueness checks for duplicate class-subject-teacher mappings.

Priority: P1.

### Timetable Records

Current state:
- Principal timetable records and Class Hub timetable generation paths exist.
- Admin timetable management also exists.

UI/UX improvements:
- Separate timetable states: Draft, Conflicted, Generated, Published, Archived.
- Use grid/table views for period scanning instead of large cards.
- Add conflict chips for teacher double-booking, room conflict, missing subject, and no teacher.

Workflow improvements:
- Principal main timetable screen should review and inspect.
- Class Hub should generate or regenerate class timetable.
- Admin timetable screen can remain the advanced institutional setup area for periods, templates, constraints, substitutions, and rooms.

Backend improvements:
- Add timetable publish/versioning.
- Add conflict summary endpoint.
- Add idempotent regenerate behavior with preview/diff before overwriting slots.

Priority: P0/P1 because timetable was the latest user-facing blocker.

### Fees Monitoring

Current state:
- Principal Fee Monitoring and Admin Fees exist.
- Parent payment request and admin/principal decision routes exist.

UI/UX improvements:
- Make Fee Monitoring a dashboard of collections, dues, defaulters, concessions, and pending parent payment requests.
- Avoid oversized financial cards; use tables with totals and filters.

Workflow improvements:
- Class fee setup should open the class in Class Hub.
- Payment request approvals should stay in a clear decision queue.
- Parent should see request status and receipt history.

Backend improvements:
- Use transaction-safe payment recording.
- Enforce invoice balance consistency server-side.
- Add export lifecycle and receipt generation audit.

Priority: P1.

### Events And Calendar

Current state:
- Principal Events Calendar is implemented and backed by `/events`.
- Events support holidays, status, audience, venue, dates/times, create/edit/delete/status actions.
- Parent calendar consumes events and PTM data.
- Backend Tables.md `events` resource validates academic year ownership and date order.

UI/UX improvements:
- Make event type obvious: Event, Holiday, Exam, PTM, Meeting, Activity.
- Add calendar/month view plus compact list view.
- Show approval and publish state separately.
- Add audience preview: All, Teachers, Parents, Class, Section.

Workflow improvements:
- Define event lifecycle:
  1. Draft.
  2. Submitted for approval if created by Admin/Teacher.
  3. Approved by Principal/Admin.
  4. Published to audience.
  5. Notified.
  6. Completed or cancelled.
- Connect PTM events to meeting slots.
- Let parents and teachers view relevant events, not edit them.

Backend improvements:
- Add event approval endpoint instead of overloading generic status update.
- Add notification delivery log for published events.
- Add audience targeting filters at backend level.
- Add cancellation reason and audit log.

Priority: P1.

### Chat Communications

Current state:
- Principal Chat Communications screen exists.
- Teacher and Parent chat screens use messages/conversations.
- Backend direct communications exist through `communications`, `message-conversations`, and `messages`.

UI/UX improvements:
- Principal needs a communications dashboard:
  - Parent-teacher chats by class.
  - Teacher internal messages.
  - Unread/escalated conversations.
  - Search by parent, teacher, student, class.
  - Conversation detail with participants and audit metadata.
- Separate "School announcements" from "Direct chat".

Workflow improvements:
- Principal should be able to monitor all teacher-parent communication without becoming the sender unless explicitly replying.
- Internal teacher communication should be separate from parent chat.
- Add escalation/flagging, read receipts, and conversation close/reopen.

Backend improvements:
- Formalize conversation membership and principal visibility.
- Ensure direct-message validation allows the intended internal-teacher communication model.
- Add read receipt and deletion policy per participant.
- Add notification fanout and audit events.

Priority: P1.

## Admin Role Audit

### Route And Navigation

Current state:
- Admin Drawer and Admin Dashboard advertise many operational modules.
- Route guards allow admin access to those routes.
- The temporary blank role module gate can hide many admin modules.

UI/UX improvements:
- Do not display admin modules that are not route-visible.
- Add route readiness badges only for internal QA builds, not production users.

Workflow improvements:
- Admin should be the daily operations owner:
  - Students and staff data entry.
  - Fee structures, invoices, and payment records.
  - Timetable templates, periods, substitutions, and constraints.
  - Exam creation, schedules, marks entry.
  - Communications, helpdesk, documents, user access, reports.
- Sensitive operations should either be principal-owned or require principal approval.

Backend improvements:
- Create an Admin/Principal ownership matrix and enforce it in backend route tests.
- Align frontend route availability with backend permissions.

Priority: P0.

### Students And Staff

Current state:
- Admin Students and Staff Management screens exist.
- Staff Management is shared with Principal via owner role.

UI/UX improvements:
- Use compact directory patterns: filters, table/list, quick preview, detail drawer.
- Reduce heavy card usage for large records.
- Add clear import/export entry points.

Workflow improvements:
- Admin creates/updates records.
- Principal approves sensitive account/class/student changes when configured.
- Staff/Student creation should end with account linkage and class/section enrollment checks.

Backend improvements:
- Add uniqueness constraints for admission number, student code, staff code, and active email per school.
- Add bulk import dry-run with row-level validation.
- Add audit trail visible to principal.

Priority: P1.

### Fees

Current state:
- Admin Fees, forms, payment requests, payment decision screens, and parent payment request integration exist.

UI/UX improvements:
- Add finance workspace tabs: Structures, Invoices, Payments, Requests, Concessions, Reports.
- Use data tables for invoices and payments.
- Show totals and filters persistently.

Workflow improvements:
- Admin records payments and decisions.
- Principal monitors exceptions and approvals.
- Parent views dues, submits payment requests, and downloads receipts.

Backend improvements:
- Make invoice payment updates transactional.
- Add balance recalculation guard.
- Add duplicate receipt/transaction validation.

Priority: P1.

### Timetable And Exams

Current state:
- Admin Timetable and Admin Exams screens exist, but route visibility must be fixed.
- Backend has timetable slots, smart generation, constraints, exams, schedules, marks, reports.

UI/UX improvements:
- Admin timetable should feel like a configuration tool, not a record viewer.
- Use structured period grid, constraint panels, conflict list, and publish controls.
- Admin exams should distinguish exam types, exams, schedules, marks, report cards, exports.

Workflow improvements:
- Admin configures institution-wide timetable rules.
- Principal/Class Hub generates and approves class-level timetable.
- Teachers consume timetable for attendance and homework context.

Backend improvements:
- Add conflict and validation endpoint before publish.
- Add role-scoped tests for teacher timetable reads and Admin/Principal writes.
- Add exam schedule lock after marks entry begins.

Priority: P1 after admin route gate is fixed.

### Communication, Helpdesk, Documents, Reports

Current state:
- Screens exist for Admin Communication, Helpdesk, Documents, User Access, Reports, ID Cards.

UI/UX improvements:
- Standardize on `SchoolDeskModuleScaffold`.
- Use consistent form/detail sheet patterns.
- Make every request/action show backend confirmation and next state.

Workflow improvements:
- Admin communications should handle announcements and operational notices.
- Helpdesk should include assignment, priority, status, SLA, and closure notes.
- Documents should support request, upload, approval, expiry, download.
- Reports should support filters, export status, download, and regeneration.

Backend improvements:
- Add explicit lifecycle endpoints for helpdesk/document workflows where generic CRUD is too weak.
- Add export job status for reports.
- Add audit and notification triggers for all status changes.

Priority: P1/P2.

## Teacher Role Audit

### Dashboard And Daily Flow

Current state:
- Teacher dashboard is visible and uses `TeacherFlowScaffold`.
- It uses backend dashboard data and role access data.

UI/UX improvements:
- Make "Today" the default mental model:
  - Current period.
  - Next class.
  - Attendance not marked.
  - Homework due.
  - Parent messages.
  - Leave/QR attendance.
- Reduce large decorative cards and emphasize tappable work items.

Workflow improvements:
- Teacher should move from dashboard to current class attendance in one tap.
- Teacher should see only assigned classes/sections and today's timetable.

Backend improvements:
- Keep `/dashboard/teacher` compact and complete.
- Include assigned class labels, current/next period, attendance due, homework due, unread messages.

Priority: P1.

### Student Attendance

Current state:
- Teacher attendance uses `RoleAccessService.teacherStaffId`, timetable slots, assigned sections, enrollments, attendance session creation, and mark attendance.
- Backend has teacher timetable access guards and attendance ownership checks.

UI/UX improvements:
- Default to current timetable period and class.
- Show roster in a compact mark-all/present/absent/late UI.
- Add unsaved changes warning and save confirmation.
- Add "attendance already marked" read-only state after cutoff.

Workflow improvements:
- Attendance should be one continuous flow:
  1. Select current period/class.
  2. Load roster.
  3. Mark quickly.
  4. Save.
  5. Confirm summary.
  6. Allow correction request if locked.

Backend improvements:
- Add attendance lock/correction endpoint.
- Validate teacher can mark only assigned section/slot.
- Return roster plus existing attendance in a single endpoint.

Priority: P1.

### Homework, Diary, Performance, Notes

Current state:
- Teacher homework posting, parent submission, and review are contract-tested.
- Teacher diary, performance, student notes, and discipline screens exist.

UI/UX improvements:
- Use consistent teacher forms with compact controls and strong defaults.
- Make homework status visible: Draft, Assigned, Submitted, Reviewed, Overdue.
- Combine diary and homework where they naturally overlap, but keep labels clear.

Workflow improvements:
- Teacher creates homework for assigned class/subject only.
- Parent submits and teacher reviews with comments/marks/status.
- Notes and discipline should be student-linked and visible to principal where needed.

Backend improvements:
- Add validation that homework section/subject/staff matches teacher assignment.
- Add notification triggers for homework assigned/reviewed.
- Add attachment lifecycle and file validation.

Priority: P1.

### Communication And Parent Interaction

Current state:
- Teacher Communication and Parent Interaction screens exist.
- Message create/update and read receipt behavior are contract-tested.

UI/UX improvements:
- Separate direct parent chat, PTM scheduling, homework feedback, and internal staff communication.
- Add conversation filters by class, unread, escalated, and student.

Workflow improvements:
- Teacher can message parents for assigned students.
- Parent interaction should tie PTM slots to events/calendar.
- Escalation to principal should be explicit.

Backend improvements:
- Enforce teacher-parent relationship scope on every conversation.
- Add membership table or explicit conversation participants.
- Add principal monitor permissions without weakening teacher/parent privacy rules.

Priority: P1.

## Parent Role Audit

### Dashboard And Child Switching

Current state:
- Parent dashboard uses backend dashboard and linked students.
- Parent drawer shows child-oriented modules.

UI/UX improvements:
- Make child switcher persistent on child-specific screens.
- Show only high-value summaries: attendance, dues, homework, notices, messages.
- Provide clear "last updated" states for trust.

Workflow improvements:
- Parent should always know which child is active.
- Any child-specific action must pass student ID explicitly.

Backend improvements:
- Keep all parent reads scoped through linked students.
- Add tests for every parent route that accepts `student_id`.

Priority: P1.

### Attendance And Academic Progress

Current state:
- Parent attendance loads summary and derives day status where possible.
- Academic progress reads marks, report cards, diary, and exports.

UI/UX improvements:
- Show month calendar, summary cards, and exception list.
- Academic progress should group by exam/subject with report card download status.

Workflow improvements:
- Parent views, downloads, and raises queries where allowed.
- Parent should not edit academic data.

Backend improvements:
- Add day-wise attendance records endpoint for parent calendar detail.
- Add report export lifecycle status and retry.
- Add teacher/principal contact route for result queries.

Priority: P1/P2.

### Homework, Chat, Fees, Leave, Calendar, Documents

Current state:
- Parent homework, submission, notices, chat/PTM, fees, payment request, leave request, calendar, and documents are implemented.

UI/UX improvements:
- Homework should show Due Today, Upcoming, Submitted, Reviewed, Overdue.
- Fees should show due timeline, request status, receipts, and payment confirmation.
- Leave should show request lifecycle and approval/rejection reason.
- Calendar should separate holidays, events, exams, PTMs, and deadlines.
- Documents should distinguish available documents, pending requests, and rejected requests.

Workflow improvements:
- Parent actions should be guided:
  - Submit homework.
  - Request payment proof/extension/concession.
  - Apply leave.
  - Book PTM.
  - Request document access.
- Each action should return an explicit state and next step.

Backend improvements:
- Parent payment request lifecycle is present; strengthen transaction and notification coverage.
- Student leave submission should remain parent-only and student-linked.
- Document access requests need explicit approval and expiry handling.

Priority: P1.

## Shared UI/UX Improvements

### 1. One Role-aware Design System

Required direction:
- Use `SchoolDeskModuleScaffold` for all operational modules.
- Use role drawers consistently.
- Keep `PrincipalDirectoryScaffold` as a specialization only if it follows the same typography, spacing, actions, and state rules.
- Keep `TeacherFlowScaffold` lightweight and avoid role-only typography inflation.

### 2. Reduce Over-zoomed Screens

Apply this across Class Hub and all role modules:
- Page title: 20-24 px.
- Toolbar title/subtitle: compact and single-line where possible.
- Card title: 14-16 px.
- Body: 13-14 px.
- Metadata/help text: 12-13 px.
- Prefer tables/lists over large cards for repeated operational data.
- Avoid thick spacing stacks on mobile.

### 3. Standard States

Every screen should implement:
- Loading skeleton or compact progress state.
- Empty state with the correct next action.
- Error state with retry and backend message.
- Permission state when role cannot perform a modification.
- Success state with the next navigation/action.

### 4. Responsive Layout

Required checks:
- 360 px mobile width.
- 390/430 px common Android widths.
- 768 px tablet portrait.
- 1024/1280 px tablet/desktop.
- Large text scale within `SchoolDeskResponsive.maxSupportedTextScale`.

### 5. Accessibility

Required improvements:
- Meaningful semantics labels for icon-only controls.
- Minimum 44 px tap targets.
- Keyboard focus order for web/tablet.
- Contrast checks for role colors and status chips.
- No text truncation for critical labels such as student names, fee amounts, and attendance statuses.

## Workflow Improvements By Module

| Module | Current direction | Recommended workflow |
| --- | --- | --- |
| Attendance | Principal/Admin/Teacher/Parent views exist; Teacher marks attendance. | Main screens view by class/date. Teacher marks assigned classes. Principal/Admin review and approve corrections. Class Hub owns class-level setup. |
| Subjects | Principal subjects and academic management exist. | Main Subjects is a coverage view. Assignment changes open the relevant Class Hub step. |
| Timetable | Admin timetable and Principal/Class Hub timetable paths exist. | Admin configures rules/templates. Class Hub previews/generates class timetable. Main Timetable views records and conflicts. |
| Fees | Admin fees, principal monitoring, parent dues/payment request exist. | Class fee setup starts from Class Hub. Admin records payments. Principal monitors exceptions. Parent requests/payments have visible status. |
| Events | Principal event calendar exists and parent calendar consumes events. | Draft -> approval -> publish -> notify -> complete/cancel. Teachers/Parents view scoped events. PTM events link to meeting slots. |
| Communication | Admin/Principal/Teacher/Parent communication screens exist. | Separate announcements, direct chat, PTM, homework feedback, and internal staff communication. Principal has oversight. |
| Approvals | Approval center and approval routes exist. | Unified approval inbox with source module, requester, before/after values, decision, audit, and notification. |
| Reports | Multiple report screens and export lifecycle tests exist. | Add report templates, export jobs, status, retry, download history, and role-scoped access. |
| CSV Import | Bulk CSV service exists and user is working with Class Hub CSV. | Dry-run, validate, preview, import job, row-level errors, rollback, and post-import setup status. |

## Backend Improvements

### RBAC And Route Ownership

Current strengths:
- Role dashboard routes are separated.
- `RBACMiddleware`, `PermissionMiddleware`, and `SchoolScopeMiddleware` are used broadly.
- Seeded permissions exist for Admin, Principal, Teacher, and Parent.
- Tables.md CRUD applies role and school scoping.

Recommended improvements:
- Create a single role-module-operation matrix and generate tests from it.
- Align frontend route visibility with backend route permissions.
- Avoid overlapping Admin/Principal write rights where product ownership differs.
- Add negative tests for every route group: wrong role, missing school, wrong student/section/staff.

### Typed API Contracts

Current state:
- There is a generated API client plus many raw helper calls.
- Raw helpers are useful but make frontend/backend contracts less explicit.

Recommended improvements:
- Gradually replace feature-critical raw calls with typed methods and DTOs.
- Standardize paginated responses in frontend repositories.
- Keep raw Tables.md access only for generic low-risk resources or admin tooling.

### Pagination, Search, Sorting, Filtering

Current state:
- Backend pagination exists with a max `page_size` of 100.
- Tables.md filters exact-match query params.

Recommended improvements:
- Add server-side search, sort, date ranges, and status filters for large directories.
- Use indexed columns for common filters:
  - `school_id`, `academic_year_id`, `section_id`, `student_id`, `staff_id`, `status`, `created_at`, `date`.
- Avoid loading 500 rows in UI unless a screen truly needs it.

### Validation And Transactions

Recommended improvements:
- Make class setup/import transactional.
- Make fee payment updates transactional.
- Lock exam schedules after marks entry begins.
- Lock attendance after cutoff and route changes through correction workflow.
- Add publish/version semantics for timetable and class setup.

### Audit, Notification, And Observability

Current strengths:
- `auditAction` exists.
- Notification routing and push device token registration exist.
- Event/homework/message notification code exists.

Recommended improvements:
- Ensure every write path records audit events.
- Add notification delivery logs for announcements, events, homework, fees, attendance exceptions, approvals, and chat.
- Add request IDs to user-visible errors for support.
- Add backend health and queue/job monitoring for imports/exports.

### Data Migration And CSV Compatibility

Current state:
- Tables.md resources and migration/backfill exist for events.
- Bulk CSV import service exists.

Recommended improvements:
- Version CSV templates.
- Keep backward-compatible column aliases.
- Add dry-run import API.
- Store import batches and row errors.
- Add tests using the existing `classhub_all_features_import.csv` style file.

## Optimization Backlog

### P0 - Blockers

1. Fix admin route blank-screen gate or remove admin nav entries that are not visible.
2. Runtime-test Class Hub timetable preview/generate/setup/fees sequence.
3. Enforce main module view-only behavior with modification redirects to Class Hub.
4. Add route availability tests that compare visible navigation against route allowlists.
5. Confirm principal chat communications can see teacher-parent and teacher-internal conversations as intended.

### P1 - High Impact

1. Refactor Class Hub into smaller widgets/controllers while keeping route and CSV compatibility.
2. Standardize typography and spacing across Class Hub, Principal, Admin, Teacher, Parent screens.
3. Finish Events lifecycle: draft, approval, publish, notify, cancel, audience scope.
4. Build formal Principal/Admin ownership matrix and backend tests.
5. Improve Teacher daily classroom flow and attendance marking UX.
6. Improve Parent child switcher and stateful action flows.
7. Add typed API methods for high-value raw calls.

### P2 - Product Depth

1. Add timetable conflict resolution and publish/version history.
2. Add attendance correction requests and locks.
3. Add report/export job dashboard.
4. Add finance reconciliation and receipt audit.
5. Add document request lifecycle and expiry.
6. Add helpdesk assignment/SLA workflow.

### P3 - Polish And Scale

1. Add more golden/responsive tests for role screens.
2. Improve keyboard navigation and accessibility semantics.
3. Add role-specific saved filters.
4. Add better no-data onboarding for fresh schools.
5. Add analytics for feature usage and abandoned workflows.

## Role-wise Smoke Test Plan

### Principal

- Login as Principal.
- Open Dashboard.
- Open Class Hub.
- Create or select class.
- Assign subjects and teachers.
- Preview timetable.
- Generate timetable.
- Continue to fees.
- Open main Attendance, Subjects, Timetable, Fees and confirm they are view-first and edit actions redirect to Class Hub.
- Create event, approve/publish/cancel event.
- Open Chat Communications and confirm teacher-parent/internal visibility.
- Open Approvals and decision flow.

### Admin

- Login as Admin.
- Click every Admin drawer item.
- Confirm no visible admin route renders a blank screen.
- Create/edit student.
- Create/edit staff.
- Configure fee structure and invoice/payment.
- Configure timetable periods/slots/substitution.
- Create exam and schedule.
- Send communication.
- Use helpdesk/documents/reports.

### Teacher

- Login as Teacher.
- Confirm dashboard current/next class.
- Open My Attendance and QR punch state.
- Open Student Attendance from current timetable period.
- Create attendance session and mark roster.
- Create homework.
- Review parent submission.
- Send/read parent chat.
- Create leave request.
- Add student note/discipline incident.

### Parent

- Login as Parent.
- Confirm linked children and active child.
- Open attendance summary and day details.
- Open homework and submit.
- Open academic progress/report card export.
- Open fees, request payment support, view receipt.
- Apply student leave.
- Open calendar and PTM.
- Open documents and request access.
- Chat with assigned teacher.

## Test And Verification Recommendations

Automated:
- `flutter analyze`.
- Route availability test for all visible role nav items.
- Widget smoke tests for every screen in `schooldesk_screen_registry.dart`.
- Responsive tests for 360, 390, 430, 768, 1024, and 1280 widths.
- Backend route RBAC tests generated from a role-operation matrix.
- CSV dry-run/import tests for Class Hub all-feature CSV files.
- Backend transaction tests for fees, timetable generation, attendance marking, and class setup.

Manual:
- Role-wise smoke testing on Android emulator or device.
- Screenshot QA for Principal/Admin/Teacher/Parent dashboard and the top 5 workflows.
- Live backend test for school scoping and wrong-role denial.
- Import one complete Class Hub CSV and verify resulting classes, subjects, timetable, fees, and dashboard statuses.

## Recommended Implementation Roadmap

### Phase 1 - Route And Workflow Safety

- Fix admin blank-route issue.
- Add route availability tests.
- Confirm main module view-only/edit-redirect behavior.
- Finish runtime QA for Class Hub timetable generation and CSV import.

### Phase 2 - UI Standardization

- Define final typography/spacing tokens.
- Apply to Class Hub first.
- Apply to Principal directory screens.
- Apply to Admin operational screens.
- Apply to Teacher and Parent flows.

### Phase 3 - Role Workflow Completion

- Principal: Class Hub, approvals, chat oversight, events lifecycle.
- Admin: operations CRUD, finance, timetable config, exams, documents, reports.
- Teacher: day flow, attendance, homework, parent communication.
- Parent: child-first views, submissions, payments, leave, documents, calendar.

### Phase 4 - Backend Hardening

- Typed contracts for high-risk modules.
- RBAC matrix tests.
- Transactions for critical writes.
- Audit/notification coverage.
- Import/export background jobs.
- Performance indexes and monitoring.

## Final Assessment

SchoolDesk is not a small prototype anymore. It has real role-specific routes, backend scoping, dashboards, Tables.md resources, tests, and several end-to-end workflows. The next quality jump should focus on consistency:

- Make every visible route real.
- Make Class Hub the single source for class setup modifications.
- Make main modules high-quality view and oversight screens.
- Make role permissions explicit and tested.
- Make UI scale, spacing, and states consistent across all roles.
- Keep CSV compatibility while adding safer dry-run and import status.

The most urgent action is to remove the mismatch between navigation and blank route gating. After that, Class Hub, Events, Chat Communications, and role-specific daily workflows should be polished in that order.
