# SchoolDesk QA And Test Strategy

## Current Architecture Snapshot

SchoolDesk is a Flutter app using a feature-first structure under `lib/features`, `Provider` for app-wide `ChangeNotifier` controllers, and Riverpod providers in `lib/app/providers/schooldesk_providers.dart` as a repository/service access layer. Runtime services are composed by `ServiceLocator`, with `BackendApiClient` and generated Retrofit `SchoolDeskApiClient` wrapping Supabase Edge Function calls.

Authentication is Supabase Auth. The app logs in through `POST /auth/login`, which resolves username aliases in `public.username_aliases`, signs into Supabase Auth with email/password, and returns Supabase session tokens plus a profile row from `public.users`. The JWT `app_metadata.school_id` and `app_metadata.role_name` drive RLS helpers in `0005_rls_policies.sql`.

Primary roles discovered:

- `principal`: primary administrative role and owner of most management screens.
- `admin`: normalized to `principal` by route guards, but still appears in test and API contracts.
- `teacher`: classroom, attendance, homework, communication, leave, timetable workflows.
- `parent`: child-linked attendance, homework, fees, health, documents, PTM workflows.
- `student`: requested for QA coverage and seeded for data consistency; the current Flutter route guard has no student dashboard route yet.
- `kiosk`: staff/student QR attendance support role.

Routing is centralized in `lib/routes/app_routes.dart`; authorization is centralized in `lib/routes/route_access_guard.dart`. Shared protected routes include notifications, settings, profile, global search, and homework messaging.

## Database Inventory

Migrations define these main tables:

- Academic: `schools`, `academic_years`, `terms`, `holidays`, `working_day_configs`, `departments`, `subjects`, `grades`, `rooms`, `sections`, `grade_subjects`
- People and auth bridge: `roles`, `permissions`, `staff`, `staff_qualifications`, `staff_subjects`, `staff_documents`, `students`, `guardians`, `student_guardians`, `medical_records`, `student_documents`, `enrollments`, `parent_student_links`, `transfer_records`, `users`, `username_aliases`, `user_sessions`, `audit_logs`
- Attendance, fees, leave, timetable: `attendance_sessions`, `student_attendances`, `staff_attendances`, `attendance_summaries`, `substitutions`, `fee_categories`, `fee_structures`, `fee_installments`, `fee_invoices`, `fee_invoice_items`, `payments`, `fee_receipts`, `fee_concessions`, `parent_payment_requests`, `school_payment_settings`, `leave_types`, `leave_balances`, `leave_applications`, `student_leave_applications`, `timetable_slots`, `timetable_templates`
- Communications and operations: `announcements`, `event_posts`, `message_conversations`, `messages`, `notification_logs`, `notification_device_tokens`, `diary_entries`, `lesson_planners`, `homework_submissions`, `approval_requests`, `account_approvals`, `uploaded_files`, `frontend_records`, `bulk_import_jobs`, `error_events`
- Calendar/PTM: `events`, `parent_teacher_meetings`

Dynamic features such as homework, documents, report exports, scoped payment configs, and some communications use `frontend_records`.

## API Surface

The Supabase Edge Function entrypoint is `supabase/functions/api/index.ts`. It exposes health/auth plus module handlers:

