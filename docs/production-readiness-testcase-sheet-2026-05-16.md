# SchoolDesk Production Readiness Testcase Sheet

Date: 2026-05-16  
Updated: 2026-05-19  
Scope: Local Docker backend verification first; Hostinger/VPS release evidence is recorded only after local gates pass.

Status legend:

| Status | Meaning |
|---|---|
| `[ ] Pending` | Not executed in the current pass. |
| `[x] Pass` | Executed and passed in the current pass. |
| `[!] Blocked` | Cannot execute until prerequisite data/device/setup exists. |

## Automated Verification Gates

| Tick | Test ID | Area | Command / Check | Expected Result | Evidence |
|---|---|---|---|---|---|
| [x] | AUTO-001 | Flutter static analysis | `flutter analyze` | No issues found | Passed after Report/export lifecycle wiring. |
| [x] | AUTO-002 | Flutter full test suite | `flutter test` | All tests pass | `232/232` passed on 2026-05-19 after adding advanced parent-link, notification-route, and transport/library gap contract coverage. |
| [x] | AUTO-003 | Admin finance/timetable contract | `flutter test test/unit/admin_run2_backend_contract_test.dart` | Admin/Parent finance routing, timetable routing, and backend contract assertions pass | Passed. |
| [x] | AUTO-004 | Principal/Academic contract | `flutter test test/unit/principal_screen_ui_regression_test.dart` | Academic routed-form contract assertions pass | Passed. |
| [x] | AUTO-005 | Local Docker API verifier | `scripts/verify-local-docker-api.sh` | Local Docker API passes with zero warnings/failures | `79 total / 79 passed / 0 warnings / 0 failed` on 2026-05-19, including parent homework notification and exam schedule notification content checks. |
| [x] | AUTO-006 | Backend Go tests | `go test ./...` in `school-backend` | All Go packages pass | Passed after Report/export lifecycle backend wiring. |
| [x] | AUTO-007 | Admin Timetable contract | Focused Flutter source-contract test | Routed timetable input screens and backend endpoints are asserted | Passed in `test/unit/admin_run2_backend_contract_test.dart`. |
| [x] | AUTO-008 | Admin Exams contract | Focused Flutter source-contract test + local API smoke | Routed exam input screens and backend endpoints are asserted | Passed in `test/unit/admin_run2_backend_contract_test.dart`; local `/api` create/update/publish exam and create schedule smoke passed. |
| [x] | AUTO-009 | Teacher Leave contract | Focused Flutter source-contract test + local API smoke | Teacher leave routed form preserves backend staff/leave-type calls | Passed in `test/unit/teacher_leave_backend_contract_test.dart`; local `GET /api/leave/balances` returned `success: true`. |
| [x] | AUTO-010 | Teacher Homework contract | Focused Flutter source-contract test + local API smoke | Teacher homework routed forms and submission lifecycle preserve backend calls | Passed in `test/unit/teacher_homework_backend_contract_test.dart`; local Docker verifier created/updated homework, parent submitted, and teacher reviewed submission. |
| [x] | AUTO-011 | Report/export lifecycle | Go + Flutter/API contract tests | Export job persists status/artifact/audit/failure | Passed with typed `report_exports`, generated artifacts, audit rows, role-scoped routes, Flutter contract test, Go tests, and local Docker report export API checks. |
| [x] | AUTO-012 | UI issue polish contract | `flutter test test/unit/ui_issue_polish_contract_test.dart` | Mobile FAB placement, filter chip density/contrast, in-app receipt preview, and local readiness artifacts remain present | Passed; fee receipt screens use `PdfService.previewDocument()` instead of direct print dialogs. |
| [x] | AUTO-013 | Local ops readiness | `curl /ready`, `curl /metrics`, CI workflow inspection | Readiness/metrics endpoints are local-only verified and CI runs local Docker gates | `/ready` returns database/redis status; `/metrics` now exposes backend/database/redis up gauges plus HTTP counts/latency, 4xx/5xx counters, DB pool stats, queue pending length, and notification worker failures. |
| [x] | AUTO-014 | No-popup input conversion | Source inventory + `flutter analyze` + `flutter test` + local Docker API verifier + Go tests | Active input-required flows open full-screen pages; remaining popup matches are confirmation-only or read-only detail surfaces | Passed 2026-05-18 after converting timetable, accounts/settings, attendance, student, communication, complaint, events, reports, oversight, helpdesk, approvals, teacher/parent, resources/documents, legacy teacher-management, and parent leave input flows. `flutter analyze` clean; `flutter test` `216/216`; local verifier `71/71`; `go test ./...` passed. |
| [x] | AUTO-015 | Hostinger release package and backend deploy | `flutter build appbundle --release --dart-define-from-file=env.hostinger.json`, AAB integrity/signature checks, deploy check/dry-run/execute, remote health/ready/metrics | Play Store AAB is signed and valid; VPS backend deploy completes with migration-once rollout and post-deploy health checks | AAB: `build/releases/schooldesk-1.0.5+7-hostinger-release.aab`, SHA-256 `073f400a1c074569a3ad04ef46b4752284da07f124f41123fa248fb30d2c66c4`; package `com.techmigos.schooldesk1`, version `1.0.5+7`; deploy backup `/root/schooldesk-backups/deploy-20260518-035850`; `/health`, `/ready`, and `/metrics` passed on Hostinger. |
| [x] | AUTO-016 | Cross-role module coordination | `flutter test test/unit/role_module_coordination_contract_test.dart` | Admin, Principal, Teacher, and Parent module contracts are connected through shared backend routes and role-scoped handlers | Passed 2026-05-19. Covers timetable -> teacher attendance, homework teacher/parent/review, chat/read receipts/notifications, parent fee request -> admin decision, admin marks -> parent/principal/report exports, approval center coordination, and shared profile/avatar flow. |
| [x] | AUTO-017 | Advanced test cases 11-20 | Flutter source contracts + Go notification tests + local Docker verifier | Parent-child linking, teacher scoping, leave, exams, notification routing, RBAC, fee sync, and documented transport/library gaps are accurately represented | Passed 2026-05-19. `communication_notifications_test.go` verifies homework/exam schedule notifications; local Docker verifier `79/79` verifies notification rows through `/notifications`. |

## School Application Acceptance Checklist

This checklist is the client-facing functional acceptance layer. Status is intentionally conservative: source/contract verification means the wiring is implemented and automated checks passed; live pass must be ticked only after the current VPS build, Android device, real FCM service account, and role credentials are used.

