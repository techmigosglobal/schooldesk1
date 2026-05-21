# SchoolDesk Wireless Mobile Testing Plan

Date: 2026-05-17  
Backend target: Local Docker only. Hostinger/VPS deployment is out of scope until this sheet is green.

## Setup Commands

```bash
docker compose up -d postgres redis go-api
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/ready
scripts/verify-local-docker-api.sh

adb kill-server && adb start-server
adb devices -l
adb -s <DEVICE_ID> reverse tcp:8080 tcp:8080
adb -s <DEVICE_ID> reverse --list
flutter run -d <DEVICE_ID> --dart-define-from-file=env.json
adb -s <DEVICE_ID> shell pidof com.techmigos.schooldesk1
docker logs -f schooldesk-go-api
```

## Tickable Execution Sheet

| Tick | ID | Role | Flow | Expected Result | Backend Evidence |
|---|---|---|---|---|---|
| [x] | MOB-001 | Device | App launch with `env.json` | App opens and stays on local backend | Passed 2026-05-17: Moto g85 wireless, `adb reverse tcp:8080 tcp:8080`, app PID `8204`, screenshot `test-artifacts/wireless-2026-05-17/mob-001-launch.png`, local `schooldesk-go-api` received app requests. |
| [x] | MOB-002 | Principal | Login and dashboard | Principal dashboard opens without overflow | Passed 2026-05-17: screenshot `test-artifacts/wireless-2026-05-17/mob-002-principal-dashboard.png`; backend logged authenticated `GET /api/dashboard/principal` 200 for `user-principal-default`. |
| [x] | MOB-003 | Admin | Login and dashboard | Admin dashboard opens without overflow | Passed 2026-05-17: screenshot `test-artifacts/wireless-2026-05-17/mob-003-admin-dashboard.png`; backend logged authenticated Admin `POST /api/auth/login` 200 plus Admin dashboard data calls. |
| [x] | MOB-004 | Teacher | Login and dashboard | Teacher dashboard opens without overflow | Passed 2026-05-17: screenshot `test-artifacts/wireless-2026-05-17/mob-004-teacher-dashboard.png`; backend logged authenticated `GET /api/dashboard/teacher` 200 for Teacher role. |
| [x] | MOB-005 | Parent | Login and dashboard | Parent dashboard opens without overflow | Passed 2026-05-17: screenshot `test-artifacts/wireless-2026-05-17/mob-005-parent-dashboard.png`; backend logged authenticated `GET /api/dashboard/parent` 200 for Parent role. |
| [x] | MOB-006 | Admin | Timetable route flow | Generate/add/edit/substitution screens open separately; no popup input | Passed 2026-05-17 route/UI pass: screenshots `mob-006-admin-timetable.png`, `mob-006-timetable-generate-screen.png`, `mob-006-timetable-add-period-screen.png`, `mob-006-timetable-substitution-screen.png`; backend logged Admin `GET /api/timetable/slots`, `/api/timetable/substitutions`, `/api/sections`, `/api/staff`, `/api/subjects`, `/api/academic-years` 200. |
| [x] | MOB-007 | Admin | Exams route flow | Create/edit/publish/schedule screens work | Passed 2026-05-17: screenshots `mob-007-admin-exams.png`, `mob-007-exam-create-screen.png`, `mob-007-exam-schedule-screen.png`, `mob-007-exam-after-publish.png`; backend logged `GET /api/exams`, `GET /api/exams/schedules`, and `PATCH /api/exams/:id/publish` 200 with audit insert. |
| [x] | MOB-008 | Teacher/Parent | Homework lifecycle | Teacher creates/edits; Parent submits; Teacher reviews | Passed 2026-05-17 after backend student-filter fix: screenshots `mob-008-parent-homework-pending-after-fix.png`, `mob-008-parent-homework-after-submit-2.png`, `mob-008-teacher-submissions-after-parent-submit.png`, `mob-008-teacher-review-after-save.png`; backend logged Parent `GET /api/homework?student_id=...` 200, Parent `POST /api/homework/:id/submissions` 201, Teacher `GET /api/homework/:id/submissions` 200, Teacher `PUT /api/homework/:id/submissions/:submission_id/review` 200, with no 403s after the fix. |
| [x] | MOB-009 | Parent/Admin | Fee payment request lifecycle | Parent submits request; Admin reviews/decides | Passed 2026-05-17: screenshots `mob-009-parent-payment-form.png`, `mob-009-parent-payment-after-submit.png`, `mob-009-admin-payment-requests.png`, `mob-009-admin-payment-decision-screen.png`, `mob-009-admin-payment-after-approve.png`; backend logged Parent `POST /api/fees/payment-requests` 201, Admin `GET /api/fees/payment-requests` 200, Admin `PUT /api/fees/payment-requests/:id/decision` 200. |
| [x] | MOB-010 | Parent/Principal | Student leave lifecycle | Parent submits linked-student leave; Principal/Admin/Teacher sees allowed scope | Passed 2026-05-18 after Approval Center bridge: screenshots `test-artifacts/wireless-2026-05-18/mob-010-parent-leave-after-submit.png`, `mob-010-principal-approval-center.png`, `mob-010-principal-student-leave-after-approve.png`; backend logged Principal `GET /api/student-leave/applications` 200 and `PUT /api/student-leave/applications/:id/decision` 200. |
| [x] | MOB-011 | All allowed roles | Report/export lifecycle | Export buttons create backend jobs and show status/download metadata | Passed 2026-05-18: API proof passed for Principal/Admin/Teacher/Parent export permissions, generated artifacts/download URLs, and Parent general-report denial. Phone proof passed for Principal `/api/reports/exports`, Admin `/api/reports/exports`, Admin `/api/fees/reports/exports`, Teacher `/api/exams/report-cards/exports`, and Parent `/api/exams/report-cards/exports`. Parent report-card button was verified after adding local Docker QA marks/report-card fixture for linked child `cee3bdb5-3723-44ea-a31a-4e87f9fa1541`. Evidence: `test-artifacts/wireless-2026-05-18/mob-011-api-export-evidence-20260518064206.txt`, `mob-011-principal-reports-screen.png`, `mob-011-admin-reports-screen.png`, `mob-011-admin-fees-export-status.png`, `mob-011-teacher-export-result.png`, `mob-011-parent-export-result.png`. |
| [x] | MOB-012 | Principal | Complaints UI polish | Passed 2026-05-18 on Moto g85 wireless: Principal Complaints opened with compact tabs/category chips, one bottom-right `New Ticket` CTA, readable complaint cards, and no overflow/error logs. | Existing complaints endpoint refreshed: Principal `GET /api/complaints` returned 200. Evidence: `test-artifacts/wireless-2026-05-18/mob-012-principal-complaints.png`, `mob-012-principal-complaints-summary.txt`. |
| [x] | MOB-013 | Admin/Principal | Student filters UI polish | Passed 2026-05-18: Admin and Principal student screens kept search and class/status chips compact/readable on Moto g85. Principal Student Oversight was verified with the long class chip inside a horizontal scroll area, then filtered by class plus `QA` search without overflow or app-side errors. | Student list calls remained backend-derived: Principal `GET /api/grades`, `/api/sections`, `/api/students?page=1&page_size=500`, `/api/users?role=Parent&status=active`, and parent-link hydration calls to `/api/parents/:parent_user_id/students` returned 200. Evidence: `test-artifacts/wireless-2026-05-18/mob-013-admin-students-filters.png`, `mob-013-principal-students-filters.png`, `mob-013-principal-students-filtered.png`. |
| [x] | MOB-014 | Principal | School/Profile screens | Passed 2026-05-18: Principal School Profile and shared Profile screens were verified on Moto g85 with compact fields and reachable lower action controls. A Profile safe-area issue was fixed so `Edit profile`, `Refresh profile`, `Settings`, and `Sign out` sit above the Android navigation bar after scrolling, not underneath it. | Backend proof passed: School Profile loaded `GET /api/schools/current` 200 and no-op saved `PATCH /api/schools/current` 200; Profile loaded `GET /api/auth/profile` 200 plus `GET /api/schools/current` 200 and no-op saved `PATCH /api/auth/profile` 200 and `PATCH /api/schools/current` 200. Evidence: `test-artifacts/wireless-2026-05-18/mob-014-principal-school-profile.png`, `mob-014-principal-school-profile-edit.png`, `mob-014-principal-school-profile-save.png`, `mob-014-principal-profile-viewport-final.png`, `mob-014-principal-profile-actions-visible.png`, `mob-014-principal-profile-save-result.png`. |
| [x] | MOB-015 | Admin/Principal | Timetable UI polish | Passed 2026-05-18: Admin and Principal timetable screens kept day/class chips readable and horizontally scrollable with no FAB/content collision. Principal `Suggest`, `Raise Advice`, and period details were converted from popup/dialog surfaces into separate full-screen routes. The Suggest screen displays class, day, academic year, term, section ID, periods, start time, duration, and gap before backend preview/send. | Backend proof stayed green: Principal timetable loaded `/api/timetable/slots`, `/api/timetable/substitutions`, `/api/sections`, `/api/staff`, `/api/academic-years`, and `/api/academic-years/:id/terms` with 200; `POST /api/timetable/suggestions` returned 200; suggestion `Send Advice` and plain `Raise Advice` both posted `POST /api/principal/timetable-advice` with 201. Evidence: `test-artifacts/wireless-2026-05-18/mob-015-principal-timetable-after-fullscreen-fix.png`, `mob-015-principal-suggest-fullscreen.png`, `mob-015-principal-suggest-preview.png`, `mob-015-principal-suggest-send-result.png`, `mob-015-principal-advice-fullscreen.png`, `mob-015-principal-advice-send-result.png`, `mob-015-principal-period-detail-fullscreen.png`. |
| [x] | MOB-016 | Admin/Parent | Fees/PDF UI polish | Passed 2026-05-18: Admin Fees toolbar/KPI RenderFlex overflow fixed and verified on Moto g85 after rebuilding with `env.json`; Parent Fees history opened backend-derived payments and Receipt opened the in-app PDF preview with print/share actions. PDF font was fixed to bundled DM Sans so rupee symbols render correctly and missing-glyph log warnings are gone. | Admin fee endpoints refreshed from local Docker: `/api/fees/structures`, `/api/fees/invoices`, `/api/fees/categories`, `/api/academic-years`, `/api/grades`, `/api/students` returned 200. Parent endpoints `/api/me/students`, `/api/fees/invoices`, and `/api/fees/payment-requests` returned 200. Evidence: `test-artifacts/wireless-2026-05-18/admin-fees-overflow-fix.png`, `mob-016-parent-fees-screen.png`, `mob-016-parent-fees-history.png`, `mob-016-parent-receipt-preview-final.png`. |

