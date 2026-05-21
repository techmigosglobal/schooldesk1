# SchoolDesk Codebase and Local Docker Role Verification - 2026-05-12

## Scope

- Verify frontend role/module wiring at codebase level.
- Verify local Docker Go backend health and safe API behavior.
- Keep Hostinger deploy, version bump, APK, and AAB generation out of this pass.
- Record evidence, blockers, and the next manual QA gates before production push.

## Environment

- Workspace: `/home/vinay/Desktop/Desktop/Desktop/schooldesk_V1`
- Verification target: local Docker backend first.
- Production target: Hostinger VPS Docker later, after local verification.
- Date: 2026-05-12

## Evidence Log

| Area | Command / Check | Result |
| --- | --- | --- |
| Flutter static analysis | `flutter analyze` | Pass: no issues found. |
| Flutter automated tests | `flutter test` | Pass: 201 tests passed. |
| Android integration launch stubs | `flutter test -d emulator-5554 --dart-define-from-file=env.json integration_test/` | Pass: 2 integration tests passed on Android emulator after fixing test harness imports/error-builder restoration. |
| Low-hardware emulator setup | Existing `Pixel_2` AVD launched with `-no-window -no-audio -gpu swiftshader_indirect -no-snapshot -no-boot-anim` | Pass: Android 11 API 30 booted headlessly. AVD enforced 2048 MB RAM even when 1536 MB was requested. |
| Emulator backend bridge | `adb -s emulator-5554 reverse tcp:8080 tcp:8080` | Pass: emulator app traffic reached local Docker API on `127.0.0.1:8080`. |
| Emulator role login smoke | `flutter test -d emulator-5554 --dart-define-from-file=env.json ... integration_test/local_role_login_smoke_test.dart` | Pass: Principal, Admin, Teacher, and Parent logged in through the real auth screen and reached their role dashboards. |
| Go backend package tests | `go test ./...` from `school-backend/` | Pass, including `school-backend/tests`. |
| Go backend API suite | `school-backend/test-report/report.json` | Pass: 54 total, 54 passed, 0 failed, 100%. |
| Docker services | `docker ps` | Pass: `schooldesk-go-api` running on 8080; Postgres and Redis healthy. |
| Backend health | `curl http://127.0.0.1:8080/health` | Pass: HTTP 200 with `{"status":"healthy"}` and `X-Request-Id`. |
| Auth guard smoke | Unauthenticated `GET /api/students`; invalid login | Pass: protected route returned 401; invalid login returned 401 and rate-limit headers. |
| Local role API probes | Fresh local QA Principal/Admin/Teacher/Parent accounts | Pass: all role logins succeeded; dashboards and representative read endpoints returned expected 200s; Parent forbidden Admin dashboard returned 403. |
| Local role fixture | Principal-created Admin/Teacher/Parent plus active linked child | Pass: Teacher sees 1 assigned class and 1 active student; Parent dashboard and `/api/me/students` show the same active child. |
| Frontend role/API trace | Route guard, dashboards, `BackendApiClient`, `BackendDataService`, raw compatibility routes | Pass at code-contract level. Role screens are backend-wired; several raw compatibility paths still require manual workflow read/write QA. |
| Logging/error visibility | Frontend Dio interceptors, Go request-id middleware, Docker logs, audit logs | Pass with caveat: API headers expose `X-Request-Id`, many JSON responses include `request_id`, and Docker logs show matching requests. Paginated responses may omit body `request_id`, so use headers/logs during QA. |

## Role Verification Status

| Role | Codebase-level status | Local Docker authenticated status | Manual QA status |
| --- | --- | --- | --- |
| Principal | Routes and service calls wired to backend. | Login, dashboard, school profile, users, approval-list probes, and emulator dashboard smoke passed. | Pending guided UI workflow QA. |
| Admin | Routes and service calls wired to backend. | Login, dashboard, students, staff, fee invoices, timetable, exams probes, and emulator dashboard smoke passed. | Pending guided UI CRUD/payment/report QA. |
| Teacher | Routes and service calls wired to backend. | Login, dashboard, assigned class, scoped student list, homework, diary, PTM, leave probes, and emulator dashboard smoke passed. | Pending guided attendance/homework/lesson/marks/resources UI QA. |
| Parent | Routes and service calls wired to backend. | Login, dashboard, linked child, homework, diary, notices, RBAC negative probe, and emulator dashboard smoke passed. | Pending guided fees/receipt/leave/chat/PTM/documents/calendar UI QA. |
| Cross-role propagation | Backend API suite covers core propagation paths for attendance, homework/diary, fees/payments, marks, messages, leave, and RBAC. | Local fixture supports Teacher/Admin/Parent cross-role testing with one shared active child. | Pending manual end-to-end readback on actual screens. |

## Current Blockers / Risks

- Not production-certified yet: full manual role workflows are still pending.
- Local Docker data was intentionally seeded with QA accounts and one active QA student for manual verification. Current local emulator QA credentials are stored outside the repo at `/tmp/schooldesk-local-emulator-qa-credentials-20260512.md`.
- Integration tests now include role-login dashboard smoke, but not full module read/write automation.
- Android emulator role smoke passed; physical/wireless device QA is still pending.
- Do not deploy to Hostinger or build release artifacts until manual Principal -> Admin -> Teacher -> Parent role QA is complete.

## Manual QA Focus Remaining

| Area | Required manual read/write verification |
| --- | --- |
| Principal | Approval decisions, school profile update, student notes/alerts/export, syllabus, reports, analytics, complaints, events, communication visibility. |
| Admin | Student CRUD, staff/account creation with login, parent linking, attendance marking, fees/payment readback, timetable/exam/academic CRUD, helpdesk, documents, reports, ID cards. |
| Teacher | Class scoping, attendance marking, homework create/readback, lesson planner, marks/performance, notes, resources, parent interaction/PTM, leave, discipline, diary. |
| Parent | Linked-child dashboard, attendance/fees/homework/diary readback, notices acknowledgement, chat/PTM, receipts, leave request, documents, calendar. |
| Cross-role | Teacher/Admin changes must appear correctly in Parent/Principal views: homework, attendance, fees, marks, notices, diary, messages, leave approvals. |

## Next Gate Before Hostinger Deploy and Release Builds

- Run guided manual role QA against local Docker using `/tmp/schooldesk-local-emulator-qa-credentials-20260512.md`.
- Monitor `docker logs -f schooldesk-go-api` during every manual role flow.
- Capture request IDs from failed UI actions and correlate them with Docker logs.
- After local manual QA is clean, deploy to Hostinger VPS Docker.
- After Hostinger smoke is clean, bump version and build both APK and AAB.