| Tick | Test ID | Module | Scenario | Coordination Expected | Current Status |
|---|---|---|---|---|---|
| [ ] | AUTH-001 | Login & Authentication | Login with valid credentials for Principal, Admin, Teacher, and Parent | Auth token, role, linked profile, route guard, dashboard data, and push-token registration all initialize together | Manual VPS/device refresh required after latest build. Prior wireless role login passed 2026-05-17; rerun before client handoff. |
| [ ] | AUTH-002 | Login & Authentication | Invalid password shows useful error | Backend auth error should surface without fake fallback login | Manual VPS/device pending. |
| [ ] | AUTH-003 | Login & Authentication | Forgot password flow | Mail/reset behavior must match production email configuration | Pending production mail input and live SMTP/API validation. |
| [ ] | AUTH-004 | Login & Authentication | Logout and app reopen | Token revocation/local session clear should return user to login without stale role data | Manual device pending. |
| [ ] | AUTH-005 | Login & Authentication | Session timeout after inactivity | Expired token should trigger refresh or safe logout | Manual long-running/device pending. |
| [x] | STUD-001 | Student Module | Admin requests student add and Principal approves | Admin creates `/student-approvals`; Principal Approval Center decides; backend creates/updates/deletes linked student safely | Contract and backend tests present; live role execution still recommended. |
| [ ] | STUD-002 | Student Module | Edit/delete/search student and duplicate admission number | Student list/search must reflect backend truth; duplicate admission/admission number should be blocked by backend | Contract/backend guards present; manual data-entry pass pending. |
| [x] | ATT-001 | Attendance Module | Teacher marks attendance from Admin/Principal timetable setup | Admin timetable slots feed teacher timetable, section enrollment, attendance session, and present/absent counts | Covered by `AUTO-016` and handler tests. |
| [ ] | ATT-002 | Attendance Module | Attendance report generation and edit previous records | Report export should persist artifact; previous-record edit must update existing session without mismatch | Export contract passed; previous-record live edit pending. |
| [x] | FEE-001 | Fees Module | Parent submits payment request and Admin records/decides payment | Parent request, admin decision, invoice balance, pending dues, and receipt preview stay in sync | Covered by `AUTO-016`, fee contract tests, and prior wireless/API proof. |
| [ ] | FEE-002 | Fees Module | Duplicate payment prevention and internet drop during payment | Backend should avoid duplicate settlement; interrupted request should not corrupt invoice balance | Manual edge-case pass pending on live VPS/device. |
| [x] | HW-001 | Homework & Assignments | Teacher uploads homework; Parent views/submits; Teacher reviews | Homework, submissions, attachment requests, and review status use shared backend records | Covered by `AUTO-016` and homework contract tests. |
| [ ] | HW-002 | Homework & Assignments | Attachment download and notification delivery | Attachment should be downloadable by allowed role; notification should reach parent/teacher | Attachment route is wired; live file/push validation pending. |
| [x] | NOTIF-001 | Notifications | Announcement/chat/approval notification reaches device as push | Backend logs notification, worker sends FCM, app opens role-safe target route | Production FCM credential, VPS worker, Android token registration, and live device push receipt passed on 2026-05-20 with the Hostinger `1.0.5+11` build. |
| [x] | TT-001 | Timetable Module | Add/update timetable entry and Teacher sees updated class timing | Admin timetable entry is same backend source consumed by Teacher Attendance and Parent/Principal timetable reads | Covered by `AUTO-016`; instant live reflection still needs device refresh test. |
| [x] | EXAM-001 | Performance & Marks | Admin enters marks; Parent/Principal see results; report card export works | Marks endpoint upserts, parent progress reads marks/report cards, principal result mapper handles backend shape, report export persists | Covered by `AUTO-016` and backend exam mark tests. |
| [ ] | EXAM-002 | Performance & Marks | Topper/rank calculations | Rank/topper values must come from backend report-card data, not hardcoded UI | Manual data-set validation pending. |
| [x] | PAR-001 | Parent Module | Parent can access only own child data | Attendance, fees, homework, marks, leave, chat, and PTM calls are scoped through linked student policy | Contract and backend scoping tests present; live negative test pending. |
| [ ] | PAR-002 | Parent Module | Communication/chat section | Parent/Teacher chat should create message, mark read, notify recipient, and route correctly from notification | Chat/read contract passed; live push/chat pass pending. |
| [ ] | PERF-001 | App Performance | Loading speed, low internet, crash handling, screen-size responsiveness | No crashes, no layout overflow, graceful network errors, responsive phone/tablet surfaces | Automated widget/layout tests passed; live low-network/crash/responsiveness matrix pending. |
| [ ] | EDGE-001 | Critical Edge Cases | Internet disconnected during payment | No duplicate fee payment and no incorrect balance after reconnect | Manual live pending. |
| [ ] | EDGE-002 | Critical Edge Cases | Same user logged in on multiple devices | Push tokens/session state remain user-scoped and latest actions sync correctly | Manual multi-device pending. |
| [ ] | EDGE-003 | Critical Edge Cases | App force close/reopen | App restores/clears session correctly and reloads backend truth | Manual device pending. |
| [ ] | EDGE-004 | Critical Edge Cases | Large image/document upload | Avatar/document validation rejects oversized/invalid files and accepts valid files | Avatar guards implemented; live upload size matrix pending. |
| [ ] | EDGE-005 | Critical Edge Cases | Invalid input: special characters, empty fields, duplicate data | Form validators and backend validation reject bad data without server 500 | Many backend guards are implemented; module-by-module manual pass pending. |

## Cross-Role Coordination Matrix

| Tick | Flow ID | Cross-Role Flow | Required Configuration | Verification |
|---|---|---|---|---|
| [x] | COORD-001 | Admin timetable -> Teacher attendance | Shared timetable slots, teacher staff link, section enrollment, attendance session routes | `role_module_coordination_contract_test.dart`; Go handler scoping tests. |
| [x] | COORD-002 | Teacher homework -> Parent submission -> Teacher review | Shared homework record, parent linked student, submission review endpoint | `role_module_coordination_contract_test.dart`; homework contract tests. |
| [x] | COORD-003 | Teacher/Parent chat -> Notification Center/push | Shared conversations/messages, read receipt whitelist, notification logs, route resolver, device token routes | `role_module_coordination_contract_test.dart`; notification route tests. |
| [x] | COORD-004 | Parent fee request -> Admin payment decision -> Parent fee status | Payment request routes, admin decision endpoint, invoice balance reload, receipt preview/export | `role_module_coordination_contract_test.dart`; fee contract tests. |
| [x] | COORD-005 | Admin marks -> Parent academic progress -> Principal results -> Report exports | Schedule marks GET/POST, upsert validation, parent marks/report-card reads, principal result mapper, report-card export route | `role_module_coordination_contract_test.dart`; backend exam mark tests. |
| [x] | COORD-006 | Admin requests -> Principal Approval Center -> backend side effects | Account, student, and class approval records; Principal decision center; backend apply handlers | `role_module_coordination_contract_test.dart`; approval handler tests. |
| [x] | COORD-007 | Shared profile/avatar for all roles | Role-safe profile route, multipart avatar upload, backend file validation, JSON avatar bypass blocked | `role_module_coordination_contract_test.dart`; profile/avatar contract checks. |
| [x] | COORD-008 | Admin parent-child link -> Parent child switching -> child-scoped modules | `/parents/:parent_user_id/students`, `/me/students`, parent dashboard child selector, linked-student policy | `role_module_coordination_contract_test.dart`; local Docker verifier parent link/read checks. |
| [x] | COORD-009 | Homework/exam creation -> Notification log -> push queue -> role-safe app route | Homework create and exam schedule create generate notification logs; route resolver opens Parent Homework, Parent Calendar, or Teacher Performance safely | `communication_notifications_test.go`; `notification_route_resolver_test.dart`; local Docker verifier `79/79` notification content checks. |
| [x] | COORD-010 | Transport/library product scope | Active transport/library routes and Flutter screens are intentionally retired from the current product scope | Historical schema remains for compatibility, but these modules are not release gaps for this migration. |

## Advanced School Application Test Cases 11-20

These rows map the advanced checklist to codebase and Docker-backend readiness. Student access is treated as parent-managed because this product currently uses linked children inside the Parent login rather than separate student accounts.

| Tick | Test ID | Module | Scenario | Current Code / Backend Evidence | Status |
|---|---|---|---|---|---|
| [x] | ADV-011.1 | Parent-Student Linking | Admin links parent to student by admission number/email/phone | Flutter assignment screen calls `BackendApiClient.assignParentStudents`; backend routes `POST/GET /parents/:parent_user_id/students`; local verifier has `Admin links Parent to fee student` and `Parent can read linked students`. | Implemented and included in fresh local Docker `79/79`. |
| [x] | ADV-011.2 | Parent-Student Linking | One parent sees and switches multiple children | Parent dashboard loads `getMyStudents()` and `getDashboard('parent')`, keeps `_activeChildIndex`, and renders `_ChildSelector`; parent screens use linked-child data. | Contract verified; device pass still needed across every child-scoped parent screen. |
| [x] | ADV-011.3 | Parent-Student Linking | Parent A cannot access Student B via API manipulation | Backend `canAccessStudent`, `ParentStudentLink` scoping, and relationship-policy tests reject unlinked student resources. | Backend automated coverage present; live negative API/device pass recommended. |
| [x] | ADV-012.1 | Teacher Module | Teacher only sees assigned classes/subjects | Teacher dashboard/staff link, `teacherSectionSubquery`, timetable scope, and route guards are covered by Flutter source contracts and Go policy tests. | Implemented; multi-class UI device pass still required. |
| [x] | ADV-012.2 | Teacher Module | Teacher attendance submission reflects for parent | Teacher attendance uses timetable slots, section enrollments, attendance sessions, and `markAttendance`; parent attendance reads student-scoped backend records. | Contract/backend coverage present; local Docker direct attendance marking is still weaker than API-suite coverage. |
| [x] | ADV-013.1 | Leave Management | Parent submits leave; Admin/Principal/Teacher decision updates parent | `/student-leave/applications` create/list/decision routes, linked-student guard, approval notifications, and local verifier parent-submit/admin-approve checks exist. | Implemented; attendance auto-marking side effect still needs live acceptance proof. |
| [x] | ADV-014.1 | Exam Schedule | Admin publishes/uploads exam schedule; parent sees dates and receives notification | Admin exam schedule form calls `/exams/schedules`; backend creates exam-schedule notification logs; route resolver opens Parent Calendar/Teacher Performance; local Docker verifies Parent and Teacher notification rows. | Backend/API passed; live push receipt still pending. |
| [x] | ADV-015.1 | Transport | Confirm transport is not exposed in the current product scope | Active `/transport/*` and `/students/:id/transport` routes are retired. Transport is out of the current product scope; historical tables/models remain only for compatibility. | No current Flutter or API release work required. |
| [x] | ADV-016.1 | Library | Confirm library is not exposed in the current product scope | Active `/library/*` routes are retired. Library is out of the current product scope; historical tables/models remain only for compatibility. | No current Flutter or API release work required. |
| [x] | ADV-017.1 | Role-Based Access | Admin/Teacher/Parent route permissions and restricted access | Flutter `RouteAccessGuard`, backend `RBACMiddleware`, relationship-policy tests, and local verifier negative checks cover major restrictions. | Implemented foundation; shared deep-link cold-start pass still required. |
| [x] | ADV-018.1 | Notifications | Homework/exam/message/approval notifications route to correct page | Message, announcement, approval, leave, homework, and exam-schedule notification logs are wired; push queue uses device-token routes and FCM sender when configured. | Production FCM credential, device-token registration, and Android receipt passed on VPS with `1.0.5+11`. |
| [x] | ADV-019.1 | Data Synchronization | Parent fee action updates Admin and Parent views | Parent payment request -> Admin decision -> invoice balance reload is covered by Flutter contract and local verifier. | Implemented for online backend-first flow; offline queue/conflict sync is not implemented. |
| [ ] | ADV-020.1 | Mobile Device Compatibility | Small/large phones, tablets, low RAM | Responsive scaffolds and prior Moto g85 wireless evidence exist for many modules. | Pending fresh device matrix for parent child switching, chat/PTM notifications, teacher attendance, transport, and library. |

