# Teacher Module Audit Report

Audit date: 2026-06-12  
Scope: Static code audit only. No app/backend source files were modified during this audit.  
Workspace: `/Users/techmigos/Documents/schooldesk_V1/schooldesk_V1`

## Audit Method

- Inspected teacher-related Flutter screens, shared teacher widgets, route registration, route guard metadata, API client modules, backend route handlers, and existing role-contract evidence.
- Did not run builds, app sessions, or tests because the request is audit-only.
- Found an existing dirty worktree before writing this report; those source changes were not touched.

## Teacher Module File Inventory

Core teacher UI and navigation:

- `lib/core/widgets/teacher_flow_ui.dart`
- `lib/core/widgets/teacher_navigation.dart`
- `lib/core/services/role_access_service.dart`
- `lib/routes/app_routes.dart`
- `lib/routes/route_access_guard.dart`
- `lib/routes/schooldesk_screen_registry.dart`

Implemented teacher screens:

- `lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart`
- `lib/features/academics/presentation/screens/teacher_classes_screen/teacher_classes_screen.dart`
- `lib/features/attendance/presentation/screens/teacher_attendance_screen/teacher_attendance_screen.dart`
- `lib/features/attendance/presentation/screens/teacher_my_attendance_screen/teacher_my_attendance_screen.dart`
- `lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_screen.dart`
- `lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_form_screens.dart`
- `lib/features/academics/presentation/screens/teacher_performance_screen/teacher_performance_screen.dart`
- `lib/features/academics/presentation/screens/teacher_student_notes_screen/teacher_student_notes_screen.dart`
- `lib/features/academics/presentation/screens/teacher_discipline_screen/teacher_discipline_screen.dart`
- `lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart`
- `lib/features/communication/presentation/screens/teacher_parent_interaction_screen/teacher_parent_interaction_screen.dart`
- `lib/features/leave/presentation/screens/teacher_leave_screen/teacher_leave_screen.dart`
- `lib/features/leave/presentation/screens/teacher_leave_screen/teacher_leave_request_form_screen.dart`
- `lib/features/reports/presentation/screens/teacher_reports_screen/teacher_reports_screen.dart`
- `lib/features/academics/presentation/screens/teacher_diary_screen/teacher_diary_screen.dart`
- `lib/features/academics/presentation/screens/teacher_mark_entry_screen/teacher_mark_entry_screen.dart`
- `lib/features/communication/presentation/screens/teacher_ptm_screen/teacher_ptm_screen.dart`
- `lib/features/academics/presentation/screens/teacher_syllabus_screen/teacher_syllabus_screen.dart`

Shared screens used by Teacher role:

- `lib/features/communication/presentation/screens/notification_center_screen/notification_center_screen.dart`
- `lib/features/profile/presentation/screens/profile_management_screen/profile_management_screen.dart`
- `lib/features/profile/presentation/screens/settings_screen/settings_screen.dart`
- `lib/features/communication/presentation/screens/homework_messaging_screen/homework_messaging_screen.dart`

Teacher API/backend dependency files:

- `lib/core/network/api_modules/attendance_api.dart`
- `lib/core/network/api_modules/homework_api.dart`
- `lib/core/network/api_modules/timetable_api.dart`
- `lib/core/network/api_modules/communications_api.dart`
- `lib/core/network/api_modules/leave_api.dart`
- `lib/core/network/api_modules/exams_events_api.dart`
- `school-backend/internal/routes/dashboard_routes.go`
- `school-backend/internal/routes/routes.go`
- `school-backend/internal/handlers/dashboard.go`
- `school-backend/internal/handlers/attendance.go`
- `school-backend/internal/handlers/homework_record.go`
- `school-backend/internal/handlers/homework_submission.go`
- `school-backend/internal/handlers/leave.go`
- `school-backend/internal/handlers/crud.go`
- `school-backend/internal/handlers/frontend_record.go`
- `school-backend/internal/handlers/timetable.go`

## Screen-By-Screen Audit

### Screen Number: 1

Screen Name: Teacher Dashboard  
File Path: `lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart`  
Class/widget: `TeacherDashboardScreen`, `_TeacherDashboardScreenState`  
Route Name / Navigation Source: `AppRoutes.teacherDashboard`, `/teacher-dashboard-screen`  
How the screen is reached: Teacher login redirects to `AppRoutes.teacherDashboard`; drawer bottom nav Home also links here.

Current UI Description:

- Teacher workspace home with greeting, assigned class/subject card, staff QR attendance status, quick action grid, today's timetable feed, homework/communication shortcuts, and refresh action.

Current Features Implemented:

- Loads role scope through `RoleAccessService.initialize()`.
- Reads teacher identity, assigned class, subject, today's timetable, dashboard metrics, announcements, and today's staff attendance.
- Navigation to My Attendance, Mark Attendance, Homework, My Classes, and Communication.

Current Data Source:

- Real API through `RoleAccessService` and `BackendApiClient`.

Current Backend Endpoint Used, if any:

- `GET /dashboard/teacher`
- `GET /students?section_id=...`
- `GET /timetable/slots?staff_id=...`
- `GET /attendance/staff/me/today`
- `GET /announcements`

Buttons and Actions Available:

- Refresh, Scan / My Attendance, Mark Attendance, Homework, My Classes, Communication, quick action cards.

Working Actions:

- Route pushes are implemented with `Navigator.pushNamed`.
- Backend load path exists.

Broken / Missing Actions:

- Dashboard depends heavily on `RoleAccessService.teacherClassId`; if backend has no assigned class or staff link, several cards degrade to empty/Not assigned.
- No direct class detail route exists from class card; it routes to the classes overview.

Navigation Issues:

- The dashboard quick actions route only to implemented core screens, not to newer Mark Entry/PTM/Syllabus screens.

State Management Used:

- `setState` plus static `RoleAccessService`; no Provider/Riverpod/BLoC for screen state.

UI/UX Issues:

- Uses teacher flow UI consistently, but operational density varies from other ERP screens.
- Error message is generic: "Unable to load teacher dashboard from backend."

Integration Issues:

- Dashboard is only as accurate as `GET /dashboard/teacher`, `GET /students`, and timetable scoping.

Required Fixes:

- Add explicit empty state when teacher account is not linked to staff.
- Add class-detail drill-down once class detail is implemented.

Priority: High  
Screenshots Needed: Yes

### Screen Number: 2

Screen Name: My Classes / Assigned Classes  
File Path: `lib/features/academics/presentation/screens/teacher_classes_screen/teacher_classes_screen.dart`  
Class/widget: `TeacherClassesScreen`  
Route Name / Navigation Source: `AppRoutes.teacherClasses`, `/teacher-classes-screen`  
How the screen is reached: Teacher drawer "My Classes", dashboard class action, and dashboard feed card.