- Auth: `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `POST /auth/password`, `GET/PATCH /auth/profile`, `POST /auth/profile/avatar`
- School setup/profile: `POST /schools/setup`, `GET /schools`, `GET/PATCH /schools/current`, `POST /schools/current/logo`
- Academics: `GET/POST/PATCH/PUT/DELETE /academic-years`, `GET /academic-years/:id/terms`, `GET/POST/PATCH /grades`, `GET/POST/PATCH /sections`, `GET/POST /departments`, `GET/POST/PATCH/PUT /subjects`, `GET/POST/PATCH /grade-subjects`, `GET/POST/PATCH/PUT/DELETE /staff-subjects`, `GET/POST /rooms`
- People: `GET/POST/PUT/PATCH/DELETE /staff`, staff photo/doc uploads, `GET/POST/PUT/PATCH/DELETE /students`, student photo/doc uploads, guardians, enrollments, parent links, `GET/POST/PATCH/DELETE /users`, user activation/avatar
- Attendance: sessions, mark, correction, reopen, summary, staff attendance, QR token/scan/log export, student attendance lookup
- Fees: categories, structures, invoice sync, invoices, payments, payment proof submit/resubmit, parent payment requests/decisions, payment configs/QR, concessions, reminders
- Leave: leave types/balances/applications, student leave applications and decisions
- Homework: `GET/POST/PUT/PATCH/DELETE /homework`, submissions, review, attachment requests, reminder status/skip
- Communications: announcements/notices, notifications, device tokens, PTM slots/meetings, conversations/messages, diary, lesson planners, generic communications
- Calendar/events: holidays, events
- Principal workflows: class hub, class imports, subject actions/mappings, timetable actions
- Uploads/documents/reports/parent: generic file upload, event posts, student documents, document requests/templates/prints, parent students, report exports
- Monitoring: error events and resolution

Every API test must assert HTTP method, path, auth header behavior, payload shape, success envelope, error envelope, RLS/authorization result, and final database state.

## Test Pyramid

1. Unit tests: validators, route guards, model conversion, repository mapping, API contract transforms, role access logic.
2. Widget tests: reusable components, responsive layouts, empty/loading/error states, form validation, dialogs/snackbars.
3. Golden tests: stable shared widgets and dense operational screens with deterministic fonts/assets.
4. Integration tests: app launch, auth, dashboards, attendance, homework, fees, communication, settings, profile, notifications against local Supabase.
5. Patrol E2E tests: role journeys requiring realistic user navigation and native interaction support.
6. API tests: direct Edge Function tests against local Supabase after deterministic reset.

## Deterministic Local Data

The local database must reset to a known state before test runs. Required baseline users:

- Principal: `principal` / `Principal@12345`
- Admin: `admin` / `Admin@12345`
- Teacher: `teacher` / `Teacher@12345`
- Parent: `parent` / `Parent@12345`
- Student: `student` / `Student@12345`
- Kiosk: `kiosk` / `Kiosk@12345`

The seed must include one school, current academic year, terms, room, grade/class/section, subjects, teacher assignment, one student, guardian, parent-child link, attendance session/records, homework, fees/invoice/payment request, notification, announcement, event, PTM slot, leave records, and storage bucket metadata.

## Execution Gates

Local verification command order:

1. `scripts/local_supabase.sh start`
2. `scripts/local_supabase.sh reset`
3. `scripts/local_supabase.sh functions`
4. `scripts/qa_verify.sh`

Continuous verification must run:

- `dart format --set-exit-if-changed .`
- `flutter analyze`
- `flutter test`
- `flutter test integration_test --dart-define-from-file=env.local.json`
- `patrol test --dart-define-from-file=env.local.json`
- `scripts/verify_production_backend_config.sh`

If a test fails, fix the cause and rerun the smallest affected test first, then the full affected suite.

Local verification never builds APKs. APK/AAB builders use production Supabase
configuration through `env.supabase.json`, `scripts/build-android-supabase.sh`,
or Codemagic push workflows.

## Coverage Priorities

Phase 1 priority is local Supabase, auth, storage, migrations, seed data, and one-command setup. Phase 2 priority is reusable test utilities and smoke coverage for each role. Phase 3+ expands to full CRUD/API/RLS matrices per module.

Known testability risks:

- Student role is requested but no student route/dashboard exists in `RouteAccessGuard`.
- Admin is normalized to principal for routing, so admin-specific UI assertions must be explicit.
- Some features use `frontend_records`, which needs stricter typed repository boundaries for robust tests.
- Current Edge Function config has `verify_jwt = false`; handlers still authenticate most protected routes, but API tests must include unauthenticated checks.
- Supabase CLI and Deno are system prerequisites and are not currently installed in this workspace.