## Route Input Conversion Test Cases

| Tick | Test ID | Role | Feature | Scenario | Expected Frontend Result | Expected Backend/API Result |
|---|---|---|---|---|---|---|
| [x] | ROUTE-001 | Parent | Leave | Submit child leave request from separate screen | `/parent-leave-screen/request` opens; no popup input | `POST /student-leave/applications` creates linked-student request. |
| [x] | ROUTE-002 | Parent | Fees | Submit payment verification from separate screen | `/parent-fees-screen/payment` opens; no popup input | `POST /fees/payment-requests` creates pending request. |
| [x] | ROUTE-003 | Admin | Payment approvals | Review/approve parent payment request | Review and decision screens open separately | `PUT /fees/payment-requests/:id/decision` settles approved payment. |
| [x] | ROUTE-004 | Admin | Fees | Create/edit fee structure from separate screen | `/admin-fees-screen/structures/form` opens | `POST/PUT /fees/structures` succeeds. |
| [x] | ROUTE-005 | Admin | Fees | Generate invoices from separate screen | `/admin-fees-screen/invoices/generate` opens | `POST /fees/invoices/generate` succeeds. |
| [x] | ROUTE-006 | Admin | Fees | Record payment from separate screen | `/admin-fees-screen/payments/record` opens | `POST /fees/payments` updates invoice balance. |
| [x] | ROUTE-007 | Admin/Principal | Academic Management | Create/edit year, subject, class, curriculum from separate screens | `/academic-management-screen/year`, `/subject`, `/class`, `/curriculum` open | Existing `BackendDataService` save methods call academic APIs. |
| [x] | ROUTE-008 | Admin | Timetable | Generate timetable from separate screen | Timetable generate route opens; no input popup | `POST /timetable/slots/generate` contract asserted; grid reloads after form result. |
| [x] | ROUTE-009 | Admin | Timetable | Add/edit period from separate screen | Period form route opens for create/edit | `POST/PUT /timetable/slots` contract asserted with section/subject/staff scope. |
| [x] | ROUTE-010 | Admin | Timetable | Assign substitution from separate screen | Substitution form route opens | `POST /timetable/substitutions` contract asserted and substitution list reloads after form result. |
| [x] | ROUTE-011 | Admin | Exams | Add/edit/publish exam from separate screen/actions | `/admin-exams-screen/form` opens; no input popup | `POST/PUT/PATCH /exams` succeeds with real academic year, term, and exam type IDs. |
| [x] | ROUTE-014 | Admin | Exams | Add exam schedule from separate screen | `/admin-exams-screen/schedule` opens; no input popup | `POST /exams/schedules` succeeds with real exam, grade, section, and subject IDs. |
| [x] | ROUTE-012 | Teacher/Parent | Homework | Add/edit homework, view submissions, and submit from separate screens | `/teacher-homework-screen/form`, `/teacher-homework-screen/submissions`, and `/parent-homework-screen/submit` open; no popup input | `POST/PUT /homework`, `GET/POST /homework/:id/submissions`, and `PUT /homework/:id/submissions/:submission_id/review` pass in local Docker verifier. |
| [x] | ROUTE-013 | Teacher | Leave | Apply leave from separate screen | `/teacher-leave-screen/request` opens; no bottom-sheet input | `POST /leave/applications` uses backend dashboard staff ID and backend leave type ID. |

## Report/Export Lifecycle Test Cases

| Tick | Test ID | Role | Feature | Scenario | Expected Frontend Result | Expected Backend/API Result |
|---|---|---|---|---|---|---|
| [x] | RPT-001 | Principal | General reports | Request a principal report export | Screen calls `createReportExport('/reports/exports')`; no fake local success-only export | `report_exports` row completes with status, artifact path, download URL, request role, and audit row. |
| [x] | RPT-002 | Admin | Fee reports | Request fee report PDF/CSV | Admin Fees export buttons call `/fees/reports/exports` | Admin export persists under `fee_reports` and returns completed artifact metadata. |
| [x] | RPT-003 | Admin | Attendance reports | Request attendance report PDF/CSV | Admin Attendance export buttons call `/attendance/reports/exports` | Admin/Principal scoped export persists under `attendance_reports`. |
| [x] | RPT-004 | Principal | Student oversight reports | Request student report export | Student Oversight calls `/student-reports/exports` | Principal scoped export persists under `student_reports`. |
| [x] | RPT-005 | Teacher/Parent | Report cards | Request report-card export from teacher, parent, and generator screens | Teacher Reports, Parent Academic Progress, and Report Card Generator call `/exams/report-cards/exports` | Teacher/Parent report-card exports persist under `report_cards`; Parent is blocked from unrelated general report exports. |

## UI Issues From `ui issues_16_May_2026.docx`

| Tick | UI ID | Screen / Area | Objective | Files To Inspect / Update | Backend Verification |
|---|---|---|---|---|---|
| [x] | UI-001 | Complaints | Keep one primary CTA, move FAB to bottom-right, clean empty state/tabs/chips | `lib/presentation/complaint_management_screen/complaint_management_screen.dart` | UI-only change; complaint backend contract preserved by full Flutter tests and local API verifier. |
| [x] | UI-002 | Student List + School Profile | Reduce wasted vertical space; improve contrast/density | `admin_students_screen.dart`, `school_profile_screen.dart` | UI-only density changes; student/school API coverage remains green in local verifier. |
| [x] | UI-003 | Top tabs/filter chips | Make chips compact, readable, scrollable, aligned | Student/admin list, oversight, and timetable filter sections | UI-only chip rendering; no query contract changed. |
| [x] | UI-004 | PDF Preview/Receipt | Compact toolbar, larger centered preview, correct FAB placement | `fee_payment_receipt_screen.dart`, `admin_fees_screen.dart`, `parent_fees_screen.dart`, `pdf_service.dart` | Receipt bytes still come from invoice/payment data; preview now opens in-app and offers print/share from the preview screen. |
| [x] | UI-005 | Timetable | Improve header spacing, day selector, card density, FAB placement | `admin_timetable_screen.dart`, `timetable_management_screen.dart` | Timetable slot/substitution APIs remain covered by local API verifier. |
| [x] | UI-006 | Fee Structure | Reduce gaps, avoid text/button collision, correct FAB placement | `admin_fees_screen.dart`, fee form screens | Fee structure/invoice/payment APIs remain green in local verifier; 2026-05-18 wireless recheck fixed Admin Fees toolbar/KPI RenderFlex overflow. Evidence: `test-artifacts/wireless-2026-05-18/admin-fees-overflow-fix.png`, `admin-fees-overflow-fix-summary.txt`. |
| [x] | UI-007 | Student filters | Improve chip contrast and search/filter hierarchy | `admin_students_screen.dart`, `student_oversight_screen.dart` | Filter/search still uses backend student data; source contract test covers chip behavior. |
| [x] | UI-008 | Profile | Fill empty lower screen with structured actions and better spacing | `profile_management_screen.dart`, `school_profile_screen.dart` | Profile update/avatar/password/logout paths unchanged; full Flutter tests pass. |

## Future Wireless Mobile Test Cases

