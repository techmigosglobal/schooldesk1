# Teacher Module Run 1 Verification

Date: 2026-05-07  
Runtime: local Docker Go API at `http://127.0.0.1:8080/api`  
Device: Moto g85 `ZA2235WH4K` with `adb reverse tcp:8080 tcp:8080`  
Teacher QA account: `qa-teacher-run1-1778093664@schooldesk.local` / `TeacherRun1@12345`  
QA prefix: `QA-TEACH-1778093664`

## Scope

This run covered every Teacher case from `docs/role-module-test-cases.md` (`TC-TEACH-001` through `TC-TEACH-016`) using Postman CLI for backend truth and Android UI tree checks for visible integration. Admin Run 2 was already saved separately in `docs/admin-module-run2-verification.md`.

## Temporary Assets

| Asset | Path |
|---|---|
| Postman collection | `/tmp/schooldesk-teacher-postman/teacher-module.postman_collection.json` |
| Postman environment | `/tmp/schooldesk-teacher-postman/teacher-local.postman_environment.json` |
| Initial failing report | `/tmp/schooldesk-teacher-postman/teacher-run-report.json` / `.html` |
| Passing report after fix | `/tmp/schooldesk-teacher-postman/teacher-run-report-after-fix.json` / `.html` |
| UI tree captures | `/tmp/schooldesk-teacher-ui/` and `/tmp/teacher-*.txt` |

## Setup Records

| Record | ID |
|---|---|
| Teacher user | `9144fe40-f4ed-4d64-a3e6-4696e4b4cce7` |
| Teacher staff | `0510eaed-f3ef-45f2-b308-ed0362ea3205` |
| Section | `e1d172c6-ddc5-42c3-9ffd-6a09903fdd68` |
| Student | `50db78b8-a1e5-4c7c-afb0-3dc90c7a92db` |
| Enrollment | `87322978-4738-4368-b8db-1b207d6602d2` |
| Timetable slot | `c6fdaab2-53d9-419d-bc9a-886efb18bca8` |
| Guardian | `793b1fd9-2405-4dee-8940-d86e2ac6b196` |
| PTM event | `faec2929-afb8-4541-b7c5-5a9dd7d25bb8` |
| Leave type | `05222e29-bd8a-4cc9-84cc-b6e4724ffa49` |

The Postman collection was run twice: once to expose the dashboard defect and once after the fix. Disposable records were intentionally left in place for UI follow-up testing: 2 each for homework, diary, attendance sessions, announcements, messages, PTM slots, leave applications, marks, curriculum records, student notes, documents, discipline incidents, and report-card exports.

## Backend Result

Initial Postman run: 40 requests, 82 assertions, 3 failed assertions. All failures were from `GET /api/dashboard/teacher`, which returned `500 Failed to load assigned classes`.

Root cause: PostgreSQL rejected the Teacher dashboard class query because it used `SELECT DISTINCT` while ordering by `grades.grade_number`, which was not in the select list.

Fix implemented:

| File | Change |
|---|---|
| `school-backend/internal/handlers/dashboard.go` | Moved Teacher assigned-class query into a subquery that selects `grade_number` for PostgreSQL-safe ordering while returning only `id`, `section_name`, and `grade_name`. |
| `school-backend/internal/handlers/dashboard_test.go` | Added a focused regression test for the Teacher assigned-class SQL shape. |

Passing Postman run after fix: 40 requests, 82 assertions, 0 failures.

Fresh dashboard readback:

| Field | Value |
|---|---|
| HTTP | `200` |
| `success` | `true` |
| assigned classes | `1` |
| assigned students | `1` |
| homework total / due | `2 / 2` |
| assigned class | `Grade 2 A` (`e1d172c6-ddc5-42c3-9ffd-6a09903fdd68`) |

Verification commands:

| Command | Result |
|---|---|
| `postman collection run ...teacher-module.postman_collection.json ...teacher-local.postman_environment.json` | Passed: 40 requests, 82 assertions, 0 failures |
| `go test ./...` from `school-backend` | Passed |
| `flutter analyze` | Passed: no issues found |

## Test Case Matrix

