# School ERP Database Table Reference

This file lists the backend database structure in a simple table-by-table format for reference. It is meant for understanding and planning only. It does not change the backend implementation.

## Reading Guide

Each table is documented like this:

| Column | Type | Constraints |
|---|---|---|
| `example_id` | TEXT | FK -> another_table, NOT NULL |

Important link patterns:

| Link Column | Meaning |
|---|---|
| `school_id` | Connects data to one school/tenant. |
| `academic_year_id` | Connects data to one academic session. |
| `term_id` | Connects data to a term inside an academic year. |
| `role_id` | Connects a user/permission to a role. |
| `grade_id` | Connects records to a class/grade level. |
| `section_id` | Connects records to a class section/division. |
| `subject_id` | Connects records to an academic subject. |
| `staff_id` / `teacher_id` | Connects records to staff/teacher. |
| `student_id` | Connects records to a student. |
| `parent_user_id` | Connects records to a parent user account. |

## Class Naming Note

The current backend does not use a main `classes` table. The class concept is represented as:

```text
grades
  -> sections
```

Example:

```text
Grade 10 = grade/class level
Grade 10 A = section/class division
```

So any Principal UI called "Classes" is usually backed by `grades` and `sections`.

---

# Foundation And School Setup

## `schools`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_name` | TEXT | NOT NULL |
| `school_code` | TEXT | UNIQUE |
| `address` | TEXT | |
| `city` | TEXT | |
| `state` | TEXT | |
| `country` | TEXT | DEFAULT India |
| `phone` | TEXT | |
| `email` | TEXT | |
| `website` | TEXT | |
| `logo_url` | TEXT | |
| `affiliation_number` | TEXT | |
| `academic_year_id` | TEXT | FK -> academic_years |
| `is_active` | BOOL | DEFAULT true |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `academic_years`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `year_name` | TEXT | NOT NULL, example: 2025-2026 |
| `start_date` | DATETIME | NOT NULL |
| `end_date` | DATETIME | NOT NULL |
| `is_current` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `terms`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `academic_year_id` | TEXT | FK -> academic_years, NOT NULL |
| `term_name` | TEXT | NOT NULL, example: Term 1 |
| `start_date` | DATETIME | NOT NULL |
| `end_date` | DATETIME | NOT NULL |
| `is_current` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `roles`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `role_name` | TEXT | NOT NULL, example: Admin, Principal, Teacher, Parent |
| `description` | TEXT | |
| `priority` | INT | DEFAULT 0 in docs |
| `is_system_role` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `permissions`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `role_id` | TEXT | FK -> roles, NOT NULL |
| `module` | TEXT | NOT NULL |
| `can_view` / `can_read` | BOOL | DEFAULT false |
| `can_create` | BOOL | DEFAULT false |
| `can_edit` / `can_update` | BOOL | DEFAULT false |
| `can_delete` | BOOL | DEFAULT false |
| `can_approve` / `can_export` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |

## `departments`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `department_name` | TEXT | NOT NULL |
| `description` | TEXT | |
| `head_staff_id` / `hod_staff_id` | TEXT | FK -> staffs |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `rooms`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `room_name` / `room_number` | TEXT | NOT NULL |
| `capacity` | INT | |
| `room_type` | TEXT | classroom/lab/library/office |
| `building` / `block` | TEXT | |
| `floor` | INT | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `grades`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `grade_name` | TEXT | NOT NULL, example: Grade 10 |
| `grade_code` | TEXT | |
| `next_grade_id` | TEXT | FK -> grades, self reference |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `sections`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `grade_id` | TEXT | FK -> grades, NOT NULL |
| `academic_year_id` | TEXT | FK -> academic_years |
| `section_name` | TEXT | NOT NULL, example: A, B |
| `capacity` | INT | |
| `class_teacher_id` | TEXT | FK -> staffs |
| `room_id` | TEXT | FK -> rooms where supported |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `subjects`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `department_id` | TEXT | FK -> departments where supported |
| `subject_name` | TEXT | NOT NULL |
| `subject_code` | TEXT | |
| `subject_type` | TEXT | core/elective/language |
| `is_mandatory` | BOOL | DEFAULT true in docs |
| `credit_hours` | DECIMAL | where supported |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `grade_subjects`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `grade_id` | TEXT | FK -> grades, NOT NULL |
| `subject_id` | TEXT | FK -> subjects, NOT NULL |
| `is_mandatory` | BOOL | DEFAULT true |
| `periods_per_week` | INT | DEFAULT 1 |
| `max_marks` | INT | DEFAULT 100 |
| `pass_marks` | INT | DEFAULT 35 |