| Tick | Test ID | Device Test | Preconditions | Expected Result |
|---|---|---|---|---|
| [x] | MOB-001 | Install debug/release APK on wireless Android device | Local backend reachable from phone on LAN or tunneled local URL | Passed 2026-05-17 on Moto g85 wireless with local `env.json`, `adb reverse tcp:8080 tcp:8080`, app PID `8204`, and local `schooldesk-go-api` request evidence. |
| [x] | MOB-002 | Role login smoke: Principal/Admin/Teacher/Parent | Local seeded accounts available | Passed 2026-05-17 on Moto g85 wireless: Principal, Admin, Teacher, and Parent reached role dashboards with local Docker backend `200` evidence. |
| [x] | MOB-003 | Admin Timetable routed flow | Admin logged in; academic setup seeded | Passed 2026-05-18 on Moto g85 wireless: Admin Timetable loaded backend slots/substitutions/sections/staff/subjects/academic-year data; Generate opened a separate screen and `Preview suggestions` called `POST /api/timetable/suggestions` 200; Add Period and Assign Substitute opened separate full-screen forms without popups. Evidence: `mob-015-admin-timetable-screen.png`, `mob-003-admin-timetable-generate-preview.png`, `mob-003-admin-timetable-add-period-screen.png`, `mob-003-admin-timetable-substitution-screen.png`. |
| [x] | MOB-004 | Admin Fees routed flow | Admin logged in; fee fixtures seeded | Passed 2026-05-18 on Moto g85 wireless: Admin Fees screen, fee structure form, generate invoices route, and record-payment route opened as separate full screens; `POST /api/fees/invoices/generate` returned 201, `POST /api/fees/payments` returned 200, and `/api/fees/invoices` reloaded with refreshed totals. Toolbar/KPI overflow fixed and rechecked. Evidence: `mob-004-admin-fees-structure-form.png`, `mob-004-admin-fees-generate-invoices-form.png`, `mob-004-admin-fees-record-payment-form.png`, `mob-004-admin-fees-record-payment-result.png`, `admin-fees-overflow-fix.png`. |
| [x] | MOB-005 | Academic Management routed flow | Admin/Principal logged in | Passed 2026-05-18 on Moto g85 wireless for Admin/shared academic management: list refreshed from `/academic-years`, `/subjects`, `/grades`, `/sections`, and `/curriculum`; Year, Subject, Class request, and Curriculum forms opened as separate full-screen routes. Evidence: `mob-005-admin-academic-management-screen.png`, `mob-005-academic-year-form.png`, `mob-005-academic-subject-form.png`, `mob-005-academic-class-form.png`, `mob-005-academic-curriculum-form.png`. |
| [x] | MOB-006 | Teacher Homework routed flow | Teacher and Parent logged in; linked student and homework seeded | Passed 2026-05-17 on Moto g85 wireless: Parent submit used separate `Submit Homework` screen; Teacher opened `Homework Submissions`, saved review inline on the dedicated submissions screen; local Docker logged `POST /api/homework/:id/submissions` 201 and `PUT /api/homework/:id/submissions/:submission_id/review` 200. |
| [x] | MOB-007 | Report/export lifecycle flow | Principal/Admin/Teacher/Parent accounts available | Passed 2026-05-18 on Moto g85 wireless plus API proof: Principal and Admin report exports, Admin fee report export, Teacher report-card export, and Parent report-card export all created backend export jobs; `POST /api/exams/report-cards/exports` returned 201 for Teacher and Parent. Parent general report access remained blocked in API proof. Evidence: `mob-011-api-export-evidence-20260518064206.txt`, `mob-011-principal-reports-screen.png`, `mob-011-admin-reports-screen.png`, `mob-011-admin-fees-export-status.png`, `mob-011-teacher-export-result.png`, `mob-011-parent-export-result.png`. |
| [x] | MOB-008 | UI issue visual pass | Screens from UI-001 through UI-008 opened on phone | Passed 2026-05-18 on Moto g85 wireless after Admin Fees KPI/toolbar overflow fix, Profile safe-area action fix, Parent receipt font fix, and Principal Timetable popup-to-screen conversion. No app-side RenderFlex/overflow/error logs remained in the verified UI issue rows. Evidence is linked in wireless MOB-012 through MOB-016. |
| [x] | MOB-009 | Follow detailed wireless plan | Use `docs/wireless-mobile-testing-plan-2026-05-17.md` with local Docker backend reachable from device | Passed 2026-05-18: every detailed wireless row `MOB-001` through `MOB-016` is ticked with phone screenshots, UI-tree evidence, local Docker backend logs, and focused automated checks before Hostinger VPS planning. |

## 2026-05-18 Continuation Note

- Fresh automated gates passed: `flutter analyze`, `flutter test` (`216/216`), `go test ./...`, `/health`, `/ready`, `/metrics`, and `scripts/verify-local-docker-api.sh` (`71/71`).
- Report/export API proof for MOB-007/MOB-011 passed across Principal, Admin, Teacher, and Parent route permissions, including generated `uploads/exports` artifacts and HTTP 200 download URLs. Evidence: `test-artifacts/wireless-2026-05-18/mob-011-api-export-evidence-20260518064206.txt`.
- Wireless ADB was restored again on Moto g85 (`adb-ZA2235WH4K-c1n0iS._adb-tls-connect._tcp`) with `adb reverse tcp:8080 tcp:8080`. Admin Fees was rebuilt with `env.json`, installed on the device, and the reported toolbar/KPI pixel overflow was fixed and verified with screenshot/UI-tree/logcat evidence: `admin-fees-overflow-fix.png`, `admin-fees-overflow-fix-ui.xml`, `admin-fees-overflow-fix-summary.txt`.
- Principal Timetable `Suggest`, `Raise Advice`, and period detail flows were converted from popup/dialog surfaces into separate full-screen routes and verified on the wireless device. Backend proof: `POST /api/timetable/suggestions` 200 and `POST /api/principal/timetable-advice` 201.
- Broad no-popup-input cleanup completed for active input-required flows. Remaining `showDialog` / `showModalBottomSheet` matches are confirmation-only dialogs or read-only detail sheets: parent teacher info, circular detail, staff/account/student delete confirmations, fee receipt success, fee/syllabus detail sheets, academic delete confirmations, settings restore/clear confirmations.
- Current ADB wireless state: `adb devices` and `adb mdns services` returned no connected/discovered device after the daemon restart. No new wireless row was ticked for this no-popup cleanup because device verification was not available in this pass.
- Hostinger release package and backend deploy completed after local gates. AAB integrity and signature verification passed; backend deploy used remote backup plus one-run migrations, restored `MIGRATE_ON_START=false`, and passed post-deploy `/health`, `/ready`, and `/metrics`.

## 2026-05-19 Cross-Role Coordination Note

- Added `test/unit/role_module_coordination_contract_test.dart` to verify feature coordination across roles instead of only individual screens.
- Fresh local gates passed after the coordination update: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test` (`232/232`), `go test ./...`, and `scripts/verify-local-docker-api.sh` (`79/79`).
- The coordination test covers Admin timetable -> Teacher attendance, Teacher homework -> Parent submission -> Teacher review, Teacher/Parent chat -> notification routing, Parent fee request -> Admin decision, Admin marks -> Parent/Principal reports, Admin requests -> Principal approvals, and shared profile/avatar configuration.
- Added backend notification generation for homework creation and exam schedule creation, plus role-safe notification routes for Parent Homework, Parent Calendar, Teacher Homework, and Teacher Performance.
- Local Docker API verification now asserts parent homework notification content and parent/teacher exam schedule notification content through `GET /notifications`.
- Live acceptance remains required on the current VPS build for forgot-password/mail behavior, session timeout, low-network behavior, multi-device login, force-close restore, large file upload limits, and payment interruption edge cases.

## 2026-05-19 Hostinger VPS + Firebase FCM Note

- Re-ran local Docker verification before deployment: `scripts/verify-local-docker-api.sh` passed `79/79`.
- Deployed the verified Go backend to the Hostinger VPS with `scripts/deploy-hostinger-backend.sh --execute --yes --no-login-smoke`; rollback backup: `/root/schooldesk-backups/deploy-20260519-033134`.
- Post-deploy VPS checks passed: public `/health`, `/ready`, and `/metrics` returned healthy/ready/up responses from `https://schooldesk-api.187.127.157.43.nip.io`.
- Firebase project `schooldesk1-509e0` now has an Android app config for package `com.techmigos.schooldesk1`; local Android builds include `android/app/google-services.json`.
- Created dedicated Firebase service account `schooldesk-fcm-sender@schooldesk1-509e0.iam.gserviceaccount.com` with `roles/firebasecloudmessaging.admin`.
- Superseded on 2026-05-20: the Firebase service-account key was provided, uploaded to `/opt/schooldesk-secrets/firebase-service-account.json`, and the VPS notification worker was enabled with the `push` compose profile. Real device receipt is now verified in the 2026-05-20 FCM evidence section.

## 2026-05-19 Local Docker vs VPS Backend Drift Fix

- Root cause found: backend source matched between local and VPS, but the VPS Postgres schema was stale because the 2026-05-19 deployment ran code-only with `MIGRATE_ON_START=false`. The `users.auth_invalidated_at` column existed in the current model/local path but was missing on the VPS, causing protected routes to return `401 Invalid token user` after login.
- Safe VPS fix applied after a fresh custom-format Postgres backup at `/root/schooldesk-backups/manual-auth-schema-20260519-171702/schooldesk-before-auth-schema.dump`: `ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_invalidated_at timestamptz;`.
- VPS verification passed after the schema fix: `/ready` returned database/redis `ok`, `/metrics` reported backend/database/redis up, and Principal-scoped protected reads returned 200 for `/auth/profile`, `/dashboard/principal`, `/users`, `/staff`, `/students`, `/grades`, `/sections`, `/academic-years`, `/schools/current`, `/timetable/slots`, `/timetable/substitutions`, `/exams`, `/exams/types`, `/announcements`, `/events`, `/notifications`, `/fees/structures`, and `/fees/invoices`.
- Client hardening added: backend refresh retry now marks a request after one refresh retry and clears token state on repeated 401 instead of looping. Gates passed: `flutter analyze` and `flutter test test/unit/role_module_coordination_contract_test.dart`.
- Rebuilt Hostinger-targeted APK: `build/app/outputs/flutter-apk/app-release.apk`, package `com.techmigos.schooldesk1`, version `1.0.5+9`, SHA-256 `23cb641235f042301d562f01fb8266d6c5137f00f8fa5b4d81a8ecf92f9ac16b`. APK integrity check passed.
- Mobile install/retest remains blocked until the Moto g85 wireless ADB session is reconnected; `adb devices -l` and `adb mdns services` currently show no connected/discovered device.

