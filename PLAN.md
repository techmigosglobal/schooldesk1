# Supabase Backend Migration Plan - Exams and Assistant Removed

## Summary
- Migrate SchoolDesk from the current backend to Supabase with a Supabase Edge Function gateway preserving `/api/v1/*` for the Flutter app.
- Use Supabase Auth plus a username alias table so existing username login remains supported.
- Migrate only real production data. No mock data, fake data, seeded demo data, or UI fallback data.
- Remove Academics `max_marks` and `pass_marks` from subject/class mappings, CSV templates, payloads, and UI.
- Remove the full Exams and Assistant feature scope from Supabase migration, API contract, navigation, generated models, dashboards, approval categories, and UI/UX.

## Explicit Removals
- Do not implement, migrate, expose, or document these API groups:
  - `/api/v1/exams`
  - `/api/v1/exam-schedules`
  - `/api/v1/results`
  - `/api/v1/assistant/*`
- Remove active Supabase schema/tables for Exams, exam schedules, results, report cards, assistant workflows, assistant sessions, assistant steps, assistant templates, and assistant imports.
- Existing legacy exam/assistant data should be exported into a timestamped archive before cutover, but not imported into active Supabase tables.
- Remove UI/UX surfaces for Exams and Assistant:
  - Principal exam advice route/card/navigation.
  - Admin user access “Exams” module option.
  - Approval Center “Exams” type/filter/icon.
  - Dashboard cards, gaps, reminders, or workflow prompts related to Exams.
  - Generated `ExamDto`, `ExamScheduleDto`, result/report-card models if unused after removal.
  - Any assistant workflow screens, buttons, templates, sessions, or intent actions.
- Removed endpoints should return `404 not_found` from the Supabase Edge Function. Do not silently keep hidden functionality.

## Academic Marks Removal
- `max_marks` and `pass_marks` must not exist on academic subject/class mapping tables or APIs.
- Remove these fields from:
  - ClassHub subject mappings.
  - Principal subject mapping requests.
  - Grade subject APIs.
  - CSV import headers, aliases, templates, validation, and examples.
  - Flutter payload builders and generated models for academic mappings.
- If an old app build sends `max_marks` or `pass_marks` to academic mapping APIs during migration, strip and ignore them for one release cycle, never persist or return them.

## Detailed API Contract