## Stop Criteria

Stop and fix before Hostinger planning if any of these appear:

| Condition | Action |
|---|---|
| App uses `env.hostinger.json` or any non-local URL | Rebuild with `--dart-define-from-file=env.json`. |
| `adb reverse --list` does not show `tcp:8080 tcp:8080` | Recreate reverse bridge before testing. |
| Docker logs show 401/403 for a role that should be allowed | Verify role credentials and RBAC route owner. |
| RenderFlex overflow, invisible text, or FAB overlap appears | Capture screenshot and patch UI before continuing. |

## 2026-05-18 Continuation Note

- Automated/local gates passed during the continuation pass: `flutter analyze`, `flutter test` (`216/216`), `go test ./...`, `/health`, `/ready`, `/metrics`, and `scripts/verify-local-docker-api.sh` (`71/71`).
- All wireless rows `MOB-001` through `MOB-016` are now ticked with local Docker backend evidence before Hostinger planning.
- Wireless ADB was restored again on Moto g85 (`adb-ZA2235WH4K-c1n0iS._adb-tls-connect._tcp`) with `adb reverse tcp:8080 tcp:8080`. The app was rebuilt from local code with `env.json`, installed, and verified after Admin Fees overflow, Parent receipt font, Profile safe-area, and Principal Timetable popup-to-screen fixes.