## 2026-05-19 Principal Module Local Docker Execution Sheet

Scope: Principal module only, local Docker backend at `http://127.0.0.1:8080/api`.

Evidence:

- Local Docker `/health` and `/ready`: passed.
- Principal API smoke: `test-artifacts/principal-local-2026-05-19/principal-tabular-api-smoke-final-20260519233952.txt` (`34/34` read/config endpoints passed).
- Principal advice API smoke: `test-artifacts/principal-local-2026-05-19/principal-advice-api-smoke-20260519234237.txt` (`/principal/timetable-advice` and `/principal/exam-advice` passed).
- Focused Principal Flutter tests: `39/39` passed.
- `flutter analyze`: no issues found.
- `go test ./...` in `school-backend`: passed.
- Rebuilt local-backend profile APK: `build/app/outputs/flutter-apk/app-profile.apk`, SHA-256 `c2c1594609905ed8efde19f62f6f0c0d7ccbce89c93c7807f251ab12d4f12cc1`.
- Wireless device screenshots/UI trees from the same local-backend session: `test-artifacts/principal-local-2026-05-19/`.

Fixes applied during this Principal pass:

- Principal Syllabus Records no longer reuses the unavailable Teacher Lesson Planner feature flag, so the false `backend pending` drawer label is removed in source.
- Principal Academic Management is read-only for Principal context; Admin keeps Add/Edit/Delete/Publish controls.

| SN | TC_ID | Testcase | Expected | Status |
|---|---|---|---|---|
| 1 | PRIN-LD-001 | Local Docker backend readiness | Go API, Postgres, and Redis are running; `/health` and `/ready` return healthy/ready | Pass |
| 2 | PRIN-LD-002 | Principal local-backend APK build | Profile APK builds with `env.json` local Docker backend config | Pass |
| 3 | PRIN-AUTH-001 | Principal login API | `POST /auth/login` returns Principal token and role payload | Pass |
| 4 | PRIN-AUTH-002 | Principal session/profile restore | `/auth/profile` and `/auth/me` return authenticated Principal identity | Pass |
| 5 | PRIN-DASH-001 | Principal Dashboard | Dashboard opens and `/dashboard/principal` returns school-scoped KPIs | Pass |
| 6 | PRIN-NAV-001 | Principal drawer module list | Drawer exposes only Principal modules with canonical Principal wording and no hardcoded stale badges | Pass |
| 7 | PRIN-NAV-002 | Principal Syllabus drawer availability | Syllabus Records should not show false `backend pending` when `/syllabus` backend is reachable | Pass after fix |
| 8 | PRIN-SCHOOL-001 | School Profile read path | School profile screen opens and `/schools/current` returns live school details | Pass |
| 9 | PRIN-SCHOOL-002 | School Profile update contract | Principal school-profile edit route remains wired to backend update path | Pass |
| 10 | PRIN-ACCESS-001 | Access & Permissions list | Principal can load user/accounts list from `/users` and audit data from `/audit-logs` | Pass |
| 11 | PRIN-ACCESS-002 | Principal account-management routes | Create/edit/assign-children routed screens are role-guarded for Principal context | Pass |
| 12 | PRIN-ACCESS-003 | Staff-linked login account contract | Principal account workflow supports linked staff-backed Admin/Teacher account creation/update | Pass |
| 13 | PRIN-STUD-001 | Student Oversight list/filter | Student Oversight opens and loads students, grades, sections, and parent-link data | Pass |
| 14 | PRIN-STUD-002 | Student Oversight action surface | Current implemented Principal student action surface remains wired to backend student APIs | Pass |
| 15 | PRIN-APPROVAL-001 | Approval Center buckets | Approval Center opens and account/student/class/leave approval buckets return 200 or honest empty state | Pass |
| 16 | PRIN-APPROVAL-002 | Student leave approvals | `/student-leave/applications` loads for Principal decision center | Pass |
| 17 | PRIN-APPROVAL-003 | Account/student/class approval reads | `/account-approvals`, `/student-approvals`, and `/class-approvals` are available to Principal | Pass |
| 18 | PRIN-TT-001 | Timetable Records | Timetable slots and substitutions load from backend without crash or overflow | Pass |
| 19 | PRIN-TT-002 | Timetable Principal ownership | Principal keeps oversight/advice workflow; Admin-owned timetable CRUD controls are not exposed in Principal records screen | Pass |
| 20 | PRIN-TT-003 | Timetable advice API | `/principal/timetable-advice` read path is available for Principal advice history | Pass |
| 21 | PRIN-SYL-001 | Syllabus Records | Syllabus Records opens and `/syllabus` plus `/curriculum` return 200 from local Docker | Pass after fix |
| 22 | PRIN-EXAM-001 | Exam Records | Exam Records opens and `/exams` plus `/exams/types` return 200 | Pass |
| 23 | PRIN-EXAM-002 | Exam advice API | `/principal/exam-advice` read path is available for Principal review/advice history | Pass |
| 24 | PRIN-ACAD-001 | Academic Management read path | Academic Management opens and academic years/grades/sections/curriculum reads return backend data | Pass |
| 25 | PRIN-ACAD-002 | Academic Management Principal ownership | Principal view is records/review only; Add/Edit/Delete/Publish controls are hidden for Principal context | Pass after fix |
| 26 | PRIN-FEE-001 | Fee Monitoring overview | Fee KPIs load from `/fees/structures`, `/fees/invoices`, and `/fees/concessions` | Pass |
| 27 | PRIN-FEE-002 | Fee Monitoring backend-truth model | Principal fee screen mirrors backend invoice/payment/concession model without fake/demo finance data | Pass |
| 28 | PRIN-COMM-001 | Communication Center | Communication Center opens; announcements/notices/notifications read APIs return 200 | Pass |
| 29 | PRIN-COMM-002 | Notice/announcement publishing contract | Principal communication publishing remains wired to backend routes and role-safe navigation | Pass |
| 30 | PRIN-COMP-001 | Complaints | Complaints screen opens and `/complaints` returns 200 with backend-backed ticket data or empty state | Pass |
| 31 | PRIN-CAL-001 | Calendar/Events | Calendar opens and `/events` returns 200; Add Event action remains wired | Pass |
| 32 | PRIN-RPT-001 | Reports | Reports screen opens; general/student/attendance/fee export lists return 200 | Pass |
| 33 | PRIN-RPT-002 | Report export lifecycle contract | Principal reports use persisted backend export lifecycle instead of local fake success | Pass |
| 34 | PRIN-ANL-001 | Analytics | Principal Analytics opens and uses backend-derived dashboard/fee/attendance data; no audited demo strings are present | Pass |
| 35 | PRIN-PROFILE-001 | Principal Profile | Profile opens with Principal identity and backend profile/school reads | Pass |
| 36 | PRIN-PROFILE-002 | Avatar/profile media contract | Profile avatar uses backend file-upload contract, not URL-only entry | Pass |
| 37 | PRIN-SET-001 | Settings | Settings opens through shared authenticated Principal route | Pass |
| 38 | PRIN-RBAC-001 | Principal route guard | Principal routes allow Principal and redirect wrong/unauthenticated roles safely | Pass |
| 39 | PRIN-QA-001 | Focused Principal automated tests | Principal source contracts, wording, route guards, reports, no-demo audit, UI polish, and login identity tests pass | Pass |
| 40 | PRIN-QA-002 | Backend Go regression gate | Backend packages and API suite pass after Principal fixes | Pass |
| 41 | PRIN-QA-003 | Static analysis | `flutter analyze` returns no issues after Principal fixes | Pass |
| 42 | PRIN-DEV-001 | Remaining Principal development blockers | No Principal-only source/API/build blocker remains after the two fixes above | Pass |
| 43 | PRIN-DEVICE-001 | Fresh reinstall of fixed APK on wireless phone | Device should appear online in `adb devices -l` before installing the rebuilt profile APK | Pass |

## 2026-05-19 Principal Module Wireless Device Execution Sheet

Scope: Principal module only, Moto g85 wireless ADB, local Docker backend through `adb reverse tcp:8080 tcp:8080`.

Evidence:

- Installed rebuilt local-backend profile APK on wireless device: `build/app/outputs/flutter-apk/app-profile.apk`, SHA-256 `c2c1594609905ed8efde19f62f6f0c0d7ccbce89c93c7807f251ab12d4f12cc1`.
- Principal login and module walkthrough screenshots/UI trees: `test-artifacts/principal-wireless-2026-05-19/`.
- Fresh API smoke: `test-artifacts/principal-wireless-2026-05-19/principal-wireless-api-smoke-20260519235746.txt` (`36/36` passed).
- Runtime logs: `test-artifacts/principal-wireless-2026-05-19/final-app-pid-logcat.txt` and `final-backend-window.log`.
- App-specific log scan: no Flutter exception, crash, overflow, socket/Dio error, or `API ERROR`.
- Backend post-login window: no `400/401/403/404/500` responses after successful Principal login.

| SN | TC_ID | TestCase | Expected | Status |
|---|---|---|---|---|
| 1 | PRIN-LD-001 | Local Docker backend readiness | Go API, Postgres, and Redis stay healthy; `/health` and `/ready` are green | Pass |
| 2 | PRIN-LD-002 | Principal local-backend APK install | Rebuilt profile APK installs on the wireless Android device | Pass |
| 3 | PRIN-AUTH-001 | Principal login | Principal signs in with local seeded account and reaches Principal Dashboard | Pass |
| 4 | PRIN-AUTH-002 | Principal session/profile restore | App loads authenticated Principal profile and `/auth/profile`/`/auth/me` return 200 | Pass |
| 5 | PRIN-DASH-001 | Principal Dashboard | Dashboard KPIs and quick access render from `/dashboard/principal` | Pass |
| 6 | PRIN-NAV-001 | Principal drawer module list | Drawer exposes Principal modules with canonical labels and no stale hardcoded badges | Pass |
| 7 | PRIN-NAV-002 | Principal Syllabus drawer availability | Syllabus Records appears without false `backend pending` label | Pass |
| 8 | PRIN-SCHOOL-001 | School Profile read path | School Profile opens and shows backend school identity/contact fields | Pass |
| 9 | PRIN-SCHOOL-002 | School Profile update contract | Edit action is visible and route remains backend-wired; no crash on screen load | Pass |
| 10 | PRIN-ACCESS-001 | Access & Permissions list | Users, permissions, and activity tabs open with backend account data | Pass |
| 11 | PRIN-ACCESS-002 | Principal account-management routes | Principal create/edit/assign-child account routes are guarded and available | Pass |
| 12 | PRIN-ACCESS-003 | Staff-linked login account contract | Staff-backed Admin/Teacher account workflow remains configured in source/API tests | Pass |
| 13 | PRIN-STUD-001 | Student Oversight list/filter | Student Oversight loads students, grades, sections, filters, and parent-link data | Pass |
| 14 | PRIN-STUD-002 | Student Oversight action surface | Implemented student actions remain visible and backend-wired | Pass |
| 15 | PRIN-APPROVAL-001 | Approval Center buckets | Approval Center opens with tabs, counts, filters, and honest empty/pending state | Pass |
| 16 | PRIN-APPROVAL-002 | Student leave approvals | Student leave approval list loads for Principal decision center | Pass |
| 17 | PRIN-APPROVAL-003 | Account/student/class approval reads | Approval read APIs return 200 for Principal | Pass |
| 18 | PRIN-TT-001 | Timetable Records | Timetable slots and substitutions load without crash or overflow | Pass |
| 19 | PRIN-TT-002 | Timetable Principal ownership | Principal sees oversight/advice actions, not Admin slot CRUD | Pass |
| 20 | PRIN-TT-003 | Timetable advice API | Principal timetable advice read API returns 200 | Pass |
| 21 | PRIN-SYL-001 | Syllabus Records | Syllabus Records opens and `/syllabus` plus `/curriculum` return 200 | Pass |
| 22 | PRIN-EXAM-001 | Exam Records | Exam Records opens with admin-managed schedules and exam APIs return 200 | Pass |
| 23 | PRIN-EXAM-002 | Exam advice API | Principal exam advice read API returns 200 | Pass |
| 24 | PRIN-ACAD-001 | Academic Management read path | Academic Management opens with academic year/class/subject/curriculum data | Pass |
| 25 | PRIN-ACAD-002 | Academic Management Principal ownership | Principal view is read-only; Add/Edit/Delete/Publish controls are hidden | Pass |
| 26 | PRIN-FEE-001 | Fee Monitoring overview | Fee Monitoring opens with billed/collected/pending/coverage KPIs | Pass |
| 27 | PRIN-FEE-002 | Fee Monitoring backend-truth model | Fee data comes from invoice/payment/concession APIs, not fake local values | Pass |
| 28 | PRIN-COMM-001 | Communication Center | Communication Center opens with circulars/notices/alerts tabs and backend data | Pass |
| 29 | PRIN-COMM-002 | Notice/announcement publishing contract | New Circular action remains visible and backend communication APIs return 200 | Pass |
| 30 | PRIN-COMP-001 | Complaints | Complaints opens with ticket tabs, filters, and backend complaint data | Pass |
| 31 | PRIN-CAL-001 | Calendar/Events | Calendar opens with month/event tabs and Add Event action | Pass |
| 32 | PRIN-RPT-001 | Reports | Reports opens with overview, quick reports, and export-backed report lists | Pass |
| 33 | PRIN-RPT-002 | Report export lifecycle contract | Report export APIs return 200 and persisted lifecycle tests remain green | Pass |
| 34 | PRIN-ANL-001 | Analytics | Analytics opens with backend-derived attendance/fee/staff/alert tabs and no demo-data audit failure | Pass |
| 35 | PRIN-PROFILE-001 | Principal Profile | Profile opens with Principal identity and school details | Pass |
| 36 | PRIN-PROFILE-002 | Avatar/profile media contract | Attach Profile Picture action uses backend upload contract | Pass |
| 37 | PRIN-SET-001 | Settings | Settings opens with appearance, notification, and backup controls | Pass |
| 38 | PRIN-RBAC-001 | Principal route guard | Principal routes remain role-guarded in focused route tests | Pass |
| 39 | PRIN-SHARED-001 | Global Search | Shared Global Search opens from Principal drawer and stays authenticated | Pass |
| 40 | PRIN-SHARED-002 | Notifications | Shared Notifications opens with Principal alerts and role tabs | Pass |
| 41 | PRIN-QA-001 | Focused Principal automated tests | Principal source contracts and route tests pass | Pass |
| 42 | PRIN-QA-002 | Backend Go regression gate | Backend package tests pass after Principal fixes | Pass |
| 43 | PRIN-QA-003 | Static analysis and runtime logs | `flutter analyze` is clean and device runtime logs show no Principal app crash/overflow/API error | Pass |

## 2026-05-20 VPS Backend Deploy And Release AAB Evidence

Scope: Current Go backend deployed to Hostinger VPS and fresh Hostinger-target Play Store AAB rebuilt with version bumped from `1.0.5+9` to `1.0.5+10`.

Evidence:

- VPS deploy script: `scripts/deploy-hostinger-backend.sh --check-only --no-login-smoke`, `--dry-run --no-login-smoke`, then `--execute --yes --no-login-smoke`.
- Remote backup created before rebuild: `/root/schooldesk-backups/deploy-20260519-183352`.
- Public backend checks: `/health` returned `{"status":"healthy"}` and `/ready` returned `{"database":"ok","environment":"production","redis":"ok","status":"ready"}`.
- Remote container check: `schooldesk-go-api` recreated successfully and `MIGRATE_ON_START=false`.
- AAB artifact: `build/releases/schooldesk-1.0.5+10-hostinger-release.aab`.
- AAB SHA-256: `6c46eeff66796f78f32a654d4320fecc9bf0677ed7147abba0d0975d335b42c2`.
- AAB manifest evidence: package `com.techmigos.schooldesk1`, `versionCode 10`, `versionName 1.0.5`.
- AAB backend target evidence: embedded release URL `https://schooldesk-api.187.127.157.43.nip.io/api`; no exact local HTTP API base URL strings found in the ARM64 release snapshot.

| SN | TC_ID | TestCase | Expected | Status |
|---|---|---|---|---|
| 1 | REL-VPS-001 | VPS SSH and fingerprint preflight | Hostinger SSH fingerprint matches expected value and remote Compose stack is reachable | Pass |
| 2 | REL-VPS-002 | Safe deploy dry-run | Dry-run checks backend tests, remote state, health, and rsync plan without changing VPS | Pass |
| 3 | REL-VPS-003 | VPS backend backup | Backup is created before source sync/rebuild | Pass |
| 4 | REL-VPS-004 | VPS backend rebuild | `schooldesk-go-api` rebuilds/restarts successfully with Postgres and Redis healthy | Pass |
| 5 | REL-VPS-005 | Production readiness endpoint | Public `/ready` reports production database and Redis OK | Pass |
| 6 | REL-AAB-001 | Version bump | `pubspec.yaml` build number is bumped to `1.0.5+10` | Pass |
| 7 | REL-AAB-002 | Release build | Hostinger-target release AAB builds successfully with `env.hostinger.json` | Pass |
| 8 | REL-AAB-003 | Release build stability | Normal future `flutter build appbundle --release --dart-define-from-file=env.hostinger.json` succeeds after dev-only `integration_test` registrant guard | Pass |
| 9 | REL-AAB-004 | AAB integrity | `unzip -t` detects no compressed data errors | Pass |
| 10 | REL-AAB-005 | AAB signing | `jarsigner -verify` reports `jar verified` with `CN=SchoolDesk, OU=Techmigos, O=Techmigos, L=Pune, ST=Maharashtra, C=IN` | Pass |
| 11 | REL-AAB-006 | Package identity | AAB manifest contains `com.techmigos.schooldesk1`, `versionCode 10`, and `versionName 1.0.5` | Pass |
| 12 | REL-AAB-007 | Backend target | AAB contains Hostinger API URL and no exact `http://localhost`, `http://127.0.0.1`, or `http://10.0.2.2` API base URL in ARM64 release snapshot | Pass |

