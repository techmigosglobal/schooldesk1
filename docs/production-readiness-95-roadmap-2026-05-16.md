# SchoolDesk Production Readiness 95 Roadmap

Date: 2026-05-16  
Updated: 2026-05-17  
Scope: Local Docker Go API only, Flutter app, Postgres, Redis. Hostinger/VPS deployment is intentionally out of scope until local verification is clean.

## Current Verified State

Estimated readiness after latest verified pass: 95/100 for local-Docker feature integration.

The application is holding the 95/100 local-Docker threshold. The 2026-05-17 pass reduced operational and usability risk through CI gates, readiness/metrics endpoints, request logs, UI issue polish, and a wireless-device execution plan. Hostinger/VPS deployment is still blocked until physical/wireless mobile verification is completed.

Completed in this pass:

| Area | Result | Evidence |
|---|---|---|
| Repeatable local Docker API gate | Added `scripts/verify-local-docker-api.sh` and `school-backend/cmd/local-api-verify`. | Generates redacted JSON/HTML reports under `school-backend/test-report/`. |
| Parent payment backend contract | Added parent-safe `parent_payment_requests` lifecycle. | Parent submits linked-invoice request; Admin approves/rejects; approval creates real payment and updates invoice. |
| Parent payment frontend wiring | Parent fee screens now call `submitParentPaymentRequest()` instead of Admin-only `recordPayment()`. | Pending requests show as "Pending verification"; receipt PDF is available only for paid/approved payments. |
| Admin payment-request decision UI | Added routed Admin review and decision screens. | Admin Fees opens Payment Requests; pending requests route to a separate approve/reject screen; decision calls `/fees/payment-requests/:id/decision`. |
| Student leave backend contract | Added typed `student_leave_applications` lifecycle. | Parent can submit for linked students; Principal/Admin/Teacher visibility is role-scoped; decisions are audited. |
| Parent leave frontend wiring | Parent leave screen now loads backend students/requests and uses a routed input screen. | No popup input screen, no hardcoded dates, no local shared-record save path. |
| Parent calendar backend wiring | Parent calendar now reads events, PTM rows, exam milestones, and academic-year holiday detail from backend APIs. | Removed fixed event/holiday/exam arrays and local RSVP mutation. |
| Backend school-scope hardening | Staff leave, school/academic reads, terms, exams, report cards, marks entry, timetable, and substitutions are scoped to the authenticated school and role. | `school_scope_hardening_test.go`, focused handler tests, and `go test ./...`. |
| Parent payment input UX | Parent payment request submission uses a routed screen instead of a popup input dialog. | `/parent-fees-screen/payment`, guarded parent route, source contract test, backend request API unchanged. |
| Admin fee input UX | Admin fee structure create/edit, invoice generation, and payment recording use separate routed screens. | `/admin-fees-screen/structures/form`, `/admin-fees-screen/invoices/generate`, `/admin-fees-screen/payments/record`; no `showDialog` in admin fee write flow. |
| Academic Management input UX | Academic year, subject, class/section, and curriculum add/edit flows use separate routed screens for Admin and Principal. | `/academic-management-screen/year`, `/subject`, `/class`, `/curriculum`; backend save calls moved into form screens and role guard allows Admin/Principal only. |
| Admin Timetable input UX | Generate timetable, add/edit period, and assign substitution now use separate routed screens. | `/admin-timetable-screen/generate`, `/period`, `/substitution`; forms call `POST /timetable/slots/generate`, `POST/PUT /timetable/slots`, and `POST /timetable/substitutions`; no popup input remains in the Admin Timetable write flow. |
| Teacher Leave input UX and contract | Apply leave now uses a separate routed form and real backend IDs. | `/teacher-leave-screen/request`; screen resolves `staff_id` from the teacher dashboard, loads `/leave/types` and `/leave/balances`, submits `POST /leave/applications`, and `/api/leave/balances` is exposed for the local Docker compat API. |
| Admin Exams input UX and contract | Create/edit/publish exams and create schedules now use routed screens/backend actions. | `/admin-exams-screen/form`, `/admin-exams-screen/schedule`; local API smoke passed `POST/PUT/PATCH /exams` and `POST /exams/schedules`. |
| Teacher Homework input UX and submission lifecycle | Teacher homework create/edit, submissions review, and parent submission now use routed screens with real backend records. | `/teacher-homework-screen/form`, `/teacher-homework-screen/submissions`, `/parent-homework-screen/submit`; local Docker verifier passed create/update/list/submit/review homework APIs. |
| Report/export lifecycle | Replaced generic/raw export records with typed backend export jobs, generated artifacts, download URLs, statuses, audit rows, and role-scoped routes. | `report_exports` model/handler; `/reports/exports`, `/fees/reports/exports`, `/attendance/reports/exports`, `/student-reports/exports`, `/exams/report-cards/exports`; local Docker verifier passed Principal/Admin/Teacher/Parent export authorization checks. |
| CI and local quality gate | Added a GitHub Actions workflow for local-Docker-only validation. | `.github/workflows/local-docker-ci.yml` runs Flutter analyze/test, Go tests, Docker Compose validation, and the local API verifier with local env files only. |
| Observability and readiness | Added structured request logs plus readiness/metrics endpoints. | `GET /ready` reports database/redis readiness; `GET /metrics` exposes backend/database/redis up gauges; local smoke returned all healthy. |
| API contract consolidation docs | Documented the active API contract surface and local verification boundary. | `docs/api-contract-consolidation-2026-05-17.md` records role/module API ownership and remaining consolidation items. |
| Ops and wireless preparation | Added local operations and mobile verification runbooks. | `docs/local-docker-ops-runbook-2026-05-17.md` and `docs/wireless-mobile-testing-plan-2026-05-17.md` define local-only procedures before VPS deployment. |
| UI issue polish | Completed the listed `ui issues_16_May_2026.docx` polish wave. | Complaint, student, timetable, fee, receipt, profile, and school profile screens were tightened; fee receipts now open an in-app PDF preview before print/share. |
| Local Docker E2E API verification | Clean pass with no warnings. | `71 total / 71 passed / 0 warnings / 0 failed`. |
| Static/tests | Pass. | `go test ./...`, `flutter analyze`, `flutter test` (`216/216`). |

