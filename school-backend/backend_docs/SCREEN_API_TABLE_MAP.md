# SchoolDesk — Flutter Screen → Backend API → Database Table Map

> **Version:** 1.0
> **Audience:** Developers, architects, QA
> **Purpose:** Trace every Flutter UI screen to the backend endpoints it calls and the database tables those endpoints read/write.

---

## Legend

| Symbol | Meaning |
|--------|---------|
| `GET`   | Read / list |
| `POST`  | Create |
| `PUT` / `PATCH` | Update |
| `DELETE` | Delete |
| `→`    | High-level service method (wraps one or more raw endpoints) |
| `◈`   | Screen also calls NotificationService / BackendDataService |
| `🔹` | Screen uses generic `getRawList` / `createRaw` / `updateRaw` / `deleteRaw` |

---

## Tables.md Root CRUD Endpoints

These endpoints are now the canonical `/api/v1` Flutter contract. Existing specialized screens may still call support endpoints for transactional details, but the root feature endpoint maps to the `Tables.md` table below.

| Feature | Root API Endpoint | Canonical Table | Primary Key | Linked Support Tables |
|---------|-------------------|-----------------|-------------|-----------------------|
| Classes | `GET/POST/PUT/PATCH/DELETE /classes` | `classes` | `class_id` | `grades`, `sections`, `staffs`, `rooms` |
| Attendance | `GET/POST/PUT/PATCH/DELETE /attendance` | `attendance` | `attendance_id` | `attendance_sessions`, `student_attendances`, `staff_attendances` |
| Fees | `GET/POST/PUT/PATCH/DELETE /fees` | `fees` | `fee_id` | `fee_categories`, `fee_invoices`, `fee_invoice_items`, `payments` |
| Exams | `GET/POST/PUT/PATCH/DELETE /exams` | `exams` | `exam_id` | `exam_types`, `exam_schedules`, `student_marks`, `report_cards` |
| Homework | `GET/POST/PUT/PATCH/DELETE /homework` | `homework` | `homework_id` | `homework_submissions`; legacy `homeworks` is backfill-only |
| Leaves | `GET/POST/PUT/PATCH/DELETE /leaves` | `leaves` | `leave_id` | `leave_types`, `leave_applications`, `student_leave_applications` |
| Notifications | `GET/POST/PUT/PATCH/DELETE /notifications` | `notifications` root + per-user `notification_logs` read state | `notification_id` / log `id` | `notification_device_tokens` |
| Holidays | `GET/POST/PUT/PATCH/DELETE /holidays` | `holidays` | `holiday_id` | `academic_years` |
| Events | `GET/POST/PUT/PATCH/DELETE /events` | `events` | `event_id` | legacy `event_calendars` is backfill-only; `parent_teacher_meetings` remains support |
| Approval Requests | `GET/POST/PUT/PATCH/DELETE /approval-requests` | `approval_requests` | `approval_id` | `frontend_records`, account/class/student approvals |
| Communications | `GET/POST/PUT/PATCH/DELETE /communications` | `communications` | `message_id` | `messages`, `message_conversations` |
| Principal Reports | `GET/POST/PUT/PATCH/DELETE /principal-reports` | `principal_reports` | `report_id` | `report_exports` |

---

## Module: Authentication (public)

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 1 | `/onboarding-screen`<br>`/principal-login-screen`<br>`/admin-login-screen`<br>`/teacher-login-screen`<br>`/parent-login-screen` | `auth_login_screen.dart` | `POST /auth/login` | `users`, `roles`, `user_sessions` |
| | | | `POST /auth/logout` | `user_sessions` (delete) |
| | | | `POST /notifications/device-tokens` (register FCM token) | `device_tokens` |
| | | | `DELETE /notifications/device-tokens` (on logout) | `device_tokens` |

---

## Module: Admin Portal

### 2. Admin Overview

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 2 | `/admin-dashboard-screen` | `admin_dashboard_screen.dart` | `GET /dashboard/admin` | Aggregated: `students`, `staffs`, `attendance`, `fees`, `exams`, `homework`, `leaves`, `announcements`, `notifications` |
| | | | `GET /notifications` | `notifications` |

### 3. Admin — Students

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 3a | `/admin-students-screen` | `admin_students_screen.dart` | `GET /students?page=&page_size=` | `students`, `enrollments`, `sections`, `grades` |
| | | | `GET /grades` | `grades` |
| | | | `GET /sections` | `sections` |
| | | | `GET /users?role=parent` | `users` |
| | | | `GET /parents/{id}/students` | `parent_student_links`, `students` |
| | | | `POST /students` | `students` |
| | | | `PUT /students/{id}` | `students` |
| | | | `PUT /students/{id}/parent` | `parent_student_links` |
| | | | `DELETE /students/{id}` | `students` |
| | | | `POST /student-approvals` | `enrollments`, `students` |

