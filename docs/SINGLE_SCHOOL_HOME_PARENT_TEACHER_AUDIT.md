# Single-School Homescreen, Parent Module, and Teacher Module Audit

Date: 2026-06-09
Scope: Flutter app (`lib/`), route registry/guards (`lib/routes/`), selected Go backend routes (`school-backend/internal/`)
Mode: Static audit plus targeted tests. No implementation changes were made for this audit.

## Executive Summary

SchoolDesk is already close to a single-school ERP in data model and role flow: users authenticate into one scoped school, and dashboards fetch role-specific backend data. The main gap is presentation and consistency. The landing page still feels like a generic public-school marketing carousel with setup affordances, while the parent and teacher modules contain a mix of mature backend-backed workflows and newer screens that are registered but not fully integrated into route guards, navigation, metadata, and row-level product expectations.

Highest priority issues:

1. Parent and teacher "new" routes are registered in `AppRoutes.routes` but missing from `RouteAccessGuard`, so wrong-role access is not consistently redirected.
2. Several newer parent screens are not exposed in `ParentDrawer`, which means they are routable but effectively hidden unless deep-linked.
3. Parent discipline reads `/discipline-incidents`, but the current generic backend handler scopes parent reads by `created_by`; parents will not see school-created incident records for their linked child.
4. Teacher marks/syllabus/PTM routes are registered but not present in teacher navigation/guard coverage, and some use broad raw endpoints plus client-side filtering.
5. Existing parent-module contract test fails against current backend source, which means the tests are stale or the parent summary contract changed without updating coverage.

## Single-School Homescreen Direction

### Current State

- `LandingPageScreen` hardcodes `Public School` as `_schoolName` and presents five slides: admissions, parent portal, curriculum, campus life, and about.
- The top bar exposes a `Set up school` action that routes to onboarding.
- The primary login action routes to `AppRoutes.principalLogin`, while role-specific login routes exist separately.
- The carousel animation is pleasant, but the page reads like a generic reusable school template instead of one school's digital front door.

### Product Direction

The application should feel like one school's official mobile portal, not a multi-tenant product shell.

Recommended homescreen concept:

- Replace generic tenant/setup language with a single-school identity panel: school name, logo, board/affiliation, motto, location, and today status.
- Keep the sliding animation, but make it operational and interactive:
  - Today at school: events, holiday status, notices, fee due reminders.
  - Role entry dock: Principal/Admin, Teacher, Parent.
  - Campus highlights: academics, attendance, homework, exams, fees, communication.
  - Admissions or enquiry card only if the school wants a public-facing admissions flow.
- Use a more eye-catching but still school-appropriate UI:
  - Full-bleed or large school/campus image background.
  - Animated role cards that lift/slide on tap.
  - Progress dots plus swipe hint.
  - Micro-interactions for notices, calendar, and role cards.
  - Avoid "create school", "setup school", or tenant-like entry points on the public first screen.
- For a single school, keep `school_id` internally for backend scoping, but hide any school selector or tenant creation UI from normal users.

### UX Improvements To Plan Before Implementation

- Add a single-school config source instead of hardcoded `Public School`; prefer backend `getCurrentSchool()` after auth and a public/static school profile before auth.
- Add one role login selector instead of pushing everyone through principal login.
- Replace onboarding button with "Admin setup" behind authenticated admin/principal access or a hidden setup route.
- Add real school media assets; the current icon/card carousel is clean but not emotionally specific.
- Respect reduced-motion settings for the auto slider.
- Ensure the first viewport hints at the next slide/action without requiring a scroll.

## Parent Module Audit

### Route And Navigation Findings