Current UI Description:

- Assigned class summary, subject context, student list, and shortcuts to attendance/homework.

Current Features Implemented:

- Loads assigned classes and class students from `RoleAccessService`.
- Displays teacher class roster based on backend teacher scope.
- Opens Attendance and Homework.

Current Data Source:

- Real API indirectly through `RoleAccessService`.

Current Backend Endpoint Used, if any:

- `GET /dashboard/teacher`
- `GET /students?section_id=...`
- `GET /timetable/slots?staff_id=...`

Buttons and Actions Available:

- Refresh, Attendance, Homework.

Working Actions:

- Navigation to Attendance and Homework is implemented.

Broken / Missing Actions:

- No true Class Detail screen exists.
- No student detail drill-down, call parent, message parent, or class timetable action from roster.
- Multi-class teachers are reduced to the first assigned class by `RoleAccessService.teacherClassId`.

Navigation Issues:

- The audit scope asks for "Class Details"; current code has no dedicated route/screen for it.

State Management Used:

- `setState` plus `RoleAccessService`.

UI/UX Issues:

- Consistent teacher flow style.
- Empty class/students state exists but is not specific enough for "not linked" vs "no students enrolled".

Integration Issues:

- Depends on backend dashboard assigned classes and student list scoping.

Required Fixes:

- Add class detail screen or expand this screen with class tabs/details.
- Support teachers assigned to multiple sections/timetable slots.

Priority: High  
Screenshots Needed: Yes

### Screen Number: 3

Screen Name: Student Attendance / Mark Attendance  
File Path: `lib/features/attendance/presentation/screens/teacher_attendance_screen/teacher_attendance_screen.dart`  
Class/widget: `TeacherAttendanceScreen`, `_AttendanceStudent`  
Route Name / Navigation Source: `AppRoutes.teacherAttendance`, `/teacher-attendance-screen`  
How the screen is reached: Teacher drawer, bottom nav "Class", dashboard quick action, My Classes shortcut.

Current UI Description:

- Current class/period attendance marking screen with student list, status chips, attendance session creation/reuse, and submit button.

Current Features Implemented:

- Initializes teacher scope.
- Selects a timetable slot, creates or finds today's attendance session.
- Loads class students and enrollment IDs.
- Allows marking each student present/absent/late and submits the full list.

Current Data Source:

- Real API.

Current Backend Endpoint Used, if any:

- `GET /timetable/slots`
- `GET /attendance/sessions`
- `POST /attendance/sessions`
- `POST /attendance/sessions/:session_id/mark`
- `GET /students`
- `GET /students/:id/enrollments`

Buttons and Actions Available:

- Refresh class, status toggles, submit attendance.

Working Actions:

- Session creation and `markAttendance()` call are implemented.
- Duplicate/already marked behavior appears to be backend-handled.

Broken / Missing Actions:

- No attendance history/review screen for teacher is implemented separately.
- No reopen/edit attendance action visible for teacher.
- Slot choice is automatic; no UI to choose between multiple periods/classes.

Navigation Issues:

- Attendance History / Attendance Review is missing as a dedicated teacher screen.

State Management Used:

- `setState` plus `RoleAccessService`.

UI/UX Issues:

- Good loading/error pattern via `TeacherFlowScaffold`.
- Multi-period edge cases are hidden behind automatic slot picking.

Integration Issues:

- Requires correct timetable slot, staff link, section ID, active enrollments, and attendance-session backend scoping.

Required Fixes:

- Add period/class selector for multi-slot teachers.
- Add attendance history/review route.
- Improve missing enrollment error handling.

Priority: Critical  
Screenshots Needed: Yes

### Screen Number: 4

Screen Name: My Attendance / Staff QR Attendance  
File Path: `lib/features/attendance/presentation/screens/teacher_my_attendance_screen/teacher_my_attendance_screen.dart`  
Class/widget: `TeacherMyAttendanceScreen`, `FullScreenScannerScreen`  
Route Name / Navigation Source: `AppRoutes.teacherMyAttendance`, `/teacher-my-attendance-screen`  
How the screen is reached: Teacher drawer "My Attendance", bottom nav "Scan", dashboard staff attendance card.

Current UI Description:

- Teacher's own staff attendance status with QR scan flow.

Current Features Implemented:

- Loads today's staff attendance.
- Opens full-screen QR scanner.
- Submits scanned token to backend.

Current Data Source:

- Real API.

Current Backend Endpoint Used, if any:

- `GET /attendance/staff/me/today`
- `POST /attendance/staff/qr-scan`

Buttons and Actions Available:

- Refresh, scan QR, back from scanner.

Working Actions:

- QR scan submission is wired to backend.

Broken / Missing Actions:

- No manual fallback if camera/QR permissions fail.
- No history beyond today's attendance.

Navigation Issues:

- None found for the registered route.

State Management Used:

- `setState`.

UI/UX Issues:

- Full-screen scanner is appropriate, but camera permission errors need stronger recovery text.

Integration Issues:

- Requires QR tokens to be generated by admin/principal flow and valid for school scope.

Required Fixes:

- Add staff attendance history and permission fallback.

Priority: Medium  
Screenshots Needed: Yes

### Screen Number: 5

Screen Name: Homework / Assignments  
File Path: `lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_screen.dart`  
Class/widget: `TeacherHomeworkScreen`  
Route Name / Navigation Source: `AppRoutes.teacherHomework`, `/teacher-homework-screen`  
How the screen is reached: Teacher drawer "Homework / Diary", bottom nav "Diary", dashboard homework action, My Classes shortcut.

Current UI Description:

- Homework list for assigned class with create, edit, delete, submission-review, and "No homework" diary action.

Current Features Implemented:

- Fetches homework by section and staff.
- Fetches submissions per homework row.
- Opens form for create/edit.
- Opens submission review screen.
- Deletes homework.
- Logs no-homework diary entry.

Current Data Source:

- Real API.

Current Backend Endpoint Used, if any:

- `GET /homework?section_id=...&staff_id=...`
- `POST /homework`
- `PUT /homework/:id`
- `DELETE /homework/:id`
- `GET /homework/:id/submissions`
- `POST /diary-entries`

Buttons and Actions Available:

- Create, edit, review submissions, delete, log no homework, refresh.

Working Actions:

- CRUD and submissions routes are implemented.

Broken / Missing Actions:

- Upload Study Material is not implemented as a separate workflow; the visible upload-style icon is for homework/submissions context, not a real study-material module.
- Attachments/material upload is not clearly wired for teacher creation in this screen.

Navigation Issues:

- Bottom nav label "Diary" routes to Homework, which can confuse users because a separate Class Diary screen exists.

State Management Used:

- `setState` plus route argument objects.

UI/UX Issues:

- Homework and diary concepts are mixed in labels/actions.

