# SchoolDesk Backend — Comprehensive Documentation

> **Generated:** May 2026
> **Stack:** Go 1.22+, Gin Web Framework, GORM ORM, PostgreSQL / SQLite
> **Project Root:** `school-backend/`

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Database Engine & ORM Setup](#2-database-engine--orm-setup)
3. [Complete Table Inventory & Schema](#3-complete-table-inventory--schema)
4. [Entity Relationship Diagram (ERD)](#4-entity-relationship-diagram-erd)
5. [Foreign Key Constraints](#5-foreign-key-constraints)
6. [Unique Indexes & Integrity Probes](#6-unique-indexes--integrity-probes)
7. [API Endpoint Registry](#7-api-endpoint-registry)
8. [API-to-DB Integration Matrix](#8-api-to-db-integration-matrix)
9. [Auth & RBAC System](#9-auth--rbac-system)
10. [Middleware Pipeline](#10-middleware-pipeline)
11. [Configuration & Environment Variables](#11-configuration--environment-variables)
12. [Deployment Guide](#12-deployment-guide)
13. [Services Layer](#13-services-layer)
14. [Testing Strategy](#14-testing-strategy)

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                     Client (Flutter)                 │
│              (Web / Mobile / Desktop)                │
└──────────────────┬──────────────────────────────────┘
                   │ HTTPS / REST JSON
                   ▼
┌─────────────────────────────────────────────────────┐
│                  Gin HTTP Router                      │
│              (school-backend/main.go)                 │
├─────────────────────────────────────────────────────┤
│  ┌─────────────┐ ┌──────────┐ ┌──────────────────┐  │
│  │  Middleware  │ │ Handlers │ │    Services      │  │
│  │  Pipeline   │ │ (23 pkg) │ │ (6 modules)      │  │
│  └──────┬──────┘ └────┬─────┘ └───────┬──────────┘  │
│         │             │               │              │
│  ┌──────┴─────────────▼───────────────▼──────────┐   │
│  │           GORM ORM Layer                      │   │
│  │        (AutoMigrate / Queries)               │   │
│  └─────────────────────┬─────────────────────────┘   │
│                        │                              │
│  ┌─────────────────────▼─────────────────────────┐   │
│  │              Database (PostgreSQL/SQLite)      │   │
│  │              ~60 tables, 30+ FK constraints   │   │
│  └───────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### Key Technologies

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Language** | Go 1.22+ | Backend runtime |
| **HTTP Framework** | Gin v1.10+ | Routing, middleware, request handling |
| **ORM** | GORM v1.25.10 | Database abstraction, migrations |
| **PostgreSQL Driver** | `gorm.io/driver/postgres` | Production DB |
| **SQLite Driver** | `github.com/glebarez/sqlite` | Dev/Test DB |
| **JWT Auth** | `github.com/golang-jwt/jwt/v5` | Token-based auth |
| **Password Hashing** | `golang.org/x/crypto/bcrypt` | Password security |
| **UUID** | `github.com/google/uuid` | ID generation |

---

## 2. Database Engine & ORM Setup

### 2.1 Database Selection Logic (`internal/config/config.go` + `internal/database/database.go`)

```go
// Production: DATABASE_URL environment variable
if strings.HasPrefix(cfg.DatabaseURL, "postgres://") ||
   strings.HasPrefix(cfg.DatabaseURL, "postgresql://") {
    // → GORM PostgreSQL driver
} else {
    // → SQLite (default: school.db file)
}
```

### 2.2 Connection Pool Configuration

```go
sqlDB, _ := db.DB()
sqlDB.SetMaxOpenConns(25)      // Max concurrent connections
sqlDB.SetMaxIdleConns(5)       // Max idle connections
sqlDB.SetConnMaxLifetime(5 * time.Minute)  // Connection reuse limit
```

### 2.3 Migration Phases

Migrations run in **3 ordered phases** via `AutoMigrate` to respect dependency order:

| Phase | Tables Migrated | Rationale |
|-------|----------------|-----------|
| **Phase 1** | Foundation tables (schools, grades, subjects, roles, etc.) | No FK dependencies |
| **Phase 2** | Staff, Students, Users, Auth tables | Depend on Phase 1 |
| **Phase 3** | Operational tables (attendance, fees, exams, timetable, etc.) | Depend on Phases 1 & 2 |

### 2.4 Tables.md Source-of-Truth Migration

`Tables.md` is now implemented as the canonical schema for the ERP feature tables below. The migration is idempotent: if a table is missing it is created with the `Tables.md` primary key, and if a legacy table already exists the required `Tables.md` columns are added without dropping legacy columns. This keeps existing screens working while the new root CRUD endpoints use the exact `Tables.md` field names.

Legacy normalized/support tables remain where the app still needs them, especially `schools`, `academic_years`, `users`, `students`, `staffs`, `subjects`, `sections`, `rooms`, `roles`, `permissions`, `fee_categories`, and `leave_types`.

| Tables.md Table | Primary Key | CRUD Endpoint | Legacy/Support Data Still Used |
|-----------------|-------------|---------------|--------------------------------|
| `classes` | `class_id` | `/api/v1/classes` | `grades`, `sections`, `rooms`, `staffs` |
| `attendance` | `attendance_id` | `/api/v1/attendance` | `attendance_sessions`, `student_attendances`, `staff_attendances` |
| `fees` | `fee_id` | `/api/v1/fees` | `fee_invoices`, `fee_invoice_items`, `payments`, `fee_categories` |
| `exams` | `exam_id` | `/api/v1/exams` | `exam_types`, `exam_schedules`, `student_marks`, `report_cards` |
| `homework` | `homework_id` | `/api/v1/homework` | `homework_submissions`; legacy `homeworks` is startup backfill-only |
| `leaves` | `leave_id` | `/api/v1/leaves` | `leave_applications`, `student_leave_applications`, `leave_types` |
| `notifications` | `notification_id` | `/api/v1/notifications` | `notification_logs` carries per-user list/read state; `notification_device_tokens` |
| `holidays` | `holiday_id` | `/api/v1/holidays` | academic-year holiday references |
| `events` | `event_id` | `/api/v1/events` | legacy `event_calendars` is startup backfill-only; `parent_teacher_meetings` |
| `approval_requests` | `approval_id` | `/api/v1/approval-requests` | `frontend_records`, account/class/student approvals |
| `communications` | `message_id` | `/api/v1/communications` | `message_conversations`, `messages` |
| `principal_reports` | `report_id` | `/api/v1/principal-reports` | `report_exports` |

Role scope on these tables:

| Role | Access Pattern |
|------|----------------|
| Admin | Full CRUD on school-scoped ERP tables |
| Principal | Full CRUD on school-scoped ERP tables |
| Teacher | Scoped access to attendance, homework, exams, leaves, notifications, communications |
| Parent | Linked-student access to fees, leaves, notifications, communications |

Every new table is tenant-scoped with `school_id` where the table contains that column. Handlers override client-sent `school_id` with the JWT school scope.

### 2.5 Canonical Tables.md Schemas

#### `classes`
| Column | Type | Constraints |
|--------|------|-------------|
| `class_id` | TEXT | PK |
| `school_id` | TEXT | JWT-scoped |
| `academic_year_id` | TEXT | FK → academic_years |
| `class_name` | TEXT | Required |
| `class_code` | TEXT | |
| `section_id` | TEXT | FK → sections |
| `class_teacher_id` | TEXT | FK → staffs |
| `room_id` | TEXT | FK → rooms |
| `medium` | TEXT | |
| `sort_order` | INT | |
| `is_active` | BOOL | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `attendance`
| Column | Type | Constraints |
|--------|------|-------------|
| `attendance_id` | TEXT | PK |
| `school_id` | TEXT | JWT-scoped |
| `academic_year_id` | TEXT | FK → academic_years |
| `attendance_type` | TEXT | student/staff |
| `student_id` | TEXT | FK → students |
| `staff_id` | TEXT | FK → staffs |
| `class_id` | TEXT | FK → classes |
| `section_id` | TEXT | FK → sections |
| `attendance_date` | DATE | Required |
| `status` | TEXT | Required |
| `check_in_time` | TIME/TEXT | |
| `check_out_time` | TIME/TEXT | |
| `remarks` | TEXT | |
| `marked_by` | TEXT | FK → users/staffs |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### Tables With Exact Primary Keys
| Table | Primary Key | Main Columns |
|-------|-------------|--------------|
| `fees` | `fee_id` | `school_id`, `academic_year_id`, `student_id`, `class_id`, `section_id`, `fee_type_id`, `invoice_no`, `receipt_no`, `due_date`, `amount`, `discount_amount`, `fine_amount`, `paid_amount`, `balance_amount`, `payment_mode`, `payment_status`, `transaction_id`, `remarks`, `created_at`, `updated_at` |
| `exams` | `exam_id` | `school_id`, `academic_year_id`, `exam_name`, `exam_type`, `class_id`, `section_id`, `subject_id`, `exam_date`, `start_time`, `end_time`, `max_marks`, `pass_marks`, `exam_room`, `invigilator_id`, `status`, `created_at`, `updated_at` |
| `homework` | `homework_id` | `school_id`, `academic_year_id`, `class_id`, `section_id`, `subject_id`, `staff_id`, `title`, `description`, `assigned_date`, `submission_date`, `attachment_url`, `submission_mode`, `status`, `created_at`, `updated_at` |
| `leaves` | `leave_id` | `school_id`, `user_type`, `student_id`, `staff_id`, `leave_type_id`, `from_date`, `to_date`, `total_days`, `reason`, `document_url`, `approval_status`, `approved_by`, `approved_at`, `remarks`, `created_at`, `updated_at` |
| `notifications` | `notification_id` | `school_id`, `title`, `message`, `notification_type`, `target_role`, `target_user_id`, `priority`, `delivery_mode`, `is_read`, `read_at`, `sent_by`, `sent_at`, `expiry_date`, `created_at`, `updated_at` |
| `holidays` | `holiday_id` | `school_id`, `holiday_name`, `holiday_type`, `start_date`, `end_date`, `description`, `is_optional`, `applicable_for`, `created_by`, `status`, `created_at`, `updated_at` |
| `events` | `event_id` | `school_id`, `event_name`, `event_type`, `description`, `start_date`, `end_date`, `start_time`, `end_time`, `venue`, `organizer_id`, `audience_type`, `attachment_url`, `status`, `created_at`, `updated_at` |
| `approval_requests` | `approval_id` | `school_id`, `academic_year_id`, `request_type`, `module_name`, `reference_table`, `reference_id`, `requested_by`, `requested_role`, `assigned_to`, `approval_level`, `priority`, `title`, `description`, `old_value_json`, `new_value_json`, `attachment_url`, `remarks_by_requester`, `approval_status`, `approved_by`, `approved_at`, `rejection_reason`, `action_taken`, `notification_sent`, `deadline_date`, `created_at`, `updated_at` |
| `communications` | `message_id` | `school_id`, `sender_id`, `sender_role`, `receiver_id`, `receiver_role`, `student_id`, `message_type`, `message_content`, `attachment_url`, `priority`, `is_read`, `read_at`, `reply_to_message_id`, `is_deleted_by_sender`, `is_deleted_by_receiver`, `sent_at`, `created_at`, `updated_at` |
| `principal_reports` | `report_id` | `school_id`, `academic_year_id`, `report_name`, `report_type`, `module_name`, `generated_by`, `generated_role`, `class_id`, `section_id`, `student_id`, `staff_id`, `date_from`, `date_to`, `report_parameters_json`, `report_summary_json`, `chart_data_json`, `total_records`, `report_file_url`, `report_status`, `is_scheduled`, `schedule_frequency`, `last_generated_at`, `remarks`, `created_at`, `updated_at` |

---

## 3. Complete Table Inventory & Schema

### 3.1 Phase 1 — Foundation Tables

#### `schools`
| Column | Type | Constraints | Description |
|--------|------|------------|-------------|
| `id` | TEXT | PK, UUID | School identifier |
| `school_name` | TEXT | NOT NULL | School name |
| `school_code` | TEXT | UNIQUE | Short code |
| `address` | TEXT | | Street address |
| `city` | TEXT | | City |
| `state` | TEXT | | State/Province |
| `country` | TEXT | DEFAULT 'India' | Country |
| `phone` | TEXT | | Contact phone |
| `email` | TEXT | | Contact email |
| `website` | TEXT | | Website URL |
| `logo_url` | TEXT | | Logo path |
| `affiliation_number` | TEXT | | Board affiliation |
| `academic_year_id` | TEXT | FK → academic_years | Current active year |
| `is_active` | BOOL | DEFAULT true | Soft delete flag |
| `created_at` | DATETIME | | Auto timestamp |
| `updated_at` | DATETIME | | Auto timestamp |

#### `academic_years`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `year_name` | TEXT | NOT NULL (e.g. "2025-2026") |
| `start_date` | DATETIME | NOT NULL |
| `end_date` | DATETIME | NOT NULL |
| `is_current` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `terms`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `academic_year_id` | TEXT | FK → academic_years, NOT NULL |
| `term_name` | TEXT | NOT NULL (e.g. "Term 1") |
| `start_date` | DATETIME | NOT NULL |
| `end_date` | DATETIME | NOT NULL |
| `is_current` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `roles`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `role_name` | TEXT | NOT NULL (Admin, Teacher, Parent, Principal, Accountant, Librarian, etc.) |
| `description` | TEXT | |
| `priority` | INT | DEFAULT 0 |
| `is_system_role` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `permissions`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `role_id` | TEXT | FK → roles, NOT NULL |
| `module` | TEXT | NOT NULL |
| `can_view` | BOOL | DEFAULT false |
| `can_create` | BOOL | DEFAULT false |
| `can_edit` | BOOL | DEFAULT false |
| `can_delete` | BOOL | DEFAULT false |
| `can_approve` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |

#### `subjects`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `subject_name` | TEXT | NOT NULL |
| `subject_code` | TEXT | |
| `subject_type` | TEXT | (core/elective/language) |
| `is_mandatory` | BOOL | DEFAULT true |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `grades`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `grade_name` | TEXT | NOT NULL (e.g. "Grade 10") |
| `grade_code` | TEXT | |
| `next_grade_id` | TEXT | FK → grades (self-ref) |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `grade_subjects`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `grade_id` | TEXT | FK → grades, NOT NULL |
| `subject_id` | TEXT | FK → subjects, NOT NULL |
| `is_mandatory` | BOOL | DEFAULT true |
| `periods_per_week` | INT | DEFAULT 1 |
| `max_marks` | INT | DEFAULT 100 |
| `pass_marks` | INT | DEFAULT 35 |

#### `holidays`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `holiday_name` | TEXT | NOT NULL |
| `holiday_date` | DATE | NOT NULL |
| `is_recurring` | BOOL | DEFAULT false |
| `holiday_type` | TEXT | (national/festival/event) |

#### `working_day_configs`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `day_of_week` | INT | NOT NULL (1=Mon..7=Sun) |
| `is_working_day` | BOOL | DEFAULT true |
| `start_time` | TEXT | |
| `end_time` | TEXT | |

#### `departments`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `department_name` | TEXT | NOT NULL |
| `description` | TEXT | |
| `head_staff_id` | TEXT | FK → staffs |

#### `rooms`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `room_name` | TEXT | NOT NULL (e.g. "Room 101") |
| `capacity` | INT | |
| `room_type` | TEXT | (classroom/lab/library/office) |
| `building` | TEXT | |
| `floor` | INT | |

---

### 3.2 Phase 2 — Staff, Student & Auth Core

#### `staffs`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `staff_code` | TEXT | UNIQUE per school, NOT NULL |
| `first_name` | TEXT | NOT NULL |
| `last_name` | TEXT | |
| `email` | TEXT | |
| `phone` | TEXT | |
| `date_of_birth` | DATE | |
| `gender` | TEXT | |
| `designation` | TEXT | |
| `employment_type` | TEXT | (permanent/contract/temporary) |
| `department_id` | TEXT | FK → departments |
| `join_date` | DATE | |
| `basic_salary` | DECIMAL | |
| `status` | TEXT | DEFAULT 'active' (active/inactive/pending_approval) |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `staff_qualifications`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `staff_id` | TEXT | FK → staffs, NOT NULL |
| `qualification_name` | TEXT | NOT NULL |
| `institution` | TEXT | |
| `year_completed` | INT | |
| `grade_or_percentage` | TEXT | |

#### `staff_subjects`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `staff_id` | TEXT | FK → staffs, NOT NULL |
| `subject_id` | TEXT | FK → subjects, NOT NULL |
| `grade_id` | TEXT | FK → grades |
| `section_id` | TEXT | FK → sections |
| `is_primary` | BOOL | DEFAULT false |

#### `staff_documents`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `staff_id` | TEXT | FK → staffs, NOT NULL |
| `doc_type` | TEXT | NOT NULL (profile_photo/certificate/id_proof) |
| `file_url` | TEXT | NOT NULL |
| `verified` | BOOL | DEFAULT false |
| `uploaded_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `sections`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `grade_id` | TEXT | FK → grades, NOT NULL |
| `section_name` | TEXT | NOT NULL (e.g. "A", "B") |
| `capacity` | INT | |
| `class_teacher_id` | TEXT | FK → staffs |
| `academic_year_id` | TEXT | FK → academic_years |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `students`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `admission_no` | TEXT | UNIQUE per school |
| `roll_number` | TEXT | |
| `first_name` | TEXT | NOT NULL |
| `last_name` | TEXT | |
| `date_of_birth` | DATE | |
| `gender` | TEXT | |
| `blood_group` | TEXT | |
| `email` | TEXT | |
| `phone` | TEXT | |
| `address` | TEXT | |
| `city` | TEXT | |
| `state` | TEXT | |
| `pincode` | TEXT | |
| `profile_photo_url` | TEXT | |
| `status` | TEXT | DEFAULT 'active' |
| `admission_date` | DATE | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `guardians`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK → students, NOT NULL |
| `guardian_name` | TEXT | NOT NULL |
| `relationship` | TEXT | (father/mother/guardian) |
| `phone` | TEXT | |
| `email` | TEXT | |
| `occupation` | TEXT | |
| `income` | DECIMAL | |
| `address` | TEXT | |
| `is_primary_contact` | BOOL | DEFAULT true |

#### `medical_records`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK → students, NOT NULL |
| `blood_group` | TEXT | |
| `allergies` | TEXT | |
| `medical_conditions` | TEXT | |
| `emergency_contact` | TEXT | |
| `blood_group` | TEXT | |
| `updated_at` | DATETIME | |

*(Note: `medical_records` has duplicate `blood_group` in the model — both on students and medical_records)*

#### `enrollments`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK → students, NOT NULL |
| `section_id` | TEXT | FK → sections, NOT NULL |
| `academic_year_id` | TEXT | FK → academic_years, NOT NULL |
| `roll_number` | TEXT | |
| `enrollment_date` | DATE | |
| `status` | TEXT | DEFAULT 'active' |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `users`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `name` | TEXT | NOT NULL |
| `username` | TEXT | NOT NULL, UNIQUE per school |
| `email` | TEXT | |
| `phone` | TEXT | |
| `password_hash` | TEXT | NOT NULL |
| `role_id` | TEXT | FK → roles, NOT NULL |
| `role_slug` | TEXT | |
| `linked_type` | TEXT | (staff/parent) |
| `linked_id` | TEXT | FK polymorphic |
| `avatar` | TEXT | |
| `is_active` | BOOL | DEFAULT true |
| `is_verified` | BOOL | DEFAULT false |
| `last_login` | DATETIME | |
| `last_password_change` | DATETIME | |
| `two_factor_enabled` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `user_sessions`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `user_id` | TEXT | FK → users, NOT NULL |
| `refresh_token` | TEXT | NOT NULL |
| `device_info` | TEXT | |
| `ip_address` | TEXT | |
| `expires_at` | DATETIME | NOT NULL |
| `is_revoked` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |

#### `otp_verifications`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `user_id` | TEXT | FK → users |
| `email` | TEXT | |
| `phone` | TEXT | |
| `otp_code` | TEXT | NOT NULL |
| `purpose` | TEXT | (password_reset/email_verify/login) |
| `expires_at` | DATETIME | NOT NULL |
| `is_used` | BOOL | DEFAULT false |
| `attempts` | INT | DEFAULT 0 |

#### `audit_logs`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools |
| `user_id` | TEXT | FK → users |
| `action` | TEXT | NOT NULL |
| `entity_type` | TEXT | NOT NULL |
| `entity_id` | TEXT | |
| `old_values` | JSON | |
| `new_values` | JSON | |
| `ip_address` | TEXT | |
| `user_agent` | TEXT | |
| `created_at` | DATETIME | |

#### `parent_student_links`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `parent_user_id` | TEXT | FK → users, NOT NULL |
| `student_id` | TEXT | FK → students, NOT NULL |
| `relationship` | TEXT | |
| `is_primary` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |

#### `transfer_records`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK → students, NOT NULL |
| `from_school_id` | TEXT | FK → schools |
| `to_school_id` | TEXT | FK → schools |
| `transfer_date` | DATE | |
| `reason` | TEXT | |
| `tc_document_url` | TEXT | |
| `created_at` | DATETIME | |

---

### 3.3 Phase 3 — Operational Tables

#### `attendance` (Student Attendance)
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK → students, NOT NULL |
| `section_id` | TEXT | FK → sections, NOT NULL |
| `date` | DATE | NOT NULL |
| `status` | TEXT | NOT NULL (present/absent/late/holiday) |
| `marked_by_id` | TEXT | FK → users |
| `remark` | TEXT | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `staff_attendances`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `staff_id` | TEXT | FK → staffs, NOT NULL |
| `date` | DATE | NOT NULL |
| `check_in` | DATETIME | |
| `check_out` | DATETIME | |
| `status` | TEXT | (present/absent/late/half-day) |
| `marked_by_id` | TEXT | FK → users |
| `qr_verified` | BOOL | DEFAULT false |
| `remarks` | TEXT | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `timetable_slots`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `section_id` | TEXT | FK → sections, NOT NULL |
| `academic_year_id` | TEXT | FK → academic_years, NOT NULL |
| `term_id` | TEXT | FK → terms, NOT NULL |
| `day_of_week` | INT | NOT NULL (1-7) |
| `period_number` | INT | NOT NULL |
| `subject_id` | TEXT | FK → subjects, NOT NULL |
| `staff_id` | TEXT | FK → staffs, NOT NULL |
| `room_id` | TEXT | FK → rooms |
| `start_time` | TEXT | (HH:MM format) |
| `end_time` | TEXT | (HH:MM format) |
| `slot_type` | TEXT | DEFAULT 'regular' |

#### `substitutions`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `timetable_slot_id` | TEXT | FK → timetable_slots, NOT NULL |
| `date` | DATE | NOT NULL |
| `original_staff_id` | TEXT | FK → staffs, NOT NULL |
| `substitute_staff_id` | TEXT | FK → staffs, NOT NULL |
| `reason` | TEXT | |
| `approved_by` | TEXT | FK → users |
| `created_at` | DATETIME | |

#### `fees`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `student_id` | TEXT | FK → students, NOT NULL |
| `fee_category_id` | TEXT | FK → fee_categories |
| `fee_structure_id` | TEXT | FK → fee_structures |
| `total_amount` | DECIMAL | NOT NULL |
| `paid_amount` | DECIMAL | DEFAULT 0 |
| `balance` | DECIMAL | DEFAULT 0 |
| `due_date` | DATE | |
| `status` | TEXT | (pending/paid/overdue/partial) |
| `invoice_number` | TEXT | |
| `receipt` | TEXT | |
| `remarks` | TEXT | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `fee_categories`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `category_name` | TEXT | NOT NULL (tuition/transport/library/etc.) |
| `description` | TEXT | |
| `is_recurring` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |

#### `fee_structures`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `grade_id` | TEXT | FK → grades |
| `fee_category_id` | TEXT | FK → fee_categories, NOT NULL |
| `amount` | DECIMAL | NOT NULL |
| `frequency` | TEXT | (monthly/quarterly/yearly/one-time) |
| `is_mandatory` | BOOL | DEFAULT true |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `concessions`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools |
| `student_id` | TEXT | FK → students |
| `fee_category_id` | TEXT | FK → fee_categories |
| `percentage` | DECIMAL | |
| `amount` | DECIMAL | |
| `reason` | TEXT | |
| `status` | TEXT | (pending/approved/rejected) |
| `approved_by` | TEXT | FK → users |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `exams`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `academic_year_id` | TEXT | FK → academic_years, NOT NULL |
| `term_id` | TEXT | FK → terms, NOT NULL |
| `exam_type_id` | TEXT | FK → exam_types, NOT NULL |
| `exam_name` | TEXT | NOT NULL |
| `start_date` | DATE | NOT NULL |
| `end_date` | DATE | NOT NULL |
| `is_published` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `exam_types`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `name` | TEXT | NOT NULL (Midterm/Final/Quiz) |
| `weightage_percent` | FLOAT | |
| `is_board_exam` | BOOL | DEFAULT false |

#### `exam_schedules`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `exam_id` | TEXT | FK → exams, NOT NULL |
| `grade_id` | TEXT | FK → grades, NOT NULL |
| `section_id` | TEXT | FK → sections, NOT NULL |
| `subject_id` | TEXT | FK → subjects, NOT NULL |
| `exam_date` | DATE | NOT NULL |
| `start_time` | TEXT | (HH:MM) |
| `end_time` | TEXT | (HH:MM) |
| `max_marks` | INT | NOT NULL |
| `pass_marks` | INT | NOT NULL |
| `room_id` | TEXT | FK → rooms |

#### `student_marks`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `exam_schedule_id` | TEXT | FK → exam_schedules, NOT NULL |
| `student_id` | TEXT | FK → students, NOT NULL |
| `enrollment_id` | TEXT | FK → enrollments, NOT NULL |
| `marks_obtained` | FLOAT | |
| `grade_label` | TEXT | (A/B/C/D/F) |
| `is_absent` | BOOL | DEFAULT false |
| `is_exempted` | BOOL | DEFAULT false |
| `entered_by` | TEXT | FK → users |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `report_cards`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK → students, NOT NULL |
| `exam_id` | TEXT | FK → exams, NOT NULL |
| `total_marks` | FLOAT | |
| `percentage` | FLOAT | |
| `grade` | TEXT | |
| `rank` | INT | |
| `remarks` | TEXT | |
| `generated_at` | DATETIME | |
| `published` | BOOL | DEFAULT false |

#### `leaves`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `staff_id` | TEXT | FK → staffs, NOT NULL |
| `leave_type_id` | TEXT | FK → leave_types, NOT NULL |
| `start_date` | DATE | NOT NULL |
| `end_date` | DATE | NOT NULL |
| `reason` | TEXT | |
| `status` | TEXT | (pending/approved/rejected/cancelled) |
| `approved_by` | TEXT | FK → users |
| `applied_on` | DATETIME | |
| `created_at` | DATETIME | |
| `updated_at` | DATETIME | |

#### `leave_types`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools |
| `leave_name` | TEXT | NOT NULL (sick/casual/annual) |
| `default_days` | INT | |
| `is_paid` | BOOL | DEFAULT true |

#### `leave_balances`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `staff_id` | TEXT | FK → staffs, NOT NULL |
| `leave_type_id` | TEXT | FK → leave_types, NOT NULL |
| `total_days` | INT | |
| `used_days` | INT | DEFAULT 0 |
| `remaining_days` | INT | |
| `academic_year_id` | TEXT | FK → academic_years |

#### `student_leaves`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK → students, NOT NULL |
| `start_date` | DATE | NOT NULL |
| `end_date` | DATE | NOT NULL |
| `reason` | TEXT | |
| `status` | TEXT | (pending/approved/rejected) |
| `approved_by` | TEXT | FK → users |
| `applied_on` | DATETIME | |

#### `announcements`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `title` | TEXT | NOT NULL |
| `content` | TEXT | |
| `target_role` | TEXT | (all/teacher/parent/student/admin) |
| `priority` | TEXT | (low/normal/high/urgent) |
| `published_by` | TEXT | FK → users |
| `is_active` | BOOL | DEFAULT true |
| `valid_from` | DATETIME | |
| `valid_until` | DATETIME | |
| `created_at` | DATETIME | |

#### `notifications`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools |
| `user_id` | TEXT | FK → users, NOT NULL |
| `title` | TEXT | NOT NULL |
| `body` | TEXT | |
| `type` | TEXT | (announcement/exam/attendance/fee/leave) |
| `data` | JSON | |
| `is_read` | BOOL | DEFAULT false |
| `read_at` | DATETIME | |
| `created_at` | DATETIME | |

#### `device_tokens`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `user_id` | TEXT | FK → users, NOT NULL |
| `device_token` | TEXT | NOT NULL |
| `platform` | TEXT | (android/ios/web) |
| `is_active` | BOOL | DEFAULT true |
| `created_at` | DATETIME | |

#### `homework`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `section_id` | TEXT | FK → sections, NOT NULL |
| `subject_id` | TEXT | FK → subjects, NOT NULL |
| `title` | TEXT | NOT NULL |
| `description` | TEXT | |
| `assigned_date` | DATE | |
| `submission_date` | DATE | |
| `max_marks` | INT | |
| `assigned_by` | TEXT | FK → users |
| `created_at` | DATETIME | |

#### `homework_submissions`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `homework_id` | TEXT | FK → homework, NOT NULL |
| `student_id` | TEXT | FK → students, NOT NULL |
| `submission_text` | TEXT | |
| `file_url` | TEXT | |
| `submitted_at` | DATETIME | |
| `marks_obtained` | FLOAT | |
| `feedback` | TEXT | |
| `graded_by` | TEXT | FK → users |

#### `diary_entries`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools |
| `section_id` | TEXT | FK → sections |
| `subject_id` | TEXT | FK → subjects |
| `entry_date` | DATE | |
| `topic_covered` | TEXT | |
| `notes` | TEXT | |
| `homework` | TEXT | |
| `created_by` | TEXT | FK → users |
| `created_at` | DATETIME | |

#### `library_books`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `isbn` | TEXT | |
| `title` | TEXT | NOT NULL |
| `author` | TEXT | |
| `publisher` | TEXT | |
| `quantity` | INT | DEFAULT 1 |
| `available` | INT | DEFAULT 1 |
| `shelf_location` | TEXT | |
| `created_at` | DATETIME | |

#### `library_transactions`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `book_id` | TEXT | FK → library_books, NOT NULL |
| `borrowed_by` | TEXT | (student/staff ID) |
| `borrowed_by_type` | TEXT | (student/staff) |
| `borrow_date` | DATE | |
| `due_date` | DATE | |
| `return_date` | DATE | |
| `status` | TEXT | (borrowed/returned/overdue/lost) |
| `fine_amount` | DECIMAL | |
| `fine_paid` | BOOL | DEFAULT false |
| `created_at` | DATETIME | |

#### `transport_routes`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `route_name` | TEXT | NOT NULL |
| `driver_name` | TEXT | |
| `driver_phone` | TEXT | |
| `vehicle_number` | TEXT | |
| `capacity` | INT | |
| `fee_amount` | DECIMAL | |
| `created_at` | DATETIME | |

#### `transport_stops`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `route_id` | TEXT | FK → transport_routes, NOT NULL |
| `stop_name` | TEXT | NOT NULL |
| `stop_order` | INT | |
| `pickup_time` | TEXT | |
| `drop_time` | TEXT | |
| `address` | TEXT | |
| `fee_amount` | DECIMAL | |

#### `student_transport_mappings`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `student_id` | TEXT | FK → students, NOT NULL |
| `route_id` | TEXT | FK → transport_routes, NOT NULL |
| `stop_id` | TEXT | FK → transport_stops |
| `academic_year_id` | TEXT | FK → academic_years |
| `status` | TEXT | DEFAULT 'active' |

#### `parent_teacher_meetings`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools, NOT NULL |
| `teacher_id` | TEXT | FK → staffs |
| `parent_user_id` | TEXT | FK → users |
| `student_id` | TEXT | FK → students |
| `scheduled_at` | DATETIME | NOT NULL |
| `duration_minutes` | INT | |
| `mode` | TEXT | (in-person/video/phone) |
| `status` | TEXT | (scheduled/completed/cancelled) |
| `notes` | TEXT | |
| `created_at` | DATETIME | |

#### `frontend_records`
| Column | Type | Constraints |
|--------|------|------------|
| `id` | TEXT | PK, UUID |
| `school_id` | TEXT | FK → schools |
| `module` | TEXT | NOT NULL |
| `record_type` | TEXT | NOT NULL |
| `data` | JSON | NOT NULL |
| `created_at` | DATETIME | |

---

## 4. Entity Relationship Diagram (ERD)

### 4.1 Foundation Layer

```
schools ──┬── academic_years ──┬── terms
          │                    │
          ├── roles ──────── permissions
          │
          ├── subjects ──┐
          │              │
          ├── grades ────┤
          │              │
          ├── grade_subjects
          │
          ├── departments
          ├── rooms
          ├── holidays
          └── working_day_configs
```

### 4.2 Staff & Auth Layer

```
schools ──┬── staffs ──┬── staff_qualifications
          │            ├── staff_subjects ──┬── subjects
          │            │                    └── sections
          │            ├── staff_documents
          │            └── leave_balances ──┬── leave_types
          │
          └── users ──┬── role (roles)
                      ├── user_sessions
                      ├── otp_verifications
                      ├── audit_logs
                      ├── device_tokens
                      └── parent_student_links ──┬── students
```

### 4.3 Student Layer

```
schools ──┬── students ──┬── guardians
          │              ├── medical_records
          │              ├── student_documents
          │              ├── enrollments ──┬── sections ──┬── grades
          │              │                 │              │
          │              │                 └── academic_years
          │              ├── transfer_records
          │              ├── student_transport_mappings ──┬── transport_routes
          │              │                                └── transport_stops
          │              └── parent_student_links ──┬── users (parent)
          │
          └── sections ──┬── class_teacher (staffs)
                          └── grades
```

### 4.4 Academics & Operations Layer

```
subjects ──┬── timetable_slots ──┬── sections
           │                     ├── staffs
           │                     ├── rooms
           │                     └── substitutions
           │
           ├── exam_schedules ──┬── exams ──┬── exam_types
           │                    │           ├── academic_years
           │                    │           └── terms
           │                    ├── student_marks
           │                    └── report_cards
           │
           ├── homework ──┬── homework_submissions
           │              └── sections
           │
           └── diary_entries

students ──┬── attendances
           ├── student_leaves
           ├── student_marks ──┬── exam_schedules
           ├── report_cards    └── enrollments
           ├── fees ──┬── fee_structures ──┬── fee_categories
           │          ├── concessions      └── grades
           │          └── fee_categories
           ├── homework_submissions
           └── library_transactions ──┬── library_books

staffs ──┬── leaves ──┬── leave_types
         ├── staff_attendances
         └── parent_teacher_meetings

notifications ──┬── users
announcements
```

---

## 5. Foreign Key Constraints

The following **30+ foreign key constraints** are enforced (PostgreSQL) via `internal/database/constraints.go`:

| Constraint Name | From Table | From Column | To Table | To Column |
|----------------|------------|-------------|----------|-----------|
| `fk_academic_years_school` | academic_years | school_id | schools | id |
| `fk_terms_academic_year` | terms | academic_year_id | academic_years | id |
| `fk_sections_grade` | sections | grade_id | grades | id |
| `fk_sections_teacher` | sections | class_teacher_id | staffs | id |
| `fk_enrollments_student` | enrollments | student_id | students | id |
| `fk_enrollments_section` | enrollments | section_id | sections | id |
| `fk_attendance_student` | attendance | student_id | students | id |
| `fk_attendance_section` | attendance | section_id | sections | id |
| `fk_fees_student` | fees | student_id | students | id |
| `fk_timetable_section` | timetable_slots | section_id | sections | id |
| `fk_timetable_subject` | timetable_slots | subject_id | subjects | id |
| `fk_timetable_staff` | timetable_slots | staff_id | staffs | id |
| `fk_exam_school` | exams | school_id | schools | id |
| `fk_exam_type` | exams | exam_type_id | exam_types | id |
| `fk_exam_schedule_exam` | exam_schedules | exam_id | exams | id |
| `fk_student_marks_schedule` | student_marks | exam_schedule_id | exam_schedules | id |
| `fk_student_marks_student` | student_marks | student_id | students | id |
| `fk_users_role` | users | role_id | roles | id |
| `fk_users_school` | users | school_id | schools | id |
| `fk_staff_school` | staffs | school_id | schools | id |
| `fk_staff_department` | staffs | department_id | departments | id |
| `fk_student_school` | students | school_id | schools | id |
| `fk_guardian_student` | guardians | student_id | students | id |
| `fk_notification_user` | notifications | user_id | users | id |
| `fk_parent_link_user` | parent_student_links | parent_user_id | users | id |
| `fk_parent_link_student` | parent_student_links | student_id | students | id |
| `fk_device_token_user` | device_tokens | user_id | users | id |
| ... and more for leave, homework, library, transport tables |

---

## 6. Unique Indexes & Integrity Probes

### 6.1 Unique Indexes (enforced on PostgreSQL)

| Index | Table | Column(s) | Condition |
|-------|-------|-----------|-----------|
| `idx_unique_staff_code` | staffs | `school_id, staff_code` | WHERE deleted_at IS NULL |
| `idx_unique_admission_no` | students | `school_id, admission_no` | WHERE deleted_at IS NULL |
| `idx_unique_username` | users | `school_id, LOWER(username)` | WHERE deleted_at IS NULL |
| `idx_unique_school_code` | schools | `school_code` | WHERE deleted_at IS NULL |
| `idx_unique_grade_name` | grades | `school_id, grade_name` | |
| `idx_unique_section_name` | sections | `grade_id, section_name` | |
| `idx_unique_role_name` | roles | `school_id, LOWER(role_name)` | |

### 6.2 Integrity Probes (run before migration)

The `integrityprobes` function checks these BEFORE allowing migrations:

1. **Duplicate school codes**
2. **Orphaned staff records** (staff_code duplicates)
3. **Missing foreign key references** (students referencing non-existent schools)
4. **Duplicate admission numbers**
5. **Duplicate usernames**
6. **Role referential integrity** (users referencing non-existent roles)

---

## 7. API Endpoint Registry

### 7.1 Route Group Structure

All endpoints are under `/api/v1/` unless noted otherwise.

#### Authentication (`/api/v1/auth/`)

| Method | Path | Handler | Middleware | Description |
|--------|------|---------|-----------|-------------|
| POST | `/auth/login` | `AuthHandler.Login` | None | Username/password login |
| POST | `/auth/register` | `AuthHandler.Register` | None | Self-registration (parent role) |
| POST | `/auth/refresh` | `AuthHandler.RefreshToken` | None | Refresh JWT token |
| POST | `/auth/logout` | `AuthHandler.Logout` | Auth | Invalidate session |
| POST | `/auth/change-password` | `AuthHandler.ChangePassword` | Auth | Change own password |
| POST | `/auth/forgot-password` | `AuthHandler.ForgotPassword` | None | Request OTP |
| POST | `/auth/reset-password` | `AuthHandler.ResetPassword` | None | Reset with OTP |
| GET | `/auth/me` | `AuthHandler.Me` | Auth | Get current user profile |

#### School Management (`/api/v1/school/`)

| Method | Path | Handler | Middleware |
|--------|------|---------|-----------|
| GET | `/school/current` | `SchoolHandler.GetCurrentSchool` | Auth |
| PUT | `/school/current` | `SchoolHandler.UpdateCurrentSchool` | Auth, RBAC(Admin) |
| POST | `/school/current/logo` | `SchoolHandler.UploadCurrentSchoolLogo` | Auth, RBAC(Admin) |
| GET | `/school/academic-years` | `SchoolHandler.GetAcademicYears` | Auth |
| POST | `/school/academic-years` | `SchoolHandler.CreateAcademicYear` | Auth, RBAC(Admin) |
| GET | `/school/academic-years/:id` | `SchoolHandler.GetAcademicYear` | Auth |
| PUT | `/school/academic-years/:id` | `SchoolHandler.UpdateAcademicYear` | Auth, RBAC(Admin) |

#### CRUD Resources (`/api/v1/{resource}`)

| Resource | GET (list) | GET /:id | POST | PUT /:id | DELETE /:id |
|----------|-----------|----------|------|----------|-------------|
| `/classes` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/attendance` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/fees` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/exams` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/homework` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/leaves` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/notifications` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/holidays` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/events` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/approval-requests` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/communications` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/principal-reports` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/grades` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/subjects` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/grade-subjects` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/sections` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/terms` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/departments` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/rooms` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/working-days` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/exam-types` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/fee-categories` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/fee-structures` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/leave-types` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/library-books` | Historical schema only | | | | |
| `/transport-routes` | Historical schema only | | | | |
| `/promotion-rules` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/roles` | ✓ | | ✓ | ✓ | ✓ |
| `/permissions` | ✓ | | ✓ | ✓ | ✓ |

#### Staff Management (`/api/v1/staff/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/staff` | `StaffHandler.GetStaff` |
| GET | `/staff/:id` | `StaffHandler.GetStaffMember` |
| POST | `/staff` | `StaffHandler.CreateStaff` |
| PUT | `/staff/:id` | `StaffHandler.UpdateStaff` |
| DELETE | `/staff/:id` | `StaffHandler.DeleteStaff` |
| POST | `/staff/:id/photo` | `StaffHandler.UploadStaffPhoto` |
| POST | `/staff/:id/document` | `StaffHandler.UploadStaffDocument` |
| GET | `/staff/:id/leave-balance` | `StaffHandler.GetStaffLeaveBalance` |
| GET | `/staff/:id/attendance` | `StaffHandler.GetStaffAttendance` |

#### Student Management (`/api/v1/students/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/students` | `StudentHandler.GetStudents` |
| GET | `/students/:id` | `StudentHandler.GetStudent` |
| POST | `/students` | `StudentHandler.CreateStudent` |
| PUT | `/students/:id` | `StudentHandler.UpdateStudent` |
| DELETE | `/students/:id` | `StudentHandler.DeleteStudent` |
| POST | `/students/:id/photo` | `StudentHandler.UploadStudentPhoto` |
| POST | `/students/:id/document` | `StudentHandler.UploadStudentDocument` |
| GET | `/students/:id/enrollments` | `StudentHandler.GetStudentEnrollments` |
| POST | `/students/:id/enrollments` | `StudentHandler.CreateEnrollment` |
| GET | `/students/:id/attendance` | `StudentHandler.GetStudentAttendance` |
| GET | `/students/:id/fees` | `StudentHandler.GetStudentFees` |
| GET | `/students/:id/marks` | `StudentHandler.GetStudentMarks` |
| _retired_ | `/students/:id/transport` | Historical handler retained for tests/backfill only; not registered in current API |

#### Attendance (`/api/v1/attendance/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/attendance` | `AttendanceHandler.GetAttendance` |
| POST | `/attendance/bulk` | `AttendanceHandler.BulkMarkAttendance` |
| GET | `/attendance/summary` | `AttendanceHandler.GetAttendanceSummary` |
| POST | `/attendance/staff/bulk` | `AttendanceHandler.BulkMarkStaffAttendance` |
| GET | `/attendance/staff` | `AttendanceHandler.GetStaffAttendance` |
| POST | `/attendance/staff/qr-verify` | `AttendanceHandler.QrVerifyStaffAttendance` |

#### Fees (`/api/v1/fees/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/fees` | `FeeHandler.GetFees` |
| POST | `/fees` | `FeeHandler.CreateFee` |
| PUT | `/fees/:id` | `FeeHandler.UpdateFee` |
| GET | `/fees/structures` | `FeeHandler.GetFeeStructures` |
| POST | `/fees/structures` | `FeeHandler.CreateFeeStructure` |
| POST | `/fees/payment` | `FeeHandler.RecordPayment` |
| GET | `/fees/concessions` | `FeeHandler.GetConcessions` |
| POST | `/fees/concessions` | `FeeHandler.CreateConcession` |
| GET | `/fees/categories` | (via CRUD handler) |
| GET | `/fees/invoices` | `FeeHandler.GetInvoices` |
| POST | `/fees/generate` | `FeeHandler.GenerateFees` |

#### Exams (`/api/v1/exams/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/exams` | `TablesMDCRUDHandler.List` (`exams.exam_id`) |
| POST | `/exams` | `TablesMDCRUDHandler.Create` (`exams.exam_id`) |
| GET | `/exams/:id` | `TablesMDCRUDHandler.Get` (`exams.exam_id`) |
| PUT/PATCH | `/exams/:id` | `TablesMDCRUDHandler.Update` (`exams.exam_id`) |
| DELETE | `/exams/:id` | `TablesMDCRUDHandler.Delete` (`exams.exam_id`) |
| PATCH | `/exams/:id/publish` | `ExamHandler.PublishExam` |
| POST | `/exams/schedules` | `ExamHandler.CreateExamSchedule` |
| GET | `/exams/schedules/:schedule_id/marks` | `ExamHandler.GetScheduleMarks` |
| POST | `/exams/schedules/:schedule_id/marks` | `ExamHandler.EnterMarks` |
| GET | `/exams/report-cards` | `ExamHandler.GetReportCards` |
| GET | `/exams/grading-scale` | `ExamHandler.GetGradingScale` |

#### Timetable (`/api/v1/timetable/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/timetable/slots` | `TimetableHandler.GetTimetableSlots` |
| POST | `/timetable/slots` | `TimetableHandler.CreateTimetableSlot` |
| PUT | `/timetable/slots/:id` | `TimetableHandler.UpdateTimetableSlot` |
| DELETE | `/timetable/slots/:id` | `TimetableHandler.DeleteTimetableSlot` |
| GET | `/timetable/section/:section_id` | `TimetableHandler.GetTimetableBySection` |
| POST | `/timetable/suggest` | `TimetableHandler.SuggestTimetableSlots` |
| POST | `/timetable/generate` | `TimetableHandler.GenerateTimetableSlots` |
| GET | `/timetable/substitutions` | `TimetableHandler.GetSubstitutions` |
| POST | `/timetable/substitutions` | `TimetableHandler.CreateSubstitution` |

#### Dashboard (`/api/v1/dashboard/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/dashboard/admin` | `DashboardHandler.AdminDashboard` |
| GET | `/dashboard/principal` | `DashboardHandler.PrincipalDashboard` |
| GET | `/dashboard/teacher` | `DashboardHandler.TeacherDashboard` |
| GET | `/dashboard/parent` | `DashboardHandler.ParentDashboard` |

#### User Management (`/api/v1/users/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/users` | `UserHandler.GetUsers` |
| POST | `/users/:id/avatar` | `UserHandler.UploadUserAvatar` |
| GET | `/users/accounts` | (list account approval requests) |
| PATCH | `/users/accounts/:id/approve` | (approve/reject account) |

#### Parent-Student Links (`/api/v1/parents/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/parents/students` | `ParentLinkHandler.GetLinkedStudents` |
| POST | `/parents/students` | `ParentLinkHandler.LinkStudent` |
| DELETE | `/parents/students/:id` | `ParentLinkHandler.UnlinkStudent` |

#### Notifications (`/api/v1/notifications/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/notifications` | `NotificationHandler.GetNotifications` |
| PUT | `/notifications/:id/read` | `NotificationHandler.MarkRead` |
| PUT | `/notifications/read-all` | `NotificationHandler.MarkAllRead` |
| POST | `/notifications/device-token` | `DeviceTokenHandler.RegisterDeviceToken` |

#### Leaves (`/api/v1/leaves/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/leaves` | `LeaveHandler.GetLeaves` |
| POST | `/leaves` | `LeaveHandler.CreateLeave` |
| PATCH | `/leaves/:id/status` | `LeaveHandler.UpdateLeaveStatus` |
| POST | `/leaves/student` | `StudentLeaveHandler.CreateStudentLeave` |
| GET | `/leaves/student` | `StudentLeaveHandler.GetStudentLeaves` |

#### Announcements (`/api/v1/announcements/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/announcements` | `AnnouncementHandler.GetAnnouncements` |
| POST | `/announcements` | `AnnouncementHandler.CreateAnnouncement` |
| PUT | `/announcements/:id` | `AnnouncementHandler.UpdateAnnouncement` |
| DELETE | `/announcements/:id` | `AnnouncementHandler.DeleteAnnouncement` |

#### Principal Academic Commands (`/api/v1/principal/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/principal/timetable-overview` | `PrincipalAcademicCommandHandler.TimetableOverview` |
| POST | `/principal/timetable-save` | `PrincipalAcademicCommandHandler.SaveTimetableAction` |
| GET | `/principal/exams-overview` | `PrincipalAcademicCommandHandler.ExamsOverview` |
| POST | `/principal/exam-save` | `PrincipalAcademicCommandHandler.SaveExamAction` |
| GET | `/principal/results-overview` | `PrincipalAcademicCommandHandler.ResultsOverview` |
| POST | `/principal/result-save` | `PrincipalAcademicCommandHandler.SaveResultAction` |
| GET | `/principal/subjects` | `PrincipalSubjectsHandler.Overview` |
| POST | `/principal/subjects/create` | `PrincipalSubjectsHandler.CreateAction` |
| POST | `/principal/subjects/map` | `PrincipalSubjectsHandler.SaveMapping` |
| GET | `/principal/classes` | `PrincipalClassesHandler.GetClasses` |

#### Report Card Export (`/api/v1/reports/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/reports/export/:student_id/:exam_id` | `ReportExportHandler.ExportReportCard` |
| GET | `/reports/class/:section_id/:exam_id` | `ReportExportHandler.ExportClassResults` |

#### Account Approval (`/api/v1/accounts/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/accounts/pending` | `AccountApprovalHandler.GetPendingApprovals` |
| PATCH | `/accounts/:id/approve` | `AccountApprovalHandler.ApproveAccount` |
| PATCH | `/accounts/:id/reject` | `AccountApprovalHandler.RejectAccount` |
| POST | `/accounts` | `AccountPermissionsHandler.CreateAccount` |
| PUT | `/accounts/:id` | `AccountPermissionsHandler.UpdateAccount` |
| DELETE | `/accounts/:id` | `AccountPermissionsHandler.DeleteAccount` |

#### Parent-Teacher Meetings (`/api/v1/ptm/`)

| Method | Path | Handler |
|--------|------|---------|
| POST | `/ptm/book` | `PTMHandler.Book` |
| GET | `/ptm` | `PTMHandler.List` |
| PATCH | `/ptm/:id/status` | `PTMHandler.UpdateStatus` |

#### Communication (`/api/v1/communications/`)

| Method | Path | Handler |
|--------|------|---------|
| POST | `/communications/send` | `CommunicationHandler.Send` |

#### Health & System (`/api/v1/`)

| Method | Path | Handler |
|--------|------|---------|
| GET | `/health` | Inline handler (DB + Redis check) |
| GET | `/metrics` | Inline Prometheus handler with HTTP, DB pool, Redis, queue, and notification-worker metrics |
| GET | `/frontend-records` | `FrontendRecordHandler.List` |
| POST | `/frontend-records` | `FrontendRecordHandler.Create` |

---

## 8. API-to-DB Integration Matrix

### 8.1 Common Query Patterns

Each handler follows consistent GORM query patterns:

| Pattern | Example | Used In |
|---------|---------|---------|
| **List with pagination** | `.Offset((page-1)*pageSize).Limit(pageSize)` | GetStudents, GetStaff, GetUsers, GetFees |
| **School-scoped queries** | `.Where("school_id = ?", schoolID)` | All multi-tenant endpoints |
| **Preload relationships** | `.Preload("Subject").Preload("Staff")` | Timetable, Exams, Marks |
| **Transactional writes** | `database.DB.Transaction(func(tx *gorm.DB) error {})` | CreateStudent, CreateStaff, Fee payment |
| **Scoped joins** | `.Joins("JOIN grades ON grades.id = sections.grade_id")` | Timetable (school-scoped via grade) |
| **Audit logging** | `auditAction(c, entity, action, type, &id)` | All Create/Update/Delete operations |

### 8.2 Role-Based Query Scoping

| Role | Data Scope | Enforcement |
|------|-----------|-------------|
| **Admin** | All data within school | `schoolID` context |
| **Principal** | All data within school | `schoolID` context |
| **Teacher** | Assigned sections only | `canAccessSection()` check |
| **Parent** | Linked students only | `canAccessStudent()` check |
| **Student** | Self data only | (future: student portal) |

### 8.3 Example: Create Staff Transaction

```
POST /api/v1/staff
  ↓
StaffHandler.CreateStaff()
  ├── Validate: employee ID, email, role hierarchy
  ├── Transaction:
  │   ├── ensureStaffCodeAvailable(tx)        // DB: SELECT staffs
  │   ├── resolveDepartmentID(tx)              // DB: SELECT/CREATE departments
  │   ├── tx.Create(&staff)                    // DB: INSERT staffs
  │   ├── h.createStaffUser(tx)                // DB: CREATE users
  │   │   ├── Validate username/email unique   // DB: SELECT users
  │   │   ├── database.HashPassword(password)  // bcrypt
  │   │   └── tx.Create(&user)                 // DB: INSERT users
  │   └── createAccountApprovalRecord(tx)      // If pending_approval
  └── auditAction(c, "staff", "create")        // DB: INSERT audit_logs
```

### 8.4 Example: Bulk Mark Attendance

```
POST /api/v1/attendance/bulk
  ↓
AttendanceHandler.BulkMarkAttendance()
  ├── Extract schoolID, userID from JWT context
  ├── For each attendance record:
  │   ├── Attendance{StudentID, SectionID, Date, Status}
  │   ├── database.DB.Where("student_id=? AND date=?").First(&existing)
  │   ├── If exists: UPDATE attendance SET status=?
  │   └── If not: INSERT attendance
  ├── Create notification for student's parents
  └── Return success count
```

### 8.5 Principal Dashboard Query Pattern

```
GET /api/v1/dashboard/principal
  ↓
DashboardHandler.PrincipalDashboard()
  ├── Total students     → SELECT COUNT(*) FROM students WHERE school_id=?
  ├── Total staff        → SELECT COUNT(*) FROM staffs WHERE school_id=?
  ├── Today's attendance → SELECT COUNT(*) FROM attendance WHERE date=? AND status=?
  ├── Pending fees       → SELECT SUM(balance) FROM fees WHERE school_id=? AND status IN ('pending','overdue')
  ├── Recent payments    → SELECT * FROM payments WHERE school_id=? ORDER BY created_at DESC LIMIT 5
  ├── Exam status        → SELECT * FROM exams WHERE school_id=? AND is_published=false
  ├── Leave requests     → SELECT * FROM leaves WHERE status='pending'
  └── Aggregate all into response
```

---

## 9. Auth & RBAC System

### 9.1 Authentication Flow

```
Login Request
  │
  ▼
POST /api/v1/auth/login { username, password }
  │
  ▼
AuthHandler.Login()
  ├── Find user by username/email → DB: SELECT users JOIN roles
  ├── Verify password → bcrypt.CompareHashAndPassword
  ├── Generate JWT (access token, 24h expiry)
  │   └── Payload: { user_id, school_id, role_id, role_name, linked_type }
  ├── Generate refresh token → DB: INSERT user_sessions
  └── Response: { access_token, refresh_token, user, school }
```

### 9.2 JWT Token Structure

```json
{
  "sub": "user-uuid",
  "school_id": "school-uuid",
  "role_id": "role-uuid",
  "role_name": "Admin",
  "linked_type": "staff",
  "exp": 1716000000,
  "iat": 1715913600
}
```

### 9.3 Role Hierarchy

```
                    ┌─────────────┐
                    │   Super     │ (cross-school, system-level)
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   Admin     │ (full school management)
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
       ┌──────▼──────┐ ┌──▼───┐ ┌─────▼──────┐
       │  Principal  │ │Teacher│ │  Accountant │
       └──────┬──────┘ └──┬───┘ └──────┬──────┘
              │           │            │
       ┌──────▼──────┐    │     ┌──────▼──────┐
       │    Parent   │    │     │  Librarian   │
       └─────────────┘    │     └─────────────┘
                          │
                   ┌──────▼──────┐
                   │   Student   │ (future portal)
                   └─────────────┘
```

### 9.4 RBAC Middleware Chain

```go
// Applied to each protected route:
r.GET("/api/v1/staff",
    AuthMiddleware(),                    // 1. Verify JWT
    SchoolScopeMiddleware(),             // 2. Extract school_id
    RBACMiddleware("Admin", "Principal"), // 3. Check role
    StaffHandler.GetStaff,               // 4. Execute handler
)
```

### 9.5 Permission Matrix (Module × Role)

| Module | Admin | Principal | Teacher | Parent | Accoun- tant | Librarian |
|--------|-------|-----------|---------|--------|:-----------:|:---------:|
| **Dashboard** | CRUD | CRUD | R | R | R | R |
| **Students** | CRUD | CRUD | R | R (own) | R | - |
| **Staff** | CRUD | CRUD | - | - | - | - |
| **Attendance** | CRUD | R | CRUD (own section) | R (own child) | - | - |
| **Fees** | CRUD | R | - | R (own child) | CRUD | - |
| **Exams** | CRUD | CRUD | CRUD (own subject) | R (own child) | - | - |
| **Timetable** | CRUD | CRUD | R | R (own child) | - | - |
| **Homework** | CRUD | R | CRUD | R (own child) | - | - |
| **Leaves** | CRUD (approve) | R | CRUD | - | - | - |
| **Announcements** | CRUD | CRUD | R | R | R | R |
| **Library** | CRUD | R | - | - | - | CRUD |
| **Transport** | CRUD | R | - | R | - | - |
| **Reports** | CRUD | CRUD | R (own section) | R (own child) | R | R |
| **Users** | CRUD | CRUD | - | - | - | - |
| **Roles/Perms** | CRUD | R | - | - | - | - |
| **School Config** | CRUD | R | - | - | - | - |
| **Parent Links** | CRUD | R | - | CRUD | - | - |
| **PTM** | CRUD | R | CRUD | R | - | - |

*(R = Read/View, C = Create, U = Update, D = Delete)*

### 9.6 Permission Middleware (Fine-Grained)

For routes requiring module-level access:

```go
PermissionMiddleware("students", "view")   // Must have students.can_view = true
PermissionMiddleware("fees", "create")      // Must have fees.can_create = true
```

Defined via `permissions` table: each role_id has `can_view`, `can_create`, `can_edit`, `can_delete`, `can_approve` per module.

### 9.7 Role Management Rules

| Action | Allowed By | Check Function |
|--------|-----------|----------------|
| Create Admin account | Only another Admin | `ensureActorCanManageRole(c, "Admin")` |
| Create Teacher account | Admin, Principal | `ensureActorCanManageRole(c, "Teacher")` |
| Create Principal account | Only Admin | `ensureActorCanManageRole(c, "Principal")` |
| Delete Admin account | Only another Admin | `ensureActorCanManageRole(c, "Admin")` |
| Self-password change | Any authenticated user | `AuthHandler.ChangePassword` |

### 9.8 Account Approval Flow

```
Admin creates staff account with password
  ↓
If pending_approval flag set:
  → Staff status = "pending_approval"
  → User is_active = false
  → AccountApprovalRecord created
  → Principal reviews via GET /accounts/pending
  → Principal approves via PATCH /accounts/:id/approve
  → User is_active = true, Staff status = "active"
```

---

## 10. Middleware Pipeline

### 10.1 Middleware Execution Order

```
Request
  │
  ▼
┌─────────────────────────────────┐
│  1. RequestIDMiddleware         │  Assigns unique X-Request-ID
├─────────────────────────────────┤
│  2. RequestLogMiddleware        │  Logs method, path, status, duration
├─────────────────────────────────┤
│  3. CORSMiddleware              │  CORS headers (configurable origins)
├─────────────────────────────────┤
│  4. RateLimitMiddleware         │  Per-endpoint rate limiting (optional)
├─────────────────────────────────┤
│  5. CacheMiddleware             │  Redis caching for GET responses (optional)
├─────────────────────────────────┤
│  6. AuthMiddleware              │  JWT validation + user context injection
├─────────────────────────────────┤
│  7. SchoolScopeMiddleware       │  Extracts school_id from token
├─────────────────────────────────┤
│  8. RBACMiddleware /            │  Role check or module-level permission
│     PermissionMiddleware        │
├─────────────────────────────────┤
│  9. Handler                     │  Business logic execution
└─────────────────────────────────┘
```

### 10.2 Middleware Details

#### `RequestIDMiddleware`
- Generates UUID for each request
- Sets `X-Request-ID` response header
- Stores in context for logging

#### `RequestLogMiddleware`
- Logs: method, path, status code, duration, request ID
- Uses structured logging

#### `CORSMiddleware`
- Allows configurable origins (default: `*`)
- Standard CORS headers (`Access-Control-Allow-Origin`, etc.)

#### `RateLimitMiddleware`
- Token-bucket algorithm per endpoint per IP/User
- Configurable: `maxRequests` per `window` duration
- Uses in-memory map (Redis optional via service)

#### `CacheMiddleware`
- Redis-backed response caching
- Configurable TTL per route
- Cache key: `{route_name}:{query_params}`
- Invalidated on write operations

#### `AuthMiddleware`
- Extracts JWT from `Authorization: Bearer <token>` header
- Validates signature, expiry
- Injects: `user_id`, `school_id`, `role_id`, `role_name` into context
- Rejects expired/invalid tokens with 401

#### `SchoolScopeMiddleware`
- Extracts `school_id` from JWT claims
- Injects into `gin.Context` for downstream handlers
- Rejects requests without `school_id` claim

#### `RBACMiddleware`
- Accepts variadic `allowedRoles ...string`
- Compares `role_name` from JWT context
- Returns 403 if not authorized

#### `PermissionMiddleware`
- Accepts `module` and `action` (view/create/edit/delete/approve)
- Queries `permissions` table for role_id + module
- Returns 403 if permission denied

---

## 11. Configuration & Environment Variables

### 11.1 Environment Variable Reference (`internal/config/config.go`)

| Variable | Default | Required (Prod) | Description |
|----------|---------|:---------------:|-------------|
| `PORT` | `8080` | | HTTP listen port |
| `DATABASE_URL` | `""` | **Yes** | PostgreSQL connection string (e.g., `postgres://user:pass@host:5432/db`) |
| `DATABASE_DSN` | `school.db` | | SQLite file path (fallback when DATABASE_URL is empty) |
| `JWT_SECRET` | | **Yes** | HMAC secret for JWT signing (min 32 chars) |
| `JWT_EXPIRY` | `24h` | | Access token TTL |
| `REFRESH_TOKEN_EXPIRY` | `7d` | | Refresh token TTL |
| `REDIS_URL` | `""` | | Redis connection string |
| `CORS_ORIGINS` | `*` | | Allowed CORS origins |
| `MIGRATE_ON_START` | `true` | | Auto-run GORM migrations on startup |
| `RESET_DB` | `false` | | Drop all tables before migration |
| `SEED_ON_START` | `false` | | Seed demo data (dev only) |
| `ENVIRONMENT` | `development` | | `development`, `staging`, `production` |
| `LOG_LEVEL` | `info` | | Logging verbosity |
| `UPLOAD_DIR` | `./uploads` | | File upload directory |

### 11.2 Production Requirements

```
DATABASE_URL=postgres://user:pass@postgres:5432/schooldesk?sslmode=require
JWT_SECRET=<32+ char random string>
REDIS_URL=redis://redis:6379
ENVIRONMENT=production
MIGRATE_ON_START=true
```

### 11.3 Development Defaults

```
# SQLite auto-used when DATABASE_URL is empty
ENVIRONMENT=development
MIGRATE_ON_START=true
SEED_ON_START=false
```

---

## 12. Deployment Guide

### 12.1 Docker Deployment

**Dockerfile** (multi-stage build):
```
Stage 1: golang:1.22-alpine → Build binary
Stage 2: alpine:3.19 → Copy binary + run
```

**docker-compose.yml**:
```yaml
services:
  backend:
    build: ./school-backend
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgres://user:pass@db:5432/schooldesk
      - JWT_SECRET=${JWT_SECRET}
      - REDIS_URL=redis://redis:6379
      - ENVIRONMENT=production
    depends_on:
      - db
      - redis
  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
  redis:
    image: redis:7-alpine
```

### 12.2 Coolify / VPS Deployment

See `deploy/COOLIFY_DEPLOYMENT.md` and `deploy/hostinger-traefik.env.example` for:
- Coolify: Set env vars, build pack = Docker Compose
- Hostinger: Traefik reverse proxy with SSL + Docker Compose
- Health check: `GET /api/v1/health`

### 12.3 Observability Overlay

Prometheus and Grafana are provided by `docker-compose.observability.yml`:

```bash
docker compose -f docker-compose.yml -f docker-compose.observability.yml --profile observability up -d
```

- Prometheus scrapes the Go API at `go-api:8080/metrics`.
- Grafana provisions the Prometheus datasource and `SchoolDesk API Overview`.
- Default local URLs are `http://127.0.0.1:9090` and `http://127.0.0.1:3000`.
- On VPS/Hostinger, keep both tools bound to localhost and open them through SSH tunnels unless a protected reverse proxy is configured.

### 12.4 Production Checklist

- [ ] `JWT_SECRET` = strong random string
- [ ] `DATABASE_URL` = PostgreSQL with SSL
- [ ] `ENVIRONMENT` = production
- [ ] `CORS_ORIGINS` = restricted to Flutter web domain
- [ ] Redis configured for caching + rate limiting
- [ ] Database migrations run on deploy (`MIGRATE_ON_START=true`)
- [ ] File uploads directory persisted or cloud storage
- [ ] Backup plan for PostgreSQL DB

---

## 13. Services Layer

### 13.1 Runtime Service (`internal/services/runtime.go`)
- Application runtime metadata
- Uptime tracking
- Metrics endpoint (`/metrics`)
- Prometheus-format metrics for backend/database/Redis up state, HTTP request counts and latency, 4xx/5xx counts, DB pool stats, queue pending length, and notification worker failures

### 13.2 Cache Service (`internal/services/cache.go`)
- Redis client wrapper
- Functions: `Get`, `Set`, `Delete`, `Exists`
- TTL-based expiration
- Used by `CacheMiddleware` for endpoint caching

### 13.3 Rate Limit Service (`internal/services/rate_limit.go`)
- In-memory + Redis-backed rate limiter
- Token-bucket algorithm
- Per-endpoint, per-user/IP tracking

### 13.4 Session Store (`internal/services/session_store.go`)
- Refresh token management
- Blacklisted token tracking
- Session revocation

### 13.5 Push Notification Service (`internal/services/push_notifications.go`)
- Firebase Cloud Messaging (FCM) integration
- Sends push notifications to device tokens
- Used for: exam schedules, announcements, fee reminders

### 13.6 Job Queue (`internal/services/job_queue.go`)
- In-process job queue
- Background processing for:
  - PDF report generation
  - Bulk notification dispatch
  - Fee generation

---

## 14. Testing Strategy

### 14.1 Test Structure

Tests are located in:
- `school-backend/tests/` — Integration test suite
- `school-backend/internal/handlers/*_test.go` — Handler tests
- `school-backend/internal/database/*_test.go` — DB tests
- `school-backend/internal/config/*_test.go` — Config tests

### 14.2 Test Database Setup

```go
// tests/api_suite_test.go
func prepareDatabase(path string) error {
    cfg := &config.Config{
        Environment:  "test",
        DatabaseDSN:  path,  // SQLite file
        JWTSecret:    "12345678901234567890123456789012",
        MigrateOnStart: true,
    }
    // Uses SQLite for fast, isolated test runs
}
```

### 14.3 Test Coverage

| Package | Coverage Areas |
|---------|---------------|
| **handlers/auth_test.go** | Login, register, refresh, password reset |
| **handlers/student_test.go** | CRUD, photo upload, enrollment, attendance |
| **handlers/staff_test.go** | CRUD, photo upload, leave balance |
| **handlers/attendance_test.go** | Bulk mark, staff attendance, QR verify |
| **handlers/fee_test.go** | CRUD, payment, concessions |
| **handlers/user_test.go** | List, avatar upload, role filters |
| **handlers/account_approval_test.go** | Approval workflow, rejection |
| **handlers/dashboard_test.go** | Role-scoped dashboard data |
| **database/constraints_test.go** | FK constraint validation |

### 14.4 Running Tests

```bash
# All tests
cd school-backend && go test ./...

# Specific package
cd school-backend && go test ./internal/handlers/...

# With coverage
cd school-backend && go test -cover ./internal/...
```

---

## Appendix A: Legacy Compatibility

The `compat_schema.go` file provides backward compatibility for older schema versions. It creates tables using traditional `CREATE TABLE IF NOT EXISTS` statements for:

- `teachers` (legacy teacher records, migrated to `staffs`)
- `classes` (legacy classes, migrated to `sections`)
- `attendance` (legacy attendance table)
- `timetable` (legacy timetable)
- `fees` (legacy fees table)
- `notices` (legacy announcements)
- `notifications` (legacy notifications)

These are maintained alongside the GORM-managed tables to ensure backward compatibility during the migration period.

---

## Appendix B: GORM Model Structure

All models are defined in `school-backend/internal/models/` organized by domain:

| File | Models |
|------|--------|
| `foundation.go` | School, AcademicYear, Term, Grade, Subject, Section, Room, Department, Holiday, WorkingDayConfig, Role, Permission |
| `auth.go` | User, UserSession, OTPVerification, AuditLog |
| `student.go` | Student, Guardian, MedicalRecord, StudentDocument, Enrollment, ParentStudentLink, TransferRecord |
| `staff.go` | Staff, StaffQualification, StaffSubject, StaffDocument |
| `attendance.go` | Attendance, StaffAttendance |
| `exam.go` | Exam, ExamType, ExamSchedule, StudentMark, ReportCard, GradingScale |
| `fee.go` | Fee, FeeCategory, FeeStructure, Concession |
| `hr_comms.go` | Leave, LeaveType, LeaveBalance, Announcement, Notification, DeviceToken |
| `library_transport.go` | LibraryBook, LibraryTransaction, TransportRoute, TransportStop, StudentTransportMapping |
| `homework.go` | Homework, HomeworkSubmission |
| `dto.go` | Create/Update request/response DTOs |
| `frontend_record.go` | FrontendRecord (dynamic data store) |
| `report_export.go` | ReportCardExport, ClassResultExport models |

---

## Appendix C: Visual ERD Diagrams

> 📊 **Full visual ERD diagrams are available in [`ERD_DIAGRAM.md`](./ERD_DIAGRAM.md)** (Mermaid format)

The ERD diagram file includes:

| Diagram | Tables | Description |
|---------|--------|-------------|
| **Layer 1: Foundation** | schools, academic_years, terms, grades, subjects, sections, roles, permissions, departments, rooms, holidays, working_day_configs | School configuration & setup |
| **Layer 2: Staff & Auth** | staffs, users, user_sessions, otp_verifications, audit_logs, device_tokens, staff_qualifications, staff_subjects, staff_documents | Staff management & authentication |
| **Layer 3: Students** | students, guardians, medical_records, enrollments, parent_student_links, transfer_records, promotion_rules | Student enrollment & profiles |
| **Layer 4: Operations** | attendance, timetable, fees, exams, marks, homework, leaves, announcements, notifications, PTM, library, transport | Day-to-day school operations |
| **Full Overview** | All tables in graph form | High-level relationship map |

To view:
- Open [`ERD_DIAGRAM.md`](./ERD_DIAGRAM.md) in any Mermaid-compatible viewer
- VS Code: install *Markdown Preview Mermaid Support*
- Browser: paste into [Mermaid Live Editor](https://mermaid.live/)

---

*This document is auto-generated from the SchoolDesk backend source code (`school-backend/`). For the most up-to-date information, refer to the actual source files and tests.*