## 2026-05-20 Admin Module Wireless Device Execution Sheet

Scope: Admin role module only, Moto g85 wireless ADB, local Docker backend through `adb reverse tcp:8080 tcp:8080`.

Evidence:

- Wireless device: `adb-ZA2235WH4K-c1n0iS._adb-tls-connect._tcp`, model `moto_g85_5G`.
- Local Docker readiness: `/health` returned `{"status":"healthy"}` and `/ready` returned `{"database":"ok","environment":"development","redis":"ok","status":"ready"}`.
- Docker containers: `schooldesk-go-api`, `schooldesk-postgres`, and `schooldesk-redis` all running; Postgres/Redis healthy.
- Installed rebuilt local-backend profile APK on wireless device: `build/app/outputs/flutter-apk/app-profile.apk`, SHA-256 `b0688806413ca8a81263e3347b4f9b5d0a0da377de46cd3e7dc98674817e4347`.
- Admin login account verified against local Docker backend: username `admin`, role `Admin`, email `admin@test.com`.
- Admin screenshots/UI trees/logs: `test-artifacts/admin-wireless-2026-05-20/`.
- Local Docker API suite: `school-backend/test-report/local-docker-api-report.json` / `.html`, `79` passed, `0` warnings, `0` failed.
- Focused Flutter source-contract tests passed after Admin fixes: `20` passed across Admin wording, route guard, and production readiness contracts.
- `flutter analyze` after Admin fixes: no issues found.
- Runtime log scan after final Admin walkthrough/logout: no Flutter exception, crash, overflow, Helpdesk null-cast error, or app error screen found.

Fixes completed during this Admin test pass:

- Fixed Admin Helpdesk crash caused by nullable backend ticket fields by normalizing ticket text/status fields before rendering.
- Added missing Admin `Academic Info` drawer entry and removed incorrect `backend pending` badges from Admin Helpdesk, Documents, and ID Cards metadata after those Admin screens proved backend-backed on device.

| SN | TC_ID | TestCase | Expected | Status |
|---|---|---|---|---|
| 1 | ADMIN-LD-001 | Local Docker backend readiness | Go API, Postgres, and Redis are healthy; `/health` and `/ready` are green | Pass |
| 2 | ADMIN-LD-002 | Admin local-backend APK install | Rebuilt profile APK installs on the wireless Android device | Pass |
| 3 | ADMIN-AUTH-001 | Admin API login | Seeded Admin account authenticates against local Docker and returns Admin role/profile | Pass |
| 4 | ADMIN-AUTH-002 | Admin device login | Admin signs in on wireless device and reaches Admin Dashboard | Pass |
| 5 | ADMIN-AUTH-003 | Admin session restore after reinstall | Reinstalled profile APK preserves authenticated Admin session and opens Admin Dashboard | Pass |
| 6 | ADMIN-DASH-001 | Admin Dashboard | Dashboard KPIs render backend counts for students, staff, classes, notices, and fee dues | Pass |
| 7 | ADMIN-NAV-001 | Admin drawer module list | Drawer exposes all Admin modules with canonical labels and no stale false pending badges | Pass after fix |
| 8 | ADMIN-STUD-001 | Students list/search/filter | Students screen opens with backend student list, tabs, search, filter, and request action | Pass |
| 9 | ADMIN-STUD-002 | Student request/backend approval path | Admin student action surface remains routed to backend approval workflow | Pass |
| 10 | ADMIN-STAFF-001 | Staff list/search/filter | Staff screen opens with backend staff list, filters, Add staff, and export action | Pass |
| 11 | ADMIN-STAFF-002 | Staff account/profile creation route | Staff creation action remains visible and route/API contracts are guarded for Admin | Pass |
| 12 | ADMIN-ATT-001 | Attendance dashboard | Attendance screen opens with Today, Exceptions, and Reports tabs plus class selector | Pass |
| 13 | ADMIN-ATT-002 | Attendance reports/exports | Attendance reporting routes and backend contract remain available to Admin | Pass |
| 14 | ADMIN-FEE-001 | Fees overview | Fees screen opens with Fee Structure, Pending Dues, Payments, Reports, and finance KPIs | Pass |
| 15 | ADMIN-FEE-002 | Fee structure/invoice/payment actions | New structure, generate invoices, record payment, and payment request actions are wired | Pass |
| 16 | ADMIN-FEE-003 | Payment request decision path | Admin payment request decision route and API contract remain guarded and available | Pass |
| 17 | ADMIN-TT-001 | Timetable grid | Timetable opens with class selector, weekday selector, periods, and substitution data | Pass |
| 18 | ADMIN-TT-002 | Timetable CRUD/action surface | Generate suggestions, Add period, and substitution workflows remain visible and routed | Pass |
| 19 | ADMIN-EXAM-001 | Exams overview | Exams screen opens with Exams, Schedules, Report Cards tabs and exam data | Pass |
| 20 | ADMIN-EXAM-002 | Exam create/schedule/publish actions | Create exam, exam type, schedule, publish/unpublish, and notification routes are available | Pass |
| 21 | ADMIN-ACAD-001 | Academic Management read path | Academic years, subjects, classes, and curriculum tabs load for Admin | Pass |
| 22 | ADMIN-ACAD-002 | Academic Management CRUD controls | Admin Add/Edit/Delete/Publish controls remain visible and route contracts are guarded | Pass |
| 23 | ADMIN-COMM-001 | Communication notices | Communication screen opens with Notices, Templates, History, filters, and backend notices | Pass |
| 24 | ADMIN-COMM-002 | Notice compose/delete actions | Compose notice and delete notice actions remain visible and backend-wired | Pass |
| 25 | ADMIN-HELP-001 | Helpdesk open and ticket list | Helpdesk opens without app error and renders backend tickets/tabs | Pass after fix |
| 26 | ADMIN-HELP-002 | Helpdesk nullable backend fields | Null status/category/name/date fields render safe defaults instead of crashing | Pass after fix |
| 27 | ADMIN-HELP-003 | Helpdesk status filters/stats | Ticket status normalization supports All/Open/In Progress/Resolved and Stats tab counts | Pass after fix |
| 28 | ADMIN-DOC-001 | Documents request list | Documents opens with Requests, Generate, Records tabs and backend request rows | Pass after fix |
| 29 | ADMIN-DOC-002 | Document request/update/print routes | Create document request and request decision/print actions remain visible and backend-routed | Pass |
| 30 | ADMIN-ACCESS-001 | User & Access overview | Users, Permissions, and Activity tabs open with backend users and filters | Pass |
| 31 | ADMIN-ACCESS-002 | Account create/edit/child assignment | Teacher/Parent account creation, edit, and child assignment routes remain Admin-guarded | Pass |
| 32 | ADMIN-RPT-001 | Reports overview | Reports opens with All Reports/Compliance tabs and report-card generator | Pass |
| 33 | ADMIN-RPT-002 | Report exports | Admission/Fee report PDF and CSV export actions remain visible and export contract tests pass | Pass |
| 34 | ADMIN-INFO-001 | Academic Info drawer availability | Academic Info appears in Admin drawer under School Info | Pass after fix |
| 35 | ADMIN-INFO-002 | Academic Info read path | Academic Info opens with active academic year and curriculum/subjects/classes tabs | Pass |
| 36 | ADMIN-ID-001 | ID Cards list | ID Cards opens with backend student list, search, class chips, and per-student actions | Pass after fix |
| 37 | ADMIN-ID-002 | ID card generate/print action | Generate ID Card opens Android print/PDF preview with a one-page output | Pass |
| 38 | ADMIN-SEARCH-001 | Global Search open | Global Search opens from Admin shared tools with role-safe shared route | Pass |
| 39 | ADMIN-SEARCH-002 | Global Search query | Searching `QA` returns grouped backend results for Students, Staff, and Notices | Pass |
| 40 | ADMIN-NOTIF-001 | Notifications | Notifications opens with Admin alerts, unread count, Mark all read, and category tabs | Pass |
| 41 | ADMIN-PROFILE-001 | Profile | Profile opens with Admin identity, email, edit, refresh, settings, and sign-out actions | Pass |
| 42 | ADMIN-SET-001 | Settings | Settings opens with appearance, notification, and backup/restore controls | Pass |
| 43 | ADMIN-LOGOUT-001 | Logout | Admin sign-out clears session and returns to public landing/login surface | Pass |
| 44 | ADMIN-RBAC-001 | Admin route guards | Admin-only routes allow Admin and redirect wrong/unauthenticated roles in focused tests | Pass |
| 45 | ADMIN-QA-001 | Local Docker API suite | Local Docker API verifier passes with `79` passed, `0` warnings, `0` failed | Pass |
| 46 | ADMIN-QA-002 | Focused Flutter Admin contracts | Admin wording, production readiness, and route guard tests pass after fixes | Pass |
| 47 | ADMIN-QA-003 | Static analysis and runtime logs | `flutter analyze` is clean and final device logs show no Admin crash/overflow/API error | Pass |
| 48 | ADMIN-DEV-001 | Remaining Admin development blockers | No Admin-only source/API/build blocker remains after the Helpdesk and navigation metadata fixes | Pass |

