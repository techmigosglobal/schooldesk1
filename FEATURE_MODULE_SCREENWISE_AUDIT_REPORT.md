# Feature Module Screenwise Audit Report

Date: 2026-06-18  
Scope: Subjects, Timetables, Event Posting, Calendars, Communications, and Lesson Planning for Principal and Teacher roles.  
Mode: Read-only audit plus targeted contract-test verification. No product code was changed.

## Executive Summary

The audited modules are not empty or placeholder-only. Most have real Flutter screens, route entries, API calls, and Go backend route groups. The main problems are integration consistency and product completeness:

- Some features are visible in navigation but are missing from route guards or screen registry metadata.
- Teacher event posting and lesson planning use direct `Dio` calls from UI files, while an existing contract says migrated active UI must go through the API facade.
- Lesson planner is in a conflicted state: active routes and backend exist, but one contract test still expects the teacher lesson planner module to be retired.
- Principal has backend access to lesson planners but no visible principal lesson-planner review screen was found.
- Principal timetable is intentionally read-only in the standalone timetable module, so timetable setup is split across other flows instead of being fully manageable from that screen.
- Several UI actions are worded like real workflows but only save action/instruction records.

## Verification Performed

### Static Integration Checks

Reviewed:

- Flutter route map: `lib/routes/app_routes.dart`
- Route guard: `lib/routes/route_access_guard.dart`
- Screen registry: `lib/routes/schooldesk_screen_registry.dart`
- Principal and teacher navigation: `lib/core/widgets/app_navigation.dart`, `lib/core/widgets/teacher_navigation.dart`
- Feature screens under `lib/features/academics`, `lib/features/calendar`, and `lib/features/communication`
- API facade modules under `lib/core/network/api_modules`
- Go backend routes and handlers under `school-backend/internal/routes` and `school-backend/internal/handlers`

### Targeted Tests Run

Command:

```sh
flutter test test/unit/tables_md_migration_contract_test.dart
```

Result: Failed.

Key failures:

- Active UI files still import `package:dio/dio.dart`; first reported file was `lib/features/academics/presentation/screens/lesson_planner_screen.dart`.
- Test expects `/teacher-lesson-planner-screen` not to be exposed, but it is present in `app_routes.dart`.

Command:

```sh
flutter test test/unit/event_gallery_lesson_flow_contract_test.dart
```

Result: Failed.

Key failures:

- Role guard expectation for event/gallery/planner routes failed.
- Parent dashboard no longer contains `/lesson-planners/parent`, while the test expects it.

Command:

```sh
flutter test test/unit/route_access_guard_test.dart
```

Result: Failed.

Key failures:

- Several route guard expectations fail for admin/principal-owned routed input screens.
- Teacher module route checks pass in that file, but the broader guard suite is currently not healthy.

Note: Running multiple Flutter tests in parallel triggered the Flutter startup lock, but all three commands completed and produced usable results.

## Screenwise Findings

## Principal Role

### 1. Subjects

Screen:

- `lib/features/academics/presentation/screens/principal_subjects_screen/principal_subjects_screen.dart`

Routes and access:

- Route exists: `AppRoutes.principalSubjects`
- Guard exists for principal.
- Screen registry entry exists.

Backend integration:

- Loads principal subject overview through `getPrincipalSubjectsOverview()`.
- Loads grade-subject and staff-subject mappings through `/grade-subjects` and `/staff-subjects`.
- Backend route support exists for `/subjects`, `/grade-subjects`, `/staff-subjects`, and `/principal/subjects`.

UI/UX and product gaps:

- The screen is mainly a directory/analytics workspace.
- Some action labels imply direct workflows, but the action saves a principal subject action/instruction rather than opening the actual workflow.
- Examples: “Map Teacher to Class” and “View Teaching Materials” appear as action choices, but they do not directly perform mapping or open teaching-material records.
- This can confuse principals because the visible command sounds operational while the backend effect is closer to task/instruction tracking.

Severity: Medium.

Recommended direction:

- Either rename these actions as trackable instructions, or wire them to the real mapping/material workflows.

### 2. Timetable

Screens:

- `lib/features/academics/presentation/screens/timetable_management_screen/timetable_management_screen.dart`
- `lib/features/academics/presentation/screens/principal_command_center_screens/principal_academic_command_screens.dart`
- Principal classes setup also calls timetable APIs.

Routes and access:

- `AppRoutes.principalTimetable` exists.
- `AppRoutes.timetableManagement` exists.
- Guard exists for principal.

Backend integration:

- Backend route group exists at `/timetable`.
- Timetable slots, templates, smart preview, smart generate, CSV import/export, and pre-primary timetable routes exist.
- Client API has `getTimetableSlots`, `previewSmartTimetable`, `generateSmartTimetable`, `saveTimetableTemplate`, and slot CRUD helpers.

UI/UX and product gaps:

- `TimetableManagementScreen` is deprecated and delegates to `PrincipalTimetableScreen`.
- The file explicitly says principal timetable is read-only.
- If the expected principal workflow is “manage timetable from timetable module,” the standalone screen is incomplete.
- Timetable creation/setup appears to depend on classes setup or admin-style flows rather than a complete principal timetable management surface.

Severity: High if principals are expected to manage timetable directly; Medium if read-only is intentional.

Recommended direction:

- Decide one product contract: read-only monitoring vs full principal timetable management.
- If full management is required, expose create/edit/generate/publish flows from the principal timetable screen itself.

### 3. Events Calendar

Screen:

- `lib/features/calendar/presentation/screens/events_calendar_screen/events_calendar_screen.dart`

Routes and access:

- Route exists: `AppRoutes.eventsCalendar`
- Guard exists for principal.
- Screen registry entry exists.

Backend integration:

- Loads academic years, selects current academic year, and calls `getEvents(academicYearId: selectedYearId)`.
- Backend `/events` supports read for Admin, Principal, Teacher, Parent and write for Admin/Principal.

UI/UX and product gaps:

- Principal calendar is comparatively well integrated.
- It supports current-year filtering better than the teacher calendar.
- Risk area: calendar creation/editing depends on the generic event model, while teacher event-posting uses a separate `/event-posts` approval pipeline. These are separate products and may confuse users if both are called “events.”

Severity: Low to Medium.

Recommended direction:

- Clarify the difference between school calendar events and teacher event posts in labels and navigation.

### 4. Event Approvals

Screen:

- `lib/features/communication/presentation/screens/principal_event_approval_screen.dart`

Routes and access:

- Route exists: `AppRoutes.principalEventApprovals`
- Guard exists for principal.
- Screen registry entry exists.

Backend integration:

- Uses direct `BackendApiClient.instance.dio` calls to:
  - `GET /event-posts/pending`
  - `POST /event-posts/:id/approve`
  - `POST /event-posts/:id/reject`
- Backend handlers exist for create, pending list, approve, reject, gallery, parent home feed, and all-posts listing.

UI/UX and product gaps:

- Principal approval screen only shows pending posts.
- Backend has `GET /event-posts` for all event posts, but the screen does not expose approved/rejected history or audit view.
- Rejection requires a reason, but if the dialog is confirmed with an empty reason, the screen silently does nothing.
- The screen uses raw `Dio` access instead of a typed/facade API.

Severity: Medium.

Recommended direction:

- Add approval history filters: Pending, Approved, Rejected, Drafts if applicable.
- Add a clear validation message when rejection reason is empty.
- Move event-post API calls into `BackendApiClient` or an API module.

### 5. Communication Center

Screen:

- `lib/features/communication/presentation/screens/communication_center_screen/communication_center_screen.dart`

Routes and access:

- Route exists: `AppRoutes.communicationCenter`
- Guard exists for principal.
- Screen registry entry exists.

Backend integration:

- Uses announcements, notices, notifications, profile, direct communications, and users.
- Sends direct communications through `sendCommunication`.
- Marks messages read through `markCommunicationRead`.

UI/UX and product gaps:

- This is a broad operations workspace: circulars, notice board, alerts, messages.
- It overlaps conceptually with Principal Chat Communications, which may create duplicate communication entry points.
- Backend integration is mostly real, but messages are based on generic communications rows rather than a richer conversation model.

Severity: Medium.

Recommended direction:

- Define whether Communication Center is announcement/notice operations and Chat Communications is real-time messaging.
- Keep both only if their labels and tasks are clearly separated.

### 6. Principal Chat Communications

Screen:

- `lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart`

Routes and access:

- Route exists: `AppRoutes.principalChatCommunications`
- Guard exists for principal.
- Screen registry entry exists.

Backend integration:

- Loads:
  - `/message-conversations`
  - `/messages`
  - `/communications`
  - announcements
  - teachers and parents
  - students and sections
- Sends direct teacher messages through `sendCommunication`.
- Marks direct communications read.