Integration Issues:

- Requires teacher staff ID, section ID, homework permissions, and parent submission lifecycle.

Required Fixes:

- Separate Homework, Class Diary, and Study Material labels/workflows.
- Add real material upload if required by product scope.

Priority: High  
Screenshots Needed: Yes

### Screen Number: 6

Screen Name: Create/Edit Assignment  
File Path: `lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_form_screens.dart`  
Class/widget: `TeacherHomeworkFormScreen`, `TeacherHomeworkFormArgs`  
Route Name / Navigation Source: `AppRoutes.teacherHomeworkForm`, `/teacher-homework-screen/form`  
How the screen is reached: Homework screen create/edit button with `TeacherHomeworkFormArgs`.

Current UI Description:

- Minimal homework form with class, title, type, date, student selection, description, and submit button.

Current Features Implemented:

- Creates and updates homework.
- Can write a diary entry after homework save.
- Uses assigned classes and students passed through route args.

Current Data Source:

- Real API for save; route-local state for options.

Current Backend Endpoint Used, if any:

- `POST /homework`
- `PUT /homework/:id`
- `POST /diary-entries`

Buttons and Actions Available:

- Save/share, date selection, dropdown selections.

Working Actions:

- Create/update methods are implemented.

Broken / Missing Actions:

- If opened directly without args, fallback `teacherStaffId` is empty and save fails.
- No file attachment/material upload field.
- No rich validation for due dates vs submission dates.

Navigation Issues:

- Direct deep-link route has insufficient data because fallback args are empty.

State Management Used:

- `setState`.

UI/UX Issues:

- Clear form, but direct-entry failure state should explain that the user must open from Homework screen.

Integration Issues:

- Depends on parent screen to pass teacher/class/student context.

Required Fixes:

- Resolve context inside the form if args are missing.
- Add upload/material support if assignments require attachments.

Priority: High  
Screenshots Needed: Yes

### Screen Number: 7

Screen Name: Assignment Submission Review  
File Path: `lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_form_screens.dart`  
Class/widget: `TeacherHomeworkSubmissionsScreen`, `TeacherHomeworkSubmissionsArgs`  
Route Name / Navigation Source: `AppRoutes.teacherHomeworkSubmissions`, `/teacher-homework-screen/submissions`  
How the screen is reached: Homework list "Review" action with homework row args.

Current UI Description:

- Submission list with review actions.

Current Features Implemented:

- Loads submissions for selected homework.
- Marks submissions reviewed/accepted/rejected through backend review endpoint.

Current Data Source:

- Real API.

Current Backend Endpoint Used, if any:

- `GET /homework/:id/submissions`
- `PUT /homework/:id/submissions/:submission_id/review`

Buttons and Actions Available:

- Refresh, review status actions.

Working Actions:

- Backend review call is implemented.

Broken / Missing Actions:

- Direct route without homework args has empty fallback and cannot load a meaningful submission list.
- No preview/download handling for submitted attachments was confirmed in this screen.

Navigation Issues:

- Requires route args; not robust as a standalone route.

State Management Used:

- `setState`.

UI/UX Issues:

- Needs stronger empty state for no submissions vs invalid homework context.

Integration Issues:

- Depends on parent homework row.

Required Fixes:

- Support loading by homework ID from route arguments or query-style args.
- Add attachment preview/download if backend submissions include files.

Priority: Medium  
Screenshots Needed: Yes

### Screen Number: 8

Screen Name: Student Performance  
File Path: `lib/features/academics/presentation/screens/teacher_performance_screen/teacher_performance_screen.dart`  
Class/widget: `TeacherPerformanceScreen`, `_StudentPerformanceRow`  
Route Name / Navigation Source: `AppRoutes.teacherPerformance`, `/teacher-performance-screen`  
How the screen is reached: Teacher drawer "Student Performance", dashboard/performance shortcuts.

Current UI Description:

- Class performance overview with student rows, grades/statuses, and actions to notes/reports.

Current Features Implemented:

- Loads class students from `RoleAccessService`.
- Optionally loads report cards/marks from raw backend endpoints.
- Filters and displays progress rows.

Current Data Source:

- Mixed: real class students plus optional raw API; gracefully falls back to empty/derived state when raw endpoints fail.

Current Backend Endpoint Used, if any:

- `GET /dashboard/teacher`
- `GET /students?section_id=...`
- `GET /report-cards` or marks/report raw paths via `_optionalRaw()`

Buttons and Actions Available:

- Notes, Reports, filter chips/menus, student note drill-down.

Working Actions:

- Navigation to Student Notes and Reports is implemented.

Broken / Missing Actions:

- Actual performance analytics are partial and depend on optional raw data.
- No marks entry from this screen.
- No student profile/detail page.

Navigation Issues:

- Student row opens notes rather than a student performance detail page.

State Management Used:

- `setState`.

UI/UX Issues:

- Good teacher styling, but analytics can look real even if based on sparse data.

Integration Issues:

- Needs authoritative student marks/report-card endpoints and per-student performance model.

Required Fixes:

- Define real performance contract and connect to exams/marks/report-card backend.

Priority: Medium  
Screenshots Needed: Yes

### Screen Number: 9

Screen Name: Student Notes  
File Path: `lib/features/academics/presentation/screens/teacher_student_notes_screen/teacher_student_notes_screen.dart`  
Class/widget: `TeacherStudentNotesScreen`  
Route Name / Navigation Source: `AppRoutes.teacherStudentNotes`, `/teacher-student-notes-screen`  
How the screen is reached: Teacher drawer, Student Performance actions.

Current UI Description:

- Teacher-owned student observation/notes form and notes list.

Current Features Implemented:

- Loads class students.
- Loads `/student-notes`.
- Filters notes to teacher-owned or assigned class students.
- Creates notes.

Current Data Source:

- Real API through generic frontend-record endpoint.

Current Backend Endpoint Used, if any:

- `GET /student-notes`
- `POST /student-notes`

Buttons and Actions Available:

- Save note, refresh, student/category/priority selectors.

Working Actions:

- Create note is wired.

Broken / Missing Actions:

- No edit/delete note actions.
- Backend endpoint is generic frontend record, not a strongly typed notes domain API.

Navigation Issues:

- No student detail or parent communication action from note.

State Management Used:

- `setState`.

UI/UX Issues:

- Consistent with teacher flow.

Integration Issues:

- Needs backend scoping and lifecycle rules for notes visibility.

Required Fixes:

- Add typed backend contract or strengthen generic resource validation.
- Add edit/delete if product requires note management.

Priority: Medium  
Screenshots Needed: Yes

### Screen Number: 10