| Domain | API Call | Method | Required Parameters | Optional Parameters | Response |
|---|---:|---|---|---|---|
| Health | `/health` | GET | none | none | `{status, timestamp, version}` |
| Health | `/ready` | GET | none | none | `{database, auth, storage, edge_function}` |
| Auth | `/api/v1/auth/login` | POST | `password`, one of `username` or `email` | `device_id`, `remember_me` | `{access_token, refresh_token, user, profile, school}` |
| Auth | `/api/v1/auth/refresh` | POST | `refresh_token` | none | `{access_token, refresh_token}` |
| Auth | `/api/v1/auth/logout` | POST | auth token | `refresh_token` | `{success}` |
| Auth | `/api/v1/auth/password` | POST | auth token, `current_password`, `new_password` | none | `{success}` |
| Auth | `/api/v1/auth/profile` | GET | auth token | none | `{user, profile, roles, school}` |
| Auth | `/api/v1/auth/profile` | PATCH | auth token | `name`, `email`, `phone`, `language`, `notification_preferences` | `{profile}` |
| Auth | `/api/v1/auth/profile/avatar` | POST | auth token, multipart `avatar` | none | `{avatar_url}` |
| Setup | `/api/v1/schools/setup` | POST | `school_name`, `admin_email`, `admin_password`, `admin_name` | `school_type`, `affiliation_board`, `phone`, `city`, `state`, `admin_username`, `admin_phone`, `admin_role` | `{school, admin_user}` |
| Schools | `/api/v1/schools` | GET | auth token | `page`, `page_size`, `search` | school list |
| Schools | `/api/v1/schools/current` | GET | auth token | none | current school |
| Schools | `/api/v1/schools/current` | PATCH | auth token | school profile fields | updated school |
| Schools | `/api/v1/schools/current/logo` | POST | auth token, multipart `logo` | none | `{logo_url}` |
| Dashboard | `/api/v1/dashboard/admin` | GET | auth token | `refresh_nonce` | admin dashboard |
| Dashboard | `/api/v1/dashboard/principal` | GET | auth token | `refresh_nonce`, `academic_year_id` | principal dashboard without exam/assistant cards |
| Dashboard | `/api/v1/dashboard/teacher` | GET | auth token | `refresh_nonce`, `date` | teacher dashboard without exam cards |
| Dashboard | `/api/v1/dashboard/parent` | GET | auth token | `refresh_nonce`, `student_id` | parent dashboard without result cards |
| Principal Classes | `/api/v1/principal/classes` | GET | auth token | `academic_year_id`, `grade_id`, `search` | class list |
| Principal Classes | `/api/v1/principal/classes` | POST | `academic_year_id`, `section_name` | `grade_id`, `grade_name`, `grade_number`, `capacity`, `class_teacher_id`, `co_teacher_id`, `room_number`, `room_type`, `room_capacity`, `subject_mappings[]`, `fee_items[]` | created class |
| Principal Classes | `/api/v1/principal/classes/:section_id` | PATCH | `section_id` | same as create, `deleted_fee_structure_ids[]`, `deleted_grade_subject_ids[]`, `deleted_staff_subject_ids[]` | updated class |
| Principal Classes | `/api/v1/principal/classes/:section_id` | DELETE | `section_id` | none | `{success}` |
| Principal Classes | `/api/v1/principal/classes/import/dry-run` | POST | `csv_text` | `academic_year_id` | validation preview without marks columns |
| Principal Classes | `/api/v1/principal/classes/import` | POST | `csv_text` | `academic_year_id` | import result |
| Principal Classes | `/api/v1/principal/classes/:section_id/instructions` | POST | `section_id`, `message` | `title`, `type`, `priority`, `send_notice`, `target_route` | instruction record |
| Subjects | `/api/v1/principal/subjects` | GET | auth token | `academic_year_id`, `department_id`, `grade_id`, `section_id` | subject list |
| Subjects | `/api/v1/principal/subjects/:subject_id/mappings` | POST | `subject_id`, `academic_year_id`, `grade_id` | `section_id`, `teacher_id`, `assignment_id`, `periods_per_week`, `is_mandatory`, `is_primary` | subject mapping without marks |
| Subjects | `/api/v1/principal/subjects/:subject_id/actions` | POST | `subject_id`, `action_type` | `title`, `message`, `priority`, `teacher_id`, `grade_id`, `due_date` | action result |
| Academics | `/api/v1/academic-years` | GET | auth token | none | academic year list |
| Academics | `/api/v1/academic-years` | POST | `year_label`, `start_date`, `end_date` | `is_current` | academic year |
| Academics | `/api/v1/academic-years/:id` | GET | `id` | none | academic year |
| Academics | `/api/v1/academic-years/:id` | PATCH | `id` | `year_label`, `start_date`, `end_date`, `is_current` | academic year |
| Academics | `/api/v1/academic-years/:id` | DELETE | `id` | `cascade` | `{success}` |
| Academics | `/api/v1/academic-years/:id/terms` | GET | `id` | none | terms |
| Academics | `/api/v1/grades` | GET | auth token | none | grade list |
| Academics | `/api/v1/grades` | POST | `grade_number`, `grade_name` | none | grade |
| Academics | `/api/v1/grades/:id` | PATCH | `id` | `grade_number`, `grade_name` | grade |
| Academics | `/api/v1/sections` | GET | auth token | `grade_id`, `academic_year_id` | section list |
| Academics | `/api/v1/sections` | POST | `grade_id`, `academic_year_id`, `section_name` | `capacity`, `class_teacher_id`, `co_teacher_id`, `room_id` | section |
| Academics | `/api/v1/sections/:id` | PATCH | `id` | mutable section fields | section |
| Academics | `/api/v1/departments` | GET | auth token | none | department list |
| Academics | `/api/v1/departments` | POST | `department_name` | none | department |
| Academics | `/api/v1/subjects` | GET | auth token | `department_id`, `subject_type`, `search` | subject list |
| Academics | `/api/v1/subjects` | POST | `subject_name` | `subject_code`, `subject_type`, `department_id`, `subject_color` | subject without marks |
| Academics | `/api/v1/subjects/:id` | PATCH | `id` | `subject_name`, `subject_code`, `subject_type`, `department_id`, `subject_color` | subject |
| Academics | `/api/v1/grade-subjects` | GET | auth token | `academic_year_id`, `grade_id`, `section_id`, `subject_id` | mapping list without marks |
| Academics | `/api/v1/grade-subjects` | POST | `academic_year_id`, `grade_id`, `subject_id` | `section_id`, `periods_per_week`, `is_mandatory`, `is_primary` | mapping |
| Academics | `/api/v1/grade-subjects/:id` | PATCH | `id` | mutable mapping fields except marks | mapping |
| Academics | `/api/v1/rooms` | GET | auth token | `room_type`, `available` | room list |
| Academics | `/api/v1/rooms` | POST | `room_number`, `room_type`, `capacity` | `block`, `floor` | room |
| Staff | `/api/v1/staff` | GET | auth token | `school_id`, `status`, `page`, `page_size`, `search` | staff list |
| Staff | `/api/v1/staff` | POST | `first_name`, `last_name`, `account_role` | `staff_code`, `username`, `email`, `phone`, `designation`, `password`, `gender`, `employment_type`, `join_date`, `date_of_birth`, `basic_salary`, `request_principal_approval` | staff |
| Staff | `/api/v1/staff/:id` | GET | `id` | none | staff |
| Staff | `/api/v1/staff/:id` | PATCH | `id` | mutable staff fields | staff |
| Staff | `/api/v1/staff/:id` | DELETE | `id` | none | `{success}` |
| Staff | `/api/v1/staff/:id/photo` | POST | `id`, multipart `photo` | none | `{photo_url}` |
| Staff | `/api/v1/staff/:id/documents` | POST | `id`, multipart `document`, `doc_type` | `title`, `expires_at` | document |
| Students | `/api/v1/students` | GET | auth token | `school_id`, `section_id`, `status`, `page`, `page_size`, `search` | student list |
| Students | `/api/v1/students` | POST | `first_name`, `last_name`, `date_of_birth`, `gender` | `admission_number`, `student_code`, `current_section_id`, `admission_date`, `status` | student |
| Students | `/api/v1/students/:id` | GET | `id` | none | student |
| Students | `/api/v1/students/:id` | PATCH | `id` | mutable student fields | student |
| Students | `/api/v1/students/:id` | DELETE | `id` | none | `{success}` |
| Students | `/api/v1/students/:id/photo` | POST | `id`, multipart `photo` | none | `{photo_url}` |
| Students | `/api/v1/students/:id/documents` | POST | `id`, multipart `document`, `doc_type` | `title`, `expires_at` | document |
| Students | `/api/v1/students/enrollments` | POST | `student_id`, `section_id`, `academic_year_id` | `roll_number`, `status` | enrollment |
| Users | `/api/v1/users` | GET | auth token | `role`, `status`, `page`, `page_size`, `search` | user list |
| Users | `/api/v1/users` | POST | `username`, `password`, `role` | `name`, `email`, `phone`, `is_active`, `request_principal_approval` | user |
| Users | `/api/v1/users/:id` | GET | `id` | none | user |
| Users | `/api/v1/users/:id` | PATCH | `id` | `username`, `role`, `name`, `email`, `phone`, `is_active` | user |
| Users | `/api/v1/users/:id/avatar` | POST | `id`, multipart `avatar` | none | `{avatar_url}` |
| Users | `/api/v1/users/:id` | DELETE | `id` | `permanent` | `{success}` |
| Approvals | `/api/v1/account-approvals` | GET | auth token | `status`, `role` | approval list |
| Approvals | `/api/v1/account-approvals/:id` | PATCH | `id`, `status` | `reason` | approval |
| Approvals | `/api/v1/approvals` | GET | auth token | `status`, `module`, `entity_type` | approval request list without exam module |
| Approvals | `/api/v1/approvals` | POST | `module`, `operation_type`, `entity_type`, `status`, `payload_json` | `entity_id`, `academic_year_id`, `before_snapshot_json`, `after_snapshot_json` | approval request |
| Approvals | `/api/v1/approvals/:id/submit` | POST | `id` | none | approval request |
| Approvals | `/api/v1/approvals/:id/approve` | POST | `id` | `note` | approval result |
| Approvals | `/api/v1/approvals/:id/reject` | POST | `id`, `reason` | none | approval result |
| Attendance | `/api/v1/attendance/sessions` | GET | auth token | `section_id`, `date`, `subject_id` | session list |
| Attendance | `/api/v1/attendance/sessions` | POST | `section_id`, `academic_year_id`, `subject_id`, `staff_id`, `date` | `period_number`, `timetable_slot_id` | attendance session |
| Attendance | `/api/v1/attendance/sessions/:session_id/mark` | POST | `session_id`, `attendances[]` | `finalize` | mark result |
| Attendance | `/api/v1/attendance/sessions/:session_id/correction-request` | POST | `session_id`, `reason` | none | correction request |
| Attendance | `/api/v1/attendance/sessions/:session_id/reopen` | POST | `session_id`, `reason` | none | session |
| Attendance | `/api/v1/attendance/summary` | GET | `student_id` | `academic_year_id`, `term_id` | attendance summary |
| Attendance | `/api/v1/attendance/staff` | GET | auth token | `date`, `staff_id` | staff attendance |
| Attendance | `/api/v1/attendance/staff` | POST | `staff_id`, `date`, `status` | `check_in`, `check_out`, `notes` | staff attendance |
| Attendance | `/api/v1/attendance/staff/qr-token` | GET | auth token | `refresh_nonce` | QR token |
| Attendance | `/api/v1/attendance/staff/qr-scan` | POST | `token` | `location` | scan result |
| Fees | `/api/v1/fee-categories` | GET | auth token | none | category list |
| Fees | `/api/v1/fee-categories` | POST | `name` | `description`, `is_active` | category |
| Fees | `/api/v1/fee-structures` | GET | auth token | `academic_year_id`, `grade_id`, `section_id` | structure list |
| Fees | `/api/v1/fee-structures` | POST | `academic_year_id`, `grade_id`, `category_id`, `amount` | `section_id`, `due_date`, `frequency`, `is_mandatory` | structure |
| Fees | `/api/v1/fee-invoices` | GET | auth token | `student_id`, `status`, `academic_year_id` | invoice list |
| Fees | `/api/v1/fee-invoices/generate` | POST | `academic_year_id` | `section_id`, `student_id`, `fee_structure_ids[]` | generation result |
| Fees | `/api/v1/fee-payments` | GET | auth token | `student_id`, `invoice_id`, `status` | payment list |
| Fees | `/api/v1/fee-payments` | POST | `student_id`, `amount`, `payment_method` | `invoice_id`, `reference_number`, `paid_at`, `notes` | payment |
| Leave | `/api/v1/leave/applications` | GET | auth token | `status`, `staff_id`, `student_id` | leave list |
| Leave | `/api/v1/leave/applications` | POST | `leave_type`, `start_date`, `end_date`, `reason` | `staff_id`, `student_id`, `attachments[]` | leave application |
| Leave | `/api/v1/leave/applications/:id/approve` | POST | `id` | `note` | leave result |
| Leave | `/api/v1/leave/applications/:id/reject` | POST | `id`, `reason` | none | leave result |
| Timetable | `/api/v1/timetable` | GET | auth token | `section_id`, `staff_id`, `academic_year_id`, `day_of_week` | timetable |
| Timetable | `/api/v1/timetable/slots` | POST | `section_id`, `subject_id`, `staff_id`, `day_of_week`, `start_time`, `end_time` | `room_id`, `period_number` | slot |
| Timetable | `/api/v1/timetable/slots/:id` | PATCH | `id` | mutable slot fields | slot |
| Timetable | `/api/v1/timetable/slots/:id` | DELETE | `id` | none | `{success}` |
| Communications | `/api/v1/announcements` | GET | auth token | `audience`, `status`, `page`, `page_size` | announcement list |
| Communications | `/api/v1/announcements` | POST | `title`, `body`, `audience` | `attachments[]`, `scheduled_at`, `priority` | announcement |
| Communications | `/api/v1/notices` | GET | auth token | `target_role`, `status` | notice list |
| Communications | `/api/v1/notices` | POST | `title`, `body` | `target_role`, `target_section_id`, `attachments[]` | notice |
| Communications | `/api/v1/notifications` | GET | auth token | `unread_only`, `page`, `page_size` | notification list without exam notification type |
| Communications | `/api/v1/notifications/:id/read` | POST | `id` | none | notification |
| Messages | `/api/v1/message-conversations` | GET | auth token | `student_id`, `participant_id` | conversation list |
| Messages | `/api/v1/message-conversations` | POST | `participant_ids[]` | `student_id`, `title` | conversation |
| Messages | `/api/v1/messages` | GET | auth token | `conversation_id`, `page`, `page_size` | message list |
| Messages | `/api/v1/messages` | POST | `conversation_id`, `body` | `attachments[]` | message |
| Media | `/api/v1/uploads` | POST | multipart `file` | `folder`, `entity_type`, `entity_id` | `{url, path, metadata}` |
| Media | `/api/v1/event-posts` | GET | auth token | `status`, `event_id` | post list |
| Media | `/api/v1/event-posts` | POST | `title`, `body` | `media_urls[]`, `event_id`, `visibility` | post |
| Parent | `/api/v1/me/students` | GET | auth token | none | linked students |
| Parent | `/api/v1/parents/:parent_user_id/students` | GET | `parent_user_id` | none | linked students |
| Parent | `/api/v1/parents/:parent_user_id/students` | POST | `parent_user_id` | `admission_numbers[]`, `student_ids[]` | link result |
| Reports | `/api/v1/reports/*` | GET/POST | report key | `academic_year_id`, `section_id`, `from_date`, `to_date`, `format` | non-exam report/export payload |