### 4. Admin — Teachers / Staff

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 4a | `/admin-teachers-screen` | `staff_management_screen.dart` (ownerRole: admin) | `GET /staff?page=&page_size=` | `staffs` |
| | | | `GET /grades` | `grades` |
| | | | `GET /sections` | `sections` |
| | | | `GET /subjects` | `subjects` |
| | | | `GET /staff-subjects` | `staff_subjects` |
| | | | `GET /users?role=teacher` | `users` |
| | | | `POST /staff` 🔹 | `staffs`, `users` |
| | | | `PUT /staff/{id}` 🔹 | `staffs` |
| | | | `DELETE /staff/{id}` | `staffs` |
| | | | `POST /staff/{id}/photo` | `staff_documents` |
| | | | `POST /staff/{id}/documents` | `staff_documents` |
| | | | 🔹 `POST /staff-subjects` | `staff_subjects` |
| | | | 🔹 `DELETE /staff-subjects/{id}` | `staff_subjects` |
| | | | 🔹 `PUT /sections/{id}` | `sections` |

### 5. Admin — Attendance

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 5 | `/admin-attendance-screen` | `admin_attendance_screen.dart` | `GET /attendance/sessions` | `attendance`, `attendance_sessions` |
| | | | `POST /attendance/sessions` | `attendance_sessions` |
| | | | `POST /attendance/sessions/{id}/mark` | `attendance`, `attendance_sessions` |
| | | | `GET /attendance/summary` | `attendance` |
| | | | `GET /attendance/staff/qr-token` | `staff_attendances` (QR token gen) |
| | | | `POST /attendance/staff/qr-scan` | `staff_attendances` |
| | | | `GET /attendance/staff` | `staff_attendances` |

### 6. Admin — Fees

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 6a | `/admin-fees-screen` | `admin_fees_screen.dart` | `GET /fees/structures` | `fee_structures` |
| | | | `GET /fees/invoices` | `fees` |
| | | | `GET /fees/concessions` | `concessions` |
| | | | `GET /fees/categories` | `fee_categories` |
| | | | `GET /fees/stats` | Aggregated: `fees` |
| | | | `POST /fees/payments` | `fees` (payment) |
| | | | `GET /fees/payment-requests` | `fees` (payment_requests) |
| | | | `PUT /fees/payment-requests/{id}/decision` | `fees` (payment_requests) |
| 6b | `/admin-fees-screen/structures/form` | `admin_fee_form_screens.dart` (FeeStructureForm) | 🔹 `POST /fees/structures` | `fee_structures` |
| | | | 🔹 `PUT /fees/structures/{id}` | `fee_structures` |
| 6c | `/admin-fees-screen/invoices/generate` | `admin_fee_form_screens.dart` (InvoiceGenerationForm) | 🔹 `POST /fees/invoices/generate` | `fees` (bulk insert) |
| | | | 🔹 `POST /fees/invoices` | `fees` (single invoice) |
| 6d | `/admin-fees-screen/payments/record` | `admin_fee_form_screens.dart` (PaymentRecordForm) | 🔹 `POST /fees/payments` | `fees` (payment record) |
| | | | 🔹 `PUT /fees/payments/{id}` | `fees` |
| 6e | `/admin-fees-screen/payment-requests` | `admin_payment_requests_screen.dart` | `GET /fees/payment-requests` | `fees` (payment_requests) |
| 6f | `/admin-fees-screen/payment-requests/decision` | `admin_payment_request_decision_screen.dart` | `PUT /fees/payment-requests/{id}/decision` | `fees` (payment_requests) |

### 7. Admin — Timetable

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 7a | `/admin-timetable-screen` | `admin_timetable_screen.dart` | 🔹 `GET /timetable/slots` | `timetable_slots` |
| | | | `GET /subjects` | `subjects` |
| | | | 🔹 `DELETE /timetable/slots/{id}` | `timetable_slots` |
| 7b | `/admin-timetable-screen/generate` | `admin_timetable_form_screens.dart` (GenerationForm) | `POST /timetable/suggestions` | `timetable_slots` (preview) |
| | | | `POST /timetable/slots/generate` | `timetable_slots` (bulk generate) |
| 7c | `/admin-timetable-screen/period` | `admin_timetable_form_screens.dart` (PeriodForm) | 🔹 `POST /timetable/slots` | `timetable_slots` |
| | | | 🔹 `PUT /timetable/slots/{id}` | `timetable_slots` |
| 7d | `/admin-timetable-screen/substitution` | `admin_timetable_form_screens.dart` (SubstitutionForm) | 🔹 `POST /timetable/substitutions` | `substitutions` |

### 8. Admin — Exams

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 8a | `/admin-exams-screen` | `admin_exams_screen.dart` | `GET /exams` | `exams` |
| | | | 🔹 `GET /exams/schedules` | `exam_schedules` |
| | | | 🔹 `GET /exams/report-cards` | `report_cards` |
| | | | `POST /exams` | `exams` |
| | | | `PUT /exams/{id}` | `exams` |
| | | | `PATCH /exams/{id}/publish` | `exams` (publish_status) |
| | | | 🔹 `POST /exams/types` | `exam_types` |
| 8b | `/admin-exams-screen/form` | `admin_exam_form_screens.dart` (ExamForm) | `GET /exams/types` | `exam_types` |
| | | | `POST /exams` | `exams` |
| | | | `PUT /exams/{id}` | `exams` |
| 8c | `/admin-exams-screen/schedule` | `admin_exam_form_screens.dart` (ScheduleForm) | 🔹 `POST /exams/schedules` | `exam_schedules` |
| | | | 🔹 `GET /exams/marks` | `student_marks` |