Resolved verified warning:

| Warning | Previous Behavior | Current Result |
|---|---|---|
| Parent student leave | Parent submit hit the staff leave contract and returned `400`. | Moved to `/student-leave/applications`; local Docker verifier now passes create/list/approval/negative checks. |

## Priority Path To 95/100

| Target Score | Priority | Task | Acceptance Criteria |
|---:|---|---|---|
| 86 | P0 | Implement student leave end-to-end. | Completed and verified: parent submits for linked child; Principal/Admin list; Admin decides; Teacher cannot decide unassigned student; no local API warning. |
| 89 | P0 | Add Admin UI for parent payment request decisions. | Completed and verified: Admin Fees has routed payment-request review and decision screens; approval/rejection uses backend decision API. |
| 90 | P0 | Replace parent calendar hardcoded data. | Completed and verified: Parent calendar loads backend events, holidays, exams/PTM data; no fixed local 2026 arrays remain. |
| 91 | P0 | Backend school-scope hardening. | Completed and verified: cross-school tests cover staff leave, academic year, grade, term, exam, timetable, substitutions, marks/report cards, and by-ID reads. |
| 92 | P1 | Convert highest-risk finance/account input dialogs to routed screens. | Completed wave: account creation was already routed; Parent Leave and Parent Payment are routed; Admin Fees structure/generate/payment writes are now routed. Remaining input-dialog modules are listed below. |
| 93 | P1 | Convert Academic Management inputs to routed screens. | Completed and verified: Admin/Principal academic year, subject, class/section, and curriculum add/edit flows are separate screens with guarded routes. |
| 94 | P1 | Remaining routed-input plus report/export lifecycle. | Completed and verified: Admin Timetable, Teacher Leave, Admin Exams, Teacher Homework, and typed Report/export lifecycle are locally green. |
| 95 | P1/P2 | Local-Docker production integration threshold. | Completed and verified locally: Go tests, Flutter analyze/test, local API verifier, typed high-value export lifecycle, and route/input conversions for the agreed priority modules. |

## Next Implementation Order

1. Execute wireless mobile testing against local Docker using `docs/wireless-mobile-testing-plan-2026-05-17.md`.
2. Capture role-wise evidence for Principal/Admin/Teacher/Parent login, Admin Exams, Teacher Homework, Report/export lifecycle, fee receipts, and UI issue screens.
3. Convert any remaining legacy generic API handlers into typed handlers where API contract consolidation flags them as residual risk.
4. Add backup/restore dry-run evidence for Postgres and Redis before deployment planning.
5. Prepare the Hostinger VPS deployment plan only after local wireless verification is complete and signed off.

## Local Verification Command

```bash
scripts/verify-local-docker-api.sh
```

The verifier refuses non-local targets by default. Keep Hostinger deployment blocked until this command, `go test ./...`, `flutter analyze`, and `flutter test` are all green.