| Finding | Severity | Evidence | Impact | Recommendation |
|---|---:|---|---|---|
| New parent routes are missing from `RouteAccessGuard`. | P1 | `parentTimetable`, `parentExamSchedule`, `parentReportCards`, `parentPTMBooking`, `parentDiscipline` are defined and registered in `app_routes.dart`, but `route_access_guard.dart` only allows older parent routes through `feePaymentReceipt`. | Wrong-role users can reach these routes without the normal redirect behavior because unknown protected routes return `null` in `redirectFor`. | Add these routes to `_routeRoles` with `{'parent'}` and add route guard tests. |
| New parent routes are not visible in `ParentDrawer`. | P2 | Drawer includes dashboard, progress, attendance, homework, diary, notices, chat/PTM, fees, leave, calendar, documents, academic info. It does not include timetable, exam schedule, report cards, PTM booking, or discipline. | Features exist but are hard to discover and may look broken or incomplete to parents. | Add them under Child Academics / Communication, or intentionally remove/hide them until fully integrated. |
| Existing parent module visibility test only checks older route set. | P2 | `parent_module_ui_backend_contract_test.dart` checks older routes and omits the newer five parent routes. | Missing guard/navigation regressions are not caught. | Expand parent route tests to include every route registered in `AppRoutes.routes`. |

### Backend Integration Findings

| Finding | Severity | Evidence | Impact | Recommendation |
|---|---:|---|---|---|
| Parent timetable uses the correct self-service backend route but passes query in the path string. | P3 | `ParentTimetableScreen` calls `getRawList('/me/timetable?student_id=$studentId')`; backend has `GET /me/timetable`. | Works with Dio in many cases, but bypasses the cleaner `queryParameters` API and is harder to test/cache. | Use `getRawList('/me/timetable', queryParameters: {'student_id': studentId})`. |
| Parent exam schedule also uses path-string query. | P3 | `ParentExamScheduleScreen` calls `getRawList('/me/exam-schedule?student_id=$studentId')`; backend has `GET /me/exam-schedule`. | Same maintainability risk as timetable. | Use structured query parameters. |
| Parent discipline cannot see school-created incidents. | P1 | `ParentDisciplineScreen` reads `/discipline-incidents`. Backend `FrontendRecordHandler` scopes parent-owned records by `created_by = currentUserID`. | School/teacher-created discipline incidents for a linked child are likely hidden from parents, while the UI promises "Monitor student behavior and incident reports." | Create a child-scoped discipline endpoint or adjust frontend record scoping to allow linked-child incident visibility. |
| Parent report cards use `GET /exams/report-cards` and export endpoints that are RBAC-enabled for Parent. | P2 | Backend routes include Parent for report cards and exports. | Good base, but the app still filters export history client-side by `parameters.student_id`. | Ensure backend report export list is also scoped by linked student for Parent, not only filtered in Flutter. |
| Parent PTM booking uses generic `/parent-teacher-meetings`; backend has parent-scoped CRUD and book endpoints. | P2 | Routes allow Parent read/create and `PUT/PATCH /:id/book`. | The screen reads all scoped slots and filters locally. This is acceptable if CRUD scoping is strict, but UX should use the dedicated booking flow consistently. | Prefer a parent-specific PTM availability endpoint or use query params for active student/class teacher. |

### Parent UI/UX Findings

- Child selector patterns are duplicated across timetable, exam schedule, report cards, PTM booking, and discipline.
- Several screens only show snackbars on API failure, then leave the body in an empty-looking state.
- The parent dashboard has a stronger responsive/mobile treatment than the newer child-specific screens; newer screens use basic fixed padding and `Column + Expanded`.
- Floating action button location is `startFloat` on several parent screens, which can conflict with expected role FAB placement and bottom navigation muscle memory.
- Empty states are polite, but they do not explain whether data is unpublished, unavailable, or failed to load.

## Teacher Module Audit

### Route And Navigation Findings