### 9. Admin — Communication

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 9 | `/admin-communication-screen` | `admin_communication_screen.dart` | 🔹 `GET /notices` | `notices` |
| | | | `GET /announcements` | `announcements` |
| | | | `POST /announcements` | `announcements` |
| | | | 🔹 `POST /notices` | `notices` |
| | | | 🔹 `DELETE /notices/{id}` | `notices` |

### 10. Admin — Helpdesk

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 10 | `/admin-helpdesk-screen` | `admin_helpdesk_screen.dart` | 🔹 `GET /helpdesk-tickets` | `frontend_records` (or helpdesk) |
| | | | 🔹 `POST /helpdesk-tickets` | `frontend_records` |
| | | | 🔹 `PUT /helpdesk-tickets/{id}` | `frontend_records` |

### 11. Admin — Documents

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 11 | `/admin-documents-screen` | `admin_documents_screen.dart` | 🔹 `GET /documents` | `student_documents`, `staff_documents` |
| | | | 🔹 `POST /documents` | `student_documents`, `staff_documents` |
| | | | 🔹 `PUT /documents/{id}` | `student_documents`, `staff_documents` |
| | | | 🔹 `POST /documents/requests` | `frontend_records` (doc request) |

### 12. Admin — User Access

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 12a | `/admin-user-access-screen` | `admin_user_access_screen.dart` | `GET /users?role=&status=&page=&page_size=` | `users`, `roles` |
| | | | `POST /users` | `users` |
| | | | `PATCH /users/{id}` | `users` |
| | | | `DELETE /users/{id}` | `users` |
| 12b | `/admin-user-access-screen/create`<br>`/admin-user-access-screen/edit` | `account_access_form_screen.dart` | `POST /users` | `users` |
| | | | `PATCH /users/{id}` | `users` |
| | | | `POST /parents/{parentUserId}/students` | `parent_student_links` |
| | | | `POST /staff` (if staff account) | `staffs`, `users` |
| 12c | `/admin-user-access-screen/assign-children` | `account_child_assignment_screen.dart` | `POST /parents/{parentUserId}/students` | `parent_student_links` |

### 13. Admin — Reports & ID Cards

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 13a | `/admin-reports-screen` | `admin_reports_screen.dart` | `GET /report-exports` | `frontend_records` (report exports) |
| | | | `POST /report-exports` | `frontend_records` |
| 13b | `/id-card-generation-screen` | `id_card_generation_screen.dart` | `GET /students` | `students`, `enrollments`, `sections` |
| | | | `GET /schools/current` | `schools` |
| 13c | `/report-card-generator-screen` | `report_card_generator_screen.dart` | `GET /exams` | `exams` |
| | | | `GET /exams/report-cards` | `report_cards` |
| | | | `GET /students` | `students` |

---

## Module: Principal Portal

### 14. Principal — Dashboard

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 14 | `/principal-dashboard-screen` | `principal_dashboard_screen.dart` | `GET /dashboard/principal` | Aggregated: `students`, `staffs`, `attendance`, `fees`, `exams`, `homework`, `leaves`, `notifications` |
| | | | `GET /notifications` | `notifications` |
| | | | `GET /events` | `holidays`, `events` |

### 15. Principal — Staff Oversight

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 15a | `/staff-management-screen` | `staff_management_screen.dart` (ownerRole: principal) | `GET /staff?page=&page_size=` | `staffs` |
| | | | `GET /grades` | `grades` |
| | | | `GET /sections` | `sections` |
| | | | 🔹 `GET /subjects` | `subjects` |
| | | | 🔹 `GET /staff-subjects` | `staff_subjects` |
| | | | `GET /users?role=teacher` | `users` |
| | | | `POST /staff` | `staffs`, `users` |
| | | | `PUT /staff/{id}` | `staffs` |
| | | | `DELETE /staff/{id}` | `staffs` |
| | | | `POST /staff/{id}/photo` | `staff_documents` |
| | | | `POST /staff/{id}/documents` | `staff_documents` |
| | | | 🔹 `POST /staff-subjects` | `staff_subjects` |
| | | | 🔹 `PUT /sections/{id}` | `sections` |
| 15b | `/staff-management-screen/form` | `staff_form_screen.dart` | `POST /staff` | `staffs`, `users` |
| | | | `PUT /staff/{id}` | `staffs` |

### 16. Principal — Student Oversight

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 16 | `/student-oversight-screen` | `student_oversight_screen.dart` | `GET /students?page=&page_size=` | `students`, `enrollments`, `sections` |
| | | | `GET /grades` | `grades` |
| | | | `GET /sections` | `sections` |

### 17. Principal — Approval Center

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 17 | `/approval-center-screen` | `approval_center_screen.dart` | `GET /leave/applications` | `leaves` |
| | | | `GET /student-leave/applications` | `student_leaves` |
| | | | 🔹 `GET /student-approvals` | `frontend_records` (student approvals) |
| | | | 🔹 `GET /class-approvals` | `frontend_records` (class approvals) |
| | | | `PUT /leave/applications/{id}/approve` | `leaves` |
| | | | `PUT /student-leave/applications/{id}/decision` | `student_leaves` |