## Implementation Phases
- Phase 1: Freeze API scope and delete Exams/Assistant from the Supabase contract before schema work starts.
- Phase 2: Design Supabase schema for active modules only: auth/profile, school setup, academics, people, attendance, fees, leave, timetable, communication, documents, uploads, approvals, reports.
- Phase 3: Build Edge Function routing for only the approved API table above; removed routes return `404 not_found`.
- Phase 4: Migrate real data into Supabase, excluding Exams and Assistant active tables; generate an archive export for legacy exam/assistant data.
- Phase 5: Update Flutter API clients, generated models, navigation, dashboards, approval center, access-control module lists, and all visible UI to remove Exams and Assistant.
- Phase 6: Remove academic `max_marks` / `pass_marks` from UI, DTOs, CSV import/export, validators, and payload builders.
- Phase 7: Run role-wise end-to-end testing on real migrated data only.

## Test Plan
- API contract tests: every listed endpoint supports required/optional parameters, returns the expected envelope, and enforces auth/RLS.
- Removed API tests: `/api/v1/exams`, `/api/v1/exam-schedules`, `/api/v1/results`, and `/api/v1/assistant/*` return `404 not_found`.
- UI removal tests: no Exams or Assistant routes, menu items, cards, filters, approval types, dashboard widgets, generated labels, or workflow screens remain visible.
- Academics tests: no `max_marks` or `pass_marks` in ClassHub CSV templates, academic payloads, academic responses, or rendered Academics/ClassHub UI.
- Migration tests: all active modules reconcile row counts and foreign keys; Exams and Assistant are present only in archive export, not active Supabase tables.
- No-mock tests: empty backend responses render empty states or errors, never fake/demo records.

## Assumptions
- Exams and Assistant are fully out of scope for the Supabase backend and app UI.
- Legacy Exams/Assistant data should be archived for safety but not migrated into active Supabase.
- Academic subject mappings do not need marks fields anywhere.
- The Flutter app continues using `/api/v1` through the Supabase Edge Function gateway.