UI/UX and product gaps:

- Richest communication surface in the audit.
- It polls every 5 seconds, but no true realtime channel was verified.
- Monitoring settings are local notification settings, not backend-enforced communication permissions.
- Parent-chat monitoring and teacher direct messaging are mixed into one large screen, increasing complexity.

Severity: Medium.

Recommended direction:

- Keep as the primary principal messaging screen, but make monitoring settings persistent/enforced if they affect policy.
- Consider reducing overlap with Communication Center.

### 7. Principal Lesson Planning

Screen:

- No principal-facing lesson planner screen/route found.

Backend integration:

- Backend supports `GET /lesson-planners/principal` for Principal/Admin.

UI/UX and product gaps:

- Backend capability exists, but principal has no obvious screen to review teacher lesson plans.
- This is a direct screenwise gap for the requested “principal and teacher roles” scope.

Severity: High.

Recommended direction:

- Add a principal lesson planner review screen or integrate it into principal academics/subjects analytics.
- Include filters for grade, section, teacher, week, uploaded/completed status, and missing submissions.

## Teacher Role

### 1. Teacher Timetable

Screen:

- `lib/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart`

Routes and access:

- Route exists: `AppRoutes.teacherTimetable`
- Guard exists for teacher.
- Screen registry entry exists.

Backend integration:

- Requires teacher staff link through `RoleAccessService`.
- Calls `getTimetableSlots(staffId: RoleAccessService.teacherStaffId)`.
- Backend ownership tests exist around timetable access.

UI/UX and product gaps:

- Read-only schedule display is appropriate for teacher.
- The assigned-class summary uses the first timetable slot when available, which can misrepresent teachers who teach multiple classes.
- Empty state depends heavily on class assignment and timetable publication.

Severity: Low to Medium.

Recommended direction:

- Show multi-class summary instead of a single “Today’s Assigned Class” based on the first slot.

### 2. Teacher Calendar

Screen:

- `lib/features/calendar/presentation/screens/teacher_calendar_screen/teacher_calendar_screen.dart`

Routes and access:

- `AppRoutes.teacherCalendar` exists and is used in teacher navigation.
- Missing from `RouteAccessGuard`.
- Missing from `schooldesk_screen_registry.dart`.

Backend integration:

- Calls `getEvents()` with no academic year filter.

UI/UX and product gaps:

- Route exposure is inconsistent: visible in nav and route map, but not guarded/registered like other teacher screens.
- Calendar loads all events instead of current academic year events, unlike principal calendar.
- This can show stale/cross-year events to teachers.

Severity: High.

Recommended direction:

- Add `teacherCalendar` to `RouteAccessGuard` and screen registry.
- Align teacher calendar filtering with principal calendar, preferably current academic year by default.

### 3. Teacher Event Posts

Screen:

- `lib/features/communication/presentation/screens/event_post_screen.dart`

Routes and access:

- Route exists: `AppRoutes.teacherEventPosts`
- Guard exists for teacher.
- Screen registry entry exists.

Backend integration:

- Backend supports:
  - `POST /event-posts`
  - `GET /event-posts/teacher`
  - approval flow through principal/admin
  - gallery and parent home feed destinations
- Screen uploads files through `/uploads`.

UI/UX and product gaps:

- Uses direct `Dio` in the UI file.
- No grade/class targeting in the form, although backend accepts optional `grade_id`.
- Status tab only shows teacher’s own posts; no edit/resubmit flow for rejected drafts was found.
- Media URLs are stored as comma-separated values, which is fragile for future metadata.

Severity: Medium.

Recommended direction:

- Move event-post and upload calls to API facade.
- Add class/grade targeting if event posts should be scoped.
- Add edit/resubmit for rejected or draft posts.

### 4. Teacher Communication

Screen:

- `lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart`

Routes and access:

- Route exists: `AppRoutes.teacherCommunication`
- Guard exists for teacher.
- Screen registry entry exists.

Backend integration:

- Loads:
  - `/message-conversations`
  - `/messages`
  - `/communications`
  - announcements
  - staff
  - students for assigned class
- Sends messages through `/messages` and direct communications through `sendCommunication`.
- Marks communications read.

UI/UX and product gaps:

- Real backend messaging exists.
- Polls every 5 seconds rather than realtime.
- Parent chat targeting depends on `RoleAccessService.teacherClassId`, which picks a primary/class-teacher class. Teachers with multiple assigned classes may not see all possible parent contacts.
- The tab labels mix “Notices” and “Announcements” in a way that can be semantically confusing.