| Finding | Severity | Evidence | Impact | Recommendation |
|---|---:|---|---|---|
| New teacher routes are missing from `RouteAccessGuard`. | P1 | `teacherMarkEntry`, `teacherPTM`, and `teacherSyllabus` are defined and registered in `app_routes.dart`; guard only includes older teacher routes through `teacherDiary`. | Wrong-role access is not consistently redirected. | Add these routes to `_routeRoles` with `{'teacher'}` and add tests. |
| `teacherDiscipline` is registered but missing from `RouteAccessGuard`. | P1 | `teacherDiscipline` is in `AppRoutes.routes`; guard omits it. | Discipline screen access control is inconsistent despite being a sensitive module. | Add to guard and test wrong-role redirects. |
| `teacherMarkEntry`, `teacherPTM`, and `teacherSyllabus` are not exposed in `TeacherDrawer`. | P2 | Teacher drawer includes Dashboard, My Attendance, Classes, Student Attendance, Homework/Diary, Class Diary, Performance, Notes, Communication, Parent Interaction, Leave, Reports. | Valuable teacher workflows are hidden unless launched through deep links or dashboard action cards. | Integrate under Learning Support / Communication / Classroom Flow, or remove until ready. |
| Teacher quick actions omit marks, PTM management, and syllabus tracking. | P2 | `_TeacherQuickActionGrid` includes classes, attendance, homework, communication, leaves, reports. | The dashboard does not surface key academic work. | Add a compact "Today's academic tasks" row with marks due, PTM slots, syllabus progress. |

### Backend Integration Findings

| Finding | Severity | Evidence | Impact | Recommendation |
|---|---:|---|---|---|
| Teacher mark entry fetches all exam schedules, then filters client-side. | P1 | `TeacherMarkEntryScreen` calls `getRawList('/exams/schedules')`, filters by `RoleAccessService.teacherClassId`, and falls back to all schedules when filtered is empty. | If backend returns schedules across school, teacher can see schedules outside assignment. The fallback is especially risky. | Create/use a teacher-scoped schedules endpoint; remove fallback to all schedules. |
| Mark entry performs one enrollment API call per student. | P2 | `_selectSchedule` loops students and awaits `getStudentEnrollments(s.id)` for every row. | Slow on large classes; high mobile latency and battery/network usage. | Return enrollment id in the section student list or fetch enrollments in one batch. |
| Mark entry writes marks via teacher RBAC-enabled endpoint. | P2 | Backend allows Teacher on `POST /exams/schedules/:schedule_id/marks`. | Good base, but row-level schedule ownership should be enforced server-side. | Ensure `EnterMarks` validates teacher access to schedule section/subject. |
| Teacher syllabus uses generic `/syllabus` frontend resource and client-side filtering. | P1 | `TeacherSyllabusScreen` loads all `/syllabus`, filters by teacher/class, then updates whole records. | If backend returns broad records, client-side filtering is not enough. Updates could overwrite unrelated fields. | Add teacher-scoped syllabus endpoint and partial topic-status update endpoint. |
| Teacher PTM screen uses generic `/parent-teacher-meetings`, while backend has `/teacher/ptm-slots`. | P2 | Routes define `GET/POST /teacher/ptm-slots`, but screen reads/writes `/parent-teacher-meetings`. | Duplicate concepts and inconsistent permission path. | Migrate teacher PTM UI to `/teacher/ptm-slots` for availability, keep generic route only for shared meeting records. |
| Teacher reports may still depend on broad export/report endpoints. | P2 | Older audit notes this risk; current route table allows Parent/Teacher on report-card exports but general reports remain Admin/Principal. | Some teacher export actions may 403 depending on category/path. | Confirm each report card/action path; hide or scope unsupported export types. |

### Teacher UI/UX Findings

- Teacher dashboard has a good interactive style and sliding/animated feel through `TeacherFlow` components, but the module map is incomplete.
- Teacher screens mix newer `TeacherFlowScaffold` with direct raw API workflows; visual consistency is decent, data consistency less so.
- Teacher PTM uses a fixed `SizedBox(height: 600)` tab body. This is fragile on small phones and landscape screens.
- Teacher mark entry can become heavy because all rows include controllers and enrollment calls; large classes may feel laggy.
- Several teacher screens show raw error strings directly, which can leak backend wording and look unpolished.