## `working_day_configs`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `day_of_week` | INT | NOT NULL |
| `is_working_day` / `is_working` | BOOL | DEFAULT true |
| `start_time` / `school_start_time` | TEXT | |
| `end_time` / `school_end_time` | TEXT | |
| `periods_per_day` | INT | where supported |
| `period_duration_min` | INT | where supported |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `holidays`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `academic_year_id` | TEXT | FK -> academic_years where supported |
| `holiday_name` | TEXT | NOT NULL |
| `holiday_date` / `from_date` | DATE | NOT NULL |
| `to_date` | DATE | where supported |
| `holiday_type` / `type` | TEXT | national/festival/event |
| `is_recurring` | BOOL | DEFAULT false in docs |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

---

# Staff, Users, And Authentication

## `staffs`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `staff_code` | TEXT | UNIQUE per school, NOT NULL |
| `first_name` | TEXT | NOT NULL |
| `last_name` | TEXT | |
| `email` | TEXT | |
| `phone` | TEXT | |
| `date_of_birth` | DATE | |
| `gender` | TEXT | |
| `designation` | TEXT | |
| `employment_type` | TEXT | permanent/contract/temporary |
| `department_id` | TEXT | FK -> departments |
| `join_date` | DATE | |
| `basic_salary` | DECIMAL | |
| `status` | TEXT | active/inactive/pending_approval |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `staff_qualifications`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `staff_id` | TEXT | FK -> staffs, NOT NULL |
| `qualification_name` / `degree` | TEXT | NOT NULL |
| `institution` | TEXT | |
| `year_completed` | INT | |
| `grade_or_percentage` | TEXT | |

## `staff_subjects`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `staff_id` | TEXT | FK -> staffs, NOT NULL |
| `subject_id` | TEXT | FK -> subjects, NOT NULL |
| `grade_id` | TEXT | FK -> grades |
| `section_id` | TEXT | FK -> sections |
| `is_primary` | BOOL | DEFAULT false |

