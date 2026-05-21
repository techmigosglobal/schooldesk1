# SchoolDesk RBAC Production Execution Guide

Generated for the SchoolDesk Go API path. Local Docker remains the first
verification gate; Play Store production builds target the Hostinger/VPS Go API.

## Production RBAC Target

SchoolDesk uses the Oversight Principal model.

| Role | Production ownership |
| --- | --- |
| Principal | Governance, approvals, analytics, complaints, reports, Admin/Teacher account oversight. |
| Admin | Daily operations: students, classes, sections, staff, parents, timetable, syllabus, exams, fees, documents. |
| Teacher | Classroom execution: assigned class, attendance, homework, diary, marks, PTM/messages, discipline notes. |
| Parent | Linked-child visibility and requests: child switching, fees, attendance, homework, marks, messages, documents, complaints. |

Active runtime path:

```text
Flutter app -> BackendApiClient -> Go API -> Postgres/Redis
```

Do not use Appwrite/PocketBase paths for this checkout. Use local Docker for
pre-release gates and Hostinger/VPS for the production Play Store artifact.
Student access is Parent-managed; do not create separate Student login accounts
for this release.

## Linkage Execution Order

| Order | Linkage | Production gate |
| --- | --- | --- |
| 1 | Foundation | Auth, role routing, profile, logout, Docker API config. |
| 2 | Admin -> Parent | Admin creates parent, links child, parent dashboard shows only linked children. |
| 3 | Admin -> Teacher | Admin creates teacher/staff, assigns section/subject/timetable. |
| 4 | Teacher -> Parent | Homework, diary, marks, PTM/message visibility. |
| 5 | Parent -> Teacher | Parent message and PTM request reaches teacher. |
| 6 | Admin -> Parent/Principal | Fee invoice/payment updates parent and Principal views. |
| 7 | Teacher/Admin -> Parent/Principal | Attendance write propagates to parent/principal/admin readback. |
| 8 | Parent/Admin -> Principal | Helpdesk or complaint escalation reaches Principal complaints. |
| 9 | Teacher -> Principal | Leave and discipline escalation reaches Principal approval/complaint flow. |
| 10 | Principal -> Admin/Teacher/Parent | Approvals, announcements, analytics, and reports are role-scoped. |

## Per-Linkage Execution Prompt

Use this exact sequence for every linkage.

```text
You are verifying and hardening SchoolDesk production readiness.

Active architecture:
Flutter app -> BackendApiClient -> Go API -> Postgres/Redis.
Do not use old Appwrite/PocketBase paths. Verify locally first, then deploy the
same Go backend to Hostinger/VPS for the Play Store artifact.

RBAC target:
Principal = oversight/approval/analytics.
Admin = daily operational CRUD.
Teacher = classroom execution.
Parent = linked-child visibility, child switching, and requests. Separate
Student login accounts are out of scope for this production release.

For the selected linkage:

1. Identify workflow contract:
   - Source role
   - Receiving role
   - Record type
   - Creating screen
   - Receiving screen
   - Backend endpoint
   - Database table/model
   - Expected forbidden roles

2. Verify backend first:
   - Login as source role.
   - Create/update the record.
   - Confirm API success.
   - Confirm backend readback.
   - Login as receiving role.
   - Confirm the same record is visible with matching IDs/fields.
   - Login as forbidden role.
   - Confirm access is blocked or absent.

3. Verify frontend second:
   - Open source role screen.
   - Perform the workflow.
   - Check loading, empty, error, success, and refresh states.
   - Open receiving role screen.
   - Confirm the record appears without mock/local/hardcoded data.
   - Refresh/relogin and confirm persistence.

4. Verify RBAC/security:
   - Source role can perform only allowed actions.
   - Receiving role can only read/respond as designed.
   - Parent sees only linked child data.
   - Teacher sees only assigned class/student data.
   - Principal does not expose Admin-only CRUD actions.
   - Admin does not bypass Principal-only approvals where approval is required.

5. Fix root cause only:
   - Missing endpoint: add/repair backend contract.
   - Backend works but UI misses data: fix Flutter data wiring.
   - Local/mock data appears: remove it and bind backend truth.
   - Permission is wrong: fix RBAC middleware or role filters.
   - Cross-role data is missing: fix linkage IDs, not labels.

6. Run verification:
   - flutter analyze
   - focused Flutter test for touched UI/client contract
   - go test ./... inside school-backend
   - local Docker health check
   - device/manual role flow when UI is touched

7. Update status:
   - Production Ready only when backend, UI, RBAC, receiving role, forbidden role, and persistence all pass.
```

## Status Rules

| Status | Meaning |
| --- | --- |
| Production Ready | Backend, UI, persistence, receiving role, forbidden role, and regression checks passed fresh. |
| Backend Verified | API/database path works, but UI/device readback is not complete. |
| UI Integration Needed | Backend path exists, but Flutter is still local, stale, unassigned, or incomplete. |
| RBAC Gap | A role can see or mutate something outside the production ownership model. |
| Environment Blocked | The local command/device/Docker gate cannot be executed from the current shell. |

## Current Implementation Checkpoint

Last verified: 2026-05-08 against local Docker Go API.

| Area | Status | Evidence |
| --- | --- | --- |
| Local Docker API | Passed | `schooldesk-go-api`, Postgres, and Redis are up; `/health` returns `200 {"status":"healthy"}`. |
| Username/password login | Passed | `/api/auth/login` accepts `{"username":"principal","password":"..."}` and returns Principal; email fallback still works. |
| Flutter login payload | Passed | `LoginRequest` sends username first and adds email only as fallback for email input/principal aliases. |
| Backend username model | Passed | `users.username` is supported, existing email users are backfilled, account creation stores username, and email login remains compatible. |
| Flutter role route guard | Passed | Role-specific routes now redirect wrong-role users to their own dashboard and unauthenticated users to landing. |
| Current role state | Passed | Login/register/profile role state is stored in `BackendApiClient` for route guarding; logout clears it. |
| Teacher role context | Passed | Backend timetable subject is retained even when no period is scheduled today. |
| Teacher My Classes direct navigation | Passed | Screen initializes backend role scope before rendering assigned class/student data. |
| Test package imports | Passed | Test imports now use the actual package name `schooldesk1`. |
| Flutter tests | Passed | `flutter test` completed with all tests passing. |
| Flutter static analysis | Passed | `flutter analyze` returned no issues. |
| Go backend tests | Passed | `go test ./...` passed in `school-backend`. |

## Remaining Foundation Tasks

Manual checklist: [Foundation Manual Test Cases](foundation-manual-test-cases.md).  
Release handoff and next-task memory:
[Foundation Release Handoff](foundation-release-handoff.md).

Before marking Foundation fully Production Ready on a real device:

1. Run manual login/logout/profile flow for Principal, Admin, Teacher, and Parent on device.
2. Verify token refresh by forcing/observing an expired access token path.
3. Verify profile update and avatar upload on device for at least one role.
4. Confirm direct deep-link route entry after cold app start for each role.

## Next Linkage To Execute

After the device Foundation checks above, move to Admin -> Parent:

1. Admin creates parent account with username/password and optional email.
2. Admin links the parent to exactly one or more child records by backend IDs.
3. Parent logs in with username/password.
4. Parent dashboard, fees, attendance, homework, documents, and diary show only linked-child data.
5. Teacher/other parent forbidden-role checks confirm no unrelated child data leaks.