Severity: Medium.

Recommended direction:

- Build parent target list from all `teacherAssignedClasses`, not only one class.
- Clarify tab naming: Parent Chats, Staff Chats, Principal Messages, School Announcements.

### 5. Teacher Lesson Planner

Screen:

- `lib/features/academics/presentation/screens/lesson_planner_screen.dart`

Routes and access:

- Route exists: `AppRoutes.teacherLessonPlanner`
- Guard exists for teacher.
- Screen registry entry exists.
- Teacher dashboard and navigation expose it.

Backend integration:

- Backend supports:
  - `POST /lesson-planners`
  - `GET /lesson-planners/teacher`
  - `POST /lesson-planners/:id/complete`
  - `GET /lesson-planners/parent`
  - `GET /lesson-planners/principal`
- Create handler verifies teacher ownership by class teacher or timetable slot assignment.

UI/UX and product gaps:

- Uses direct `Dio` in the UI file.
- Contract conflict: `tables_md_migration_contract_test.dart` says teacher lesson planner should not be exposed through active routes/navigation, but the route is active.
- The upload form allows saving without requiring an attachment, so “Lesson Plan Attachment” is optional even though the workflow is upload-oriented.
- No delete/edit/update flow found.
- “Complete” can be marked by teacher; no principal review/approval step was found.
- Teacher ownership validation depends on section class-teacher assignment or timetable slots. If a teacher is assigned through another relationship only, planner creation may be blocked.

Severity: High.

Recommended direction:

- Decide whether this module is active or retired.
- If active, update tests/contracts, move API calls into facade, add edit/resubmit/delete as needed, and expose principal review.
- If retired, remove route/nav/dashboard entries and backend exposure if no longer needed.

## Cross-Module Issues

### 1. Route/Registry/Guard Drift

Teacher calendar is the clearest example: route and navigation exist, but guard/registry do not.

Impact:

- Inconsistent access control.
- Screen may not appear in app-wide registry/search/QA tools.
- Future tests may miss it.

### 2. API Facade Drift

Event posting and lesson planner screens call `BackendApiClient.instance.dio` directly and import `package:dio/dio.dart`.

Impact:

- Breaks the project’s migration contract.
- Duplicates endpoint handling in UI.
- Makes retries, errors, refresh, normalization, and tests harder to keep consistent.

### 3. Product Contract Drift

Lesson planner is both exposed and expected to be retired by an existing contract test.

Impact:

- Developers cannot know whether to fix, remove, or extend it without a product decision.
- Tests and product behavior are currently contradictory.

### 4. Principal/Teacher Scope Asymmetry

Teacher lesson planner exists. Principal backend list exists. Principal UI review does not.

Impact:

- Teachers can upload and complete plans, but principals have no clear operational oversight surface.

### 5. Event vs Event Post Naming Collision

Calendar events and teacher event posts use separate backend models and workflows.

Impact:

- Users may expect teacher event posts to appear on the calendar automatically, but they are handled through approval destinations like parent feed/gallery/landing.

## Priority Fix List

1. Resolve lesson planner product contract: active module or retired module.
2. Add `teacherCalendar` to route guard and screen registry if the feature remains active.
3. Move lesson planner and event-post API calls out of UI files into API facade methods.
4. Add principal lesson planner review UI or remove unused principal backend route.
5. Align teacher calendar academic-year filtering with principal calendar.
6. Add event-post approval history and rejection validation.
7. Rename or rewire principal subject actions that currently sound like direct workflows.
8. Reduce overlap between Communication Center and Principal Chat Communications.

## Overall Status

| Module | Principal Status | Teacher Status | Main Gap |
| --- | --- | --- | --- |
| Subjects | Partially integrated | Not a teacher module in this scope | Principal actions are more task notes than direct workflows |
| Timetable | Integrated but read-only in standalone module | Integrated read-only | Principal management expectations unclear |
| Event Posting | Approval only, pending-only view | Create/list works | Direct Dio usage, limited history, no class targeting |
| Calendar | Better integrated with academic-year filtering | Route drift and all-year loading | Teacher calendar guard/registry/filtering |
| Communications | Real backend integration, overlapping screens | Real backend integration | Polling, scope, and UX overlap |
| Lesson Planning | Backend exists, no principal UI | Active but contract-conflicted | Product decision and API facade needed |