## `staff_documents`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `staff_id` | TEXT | FK -> staffs, NOT NULL |
| `doc_type` | TEXT | profile_photo/certificate/id_proof |
| `file_url` | TEXT | NOT NULL |
| `verified` | BOOL | DEFAULT false |
| `uploaded_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `users`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `name` | TEXT | |
| `username` | TEXT | UNIQUE per school |
| `email` | TEXT | |
| `phone` | TEXT | |
| `password_hash` | TEXT | NOT NULL |
| `role_id` | TEXT | FK -> roles, NOT NULL |
| `role_slug` / `role` | TEXT | role cache/string |
| `linked_type` | TEXT | staff/parent |
| `linked_id` | TEXT | polymorphic FK to staff/parent target |
| `avatar` | TEXT | |
| `is_active` | BOOL | DEFAULT true |
| `is_verified` | BOOL | DEFAULT false |
| `last_login` | DATETIME | |
| `failed_attempts` | INT | DEFAULT 0 where supported |
| `locked_until` | DATETIME | where supported |
| `auth_invalidated_at` | DATETIME | where supported |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `user_sessions`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `user_id` | TEXT | FK -> users, NOT NULL |
| `refresh_token` / `refresh_token_hash` | TEXT | NOT NULL |
| `device_info` | TEXT | |
| `ip_address` | TEXT | |
| `user_agent` | TEXT | where supported |
| `issued_at` | DATETIME | where supported |
| `expires_at` | DATETIME | NOT NULL |
| `is_revoked` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `otp_verifications`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `user_id` | TEXT | FK -> users where supported |
| `identifier` | TEXT | email/phone where supported |
| `email` | TEXT | |
| `phone` | TEXT | |
| `otp_code` / `otp_hash` | TEXT | NOT NULL |
| `purpose` | TEXT | password_reset/email_verify/login |
| `expires_at` | DATETIME | NOT NULL |
| `is_used` | BOOL | DEFAULT false |
| `attempts` | INT | DEFAULT 0 |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `audit_logs`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools where supported |
| `user_id` | TEXT | FK -> users |
| `role` | TEXT | actor role where supported |
| `action` | TEXT | NOT NULL |
| `module` | TEXT | |
| `entity_type` | TEXT | |
| `entity_id` | TEXT | |
| `table_name` | TEXT | where supported |
| `record_id` | TEXT | where supported |
| `old_values` / `old_value` | JSON/TEXT | |
| `new_values` / `new_value` | JSON/TEXT | |
| `ip_address` | TEXT | |
| `user_agent` | TEXT | |
| `created_at` | DATETIME | |

---

# Students And Enrollment

## `students`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `user_id` | TEXT | FK -> users where supported |
| `parent_id` | TEXT | FK -> users/parent where supported |
| `student_code` | TEXT | |
| `admission_number` / `admission_no` | TEXT | UNIQUE per school |
| `roll_number` | TEXT | docs/compat |
| `first_name` | TEXT | NOT NULL |
| `last_name` | TEXT | |
| `date_of_birth` | DATE | |
| `gender` | TEXT | |
| `blood_group` | TEXT | docs/compat |
| `caste_category` | TEXT | where supported |
| `nationality` | TEXT | where supported |
| `admission_date` | DATE | |
| `current_section_id` | TEXT | FK -> sections |
| `aadhar_number` | TEXT | |
| `email` | TEXT | docs/compat |
| `phone` | TEXT | docs/compat |
| `address` | TEXT | |
| `city` | TEXT | docs/compat |
| `state` | TEXT | docs/compat |
| `pincode` | TEXT | docs/compat |
| `profile_photo_url` | TEXT | docs/compat |
| `status` | TEXT | DEFAULT active |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `guardians`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `guardian_name` / `full_name` | TEXT | NOT NULL |
| `relationship` | TEXT | father/mother/guardian |
| `phone` | TEXT | |
| `email` | TEXT | |
| `occupation` | TEXT | |
| `income` / `annual_income` | DECIMAL | |
| `address` | TEXT | docs/compat |
| `is_primary_contact` / `is_primary` | BOOL | DEFAULT false/true depending source |
| `can_pickup` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `medical_records`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `blood_group` | TEXT | docs/compat |
| `conditions` / `medical_conditions` | TEXT | |
| `allergies` | TEXT | |
| `medications` | TEXT | |
| `doctor_name` | TEXT | |
| `doctor_phone` | TEXT | |
| `emergency_contact` | TEXT | docs/compat |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `student_documents`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `doc_type` | TEXT | profile_photo/birth_certificate/etc. |
| `file_url` | TEXT | |
| `verified` | BOOL | DEFAULT false |
| `uploaded_at` | DATETIME | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `enrollments`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `section_id` | TEXT | FK -> sections, NOT NULL |
| `academic_year_id` | TEXT | FK -> academic_years, NOT NULL |
| `roll_number` | TEXT | |
| `enrollment_date` | DATE | |
| `status` | TEXT | DEFAULT active/enrolled |
| `promoted_from_id` | TEXT | FK -> enrollments |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `parent_student_links`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL where supported |
| `parent_user_id` | TEXT | FK -> users, NOT NULL |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `student_admission_number` | TEXT | NOT NULL where supported |
| `relationship` | TEXT | docs/compat |
| `is_primary` | BOOL | DEFAULT false in docs |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `transfer_records`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `transfer_type` | TEXT | NOT NULL where supported |
| `from_school_id` / `from_school` | TEXT | FK -> schools or text school name |
| `to_school_id` / `to_school` | TEXT | FK -> schools or text school name |
| `transfer_date` | DATE | |
| `transfer_cert_number` | TEXT | |
| `last_grade_id` | TEXT | FK -> grades |
| `reason` | TEXT | |
| `tc_document_url` | TEXT | docs/compat |
| `issued_by` | TEXT | FK -> users/staff |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `promotion_rules`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `academic_year_id` | TEXT | FK -> academic_years, NOT NULL |
| `from_grade_id` | TEXT | FK -> grades, NOT NULL |
| `to_grade_id` | TEXT | FK -> grades, NOT NULL |
| `min_attendance_pct` | DECIMAL | |
| `min_pass_percentage` | DECIMAL | |
| `subjects_must_pass` | INT | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

---

# Attendance And Timetable

## `timetable_slots`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `section_id` | TEXT | FK -> sections, NOT NULL |
| `academic_year_id` | TEXT | FK -> academic_years, NOT NULL |
| `term_id` | TEXT | FK -> terms, NOT NULL |
| `day_of_week` | INT | NOT NULL |
| `period_number` | INT | NOT NULL |
| `start_time` | TEXT | HH:MM |
| `end_time` | TEXT | HH:MM |
| `subject_id` | TEXT | FK -> subjects, NOT NULL |
| `staff_id` | TEXT | FK -> staffs, NOT NULL |
| `room_id` | TEXT | FK -> rooms |
| `slot_type` | TEXT | DEFAULT regular |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `substitutions`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `timetable_slot_id` | TEXT | FK -> timetable_slots, NOT NULL |
| `date` | DATE | NOT NULL |
| `original_staff_id` | TEXT | FK -> staffs, NOT NULL |
| `substitute_staff_id` | TEXT | FK -> staffs, NOT NULL |
| `reason` | TEXT | |
| `approved_by` | TEXT | FK -> users/staff |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `attendance_sessions`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `section_id` | TEXT | FK -> sections, NOT NULL |
| `timetable_slot_id` | TEXT | FK -> timetable_slots |
| `subject_id` | TEXT | FK -> subjects, NOT NULL |
| `staff_id` | TEXT | FK -> staffs, NOT NULL |
| `date` | DATE | |
| `period_number` | INT | |
| `total_students` | INT | |
| `present_count` | INT | |
| `is_finalized` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `student_attendances`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `session_id` | TEXT | FK -> attendance_sessions, NOT NULL |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `enrollment_id` | TEXT | FK -> enrollments, NOT NULL |
| `status` | TEXT | present/absent/late/holiday |
| `reason` | TEXT | |
| `marked_at` | DATETIME | |
| `marked_by` | TEXT | FK -> users/staff |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `staff_attendances`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `staff_id` | TEXT | FK -> staffs, NOT NULL |
| `date` | DATE | NOT NULL |
| `check_in` | DATETIME | |
| `check_out` | DATETIME | |
| `status` | TEXT | present/absent/late/half-day |
| `biometric_id` | TEXT | |
| `approved_by` | TEXT | FK -> users/staff |
| `source` | TEXT | DEFAULT manual |
| `marked_by` | TEXT | FK -> users/staff |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `attendance_summaries`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `section_id` | TEXT | FK -> sections, NOT NULL |
| `academic_year_id` | TEXT | FK -> academic_years, NOT NULL |
| `term_id` | TEXT | FK -> terms |
| `total_days` | INT | |
| `present_days` | INT | |
| `absent_days` | INT | |
| `late_count` | INT | |
| `attendance_pct` | DECIMAL | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

---

# Fees And Payments

## `fee_categories`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `category_name` | TEXT | NOT NULL |
| `frequency` | TEXT | NOT NULL |
| `description` | TEXT | docs/compat |
| `is_recurring` | BOOL | docs/compat |
| `is_refundable` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `fee_structures`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `academic_year_id` | TEXT | FK -> academic_years, NOT NULL |
| `grade_id` | TEXT | FK -> grades, NOT NULL |
| `fee_category_id` | TEXT | FK -> fee_categories, NOT NULL |
| `amount` | DECIMAL | NOT NULL |
| `frequency` | TEXT | docs/compat |
| `due_day` | INT | |
| `late_fine_per_day` | DECIMAL | |
| `is_mandatory` | BOOL | DEFAULT true in docs |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `fee_concessions`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `fee_category_id` | TEXT | FK -> fee_categories, NOT NULL |
| `academic_year_id` | TEXT | FK -> academic_years, NOT NULL |
| `concession_type` | TEXT | NOT NULL |
| `value` | DECIMAL | |
| `reason` | TEXT | |
| `approved_by` | TEXT | FK -> users/staff |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `fee_invoices`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `academic_year_id` | TEXT | FK -> academic_years, NOT NULL |
| `invoice_number` | TEXT | UNIQUE |
| `invoice_date` | DATE | |
| `due_date` | DATE | |
| `total_amount` | DECIMAL | |
| `discount_amount` | DECIMAL | |
| `net_amount` | DECIMAL | |
| `paid_amount` | DECIMAL | |
| `balance` | DECIMAL | |
| `status` | TEXT | DEFAULT pending |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `fee_invoice_items`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `invoice_id` | TEXT | FK -> fee_invoices, NOT NULL |
| `fee_category_id` | TEXT | FK -> fee_categories, NOT NULL |
| `amount` | DECIMAL | |
| `description` | TEXT | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `payments`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `invoice_id` | TEXT | FK -> fee_invoices, NOT NULL |
| `receipt_number` | TEXT | UNIQUE |
| `amount_paid` | DECIMAL | |
| `payment_date` | DATE | |
| `payment_mode` | TEXT | NOT NULL |
| `transaction_id` | TEXT | |
| `received_by` | TEXT | FK -> users/staff |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `parent_payment_requests`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `invoice_id` | TEXT | FK -> fee_invoices, NOT NULL |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `parent_user_id` | TEXT | FK -> users, NOT NULL |
| `payment_id` | TEXT | FK -> payments |
| `request_reference` | TEXT | UNIQUE |
| `amount` | DECIMAL | |
| `payment_date` | DATE | |
| `payment_mode` | TEXT | NOT NULL |
| `transaction_id` | TEXT | |
| `status` | TEXT | DEFAULT pending |
| `remarks` | TEXT | |
| `admin_remarks` | TEXT | |
| `decided_by` | TEXT | FK -> users |
| `decided_at` | DATETIME | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

---

# Exams, Marks, And Reports

## `exam_types`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `name` | TEXT | NOT NULL |
| `weightage_percent` | DECIMAL | |
| `is_board_exam` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `exams`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `academic_year_id` | TEXT | FK -> academic_years, NOT NULL |
| `term_id` | TEXT | FK -> terms, NOT NULL |
| `exam_type_id` | TEXT | FK -> exam_types, NOT NULL |
| `exam_name` | TEXT | NOT NULL |
| `start_date` | DATE | NOT NULL |
| `end_date` | DATE | NOT NULL |
| `is_published` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `exam_schedules`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `exam_id` | TEXT | FK -> exams, NOT NULL |
| `grade_id` | TEXT | FK -> grades, NOT NULL |
| `section_id` | TEXT | FK -> sections, NOT NULL |
| `subject_id` | TEXT | FK -> subjects, NOT NULL |
| `exam_date` | DATE | NOT NULL |
| `start_time` | TEXT | HH:MM |
| `end_time` | TEXT | HH:MM |
| `max_marks` | INT | NOT NULL |
| `pass_marks` | INT | NOT NULL |
| `room_id` | TEXT | FK -> rooms |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `student_marks`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `exam_schedule_id` | TEXT | FK -> exam_schedules, NOT NULL |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `enrollment_id` | TEXT | FK -> enrollments, NOT NULL |
| `marks_obtained` | DECIMAL | |
| `grade_label` | TEXT | |
| `is_absent` | BOOL | DEFAULT false |
| `is_exempted` | BOOL | DEFAULT false |
| `entered_by` | TEXT | FK -> users |
| `verified_by` | TEXT | FK -> users |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `grading_scales`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `grade_label` | TEXT | NOT NULL |
| `min_percent` | DECIMAL | |
| `max_percent` | DECIMAL | |
| `gpa_points` | DECIMAL | |
| `description` | TEXT | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `report_cards`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `exam_id` | TEXT | FK -> exams, NOT NULL |
| `enrollment_id` | TEXT | FK -> enrollments, NOT NULL |
| `total_obtained` / `total_marks` | DECIMAL | |
| `percentage` | DECIMAL | |
| `overall_grade` / `grade` | TEXT | |
| `overall_gpa` | DECIMAL | |
| `class_rank` / `rank` | INT | |
| `section_rank` | INT | |
| `remarks` | TEXT | docs/compat |
| `published` | BOOL | DEFAULT false in docs |
| `published_at` / `generated_at` | DATETIME | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

---

# Communication, HR, And Daily Work

## `announcements`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `title` | TEXT | NOT NULL |
| `content` | TEXT | |
| `target_audience` / `target_role` | TEXT | all/teacher/parent/student/admin |
| `target_grade_id` | TEXT | FK -> grades |
| `target_section_id` | TEXT | FK -> sections |
| `is_urgent` | BOOL | DEFAULT false |
| `priority` | TEXT | docs/compat |
| `created_by` / `published_by` | TEXT | FK -> users/staff |
| `published_at` | DATETIME | |
| `expires_at` / `valid_until` | DATETIME | |
| `attachment_url` | TEXT | |
| `is_active` | BOOL | DEFAULT true in docs |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `event_calendars`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `academic_year_id` | TEXT | FK -> academic_years, NOT NULL |
| `event_title` | TEXT | NOT NULL |
| `event_type` | TEXT | NOT NULL |
| `description` | TEXT | |
| `start_datetime` | DATETIME | |
| `end_datetime` | DATETIME | |
| `location` | TEXT | |
| `is_holiday` | BOOL | DEFAULT false |
| `created_by` | TEXT | FK -> users/staff, NOT NULL |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `parent_teacher_meetings`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools in docs/compat |
| `event_id` | TEXT | FK -> event_calendars |
| `section_id` | TEXT | FK -> sections |
| `slot_date` / `scheduled_at` | DATETIME | NOT NULL |
| `slot_time` | TEXT | |
| `duration_min` / `duration_minutes` | INT | |
| `teacher_id` | TEXT | FK -> staffs |
| `guardian_id` | TEXT | FK -> guardians |
| `parent_user_id` | TEXT | FK -> users in docs/compat |
| `student_id` | TEXT | FK -> students |
| `mode` | TEXT | in-person/video/phone in docs |
| `status` | TEXT | scheduled/completed/cancelled |
| `notes` | TEXT | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `homework`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `title` | TEXT | NOT NULL |
| `subject` / `subject_id` | TEXT | subject name or FK -> subjects |
| `class` / `class_name` | TEXT | UI class label |
| `section_id` | TEXT | FK -> sections |
| `teacher_id` | TEXT | FK -> staffs/users |
| `student_id` | TEXT | FK -> students where individual |
| `description` | TEXT | |
| `due_date` / `submission_date` | DATE | |
| `assigned_date` | DATE | docs/compat |
| `max_marks` | INT | |
| `status` | TEXT | DEFAULT pending |
| `created_by` / `assigned_by` | TEXT | FK -> users |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `homework_submissions`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `homework_id` | TEXT | FK -> homework, NOT NULL |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `parent_user_id` | TEXT | FK -> users |
| `answer_text` / `submission_text` | TEXT | |
| `attachment_url` / `file_url` | TEXT | |
| `status` | TEXT | DEFAULT submitted |
| `submitted_at` | DATETIME | |
| `marks_obtained` | DECIMAL | |
| `grade` | TEXT | |
| `feedback` / `remarks` | TEXT | |
| `reviewed_by` / `graded_by` | TEXT | FK -> users |
| `reviewed_at` | DATETIME | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `diary_entries`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `entry_date` / `date` | DATE | |
| `class` / `class_name` | TEXT | UI class label |
| `section_id` | TEXT | FK -> sections |
| `subject` / `subject_id` | TEXT | subject name or FK -> subjects |
| `title` | TEXT | NOT NULL |
| `topic_covered` | TEXT | docs/compat |
| `classwork` | TEXT | |
| `homework` | TEXT | |
| `notes` | TEXT | |
| `schedule` | TEXT | |
| `type` / `entry_type` | TEXT | |
| `teacher_id` | TEXT | FK -> staffs/users |
| `student_id` | TEXT | FK -> students |
| `created_by` | TEXT | FK -> users |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `message_conversations`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `reference_type` | TEXT | |
| `reference_id` | TEXT | |
| `teacher_id` | TEXT | FK -> staffs/users, NOT NULL |
| `parent_id` | TEXT | FK -> users, NOT NULL |
| `student_id` | TEXT | FK -> students |
| `title` | TEXT | |
| `last_message` | TEXT | |
| `last_message_time` | DATETIME | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `messages`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `conversation_id` | TEXT | FK -> message_conversations, NOT NULL |
| `sender_id` | TEXT | FK -> users, NOT NULL |
| `sender_role` | TEXT | NOT NULL |
| `sender_name` | TEXT | |
| `body` | TEXT | NOT NULL |
| `is_read` | BOOL | DEFAULT false |
| `sent_at` | DATETIME | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `notification_logs`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `recipient_user_id` | TEXT | FK -> users, NOT NULL |
| `channel` | TEXT | NOT NULL |
| `title` | TEXT | |
| `body` | TEXT | |
| `category` | TEXT | DEFAULT general |
| `priority` | TEXT | DEFAULT medium |
| `route` | TEXT | |
| `reference_type` | TEXT | |
| `reference_id` | TEXT | |
| `is_read` | BOOL | DEFAULT false |
| `sent_at` | DATETIME | |
| `delivery_status` | TEXT | DEFAULT pending |
| `push_status` | TEXT | DEFAULT pending |
| `push_error` | TEXT | |
| `pushed_at` | DATETIME | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `notification_device_tokens`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `user_id` | TEXT | FK -> users, NOT NULL |
| `platform` | TEXT | android/ios/web |
| `token` | TEXT | NOT NULL, hidden in JSON |
| `token_hash` | TEXT | UNIQUE, NOT NULL |
| `device_id` | TEXT | |
| `app_version` | TEXT | |
| `last_seen_at` | DATETIME | |
| `revoked_at` | DATETIME | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `leave_types`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `leave_name` | TEXT | NOT NULL |
| `max_days_per_year` / `default_days` | INT | |
| `carry_forward_days` | INT | |
| `is_paid` | BOOL | DEFAULT false/true depending source |
| `applicable_to` | TEXT | all/staff/etc. |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `leave_balances`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `staff_id` | TEXT | FK -> staffs, NOT NULL |
| `leave_type_id` | TEXT | FK -> leave_types, NOT NULL |
| `academic_year_id` | TEXT | FK -> academic_years, NOT NULL |
| `total_entitled` / `total_days` | INT | |
| `used_days` | DECIMAL | DEFAULT 0 |
| `pending_days` | DECIMAL | |
| `remaining_days` | DECIMAL | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `leave_applications`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `staff_id` | TEXT | FK -> staffs, NOT NULL |
| `leave_type_id` | TEXT | FK -> leave_types, NOT NULL |
| `from_date` / `start_date` | DATE | NOT NULL |
| `to_date` / `end_date` | DATE | NOT NULL |
| `half_day` | BOOL | DEFAULT false |
| `total_days` | DECIMAL | |
| `reason` | TEXT | |
| `status` | TEXT | pending/approved/rejected/cancelled |
| `applied_at` / `applied_on` | DATETIME | |
| `approved_by` | TEXT | FK -> users/staff |
| `rejection_reason` | TEXT | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `student_leave_applications`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `parent_user_id` | TEXT | FK -> users, NOT NULL |
| `leave_type` | TEXT | NOT NULL |
| `from_date` / `start_date` | DATE | NOT NULL |
| `to_date` / `end_date` | DATE | NOT NULL |
| `half_day` | BOOL | DEFAULT false |
| `total_days` | DECIMAL | |
| `reason` | TEXT | NOT NULL |
| `status` | TEXT | pending/approved/rejected |
| `applied_at` / `applied_on` | DATETIME | |
| `decided_by` / `approved_by` | TEXT | FK -> users |
| `decided_by_role` | TEXT | |
| `decided_at` | DATETIME | |
| `rejection_reason` | TEXT | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `payrolls`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `staff_id` | TEXT | FK -> staffs, NOT NULL |
| `academic_year_id` | TEXT | FK -> academic_years, NOT NULL |
| `month` | INT | NOT NULL |
| `year` | INT | NOT NULL |
| `basic_salary` | DECIMAL | |
| `hra` | DECIMAL | |
| `da` | DECIMAL | |
| `gross_salary` | DECIMAL | |
| `pf_deduction` | DECIMAL | |
| `esi_deduction` | DECIMAL | |
| `tds_deduction` | DECIMAL | |
| `net_salary` | DECIMAL | |
| `payment_date` | DATE | |
| `payment_mode` | TEXT | |
| `status` | TEXT | DEFAULT pending |
| `payslip_url` | TEXT | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

---

# Library And Transport

## `book_categories`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `category_name` | TEXT | NOT NULL |
| `description` | TEXT | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `books`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `category_id` | TEXT | FK -> book_categories, NOT NULL |
| `isbn` | TEXT | |
| `title` | TEXT | NOT NULL |
| `author` | TEXT | |
| `publisher` | TEXT | |
| `edition` | TEXT | |
| `publication_year` | INT | |
| `language` | TEXT | |
| `total_copies` | INT | |
| `available_copies` | INT | |
| `price` | DECIMAL | |
| `location_code` | TEXT | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `book_issues`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `book_id` | TEXT | FK -> books, NOT NULL |
| `borrower_type` | TEXT | student/staff |
| `borrower_id` | TEXT | FK -> students/staffs by borrower_type |
| `issued_date` | DATE | |
| `due_date` | DATE | |
| `return_date` | DATE | |
| `fine_per_day` | DECIMAL | |
| `fine_amount` | DECIMAL | |
| `fine_paid` | BOOL | DEFAULT false |
| `condition_on_return` | TEXT | |
| `issued_by` | TEXT | FK -> users/staff |
| `returned_to` | TEXT | FK -> users/staff |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `vehicles`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `vehicle_number` | TEXT | UNIQUE, NOT NULL |
| `vehicle_type` | TEXT | NOT NULL |
| `capacity` | INT | |
| `make_model` | TEXT | |
| `fuel_type` | TEXT | |
| `fitness_expiry` | TEXT | |
| `insurance_expiry` | TEXT | |
| `driver_name` | TEXT | |
| `driver_phone` | TEXT | |
| `gps_device_id` | TEXT | |
| `status` | TEXT | DEFAULT active |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `routes`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `route_name` | TEXT | NOT NULL |
| `route_code` | TEXT | |
| `vehicle_id` | TEXT | FK -> vehicles |
| `total_distance_km` | DECIMAL | |
| `morning_start_time` | TEXT | |
| `afternoon_start_time` | TEXT | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `route_stops`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `route_id` | TEXT | FK -> routes, NOT NULL |
| `stop_name` | TEXT | NOT NULL |
| `sequence_number` | INT | |
| `pickup_time` | TEXT | |
| `drop_time` | TEXT | |
| `landmark` | TEXT | |
| `latitude` | DECIMAL | |
| `longitude` | DECIMAL | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `student_transports`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK -> students, NOT NULL |
| `academic_year_id` | TEXT | FK -> academic_years, NOT NULL |
| `route_id` | TEXT | FK -> routes, NOT NULL |
| `stop_id` | TEXT | FK -> route_stops, NOT NULL |
| `transport_direction` | TEXT | |
| `fee_amount` | DECIMAL | |
| `is_active` | BOOL | DEFAULT true |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

---

# Reports And Dynamic Records

## `report_exports`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `category` | TEXT | NOT NULL |
| `report_title` | TEXT | NOT NULL |
| `report_type` | TEXT | |
| `format` | TEXT | NOT NULL |
| `scope` | TEXT | |
| `parameters` | TEXT/JSON | |
| `status` | TEXT | DEFAULT pending |
| `artifact_path` | TEXT | |
| `download_url` | TEXT | |
| `error_message` | TEXT | |
| `requested_by` | TEXT | FK -> users, NOT NULL |
| `requested_role` | TEXT | |
| `requested_at` | DATETIME | |
| `completed_at` | DATETIME | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

## `frontend_records`

| Column | Type | Constraints |
|---|---|---|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK -> schools, NOT NULL |
| `resource` / `module` | TEXT | NOT NULL |
| `record_type` | TEXT | docs/compat |
| `payload` / `data` | TEXT/JSON | NOT NULL |
| `created_by` | TEXT | FK -> users |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

---

# Legacy Or Documentation Alias Names

Some older docs and compatibility routes use names that map to newer/current model tables.

| Older/Docs Name | Current/More Specific Name | Note |
|---|---|---|
| `attendance` | `attendance_sessions` + `student_attendances` | Attendance is split into session header and student rows. |
| `fees` | `fee_invoices`, `fee_invoice_items`, `payments` | Fee flow is more detailed in current models. |
| `concessions` | `fee_concessions` | Fee-specific concessions. |
| `notifications` | `notification_logs` | Notification history/log table. |
| `device_tokens` | `notification_device_tokens` | Push device tokens. |
| `leaves` | `leave_applications` | Staff leave applications. |
| `student_leaves` | `student_leave_applications` | Student leave requests. |
| `library_books` | `books` | Current library book table. |
| `library_transactions` | `book_issues` | Book issue/return flow. |
| `transport_routes` | `routes` | Current transport route table. |
| `transport_stops` | `route_stops` | Current transport stop table. |
| `student_transport_mappings` | `student_transports` | Student transport assignment table. |