### 18. Principal — Fee Monitoring

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 18 | `/fee-monitoring-screen` | `fee_monitoring_screen.dart` | `GET /fees/structures` | `fee_structures` |
| | | | `GET /fees/invoices` | `fees` |
| | | | `GET /fees/concessions` | `concessions` |
| | | | `GET /fees/categories` | `fee_categories` |
| | | | `GET /academic-years` | `academic_years` |
| | | | `GET /grades` | `grades` |
| | | | `GET /sections` | `sections` |
| | | | `GET /students` | `students` |
| | | | 🔹 `POST /fees/structures` | `fee_structures` |
| | | | 🔹 `POST /fees/invoices/generate` | `fees` |
| | | | `POST /fees/payments` | `fees` |
| | | | `POST /concessions` | `concessions` |

### 19. Principal — Academics

#### 19a. Timetable

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 19a | `/timetable-management-screen` | `timetable_management_screen.dart` | `GET /timetable/slots` | `timetable_slots` |
| | | | `GET /subjects` | `subjects` |
| | | | `GET /sections` | `sections` |

#### 19b. Syllabus

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 19b | `/syllabus-monitoring-screen` | `syllabus_monitoring_screen.dart` | 🔹 `GET /syllabus` | `frontend_records` (syllabus) |
| | | | 🔹 `POST /syllabus` | `frontend_records` |
| | | | 🔹 `PUT /syllabus/{id}` | `frontend_records` |
| | | | `POST /report-exports` | `frontend_records` |

#### 19c. Exams & Results

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 19c | `/exams-results-screen` | `exams_results_screen.dart` | `GET /exams` | `exams` |
| | | | `GET /exams/schedules` | `exam_schedules` |
| | | | `GET /student-marks` | `student_marks` |
| | | | 🔹 `POST /principal/exam-advice` | `frontend_records` |

### 20. Principal — Communication

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 20a | `/communication-center-screen` | `communication_center_screen.dart` | 🔹 `GET /notices` | `notices` |
| | | | 🔹 `POST /notices` | `notices` |
| | | | 🔹 `DELETE /notices/{id}` | `notices` |
| 20b | `/complaint-management-screen` | `complaint_management_screen.dart` | 🔹 `GET /complaints` | `frontend_records` (complaints) |
| | | | `POST /complaints` | `frontend_records` |
| 20c | `/events-calendar-screen` | `events_calendar_screen.dart` | `GET /events` | `holidays`, `events` |
| | | | `POST /events` | `events` |
| | | | 🔹 `DELETE /events/{id}` | `events` |

### 21. Principal — Reports & Analytics

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 21a | `/reports-analytics-screen` | `reports_analytics_screen.dart` | `GET /report-exports` | `frontend_records` (reports) |
| | | | `POST /report-exports` | `frontend_records` |
| 21b | `/principal-analytics-screen` | `principal_analytics_screen.dart` | `GET /dashboard/principal` | Aggregated |

### 22. Principal — Command Centers

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 22a | `/principal-classes-screen` | `principal_classes_screen.dart` | `GET /principal/classes` | `sections`, `grades`, `staffs` |
| | | | `POST /principal/classes` | `sections` |
| | | | `POST /principal/classes/{id}/instructions` | `frontend_records` (instructions) |
| 22b | `/principal-subjects-screen` | `principal_subjects_screen.dart` | `GET /principal/subjects` | `subjects`, `grade_subjects`, `staff_subjects` |
| | | | 🔹 `GET /subjects` | `subjects` |
| | | | 🔹 `GET /grade-subjects` | `grade_subjects` |
| | | | 🔹 `GET /staff-subjects` | `staff_subjects` |
| | | | 🔹 `POST /subjects` | `subjects` |
| | | | 🔹 `PUT /subjects/{id}` | `subjects` |
| | | | 🔹 `DELETE /subjects/{id}` | `subjects` |
| | | | 🔹 `DELETE /grade-subjects/{id}` | `grade_subjects` |
| | | | 🔹 `DELETE /staff-subjects/{id}` | `staff_subjects` |
| | | | `POST /principal/subjects/{id}/mappings` | `grade_subjects`, `staff_subjects` |
| | | | `POST /principal/subjects/{id}/actions` | `frontend_records` |
| 22c | `/principal-timetable-screen` | `principal_academic_command_screens.dart` (TimetableSection) | `GET /principal/timetable` | `timetable_slots` |
| | | | 🔹 `GET /subjects` | `subjects` |
| | | | 🔹 `POST /timetable/slots` | `timetable_slots` |
| | | | 🔹 `PUT /timetable/slots/{id}` | `timetable_slots` |
| | | | `POST /principal/timetable/actions` | `frontend_records` |
| 22d | `/principal-exams-screen` | `principal_academic_command_screens.dart` (ExamsSection) | `GET /principal/exams` | `exams`, `exam_schedules` |
| | | | 🔹 `GET /subjects` | `subjects` |
| | | | `POST /principal/exams/actions` | `frontend_records` |
| 22e | `/principal-results-screen` | `principal_academic_command_screens.dart` (ResultsSection) | `GET /principal/results` | `student_marks`, `report_cards` |
| | | | `POST /principal/results/actions` | `frontend_records` |