Screen Name: Teacher Discipline  
File Path: `lib/features/academics/presentation/screens/teacher_discipline_screen/teacher_discipline_screen.dart`  
Class/widget: `TeacherDisciplineScreen`  
Route Name / Navigation Source: `AppRoutes.teacherDiscipline`, `/teacher-discipline-screen`  
How the screen is reached: Registered in `AppRoutes` and screen registry, but not present in Teacher drawer and not allowed in `RouteAccessGuard`.

Current UI Description:

- Discipline incident creation/list/status screen for class students.

Current Features Implemented:

- Loads class students.
- Loads `/discipline-incidents`.
- Creates incidents.
- Updates status.
- Escalates incident by creating `/complaints`.

Current Data Source:

- Real API through generic frontend-record endpoints.

Current Backend Endpoint Used, if any:

- `GET /discipline-incidents`
- `POST /discipline-incidents`
- `PUT /discipline-incidents/:id`
- `POST /complaints`

Buttons and Actions Available:

- Save incident, resolve, escalate, refresh.

Working Actions:

- Calls exist for save/update/escalate.

Broken / Missing Actions:

- Route guard omission likely blocks teacher access through guarded navigation.
- Not visible in Teacher drawer.
- Delete is not visible.

Navigation Issues:

- `AppRoutes.teacherDiscipline` is in `teacherRoutes` and registry, but missing from `RouteAccessGuard._roleRoutes`.

State Management Used:

- `setState`.

UI/UX Issues:

- Consistent teacher flow, but unreachable screens create UX dead ends.

Integration Issues:

- Uses generic frontend records; prior role-scope work indicates this endpoint needs careful teacher ownership scoping.

Required Fixes:

- Add to route guard and drawer if intended for Teacher role.
- Confirm backend scope for teacher-created vs school-created incidents.

Priority: High  
Screenshots Needed: Yes

### Screen Number: 11

Screen Name: Teacher Communication  
File Path: `lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart`  
Class/widget: `TeacherCommunicationScreen`, `_DirectThread`, `_ChatTarget`  
Route Name / Navigation Source: `AppRoutes.teacherCommunication`, `/teacher-communication-screen`  
How the screen is reached: Teacher drawer "Communication", dashboard communication action, notification resolver for message/announcement.

Current UI Description:

- Tabbed/chat-first communication screen with parent conversation list, direct messages, chat panel, and notices.

Current Features Implemented:

- Loads message conversations, messages, direct communications, announcements, staff, and class students.
- Builds chat targets from staff and class student parent accounts.
- Sends legacy messages to `/messages`.
- Creates message conversations.
- Sends direct communications through `/communications`.
- Marks messages/direct communications read.

Current Data Source:

- Real API, but mixed between legacy `/message-conversations` + `/messages` and newer `/communications`.

Current Backend Endpoint Used, if any:

- `GET /message-conversations`
- `POST /message-conversations`
- `GET /messages`
- `POST /messages`
- `PUT /messages/:id`
- `GET /communications`
- `POST /communications`
- `PUT /communications/:id`
- `GET /announcements`
- `GET /staff`
- `GET /students`

Buttons and Actions Available:

- Select conversations, send message, mark read, open target chat, refresh.

Working Actions:

- Sending and read-marking calls exist.

Broken / Missing Actions:

- Two communication models can drift and produce inconsistent inbox counts.
- Parent account extraction depends on student payload containing `parentAccounts`.
- No attachment support confirmed.

Navigation Issues:

- Drawer also links to `homeworkMessaging`, creating a second messaging surface outside this screen.

State Management Used:

- `setState`, `TabController`, periodic refresh timer.

UI/UX Issues:

- Rich screen, but multiple tabs/chat sources can be confusing.

Integration Issues:

- Needs decision on canonical communication backend: `/communications` vs `/messages`.

Required Fixes:

- Consolidate communication model or clearly separate direct messages from homework conversations.
- Ensure parent account data exists in teacher-scoped student API.

Priority: High  
Screenshots Needed: Yes

### Screen Number: 12

Screen Name: Parent Interaction  
File Path: `lib/features/communication/presentation/screens/teacher_parent_interaction_screen/teacher_parent_interaction_screen.dart`  
Class/widget: `TeacherParentInteractionScreen`  
Route Name / Navigation Source: `AppRoutes.teacherParentInteraction`, `/teacher-parent-interaction-screen`  
How the screen is reached: Teacher drawer "Parent Interaction".

Current UI Description:

- PTM/parent interaction overview with availability creation and meeting status updates.

Current Features Implemented:

- Loads `/parent-teacher-meetings`.
- Filters to teacher/class scope in UI.
- Creates availability rows.
- Marks meetings completed/cancelled.

Current Data Source:

- Real API through CRUD route.

Current Backend Endpoint Used, if any:

- `GET /parent-teacher-meetings`
- `POST /parent-teacher-meetings`
- `PUT /parent-teacher-meetings/:id`

Buttons and Actions Available:

- Add availability, complete, cancel, refresh.

Working Actions:

- Calls are implemented.

Broken / Missing Actions:

- Duplicates much of `TeacherPTMScreen`.
- Availability creation uses generic meeting row creation instead of the dedicated `/teacher/ptm-slots` backend route.

Navigation Issues:

- Overlaps with `/teacher-ptm-screen`, which is registered but guard-blocked.

State Management Used:

- `setState`, `TabController`.

UI/UX Issues:

- Duplicate PTM surfaces make teacher workflow unclear.

Integration Issues:

- Backend has both `/parent-teacher-meetings` and `/teacher/ptm-slots`; frontend should choose one contract.

Required Fixes:

- Merge or remove duplicate PTM screen.
- Use dedicated teacher PTM-slot API if that is the intended contract.

Priority: High  
Screenshots Needed: Yes

### Screen Number: 13

Screen Name: Teacher Leave  
File Path: `lib/features/leave/presentation/screens/teacher_leave_screen/teacher_leave_screen.dart`  
Class/widget: `TeacherLeaveScreen`  
Route Name / Navigation Source: `AppRoutes.teacherLeave`, `/teacher-leave-screen`  
How the screen is reached: Teacher drawer "Leave", notification resolver for leave.

Current UI Description:

- Leave balance/history screen with request button.

Current Features Implemented:

- Loads leave types, balances, and teacher applications.
- Opens request form with staff ID/name and leave type/balance args.

Current Data Source:

- Real API.

Current Backend Endpoint Used, if any:

- `GET /leave/types`
- `GET /leave/balances?staff_id=...`
- `GET /leave/applications?staff_id=...`

Buttons and Actions Available:

- Apply, refresh.

Working Actions:

- Leave load and form navigation are implemented.

Broken / Missing Actions:

- No recall/cancel action visible even though backend route exists for teacher recall.
- Apply disabled when staff ID missing.

Navigation Issues:

- Registered and guard-allowed.

State Management Used:

- `setState`.

UI/UX Issues:

- Good teacher flow consistency.

Integration Issues:

- Requires seeded leave types and valid teacher staff link.

Required Fixes:

- Add recall/cancel flow if expected.
- Improve missing leave type/staff-link empty states.

Priority: High  
Screenshots Needed: Yes

### Screen Number: 14

Screen Name: Teacher Leave Request Form  
File Path: `lib/features/leave/presentation/screens/teacher_leave_screen/teacher_leave_request_form_screen.dart`  
Class/widget: `TeacherLeaveRequestFormScreen`, `TeacherLeaveRequestFormArgs`  
Route Name / Navigation Source: `AppRoutes.teacherLeaveRequestForm`, `/teacher-leave-screen/request`  
How the screen is reached: Teacher Leave Apply button with args.

Current UI Description:

- Leave application form with leave type, dates, reason, and submit.

Current Features Implemented:

- Submits teacher leave application.
- Uses passed leave types/balances.

Current Data Source:

- Real API for submit; route-local state for leave types.

Current Backend Endpoint Used, if any:

- `POST /leave/applications`

Buttons and Actions Available:

- Submit, date pickers, leave type selection.

Working Actions:

- Submit is wired.

Broken / Missing Actions:

- Direct route fallback has empty staff ID and no leave types.
- No attachment/medical certificate flow.

Navigation Issues:

- Depends on parent screen args.

State Management Used:

- `setState`.

UI/UX Issues:

- Needs clearer empty state if leave types are unavailable.

Integration Issues:

- Backend requires a valid school leave type ID.

Required Fixes:

- Resolve staff and leave types in form when args are missing.
- Add recall/cancel/edit if required.

Priority: High  
Screenshots Needed: Yes

### Screen Number: 15

Screen Name: Teacher Reports  
File Path: `lib/features/reports/presentation/screens/teacher_reports_screen/teacher_reports_screen.dart`  
Class/widget: `TeacherReportsScreen`, `_TeacherReportType`  
Route Name / Navigation Source: `AppRoutes.teacherReports`, `/teacher-reports-screen`  
How the screen is reached: Teacher drawer "Reports", Student Performance actions.

Current UI Description:

- Report dashboard for attendance, homework, notes, incidents, and export history.

Current Features Implemented:

- Loads attendance sessions, homework, student notes, discipline incidents, report exports.
- Creates report export requests.
- Links to report card generator.

Current Data Source:

- Real API, with optional raw endpoint reads.

Current Backend Endpoint Used, if any:

- `GET /attendance/sessions`
- `GET /homework`
- `GET /student-notes`
- `GET /discipline-incidents`
- `GET /report-exports`
- `POST /report-exports`

Buttons and Actions Available:

- Export PDF/CSV or similar format actions, report card generator link, refresh.

Working Actions:

- Export request call exists.

Broken / Missing Actions:

- `AppRoutes.reportCardGenerator` is admin-only in route guard, so Teacher clicking report card generator may be blocked.
- Export download/open is not clearly implemented; screen creates export record.

Navigation Issues:

- Teacher route to report-card generator likely violates guard because `reportCardGenerator` is allowed only for admin.

State Management Used:

- `setState`.

UI/UX Issues:

- Report exports list may not make export availability clear.

Integration Issues:

- Needs teacher-scoped report generation/download backend.

Required Fixes:

- Add teacher-safe report generator route or hide blocked button.
- Complete export download/status lifecycle.

Priority: Medium  
Screenshots Needed: Yes

### Screen Number: 16

Screen Name: Class Diary  
File Path: `lib/features/academics/presentation/screens/teacher_diary_screen/teacher_diary_screen.dart`  
Class/widget: `TeacherDiaryScreen`  
Route Name / Navigation Source: `AppRoutes.teacherDiary`, `/teacher-diary-screen`  
How the screen is reached: Teacher drawer "Class Diary"; route is guard-allowed.

Current UI Description:

- Daily diary entries list and entry form for teaching progress/homework/class notes.

Current Features Implemented:

- Loads `/diary-entries`.
- Filters by teacher or section.
- Creates diary entry.
- Deletes diary entry.

Current Data Source:

- Real API through typed CRUD route.

Current Backend Endpoint Used, if any:

- `GET /diary-entries`
- `POST /diary-entries`
- `DELETE /diary-entries/:id`

Buttons and Actions Available:

- Save diary, no-homework variant, delete, refresh.

Working Actions:

- Save/delete calls are implemented.

Broken / Missing Actions:

- No edit diary entry action.
- Parent visibility is implied by backend but not controlled in UI.

Navigation Issues:

- Bottom nav "Diary" goes to Homework, not this screen.

State Management Used:

- `setState`.

UI/UX Issues:

- Good teacher flow consistency, but naming collides with Homework screen.

Integration Issues:

- Requires diary records to be correctly scoped to teacher/section.

Required Fixes:

- Add edit/publish visibility if required.
- Fix bottom nav label/route mismatch.

Priority: Medium  
Screenshots Needed: Yes

### Screen Number: 17

Screen Name: Marks Entry  
File Path: `lib/features/academics/presentation/screens/teacher_mark_entry_screen/teacher_mark_entry_screen.dart`  
Class/widget: `TeacherMarkEntryScreen`, `_StudentMarkRow`  
Route Name / Navigation Source: `AppRoutes.teacherMarkEntry`, `/teacher-mark-entry-screen`  
How the screen is reached: Registered in routes and screen registry, but not in Teacher drawer and not allowed by route guard.

Current UI Description:

- Exam schedule picker and marks entry table for class students.

Current Features Implemented:

- Loads exam schedules from raw endpoint.
- Filters schedules to teacher class when class ID exists.
- Loads students and existing marks.
- Submits marks payload.

Current Data Source:

- Real API.

Current Backend Endpoint Used, if any:

- `GET /exams/schedules`
- `GET /students`
- `GET /exams/schedules/:id/marks`
- `POST /exams/schedules/:id/marks`
- `GET /students/:id/enrollments`

Buttons and Actions Available:

- Select schedule, enter marks, submit marks, back to schedule list, refresh.

Working Actions:

- Backend calls exist.

Broken / Missing Actions:

- Route is missing from `RouteAccessGuard._roleRoutes` for teacher.
- Not visible in Teacher drawer.
- No validation against max marks beyond local fields was confirmed.

Navigation Issues:

- Likely inaccessible through normal teacher navigation.

State Management Used:

- `setState`.

UI/UX Issues:

- Functional but isolated from performance/reports screens.

Integration Issues:

- Needs teacher permission and route access alignment.

Required Fixes:

- Add route guard and drawer entry if Marks Entry is part of Teacher module.
- Add link from Performance/Exams.

Priority: Critical  
Screenshots Needed: Yes

### Screen Number: 18