## 2026-05-20 VPS Backend Deploy And Release AAB Evidence +11

Scope: Current Go backend pushed safely to Hostinger VPS Docker and fresh Hostinger-target Play Store AAB rebuilt with version bumped from `1.0.5+10` to `1.0.5+11`.

Evidence:

- VPS deploy preflight: `scripts/deploy-hostinger-backend.sh --check-only --no-login-smoke`.
- Safe dry-run: `scripts/deploy-hostinger-backend.sh --dry-run --no-login-smoke`; local `go test ./...` passed before deploy.
- Executed deploy: `scripts/deploy-hostinger-backend.sh --execute --yes --no-login-smoke`.
- Remote backup created before rebuild: `/root/schooldesk-backups/deploy-20260519-193104`.
- Remote Docker state after deploy: `schooldesk-go-api` recreated, `schooldesk-postgres` healthy, `schooldesk-redis` healthy.
- Remote migration guard after deploy: `MIGRATE_ON_START=false`.
- Public backend checks: `/health` returned `{"status":"healthy"}` and `/ready` returned `{"database":"ok","environment":"production","redis":"ok","status":"ready"}`.
- Live auth smoke: Principal login returned HTTP `200` with `success=true`, username `principal`, role `Principal`.
- AAB artifact: `build/releases/schooldesk-1.0.5+11-hostinger-release.aab`.
- AAB SHA-256: `61a280002722016656481de2db6761257462a834739d11d1329b609408da0392`.
- AAB archive integrity: `unzip -t` reported no compressed data errors.
- AAB signing: `jarsigner -verify` reported `jar verified`; signer `CN=SchoolDesk, OU=Techmigos, O=Techmigos, L=Pune, ST=Maharashtra, C=IN`.
- AAB manifest evidence: package `com.techmigos.schooldesk1`, `versionCode 11`, `versionName 1.0.5`.
- AAB backend target evidence: embedded Hostinger API URL `https://schooldesk-api.187.127.157.43.nip.io/api`; no exact local API base URL strings `http://127.0.0.1:8080/api`, `http://localhost:8080/api`, or `http://10.0.2.2:8080/api` found in the release bundle string scan.

| SN | TC_ID | TestCase | Expected | Status |
|---|---|---|---|---|
| 1 | REL-VPS11-001 | VPS preflight | Hostinger SSH fingerprint, remote compose state, migration flag, and public health are verified before changes | Pass |
| 2 | REL-VPS11-002 | Deploy dry-run | Local backend tests pass and rsync dry-run completes without changing VPS | Pass |
| 3 | REL-VPS11-003 | Remote backup | Backup is created before source sync/rebuild | Pass |
| 4 | REL-VPS11-004 | VPS backend rebuild | `schooldesk-go-api` rebuilds/recreates successfully with Postgres and Redis healthy | Pass |
| 5 | REL-VPS11-005 | Migration guard | `MIGRATE_ON_START` remains `false` after deploy | Pass |
| 6 | REL-VPS11-006 | Public readiness | Production `/health` and `/ready` endpoints return healthy/ready | Pass |
| 7 | REL-VPS11-007 | Live auth smoke | Principal login against VPS returns HTTP `200` and correct Principal role | Pass |
| 8 | REL-AAB11-001 | Version bump | `pubspec.yaml` is bumped to `1.0.5+11` | Pass |
| 9 | REL-AAB11-002 | Static analysis | `flutter analyze` returns no issues after version bump | Pass |
| 10 | REL-AAB11-003 | Release AAB build | Hostinger-target release AAB builds successfully with `env.hostinger.json` | Pass |
| 11 | REL-AAB11-004 | AAB archive integrity | `unzip -t` detects no compressed data errors | Pass |
| 12 | REL-AAB11-005 | AAB signing | `jarsigner -verify` reports `jar verified` with SchoolDesk upload certificate | Pass |
| 13 | REL-AAB11-006 | Package identity | AAB manifest contains `com.techmigos.schooldesk1`, `versionCode 11`, and `versionName 1.0.5` | Pass |
| 14 | REL-AAB11-007 | Backend target | AAB contains Hostinger API URL and no exact local API base URL strings in release bundle scan | Pass |

## 2026-05-20 VPS Firebase FCM Push Notification Evidence

Scope: Configure Firebase Cloud Messaging for the Hostinger VPS backend using the provided Firebase service-account key, verify the production worker, register an Android device token, and send one controlled push to the wireless Moto g85.

Evidence:

- Firebase service-account key uploaded securely to `/opt/schooldesk-secrets/firebase-service-account.json`; key contents were not printed or committed.
- Remote `.env` was backed up before FCM changes at `/root/schooldesk-backups/env-before-fcm-20260520-031741`.
- VPS FCM flags enabled: `ENABLE_FCM_PUSH=true`, Firebase project configured, credential path configured, and `COMPOSE_PROFILES=push`.
- `schooldesk-notification-worker` is running under Docker Compose and logs show `FCM push sender initialized`.
- Production `/ready` after setup: `{"database":"ok","environment":"production","redis":"ok","status":"ready"}`.
- Play-installed `1.0.5+8` app launched and logged in but did not call `/api/notifications/device-tokens`; the current Hostinger `1.0.5+11` build did register successfully.
- Current test APK built from the same Hostinger source as the `+11` AAB: `build/app/outputs/flutter-apk/app-release.apk`, SHA-256 `eaee9381e657fe0a11d68d4585a499098a9a1cd82cb29f0c45b1e949768f3360`.
- Android package installed for FCM verification: `com.techmigos.schooldesk1`, `versionCode 11`, `versionName 1.0.5`.
- Android notification permission was allowed for the test device.
- Principal login against VPS succeeded from the phone; VPS logs show `POST /api/auth/login` HTTP `200` and Principal profile loads.
- Device-token registration succeeded; VPS logs show `POST /api/notifications/device-tokens` HTTP `200` for `user-principal-default`.
- DB token summary after registration: `android|1.0.5+11|1|2026-05-20 03:37:43.937866+00`.
- Controlled FCM test notification was sent by the worker; DB evidence before cleanup: push status `sent`, pushed at `2026-05-20 03:41:05.6804+00`.
- Android notification dump showed active notification from `com.techmigos.schooldesk1` on channel `schooldesk_updates` with title `SchoolDesk FCM test` and body `Push notification backend is configured successfully.`
- Screenshot evidence captured at `build/evidence/fcm-notification-shade.png`.
- Temporary backend test notification row was removed after evidence capture to avoid production data pollution.

| SN | TC_ID | TestCase | Expected | Status |
|---|---|---|---|---|
| 1 | FCM-VPS-001 | Service-account upload | Firebase Admin key exists on VPS in secrets path with restricted access and no key contents exposed | Pass |
| 2 | FCM-VPS-002 | Environment configuration | VPS backend has FCM enabled, Firebase project set, credential file set, and push compose profile enabled | Pass |
| 3 | FCM-VPS-003 | Worker startup | `schooldesk-notification-worker` starts and initializes FCM sender | Pass |
| 4 | FCM-VPS-004 | Backend readiness after worker enable | API, Postgres, and Redis remain healthy/ready after worker enablement | Pass |
| 5 | FCM-APP-001 | Current app token registration | Hostinger `1.0.5+11` Android build logs in and posts `/api/notifications/device-tokens` | Pass |
| 6 | FCM-APP-002 | Device token persistence | DB stores one active Android token for `user-principal-default` with app version `1.0.5+11` | Pass |
| 7 | FCM-PUSH-001 | Controlled push send | Worker processes a queued notification and marks push status `sent` | Pass |
| 8 | FCM-PUSH-002 | Android receipt | Moto g85 receives the notification on `schooldesk_updates` channel | Pass |
| 9 | FCM-CLEAN-001 | Test data cleanup | Temporary backend test notification row is removed after evidence capture | Pass |
| 10 | FCM-REL-001 | Play-build caveat | Existing Play-installed `1.0.5+8` did not register a token; rollout must use `1.0.5+11` or newer for push receipt | Pass |