### 23. Principal — Governance

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 23a | `/principal-school-profile-screen` | `school_profile_screen.dart` | `GET /schools/current` | `schools` |
| | | | `PATCH /schools/current` | `schools` |
| | | | `POST /schools/current/logo` | `schools` (logo upload) |
| 23b | `/principal-user-management-screen` | `admin_user_access_screen.dart` (ownerRole: principal) | Same as admin user access (see 12a) | `users`, `roles` |
| 23c | `/guardian-directory-screen` | `guardian_directory_screen.dart` | 🔹 `GET /guardians` | `guardians` |
| | | | 🔹 `POST /guardians` | `guardians` |
| | | | 🔹 `PUT /guardians/{id}` | `guardians` |
| | | | 🔹 `DELETE /guardians/{id}` | `guardians` |

### 24. Principal — Academic Info

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 24 | `/principal-academic-info-screen` | `academic_info_screen.dart` (role: principal) | `GET /academic-years` | `academic_years` |
| | | | `GET /grades` | `grades` |
| | | | `GET /sections` | `sections` |
| | | | `GET /subjects` | `subjects` |
| | | | `GET /departments` | `departments` |

### 25. Principal — Attendance

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 25 | `/principal-attendance-screen` | `principal_attendance_screen.dart` | `GET /attendance/sessions` | `attendance_sessions`, `attendance` |
| | | | `GET /attendance/summary` | `attendance` |
| | | | `GET /attendance/staff` | `staff_attendances` |

---

## Module: Teacher Portal

### 26. Teacher — Dashboard

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 26 | `/teacher-dashboard-screen` | `teacher_dashboard_screen.dart` | `GET /dashboard/teacher` | Aggregated: attendance, classes, homework, timetable |
| | | | `GET /notifications` | `notifications` |
| | | | `GET /attendance/staff/me/today` | `staff_attendances` |

### 27. Teacher — My Classes

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 27 | `/teacher-classes-screen` | `teacher_classes_screen.dart` | `GET /sections?staff_id=` | `sections` |
| | | | `GET /timetable/slots?staff_id=` | `timetable_slots` |
| | | | `GET /students?section_id=` | `students`, `enrollments` |

### 28. Teacher — Attendance

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 28a | `/teacher-attendance-screen` | `teacher_attendance_screen.dart` | `GET /attendance/sessions?section_id=&date=` | `attendance_sessions` |
| | | | `POST /attendance/sessions` | `attendance_sessions` |
| | | | `POST /attendance/sessions/{id}/mark` | `attendance` |
| 28b | `/teacher-my-attendance-screen` | `teacher_my_attendance_screen.dart` | `GET /attendance/staff/me/today` | `staff_attendances` |
| | | | `POST /attendance/staff/qr-scan` | `staff_attendances` |

### 29. Teacher — Homework

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 29a | `/teacher-homework-screen` | `teacher_homework_screen.dart` | 🔹 `GET /homework` | `homework` |
| | | | 🔹 `DELETE /homework/{id}` | `homework` |
| 29b | `/teacher-homework-screen/form` | `teacher_homework_form_screens.dart` | 🔹 `POST /homework` | `homework` |
| | | | 🔹 `PUT /homework/{id}` | `homework` |
| 29c | `/teacher-homework-screen/submissions` | `teacher_homework_form_screens.dart` (Submissions) | 🔹 `GET /homework/{id}/submissions` | `homework_submissions` |
| | | | 🔹 `PUT /homework/{id}/submissions/{id}/review` | `homework_submissions` |

### 30. Teacher — Academics

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 30a | Teacher Lesson Planner | retired from current product scope | Not exposed | Historical screen source only |
| 30b | `/teacher-performance-screen` | `teacher_performance_screen.dart` | 🔹 `GET /student-marks` | `student_marks` |
| | | | 🔹 `POST /student-notes` | `frontend_records` (notes) |
| 30c | `/teacher-student-notes-screen` | `teacher_student_notes_screen.dart` | 🔹 `GET /student-notes` | `frontend_records` |
| | | | 🔹 `POST /student-notes` | `frontend_records` |
| | | | 🔹 `DELETE /student-notes/{id}` | `frontend_records` |
| 30d | Teacher Resources | retired from current product scope | Not exposed | Historical screen source only |
| 30e | `/teacher-diary-screen` | `teacher_diary_screen.dart` | 🔹 `GET /diary-entries` | `frontend_records` (diary) |
| | | | 🔹 `POST /diary-entries` | `frontend_records` |
| | | | 🔹 `PUT /diary-entries/{id}` | `frontend_records` |
| | | | 🔹 `DELETE /diary-entries/{id}` | `frontend_records` |

### 31. Teacher — Communication

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 31a | `/teacher-communication-screen` | `teacher_communication_screen.dart` | 🔹 `GET /message-conversations` | `messages` (conversations) |
| | | | 🔹 `GET /messages` | `messages` |
| | | | 🔹 `POST /messages` | `messages` |
| | | | 🔹 `PUT /messages/{id}` | `messages` (read status) |
| 31b | `/teacher-parent-interaction-screen` | `teacher_parent_interaction_screen.dart` | 🔹 `GET /parent-teacher-meetings` | `parent_teacher_meetings` |
| | | | 🔹 `POST /parent-teacher-meetings` | `parent_teacher_meetings` |

