# SchoolDesk API Contract Consolidation

Date: 2026-05-17  
Scope: Local Docker Go API only. Hostinger/VPS validation is intentionally excluded.

## Verified Command Gates

```bash
flutter analyze
flutter test
(cd school-backend && go test ./...)
scripts/verify-local-docker-api.sh
```

## Contract Ownership Rules

| Layer | Current Owner | Rule |
|---|---|---|
| Flutter primary client | `lib/services/backend_api_client.dart` | New backend-backed work should use typed methods here first. |
| Flutter compatibility reads/writes | `BackendDataService` and raw helpers | Allowed only for legacy/generic resources while typed APIs are being migrated. |
| Go route owner | `school-backend/main.go` | Every protected domain route must declare Auth, school scope, RBAC, and rate limit for writes. |
| Backend persistence | `school-backend/internal/models/*` | High-value workflows must have typed models instead of generic frontend records. |
| Verification | `school-backend/cmd/local-api-verify` plus unit/source tests | Any new user-facing workflow should add one local Docker verifier check or focused contract test. |

## High-Value Feature Map

| Domain | Flutter Surface | API Contract | Backend Owner | Persistence | Role Scope | Verification |
|---|---|---|---|---|---|---|
| Auth/Profile | Login, profile, school profile | `/auth/login`, `/auth/profile`, `/auth/profile/avatar`, `/schools/current` compat/current-school APIs | `AuthHandler`, `SchoolHandler` | `users`, `schools` | User token + school scope | Go tests, local API verifier, profile source tests |
| Accounts | Principal/Admin user access | `/users`, `/account-approvals`, `/staff` | `UserHandler`, `AccountApprovalHandler`, `StaffHandler` | `users`, `account_approvals`, `staff` | Principal owns approvals; Admin requests where required | Local API verifier account lifecycle |
| Students | Admin students, student oversight | `/students`, `/student-approvals`, `/parents/:id/students` | `StudentHandler`, `StudentApprovalHandler`, `ParentLinkHandler` | `students`, `student_approvals`, parent links | Principal direct, Admin approval path, Parent linked read | Flutter contract tests, local API verifier |
| Fees | Admin fees, parent fees, receipts | `/fees/categories`, `/fees/structures`, `/fees/invoices`, `/fees/payments`, `/fees/payment-requests` | `FeeHandler` | fee categories, structures, invoices, payments, payment requests | Admin settlement; Parent request only | Flutter contract tests, local API verifier |
| Leave | Teacher leave, parent leave | `/leave/applications`, `/leave/balances`, `/student-leave/applications` | `LeaveHandler` | staff leave, student leave | Staff/linked-student role rules | Focused tests, local API verifier |
| Calendar | Parent calendar/events | `/events`, `/academic-years`, `/exams`, PTM/event compatibility routes | `AnnouncementHandler`, `SchoolHandler`, compat routes | events, academic years, exams | Parent linked read, Admin/Principal writes | Parent calendar contract test |
| Timetable | Admin timetable, principal records | `/timetable/slots`, `/timetable/slots/generate`, `/timetable/substitutions`, `/timetable/suggestions` | `TimetableHandler` | timetable slots, substitutions | Admin writes, Principal oversight | Flutter contract tests, local API verifier |
| Exams | Admin exams, report cards | `/exams`, `/exams/schedules`, `/exams/:id/publish`, `/exams/report-cards/exports` | `ExamHandler`, `ReportExportHandler` | exams, schedules, marks, report exports | Admin writes; Teacher/Parent report-card scope | Flutter contract tests, local API verifier |
| Homework | Teacher and Parent homework | `/homework`, `/homework/:id/submissions`, `/homework/:id/submissions/:submission_id/review` | Homework compatibility + `HomeworkSubmissionHandler` | homework records, submissions | Teacher assigned scope; Parent linked submission | Flutter contract tests, local API verifier |
| Reports/Exports | Admin/Principal/Teacher/Parent exports | `/reports/exports`, `/fees/reports/exports`, `/attendance/reports/exports`, `/student-reports/exports`, `/exams/report-cards/exports` | `ReportExportHandler` | `report_exports`, `uploads/exports/*` | Route-specific RBAC | Go tests, Flutter contract test, local API verifier |

## Remaining Consolidation Tasks

| Priority | Task | Acceptance Gate |
|---|---|---|
| P1 | Replace remaining generic `FrontendRecordHandler` resources where they carry business rules: complaints, documents, notes, alerts, discipline. | Typed handler/model or explicit legacy decision documented. |
| P1 | Keep new Flutter workflows on `BackendApiClient` typed methods instead of ad hoc raw calls. | Source contract tests fail if high-value screens bypass typed client. |
| P2 | Split compatibility routes into a documented legacy group and prevent new `/api` endpoints without a `/api/v1` owner. | Route inventory doc updated and local verifier covers the active path. |
| P2 | Add artifact cleanup policy for `uploads/exports`. | Runbook and cleanup job/script exist before VPS deployment. |