Screen Name: Teacher PTM  
File Path: `lib/features/communication/presentation/screens/teacher_ptm_screen/teacher_ptm_screen.dart`  
Class/widget: `TeacherPTMScreen`  
Route Name / Navigation Source: `AppRoutes.teacherPTM`, `/teacher-ptm-screen`  
How the screen is reached: Registered in routes and screen registry, but not in Teacher drawer and not allowed by route guard.

Current UI Description:

- PTM slots/meeting workflow with create availability and meeting status actions.

Current Features Implemented:

- Loads `/parent-teacher-meetings`.
- Creates availability via generic PTM route.
- Updates meeting status.

Current Data Source:

- Real API through generic CRUD route.

Current Backend Endpoint Used, if any:

- `GET /parent-teacher-meetings`
- `POST /parent-teacher-meetings`
- `PUT /parent-teacher-meetings/:id`

Buttons and Actions Available:

- Create availability, complete, cancel/delete-as-cancel, refresh.

Working Actions:

- Calls exist.

Broken / Missing Actions:

- Duplicate of Parent Interaction PTM functions.
- Route is guard-blocked for Teacher.
- Does not use dedicated backend `/teacher/ptm-slots`.

Navigation Issues:

- Registered but effectively disconnected.

State Management Used:

- `setState`, `TabController`.

UI/UX Issues:

- Duplicate workflow increases confusion.

Integration Issues:

- Backend has two PTM contracts; frontend uses generic one here.

Required Fixes:

- Merge with Parent Interaction or replace both with dedicated PTM slot API.
- Add guard/drawer only after duplicate is resolved.

Priority: High  
Screenshots Needed: Yes

### Screen Number: 19

Screen Name: Teacher Syllabus  
File Path: `lib/features/academics/presentation/screens/teacher_syllabus_screen/teacher_syllabus_screen.dart`  
Class/widget: `TeacherSyllabusScreen`  
Route Name / Navigation Source: `AppRoutes.teacherSyllabus`, `/teacher-syllabus-screen`  
How the screen is reached: Registered in routes and screen registry, but not in Teacher drawer and not allowed by route guard.

Current UI Description:

- Syllabus progress screen with topic status updates and topic creation.

Current Features Implemented:

- Loads `/syllabus`.
- Filters records by teacher/staff/class.
- Updates topic status.
- Adds new topic.

Current Data Source:

- Real API through generic frontend-record endpoint.

Current Backend Endpoint Used, if any:

- `GET /syllabus`
- `PUT /syllabus/:id`

Buttons and Actions Available:

- Refresh, topic status buttons, add topic.

Working Actions:

- Update calls are implemented.

Broken / Missing Actions:

- Route is missing from teacher guard.
- Not visible in Teacher drawer.
- Generic `/syllabus` endpoint may not enforce curriculum validation strongly enough.

Navigation Issues:

- Registered but disconnected from normal teacher navigation.

State Management Used:

- `setState`.

UI/UX Issues:

- Consistent teacher style, but workflow is isolated.

Integration Issues:

- Needs route/guard/drawer alignment and stronger syllabus backend contract.

Required Fixes:

- Add guard/drawer entry if intended.
- Define typed syllabus progress endpoint.

Priority: High  
Screenshots Needed: Yes

### Screen Number: 20

Screen Name: Notification Center  
File Path: `lib/features/communication/presentation/screens/notification_center_screen/notification_center_screen.dart`  
Class/widget: `NotificationCenterScreen`, `NotificationRouteResolver`  
Route Name / Navigation Source: `AppRoutes.notificationCenter`, `/notification-center-screen`  
How the screen is reached: Teacher drawer footer Notifications with argument `teacher`.

Current UI Description:

- Shared notification list filtered by role with mark-read and open notification actions.

Current Features Implemented:

- Loads notifications through `NotificationService`.
- Filters notifications for teacher/all.
- Marks individual/all as read.
- Resolves notification route targets by role.

Current Data Source:

- Real API.

Current Backend Endpoint Used, if any:

- `GET /notifications`
- `PUT /notifications/:id/read` or API client generated equivalent.

Buttons and Actions Available:

- Mark all read, refresh, notification tap/open.

Working Actions:

- Role-filtered load and mark-read are implemented.

Broken / Missing Actions:

- Route resolver can only open routes allowed by guard; teacher Mark Entry/PTM/Syllabus notifications may fall back away if requested.

Navigation Issues:

- Shared route is guard-allowed.

State Management Used:

- `setState`, `NotificationService` (`ChangeNotifier`).

UI/UX Issues:

- Shared layout differs from teacher flow styling.

Integration Issues:

- Needs notification payloads to include route/type consistently.

Required Fixes:

- Ensure resolver mappings cover all teacher workflows after route guard is fixed.

Priority: Medium  
Screenshots Needed: Yes

### Screen Number: 21

Screen Name: Teacher Profile  
File Path: `lib/features/profile/presentation/screens/profile_management_screen/profile_management_screen.dart`  
Class/widget: `ProfileManagementScreen`  
Route Name / Navigation Source: `AppRoutes.profileScreen`, `/profile-screen` with argument `teacher`  
How the screen is reached: Teacher drawer footer Profile.

Current UI Description:

- Shared profile page with avatar, profile data, edit mode, and settings link.

Current Features Implemented:

- Loads user profile.
- Updates profile fields.
- Uploads avatar.
- Links to settings.

Current Data Source:

- Real API.

Current Backend Endpoint Used, if any:

- `GET /auth/profile`
- `PUT /auth/profile`
- Profile avatar upload endpoint via `BackendApiClient.uploadProfileAvatar()`

Buttons and Actions Available:

- Edit, save, upload avatar, settings.

Working Actions:

- Shared profile save and avatar upload are implemented.

Broken / Missing Actions:

- Teacher staff-specific profile fields such as designation/subjects/class ownership are not editable here.

Navigation Issues:

- Shared route is guard-allowed.

State Management Used:

- `setState`.

UI/UX Issues:

- Shared profile design, not teacher-flow-specific.

Integration Issues:

- User profile and staff record are separate; screen mostly edits user profile.

Required Fixes:

- Decide whether teacher profile should include staff record details from `/staff/:id`.

Priority: Low  
Screenshots Needed: Yes

## Teacher Module Current Flow Map

Current primary flow:

Teacher Login -> Teacher Dashboard -> My Classes -> Student Attendance -> Mark Attendance

Current homework flow:

Teacher Dashboard / My Classes -> Homework -> Homework Form -> Homework Submissions

Current communication flow:

Teacher Dashboard / Drawer -> Communication -> Parent conversations / Direct communications / Notices

Current leave flow:

Teacher Drawer -> Leave -> Leave Request Form -> Backend approval queue

Current support flows:

Teacher Drawer -> Student Performance -> Student Notes / Reports