### 32. Teacher — Leave & Management

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 32a | `/teacher-leave-screen` | `teacher_leave_screen.dart` | `GET /leave/applications?staff_id=` | `leaves` |
| | | | 🔹 `GET /leave/types` | `leave_types` |
| | | | 🔹 `GET /leave/balances` | `leave_balances` |
| 32b | `/teacher-leave-screen/request` | `teacher_leave_request_form_screen.dart` | `POST /leave/applications` | `leaves` |
| 32c | `/teacher-discipline-screen` | `teacher_discipline_screen.dart` | 🔹 `GET /discipline-incidents` | `frontend_records` (discipline) |
| | | | 🔹 `POST /discipline-incidents` | `frontend_records` |
| | | | 🔹 `PUT /discipline-incidents/{id}` | `frontend_records` |
| | | | 🔹 `POST /complaints` | `frontend_records` |
| 32d | `/teacher-reports-screen` | `teacher_reports_screen.dart` | `GET /attendance/sessions` | `attendance_sessions` |
| | | | 🔹 `POST /report-exports` | `frontend_records` |

### 33. Teacher — Academic Info

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 33 | `/teacher-academic-info-screen` | `academic_info_screen.dart` (role: teacher) | Same as principal academic info (see 24) | `academic_years`, `grades`, `sections`, `subjects` |

---

## Module: Parent Portal

### 34. Parent — Dashboard

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 34 | `/parent-dashboard-screen` | `parent_dashboard_screen.dart` | `GET /dashboard/parent` | Aggregated per linked children |
| | | | `GET /me/students` | `parent_student_links`, `students` |
| | | | `GET /notifications` | `notifications` |

### 35. Parent — Child Academics

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 35a | `/parent-academic-progress-screen` | `parent_academic_progress_screen.dart` | `GET /me/students` | `students` (linked) |
| | | | 🔹 `GET /students/{id}/marks` | `student_marks` |
| | | | 🔹 `GET /exams/report-cards?student_id=` | `report_cards` |
| | | | 🔹 `GET /diary-entries?student_id=` | `frontend_records` (diary) |
| | | | `POST /report-exports` | `frontend_records` |
| 35b | `/parent-attendance-screen` | `parent_attendance_screen.dart` | `GET /me/students` | `students` (linked) |
| | | | `GET /students/{id}/attendance` | `attendance` |
| | | | `GET /attendance/summary?student_id=` | `attendance` |
| 35c | `/parent-homework-screen` | `parent_homework_screen.dart` | `GET /me/students` | `students` (linked) |
| | | | `GET /homework?student_id=` | `homework` |
| | | | `GET /homework/{id}/submissions` | `homework_submissions` |
| | | | 🔹 `POST /homework/{id}/submissions` | `homework_submissions` |
| 35d | `/parent-homework-screen/submit` | `parent_homework_submission_screen.dart` | `POST /homework/{id}/submissions` | `homework_submissions` |
| 35e | `/parent-diary-screen` | `parent_diary_screen.dart` | `GET /me/students` | `students` (linked) |
| | | | 🔹 `GET /diary-entries?student_id=` | `frontend_records` (diary) |
| | | | 🔹 `POST /diary-entries` | `frontend_records` |

### 36. Parent — Communication

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 36a | `/parent-notices-screen` | `parent_notices_screen.dart` | `GET /announcements` | `announcements` |
| | | | 🔹 `GET /notice-acknowledgements` | `frontend_records` |
| | | | 🔹 `POST /notice-acknowledgements` | `frontend_records` |
| 36b | `/parent-teacher-chat-screen` | `parent_teacher_chat_screen.dart` | 🔹 `GET /message-conversations` | `messages` |
| | | | 🔹 `GET /messages` | `messages` |
| | | | 🔹 `GET /parent-teacher-meetings` | `parent_teacher_meetings` |
| | | | 🔹 `POST /messages` | `messages` |
| | | | 🔹 `PUT /messages/{id}` | `messages` |
| | | | 🔹 `POST /message-conversations` | `messages` (conversations) |

### 37. Parent — Finance

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 37a | `/parent-fees-screen` | `parent_fees_screen.dart` | `GET /me/students` | `students` (linked) |
| | | | `GET /fees/invoices?student_id=` | `fees` |
| | | | `GET /fees/payment-requests?student_id=` | `fees` (payment_requests) |
| 37b | `/parent-fees-screen/payment` | `parent_payment_request_form_screen.dart` | `POST /fees/payment-requests` | `fees` (payment_requests) |
| 37c | `/fee-payment-receipt-screen` | `fee_payment_receipt_screen.dart` | `GET /me/students` | `students` |
| | | | `GET /fees/invoices` | `fees` |

### 38. Parent — Leave

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 38a | `/parent-leave-screen` | `parent_leave_screen.dart` | `GET /me/students` | `students` (linked) |
| | | | `GET /student-leave/applications` | `student_leaves` |
| 38b | `/parent-leave-screen/request` | `parent_leave_request_form_screen.dart` | `POST /student-leave/applications` | `student_leaves` |

### 39. Parent — School & Docs

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 39a | `/parent-calendar-screen` | `parent_calendar_screen.dart` | `GET /events` | `events`, `holidays` |
| | | | 🔹 `GET /parent-teacher-meetings` | `parent_teacher_meetings` |
| 39b | `/parent-documents-screen` | `parent_documents_screen.dart` | 🔹 `GET /student-documents` | `student_documents` |
| 39c | `/parent-academic-info-screen` | `academic_info_screen.dart` (role: parent) | `GET /academic-years` | `academic_years` |
| | | | `GET /grades` | `grades` |
| | | | `GET /subjects` | `subjects` |