| Test case | Backend status | UI/device status | Evidence |
|---|---|---|---|
| `TC-TEACH-001` Dashboard | Verified after backend fix | Partially integrated | API returns 1 class/1 student, but UI shows `Class: Unassigned` and `0 Students`; timetable and announcements do appear. |
| `TC-TEACH-002` My Classes | Verified | UI crash | Backend `GET /students`, enrollments, and timetable are valid; UI shows `Something went wrong` because local class data is empty. |
| `TC-TEACH-003` Attendance | Verified | Verified | UI shows `Student Attendance`, `Run2Updated AdminStudent`, present/absent/late counters, and save controls. |
| `TC-TEACH-004` Attendance correction | Verified API | UI exposed but not persisted | `PATCH /attendance/:id` passed; UI correction dialog only shows snackbar `Correction request sent to Admin`, no backend call. |
| `TC-TEACH-005` Homework CRUD | Verified | Partially integrated | Backend create/update/readback passed; UI shows `Class Unassigned` and `No active homework` despite 2 backend QA homework rows. |
| `TC-TEACH-006` Lesson Planner | Verified backend record | UI crash / local-only | Backend `/syllabus` create/readback passed; UI hit `Something went wrong` and screen still uses local `kTeacherSyllabus` / `kTeacherWeeklyPlan`. |
| `TC-TEACH-007` Student Performance | Verified backend marks | UI not integrated | Marks entry and student marks readback passed; screen was not reachable after Lesson Planner crash and code path has no backend client use. |
| `TC-TEACH-008` Student Notes | Verified | UI not integrated | Backend `/student-notes` create/readback passed; code path still uses local `kTeacherNotes`. |
| `TC-TEACH-009` Resources | Verified | UI not integrated | Backend `/documents` create/readback passed; screen has no backend client use. |
| `TC-TEACH-010` Communication | Verified | Partially integrated | Announcements/messages backend passed; dashboard shows QA announcements, but Communication screen was not independently confirmed and code still relies on local shared lists. |
| `TC-TEACH-011` Parent Interaction | Verified | UI pending/local-only | PTM create/readback passed; screen still uses local `kSharedPtmMeetings`. |
| `TC-TEACH-012` Leave | Verified | UI pending | Leave application create/readback passed; device pass was interrupted by earlier crash before this screen. |
| `TC-TEACH-013` Discipline / Incidents | Verified | UI pending/local-only | Backend `/discipline-incidents` create/readback passed; code path uses frontend records/local-style data. |
| `TC-TEACH-014` Reports | Verified scoped export | UI pending | `/exams/report-cards/exports` passed for Teacher; `/reports/exports` correctly rejected with 403. |
| `TC-TEACH-015` Class Diary | Verified | UI pending | Backend `/diary-entries` create passed; device pass was interrupted before this screen. |
| `TC-TEACH-016` Academic Info | Verified | UI pending | Backend school/current, academic years, sections, students, timetable passed; device pass was interrupted before this screen. |

## Confirmed Defects

| Severity | Area | Expected | Actual | Suggested fix |
|---|---|---|---|---|
| High | Teacher My Classes | Show backend assigned section and students. | Screen crashes for a real backend-created teacher with no local class mapping. | Replace `RoleAccessService` local class assumptions with `/dashboard/teacher`, `/students?section_id=...`, and timetable/staff linkage; guard zero-student calculations. |
| High | Teacher Dashboard | KPIs match `/dashboard/teacher`. | UI shows `Unassigned` and `0 Students` while backend returns 1 class and 1 student. | Feed dashboard KPIs directly from `BackendApiClient.getDashboard('teacher')`. |
| High | Lesson Planner | Show backend `/syllabus` or `/curriculum` data. | Screen crashes / still uses local storage. | Hydrate from backend curriculum records and tolerate empty plans. |
| Medium | Homework | Show teacher-created backend homework. | UI filters by `Class Unassigned` and hides backend QA homework. | Filter by `teacher_id` or `section_id`, not display class label alone. |
| Medium | Drawer profile and badges | Show logged-in teacher and backend counts. | Drawer shows hardcoded `Mrs. Anita Sharma`, `Class Teacher — 5-A`, `Homework 3`, and `Communication 2`. | Hydrate header from profile/dashboard and compute badges from backend counts. |
| Medium | Attendance correction | Persist correction request. | UI only shows snackbar, while backend supports attendance patching. | Add dedicated correction-request API or call existing attendance patch/request endpoint with audit trail. |
| Medium | Notes/resources/communication/PTM/discipline/reports | UI should reflect backend-created rows. | Several screens still use local `BackendDataService` keys or have no backend client use. | Move each screen to the verified backend endpoints listed in the Postman collection. |

## What A Teacher Can Do Today

Fully working through backend:

- Log in as Teacher and load profile.
- Read Teacher dashboard metrics after the SQL fix.
- Read assigned section, assigned student, enrollments, and timetable.
- Create/read/update attendance and patch attendance status through API.
- Create/update/read homework.
- Create/read class diary entries.
- Create/read curriculum/syllabus frontend records.
- Create/read student notes, resource documents, announcements, conversations, messages, PTM slots, leave applications, discipline incidents, marks, and report-card export records.
- Correctly blocked from creating students and from Principal/Admin report export APIs.

Working or partly visible in UI:

- Login works.
- Dashboard shows backend timetable and announcements.
- Attendance screen shows the backend assigned student and can present attendance controls.

Not yet properly UI-integrated:

- Dashboard KPI truth, My Classes, Lesson Planner, Homework visibility, Student Notes, Resources, Communication, Parent Interaction, Discipline, Reports, and drawer profile/badges need backend-first UI integration.

## Recommended Next Teacher Fix Batch

1. Replace Teacher dashboard local KPI loading with `/dashboard/teacher`.
2. Rework `RoleAccessService` Teacher scope to store `staff_id`, assigned `section_id`, grade/section label, and subject from backend dashboard/timetable.
3. Fix My Classes zero-student crash and load students by assigned `section_id`.
4. Update Homework filtering to use `teacher_id` / `section_id`, then retest `TC-TEACH-005`.
5. Update Lesson Planner, Notes, Resources, Communication, PTM, Discipline, Reports, and Class Diary screens to consume the verified backend routes from the Postman collection.
6. Replace hardcoded Teacher drawer header and badge counts with backend profile/dashboard counts.