## Shared Parent/Teacher Issues

### Route Metadata And Guard Consistency

Every route in `AppRoutes.routes` should satisfy four contracts:

1. Registered in `AppRoutes.routes`.
2. Present in `SchoolDeskScreenRegistry`.
3. Allowed in `RouteAccessGuard`.
4. Either visible in navigation/dashboard or intentionally hidden with a test explaining why.

The current code satisfies this well for older routes. The newer parent/teacher routes are registered and visible through `_roleWorkflowVisibleRoutes`, but they are not fully represented in the access guard or navigation.

### Test Coverage Gaps

Targeted test run:

```text
flutter test test/unit/role_route_safety_contract_test.dart test/unit/parent_module_ui_backend_contract_test.dart test/widget/teacher_dashboard_screen_test.dart
```

Result:

- `role_route_safety_contract_test.dart`: passed for currently referenced routes.
- `teacher_dashboard_screen_test.dart`: passed.
- `parent_module_ui_backend_contract_test.dart`: failed in `parent child summaries surface backend operational fields` because the test expects `studentResponseRows(database.DB, schoolID, students)` in `parent_link.go`, but the current backend now uses an inline SQL summary implementation.

Interpretation:

- Some parent backend coverage is stale and should be updated to assert the current contract, not an old helper name.
- Existing route safety tests miss the newer route constants because they collect routes from navigation/dashboard source references, and those routes are not referenced there.

## Prioritized Action Plan

### P1 - Fix Before Treating Parent/Teacher As Production Ready

1. Add missing parent and teacher routes to `RouteAccessGuard`.
2. Add tests that iterate all role route constants, not only routes referenced by nav/dashboard files.
3. Decide whether new parent screens are official. If yes, add them to ParentDrawer and metadata/guard coverage; if no, remove or hide them.
4. Fix ParentDiscipline data model so parents can view school-created incidents for linked students.
5. Replace teacher mark/syllabus client-side filtering with backend teacher-scoped endpoints or server-side validation.

### P2 - Improve Reliability And Performance

1. Replace path-string queries with `queryParameters`.
2. Batch teacher mark-entry enrollment lookup.
3. Move teacher PTM availability to `/teacher/ptm-slots`.
4. Add proper loading/error/retry panels to newer parent screens.
5. Update stale tests in `parent_module_ui_backend_contract_test.dart`.

### P3 - UI/UX Polish

1. Extract shared parent child selector component.
2. Align parent screens with the stronger dashboard responsive layout.
3. Replace raw snackbar-only failures with inline status panels.
4. Add route-specific empty states: unpublished, not assigned, no records, or backend unavailable.
5. Add micro-interactions to role dashboards: animated status cards, swipeable child/day selectors, and subtle progress transitions.

## Suggested Homescreen Redesign Brief

Build a single-school first screen with these sections:

1. **Hero:** real school name/logo, motto, campus image, "Welcome to [School Name]".
2. **Role Dock:** Principal/Admin, Teacher, Parent login cards with icons and short purpose copy.
3. **Today Strip:** current date, school status, next event/holiday, latest notice.
4. **Interactive Slides:** keep the existing carousel, but use school-specific stories rather than generic product features.
5. **Quick Links:** admissions enquiry, contact school, location, calendar.
6. **Motion:** retain slide animation, add subtle card hover/tap motion, and respect reduced motion.

Design tone:

- Eye-catching but not overly decorative.
- School-branded, not SaaS-generic.
- One-school language everywhere.
- No tenant selection or public "set up school" affordance for normal users.

## Recommended Next Step

Before implementation, decide:

1. Should the public homescreen show admissions/enquiry content, or should it be only a login portal?
2. What is the real school name, logo, motto, and preferred color identity?
3. Which newer parent/teacher screens are official for the first release versus hidden until backend hardening is complete?