---

## Module: Shared / Cross-Cutting Screens

### 40. Academics Management

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 40a | `/academic-management-screen` | `academic_management_screen.dart` | `GET /academic-years` | `academic_years` |
| | | | `GET /grades` | `grades` |
| | | | `GET /sections` | `sections` |
| | | | `GET /subjects` | `subjects` |
| 40b | `/academic-management-screen/year` | `academic_management_form_screens.dart` | `POST /academic-years` | `academic_years` |
| | | | `PUT /academic-years/{id}` | `academic_years` |
| | | | 🔹 `DELETE /academic-years/{id}` | `academic_years` |
| 40c | `/academic-management-screen/subject` | `academic_management_form_screens.dart` | 🔹 `POST /subjects` | `subjects` |
| | | | 🔹 `PUT /subjects/{id}` | `subjects` |
| | | | 🔹 `DELETE /subjects/{id}` | `subjects` |
| 40d | `/academic-management-screen/class` | `academic_management_form_screens.dart` | 🔹 `POST /grades` | `grades` |
| | | | 🔹 `POST /sections` | `sections` |
| | | | 🔹 `PUT /sections/{id}` | `sections` |
| | | | 🔹 `DELETE /sections/{id}` | `sections` |
| | | | 🔹 `DELETE /grades/{id}` | `grades` |
| 40e | `/academic-management-screen/curriculum` | `academic_management_form_screens.dart` | 🔹 `POST /curriculum` | `frontend_records` (curriculum) |
| | | | 🔹 `PUT /curriculum/{id}` | `frontend_records` |
| | | | 🔹 `DELETE /curriculum/{id}` | `frontend_records` |

### 41. Shared Tools

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 41a | `/notification-center-screen` | `notification_center_screen.dart` | `GET /notifications` | `notifications` |
| | | | `PUT /notifications/{id}/read` | `notifications` |
| 41b | `/settings-screen` | `settings_screen.dart` | `POST /auth/password` | `users` (password hash) |
| | | | `PATCH /auth/profile` | `users` |
| 41c | `/profile-screen` | `profile_management_screen.dart` | `GET /auth/profile` | `users` |
| | | | `PATCH /auth/profile` | `users` |
| | | | `POST /auth/profile/avatar` | `users` (avatar) |
| 41d | `/global-search-screen` | `global_search_screen.dart` | 🔹 `GET /students?q=` (name/admission search) | `students` |
| | | | 🔹 `GET /staff?q=` | `staffs` |
| | | | 🔹 `GET /users?q=` | `users` |
| | | | 🔹 `GET /subjects?q=` | `subjects` |
| 41e | `/homework-messaging-screen` | `homework_messaging_screen.dart` | 🔹 `GET /message-conversations` | `messages` |
| | | | 🔹 `GET /messages` | `messages` |
| | | | 🔹 `POST /messages` | `messages` |
| | | | 🔹 `PUT /message-conversations/{id}` | `messages` |
| | | | 🔹 `POST /message-conversations` | `messages` |

### 42. Public Landing

| # | Route | Screen File | API Endpoints Called | Database Tables |
|---|-------|------------|---------------------|----------------|
| 42 | `/landing-page-screen` | `landing_page_screen.dart` | None (static / promotional) | — |

---

## 43. API Service Layer — BackendDataService

The `BackendDataService` (`lib/services/backend_data_service.dart`) serves as a caching / orchestration layer for dashboard widgets. It connects to the same raw endpoints:

| Cache Method | API Endpoint Called | Database Tables |
|-------------|-------------------|----------------|
| `getTeachers()` | `GET /staff?page=1&page_size=100` | `staffs` |
| `getStudents()` | `GET /students?page=1&page_size=100` | `students` |
| `getAttendanceSummary(studentId)` | `GET /attendance/summary?student_id=` | `attendance` |
| `getAcademicYears()` | `GET /academic-years` | `academic_years` |
| `getSubjects()` | 🔹 `GET /subjects` | `subjects` |
| `getGrades()` | `GET /grades` | `grades` |
| `getSections()` | `GET /sections` | `sections` |
| `getFeeStructures()` | `GET /fees/structures` | `fee_structures` |
| `getInvoices()` | `GET /fees/invoices` | `fees` |
| `getNotifications()` | `GET /notifications` | `notifications` |
| `getAnnouncements()` | `GET /announcements` | `announcements` |
| `getEvents()` | `GET /events` | `events` |
| `getTimetableSlots()` | `GET /timetable/slots` | `timetable_slots` |
| `getHomework()` | 🔹 `GET /homework` | `homework` |
| `getDiaryEntries()` | 🔹 `GET /diary-entries` | `frontend_records` |
| `getParentTeacherMeetings()` | 🔹 `GET /parent-teacher-meetings` | `parent_teacher_meetings` |
| `getLeaveApplications()` | `GET /leave/applications` | `leaves` |
| `getComplaints()` | 🔹 `GET /complaints` | `frontend_records` |

---

## Domain-Service Screens (ApiService-based)

Some screens use the lean `ApiService` wrapper instead of `BackendApiClient` directly:

| Screen | Service | Endpoints Called | Tables |
|--------|---------|-----------------|--------|
| `auth_login_screen.dart` | `AuthService` | `POST /auth/login`, `GET /auth/me`, `POST /auth/logout` | `users`, `user_sessions` |
| `guardian_directory_screen.dart` | Uses `api.` instance | 🔹 `GET /guardians`, `POST /guardians`, `PUT /guardians`, `DELETE /guardians` | `guardians` |
| `parent_calendar_screen.dart` | Uses `api.` instance | 🔹 `GET /parent-teacher-meetings`, `GET /events` | `parent_teacher_meetings`, `events` |
| `parent_teacher_chat_screen.dart` | Uses `api.` instance | 🔹 `GET /messages`, `POST /messages`, `PUT /messages/{id}` | `messages` |
| `admin_exams_screen.dart` | Uses `api.` instance | 🔹 `GET /exams/schedules`, `GET /exams/report-cards`, `GET /subjects` | `exam_schedules`, `report_cards`, `subjects` |
| `admin_timetable_screen.dart` | Uses `api.` instance | 🔹 `GET /subjects` | `subjects` |
| `communication_center_screen.dart` | Uses `api.` instance | 🔹 `GET /notices`, `POST /notices`, `DELETE /notices/{id}` | `notices` |
| `messaging_service.dart` | Uses `api.` instance | 🔹 `GET /message-conversations`, `GET /messages`, `POST /messages`, `PUT /messages/{id}`, `POST /message-conversations` | `messages` |

---

## Navigation Widgets API Usage

| Widget | API Endpoint Called | Database Tables |
|--------|-------------------|----------------|
| `app_navigation.dart` | `GET /notifications` (unread count) | `notifications` |
| `admin_navigation.dart` | `GET /notifications` (unread count) | `notifications` |
| `parent_navigation.dart` | `GET /notifications` (unread count) | `notifications` |
| `teacher_navigation.dart` | `GET /notifications` (unread count), `GET /schools/current` | `notifications`, `schools` |
| `erp_module_scaffold.dart` | `GET /notifications` (unread count) | `notifications` |

---

## Auth API-to-DB Flow Summary

| Flow Step | Endpoint | Tables (Read) | Tables (Write) |
|-----------|----------|--------------|---------------|
| Login | `POST /auth/login` | `users`, `roles` | `user_sessions` |
| Token Refresh | `POST /auth/refresh` | `user_sessions` | `user_sessions` |
| Logout | `POST /auth/logout` | — | `user_sessions` (delete) |
| Get Profile | `GET /auth/profile` | `users` | — |
| Update Profile | `PATCH /auth/profile` | — | `users` |
| Change Password | `POST /auth/password` | `users` | `users` (hash) |
| Register Device | `POST /notifications/device-tokens` | — | `device_tokens` |

---

## Key Observations

### 1. API Surface Summary
- **~170 unique endpoint paths** used across ~70 Flutter screens
- **60+ database tables** mapped via the backend GORM models
- **3 API client layers**: `BackendApiClient` (primary), `ApiService` (service wrapper), `BackendDataService` (caching orchestration)

### 2. Most-Referenced Endpoints
| Endpoint | Used By (# of Screens) |
|----------|----------------------|
| `GET /students` | 8+ screens (admin, principal, teacher, parent) |
| `GET /fees/invoices` | 7 screens (admin, principal, parent, fee forms) |
| `GET /notifications` | 8 screens (all navigation widgets + notification center) |
| `GET /attendance/sessions` | 5 screens (admin, principal, teacher) |
| `GET /sections` | 6 screens (admin, principal, teacher, academic mgmt) |

### 3. Most-Accessed Tables
| Table | Accessed By (# of Endpoints) |
|-------|-----------------------------|
| `students` | 30+ endpoints (CRUD, attendance, fees, marks, enrollments) |
| `fees` | 15+ endpoints (invoices, payments, concessions, payment_requests) |
| `attendance` | 10+ endpoints (sessions, marking, summary, reports) |
| `users` | 15+ endpoints (auth, profile, user management) |
| `staffs` | 12+ endpoints (CRUD, photo, documents, subjects, attendance) |
| `frontend_records` | 10+ endpoints (syllabus, diary, complaints, discipline, curriculum, approvals) |

### 4. Data Patterns
- **Parent screens** use `GET /me/students` as a gateway to get linked children, then call per-student endpoints
- **Teacher screens** are filtered by staff_id (extracted from JWT)
- **Admin screens** have full CRUD access to most entities
- **Principal screens** overlap with admin but with a governance/oversight focus
- **Dynamic records** (syllabus, diary, complaints, discipline) are stored as JSON in `frontend_records` via generic CRUD helpers (`getRawList`, `createRaw`, `updateRaw`, `deleteRaw`)
- **Notifications** are polled across all navigation widgets for unread badge counts

---

## Appendix: Cross-Reference Index

| Screen Count | Module | Routes |
|-------------|--------|--------|
| 7 | Admin | 2–13 |
| 22 | Principal | 14–25 |
| 14 | Teacher | 26–33 |
| 14 | Parent | 34–39 |
| 8 | Shared | 40–41 |
| 1 | Public | 42 |

**Total: ~66 active screen routes** mapped across the full stack.