Disconnected registered flows:

`/teacher-mark-entry-screen`, `/teacher-ptm-screen`, `/teacher-syllabus-screen`, and `/teacher-discipline-screen` exist as screens/routes but are not fully connected through teacher drawer and/or route guard.

## Teacher Module Actual Implemented Screens List

- Teacher Dashboard
- My Classes
- Student Attendance / Mark Attendance
- My Attendance / Staff QR Attendance
- Homework
- Homework Form
- Homework Submissions
- Student Performance
- Student Notes
- Discipline
- Communication
- Parent Interaction
- Leave
- Leave Request Form
- Reports
- Class Diary
- Marks Entry
- Teacher PTM
- Teacher Syllabus
- Notification Center
- Profile
- Settings
- Homework Messaging

## Teacher Module Missing Screens List

- Dedicated Class Details screen
- Dedicated Timetable screen for teacher viewing all assigned periods
- Attendance History / Attendance Review screen
- Study Materials list screen
- Upload Study Material screen
- Exams overview screen for teacher
- Student Performance detail screen
- Teacher-specific Profile/staff detail screen

## Teacher Module Partially Implemented Screens List

- My Classes: no class-detail drill-down and weak multi-class handling.
- Attendance: mark attendance exists; history/review and multi-period selector missing.
- Homework: CRUD exists; study-material/attachment workflow incomplete.
- Performance: uses mixed optional raw data; no authoritative analytics model.
- Student Notes: create/list only; no edit/delete.
- Discipline: functional but route/guard disconnected.
- Communication: rich but split across legacy and new message models.
- Parent Interaction / Teacher PTM: duplicate screens with overlapping responsibilities.
- Reports: export record creation exists; teacher-safe report generator/download flow incomplete.
- Mark Entry: implemented but route/guard/drawer disconnected.
- Syllabus: implemented but route/guard/drawer disconnected.
- Leave: request/history exists; recall/cancel not visible.

## Teacher Module Broken Navigation List

- `AppRoutes.teacherDiscipline` exists and is listed in teacher route constants, but is missing from `RouteAccessGuard._roleRoutes` teacher allow-list.
- `AppRoutes.teacherMarkEntry` exists and is listed in screen registry, but is missing from `RouteAccessGuard._roleRoutes` teacher allow-list and not shown in teacher drawer.
- `AppRoutes.teacherPTM` exists and is listed in screen registry, but is missing from `RouteAccessGuard._roleRoutes` teacher allow-list and duplicates Parent Interaction.
- `AppRoutes.teacherSyllabus` exists and is listed in screen registry, but is missing from `RouteAccessGuard._roleRoutes` teacher allow-list and not shown in teacher drawer.
- Teacher Reports links to `AppRoutes.reportCardGenerator`, but that route is admin-only in the guard.
- Teacher bottom navigation label "Diary" routes to `AppRoutes.teacherHomework` while a real `TeacherDiaryScreen` exists.
- Homework Form and Homework Submissions direct routes use empty fallback args and are not robust deep links.
- Leave Request Form direct route uses empty fallback args and is not robust as a standalone screen.
- No route exists for class details, teacher timetable, attendance history/review, study materials, or upload study material.

## Teacher Module API Integration Status

| Feature | Screen | API Connected? | Endpoint | Status | Issue |
|---|---|---:|---|---|---|
| Dashboard | Teacher Dashboard | Yes | `/dashboard/teacher` | Working path | Depends on staff link and assigned classes |
| Classes | My Classes | Yes, indirect | `/dashboard/teacher`, `/students`, `/timetable/slots` | Partial | No class detail, weak multi-class support |
| Timetable | Dashboard/RoleAccessService | Yes | `/timetable/slots` | Partial | No dedicated teacher timetable screen |
| Attendance | Student Attendance | Yes | `/attendance/sessions`, `/attendance/sessions/:id/mark` | Partial | No history/review selector |
| Staff Attendance | My Attendance | Yes | `/attendance/staff/me/today`, `/attendance/staff/qr-scan` | Working path | No history/manual fallback |
| Homework | Homework | Yes | `/homework` | Working path | Study material/attachments unclear |
| Homework Submissions | Submission Review | Yes | `/homework/:id/submissions`, `/review` | Working path | Direct route args fragile |
| Diary | Homework/Class Diary | Yes | `/diary-entries` | Working path | Homework/diary labels overlap |
| Student Notes | Student Notes | Yes | `/student-notes` | Partial | Generic record endpoint, no edit/delete |
| Discipline | Discipline | Yes | `/discipline-incidents`, `/complaints` | Disconnected | Guard/drawer missing |
| Communication | Communication | Yes | `/messages`, `/message-conversations`, `/communications` | Partial | Two message models coexist |
| PTM | Parent Interaction / Teacher PTM | Yes | `/parent-teacher-meetings`, `/teacher/ptm-slots` backend exists | Partial | Frontend duplicates and does not use dedicated teacher PTM slots |
| Leave | Teacher Leave | Yes | `/leave/types`, `/leave/balances`, `/leave/applications` | Working path | No recall/cancel UI |
| Reports | Teacher Reports | Yes | `/report-exports` | Partial | Report-card generator route blocked for teacher |
| Marks | Marks Entry | Yes | `/exams/schedules/:id/marks` | Disconnected | Guard/drawer missing |
| Syllabus | Teacher Syllabus | Yes | `/syllabus` | Disconnected | Guard/drawer missing |
| Notifications | Notification Center | Yes | `/notifications` | Working path | Resolver limited by guard issues |
| Profile | Profile | Yes | `/auth/profile` | Working path | Does not manage teacher staff record |

## Teacher Module Mock/Dummy Data Report

- No primary teacher screen is purely mock/static-only.
- Several screens use backend-derived fallback/default values from `RoleAccessService`, such as `Not assigned`, `General`, empty route args, or generated labels.
- `TeacherHomeworkFormScreen`, `TeacherHomeworkSubmissionsScreen`, and `TeacherLeaveRequestFormScreen` have fallback args that are local/default, not backend-loaded.
- `TeacherPerformanceScreen` can display derived rows from class students even when marks/report-card optional raw endpoints are empty or unavailable.
- `RoleAccessService` maps backend students into simplified local maps with placeholder fields such as `attendance: Not marked` and `grade: N/A`.

## Teacher Module Required Backend APIs

Dashboard:

- `GET /dashboard/teacher` with staff ID, assigned classes, metrics, current timetable, attendance status, homework count, unread count.

Classes:

- `GET /teacher/classes`
- `GET /teacher/classes/:id`
- `GET /teacher/classes/:id/students`
- Or continue with `/dashboard/teacher` + `/students`, but add multi-class support.

Attendance:

- `GET /teacher/timetable`
- `GET /attendance/sessions?teacher_id=&section_id=&date=`
- `POST /attendance/sessions`
- `POST /attendance/sessions/:id/mark`
- `POST /attendance/sessions/:id/reopen`
- `GET /attendance/history?teacher_id=&section_id=`

Assignments/Homework:

- `GET /homework?staff_id=&section_id=`
- `POST /homework`
- `PUT /homework/:id`
- `DELETE /homework/:id`
- `GET /homework/:id/submissions`
- `PUT /homework/:id/submissions/:submission_id/review`

Study Materials:

- `GET /study-materials?teacher_id=&section_id=`
- `POST /study-materials`
- `PUT /study-materials/:id`
- `DELETE /study-materials/:id`
- File upload/download endpoints.

Exams/Marks:

- `GET /exams/schedules?teacher_id=&section_id=`
- `GET /exams/schedules/:id/marks`
- `POST /exams/schedules/:id/marks`
- `GET /students/:id/performance`
- `GET /teacher/report-cards`

Messages:

- Choose one canonical path:
- `/communications` for direct messages, or
- `/message-conversations` + `/messages` for conversation threads.

Notifications:

- `GET /notifications`
- Mark read/all-read endpoints.
- Payload route/type contract for teacher workflows.

Profile:

- `GET /auth/profile`
- `PUT /auth/profile`
- Avatar upload.
- Optional `GET /staff/:id` for teacher staff details.

Leave Requests:

- `GET /leave/types`
- `GET /leave/balances?staff_id=`
- `GET /leave/applications?staff_id=`
- `POST /leave/applications`
- `POST /leave/applications/:id/recall`

## Teacher Module UI/UX Consistency Report

Bottom navigation consistency:

- Most teacher screens use `TeacherFlowScaffold` and the shared bottom actions.
- Bottom action "Diary" routes to Homework, not Class Diary, which is inconsistent.

AppBar/header consistency:

- Teacher screens using `TeacherFlowScaffold` are consistent.
- Shared Profile/Notification/Settings screens use shared styles, not the teacher flow.

Card style consistency:

- Teacher cards are consistent through `teacher_flow_ui.dart`.
- Older/shared screens may not match the teacher-specific visual language.

Button style consistency:

- Most teacher screens use shared `TeacherFlowAction`/Material buttons.
- Some generic screens use their own button treatment.

Empty state handling:

- Present in many screens, but does not always distinguish "not linked", "no assigned class", "backend unavailable", and "no records".

Loading state handling:

- Good in `TeacherFlowScaffold`.

Error state handling:

- Present but often generic.

Mobile responsiveness:

- Teacher flow uses `TeacherFlowScrollView`, responsive padding, drawer, and bottom nav.
- Complex chat/mark-entry tables need device screenshots before implementation.

iPhone/Android compatibility issues:

- QR scanner/camera permission handling needs real device validation.
- Form/table screens should be screenshot-tested on narrow mobile widths.

## Teacher Module Integration Gaps

- Teacher role scope is centralized in `RoleAccessService`; if `/dashboard/teacher` or linked staff/class data is incomplete, many screens become empty or misleading.
- Route registration, screen registry, drawer visibility, and route guard are not aligned.
- New teacher screens exist but are disconnected: Mark Entry, PTM, Syllabus, and Discipline.
- Homework, Diary, and Study Material are conceptually mixed; Study Materials are not actually implemented as a teacher workflow.
- Communication has two backend models in use, which can split conversations and unread counts.
- PTM has duplicate frontend screens and duplicate backend possibilities.
- Attendance lacks teacher-facing history/review despite backend session support.
- Deep-link/fallback route args for forms are fragile.

## Recommended Implementation Order

1. Fix route consistency first: align `AppRoutes.routes`, `SchoolDeskScreenRegistry`, `RouteAccessGuard`, and `TeacherDrawer`.
2. Decide canonical Teacher navigation: Dashboard, Classes, Timetable, Attendance, Homework, Diary, Marks, Communication, PTM, Leave, Reports/Profile.
3. Harden `RoleAccessService`: support multiple assigned classes and clear staff-link/empty-class states.
4. Complete Attendance: add period selector and Attendance History/Review.
5. Complete Homework: separate Homework, Diary, and Study Materials; add attachment/material upload only after backend contract is confirmed.
6. Connect Marks Entry: add guard/drawer links, validate exam schedule ownership, and link from Performance.
7. Consolidate Communication: choose `/communications` or `/messages` as primary, then migrate UI/unread counts.
8. Consolidate PTM: merge Parent Interaction and Teacher PTM; use either `/teacher/ptm-slots` or `/parent-teacher-meetings`.
9. Complete Performance/Reports: connect marks/report-card data and remove teacher-blocked report-card route.
10. Add screenshot/manual QA for Android/iPhone widths after implementation changes.

## Files Not To Touch Yet

Do not modify these until the audit is reviewed and route/API decisions are made:

- `lib/core/services/role_access_service.dart`
- `lib/routes/app_routes.dart`
- `lib/routes/route_access_guard.dart`
- `lib/routes/schooldesk_screen_registry.dart`
- `lib/core/widgets/teacher_navigation.dart`
- `lib/core/widgets/teacher_flow_ui.dart`
- `lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart`
- `lib/features/communication/presentation/screens/teacher_parent_interaction_screen/teacher_parent_interaction_screen.dart`
- `lib/features/communication/presentation/screens/teacher_ptm_screen/teacher_ptm_screen.dart`
- `lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_screen.dart`
- `lib/features/attendance/presentation/screens/teacher_attendance_screen/teacher_attendance_screen.dart`
- `lib/features/academics/presentation/screens/teacher_mark_entry_screen/teacher_mark_entry_screen.dart`
- `lib/features/academics/presentation/screens/teacher_syllabus_screen/teacher_syllabus_screen.dart`
- `school-backend/internal/routes/routes.go`
- `school-backend/internal/handlers/crud.go`
- `school-backend/internal/handlers/frontend_record.go`
- `school-backend/internal/handlers/dashboard.go`

## Final Recommendation

The Teacher Module should be partially reused and integrated, not rebuilt from scratch.

Reusable:

- Teacher flow scaffold/navigation/card system.
- Dashboard, attendance marking, homework CRUD, leave request, class diary, student notes, and staff QR attendance foundations.

Needs integration/refactor:

- Route guard/drawer alignment.
- Multi-class teacher scope.
- Attendance history/review.
- Marks Entry, PTM, Syllabus, and Discipline connection.
- Communication model consolidation.
- Study Material workflow.

Rebuild only screen-by-screen where duplicate or ambiguous:

- PTM / Parent Interaction should be merged into one screen.
- Study Materials should be built as a new dedicated workflow.
- Teacher Timetable and Attendance History should be added as focused screens rather than folded into unrelated screens.
