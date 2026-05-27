# School ERP Foundation Table Map

This file is a working reference for the foundation data tables required in this school management ERP application. It does not change the backend implementation. It explains the existing backend table structure in a cleaner order and shows how important columns link to other tables, roles, and modules.

## Purpose

The goal of this file is to reduce confusion while reviewing the Principal, Admin, Teacher, and Parent modules.

It should help answer:

- Which setup tables are needed first after creating a school?
- Which tables are pure foundation tables?
- Which columns link one table to another?
- Which role or module depends on each table?
- Where does the UI say "class" but the backend stores it as `grades` and `sections`?

## Important Naming Note: Classes

The current backend does not use a separate `classes` table in the main foundation schema.

Instead, class structure is represented like this:

```text
grades
  -> sections
```

Meaning:

```text
Grade 10 = class level
Grade 10 - A = actual class/division/section
```

So when the Principal UI says "Classes", the backend usually stores that data in:

```text
grades
sections
```

This should be displayed clearly in the Principal UI/UX as "Classes & Sections" or similar, even if the backend implementation remains unchanged.

## Recommended Foundation Setup Order

This is the practical order a school ERP should follow after school creation:

| Order | Setup Area | Backend Tables | Why It Comes Here |
|---:|---|---|---|
| 1 | School profile | `schools` | Every table is scoped to a school. |
| 2 | Academic calendar | `academic_years`, `terms` | Classes, exams, attendance, fees, and reports depend on academic year context. |
| 3 | Access control | `roles`, `permissions` | Users need roles before accounts can be safely created. |
| 4 | Departments | `departments` | Staff and subjects may be linked to departments. |
| 5 | Rooms/resources | `rooms` | Sections, timetable, labs, and classrooms can use room data. |
| 6 | Class levels | `grades` | Represents Grade/Class level, such as Grade 1 or Grade 10. |
| 7 | Class divisions | `sections` | Represents divisions like A, B, C under a grade. |
| 8 | Subjects | `subjects` | Academic subjects offered by the school. |
| 9 | Grade-subject mapping | `grade_subjects` | Defines which subjects belong to which grade/class level. |
| 10 | Working calendar | `working_day_configs`, `holidays` | Controls school days, holidays, attendance, timetable, and events. |

## Foundation Relationship Overview

```text
schools
  -> academic_years
      -> terms
      -> sections
      -> enrollments
      -> exams
      -> timetable_slots

schools
  -> roles
      -> permissions
      -> users

schools
  -> grades
      -> sections
          -> enrollments
          -> attendance
          -> timetable_slots
          -> homework
          -> exam_schedules
          -> staff_subjects

schools
  -> subjects
      -> grade_subjects
      -> staff_subjects
      -> timetable_slots
      -> homework
      -> exam_schedules

schools
  -> departments
      -> staffs
      -> subjects

schools
  -> rooms
      -> sections
      -> timetable_slots

schools
  -> holidays
  -> working_day_configs
```

## Foundation Tables

### 1. `schools`

Main school/tenant table. Almost every important table is connected to a school either directly with `school_id` or indirectly through another school-scoped table.

| Item | Details |
|---|---|
| Main purpose | Stores school profile and tenant identity. |
| Key linked columns | `id` is referenced by `school_id` in many tables. |
| Used by roles | Admin, Principal, Teacher, Parent. |
| Principal relevance | Principal profile, school dashboard, governance, academic setup. |
| Important linked tables | `academic_years`, `roles`, `subjects`, `grades`, `departments`, `rooms`, `holidays`, `working_day_configs`, `staffs`, `students`. |

### 2. `academic_years`

Stores the academic session, such as `2025-2026`.

| Item | Details |
|---|---|
| Main purpose | Defines the active academic year/session. |
| Key linked columns | `school_id -> schools.id`. |
| Used by roles | Admin, Principal, Teacher, Parent. |
| Principal relevance | Principal needs this before classes, sections, exams, attendance, fees, and reports make sense. |
| Important linked tables | `terms`, `sections`, `enrollments`, `exams`, `timetable_slots`, `leave_balances`, `fee_structures`. |

### 3. `terms`

Stores smaller periods inside an academic year, such as Term 1, Term 2, or Term 3.

| Item | Details |
|---|---|
| Main purpose | Divides an academic year into report/exam/planning periods. |
| Key linked columns | `academic_year_id -> academic_years.id`. |
| Used by roles | Principal, Admin, Teacher, Parent indirectly through exams/reports. |
| Principal relevance | Should help term-wise academics, results, attendance summaries, and syllabus tracking. |
| Important linked tables | Currently linked directly to `academic_years`; can support exams, report cards, syllabus, fees, and attendance analytics. |
| UI/UX note | Backend has this table, but Principal UI exposure is not clearly noticed yet. |

### 4. `roles`

Stores user role types for each school, such as Admin, Principal, Teacher, Parent, Accountant, Librarian.

| Item | Details |
|---|---|
| Main purpose | Defines who a user is in the school. |
| Key linked columns | `school_id -> schools.id`; `users.role_id -> roles.id`. |
| Used by roles | Admin and Principal manage/view user access; all users depend on a role. |
| Principal relevance | Determines whether a user enters Principal module, Teacher module, Parent module, etc. |
| Important linked tables | `permissions`, `users`. |

### 5. `permissions`

Stores what a role can do inside a module.

| Item | Details |
|---|---|
| Main purpose | Fine-grained access control for modules and actions. |
| Key linked columns | `role_id -> roles.id`. |
| Used by roles | Admin, Principal, Teacher, Parent. |
| Principal relevance | Controls whether Principal can read/create/update/delete in modules where `PermissionMiddleware` is used. |
| Important linked tables | `roles`. |
| Implementation note | Current code uses action fields like `can_read`, `can_create`, `can_update`, `can_delete`, `can_export`; some docs mention `can_view`, `can_edit`, `can_approve`, so this should be reviewed later. |

### 6. `departments`

Stores school departments, such as Science, Mathematics, Administration, Transport, Library, etc.

| Item | Details |
|---|---|
| Main purpose | Organizes staff and subjects by department. |
| Key linked columns | `school_id -> schools.id`; `head_staff_id` or `hod_staff_id -> staffs.id` depending on model/version. |
| Used by roles | Admin, Principal, Teacher indirectly. |
| Principal relevance | Helps Principal manage staff and academic departments. |
| Important linked tables | `staffs`, `subjects`. |

### 7. `rooms`

Stores rooms and physical resources such as classrooms, labs, library rooms, and offices.

| Item | Details |
|---|---|
| Main purpose | Defines physical spaces used by classes and timetables. |
| Key linked columns | `school_id -> schools.id`. |
| Used by roles | Admin, Principal, Teacher indirectly. |
| Principal relevance | Useful for class setup, room allocation, timetable planning, and capacity review. |
| Important linked tables | `sections`, `timetable_slots`. |

### 8. `grades`

Represents the class level, such as Grade 1, Grade 5, Grade 10.

| Item | Details |
|---|---|
| Main purpose | Stores class/grade level. |
| Key linked columns | `school_id -> schools.id`; `next_grade_id -> grades.id` for promotion flow. |
| Used by roles | Admin, Principal, Teacher, Parent indirectly. |
| Principal relevance | Principal expects this as part of class setup. |
| Important linked tables | `sections`, `grade_subjects`, `fee_structures`, `exam_schedules`, `promotion_rules`. |
| UI/UX note | In UI language, this may need to appear as "Class Level" rather than only "Grade". |

### 9. `sections`

Represents a class division under a grade, such as Grade 10 A or Grade 10 B.

| Item | Details |
|---|---|
| Main purpose | Stores actual class divisions/sections. |
| Key linked columns | `grade_id -> grades.id`; `academic_year_id -> academic_years.id`; `class_teacher_id -> staffs.id`; `room_id -> rooms.id` where supported. |
| Used by roles | Principal, Admin, Teacher, Parent indirectly. |
| Principal relevance | This is the closest current backend equivalent to a "classes" table. |
| Important linked tables | `enrollments`, `attendance`, `timetable_slots`, `homework`, `exam_schedules`, `diary_entries`, `staff_subjects`. |
| UI/UX note | Principal class creation should clearly create/select grade plus section, not hide the section model. |

### 10. `subjects`

Stores subjects offered by the school.

| Item | Details |
|---|---|
| Main purpose | Defines school-wide subjects such as Math, Science, English. |
| Key linked columns | `school_id -> schools.id`; `department_id -> departments.id` where supported. |
| Used by roles | Principal, Admin, Teacher, Parent indirectly. |
| Principal relevance | Used in Principal Subjects, timetable, exams, homework, and academic analytics. |
| Important linked tables | `grade_subjects`, `staff_subjects`, `timetable_slots`, `homework`, `exam_schedules`. |

### 11. `grade_subjects`

Maps subjects to a grade/class level.

| Item | Details |
|---|---|
| Main purpose | Defines curriculum per grade/class level. |
| Key linked columns | `grade_id -> grades.id`; `subject_id -> subjects.id`. |
| Used by roles | Principal, Admin, Teacher indirectly. |
| Principal relevance | Principal can understand which subjects are taught in each class level. |
| Important linked tables | `grades`, `subjects`; later connected operationally through `staff_subjects`, `exam_schedules`, `homework`, and `timetable_slots`. |
| Example | Grade 10 has Math, Science, English, Social Studies. |

### 12. `working_day_configs`

Defines which days are working days and what the school timing structure looks like.

| Item | Details |
|---|---|
| Main purpose | Stores weekly working-day setup. |
| Key linked columns | `school_id -> schools.id`. |
| Used by roles | Admin, Principal, Teacher indirectly. |
| Principal relevance | Impacts timetable, attendance, academic planning, and events. |
| Important linked tables | Supports attendance/timetable logic indirectly. |

### 13. `holidays`

Stores holidays and school closure days.

| Item | Details |
|---|---|
| Main purpose | Defines holiday calendar. |
| Key linked columns | `school_id -> schools.id`; `academic_year_id -> academic_years.id` where supported. |
| Used by roles | Admin, Principal, Teacher, Parent. |
| Principal relevance | Used by calendar, attendance planning, event visibility, and academic scheduling. |
| Important linked tables | `academic_years`, `events`, attendance/timetable modules indirectly. |

## Key Linking Columns To Remember

| Column | Meaning | Common Tables |
|---|---|---|
| `school_id` | Tenant/school ownership. Prevents cross-school data mixing. | `academic_years`, `roles`, `users`, `students`, `staffs`, `subjects`, `grades`, `departments`, `rooms`, `holidays`. |
| `academic_year_id` | Academic session context. | `terms`, `sections`, `enrollments`, `exams`, `timetable_slots`, `fee_structures`. |
| `role_id` | User access role. | `users`, `permissions`. |
| `grade_id` | Class level link. | `sections`, `grade_subjects`, `fee_structures`, `exam_schedules`, `promotion_rules`. |
| `section_id` | Actual class/division link. | `enrollments`, `attendance`, `timetable_slots`, `homework`, `staff_subjects`, `exam_schedules`. |
| `subject_id` | Academic subject link. | `grade_subjects`, `staff_subjects`, `timetable_slots`, `homework`, `exam_schedules`. |
| `staff_id` / `class_teacher_id` | Staff/teacher responsibility link. | `sections`, `staff_subjects`, `attendance_sessions`, `timetable_slots`, `parent_teacher_meetings`. |
| `student_id` | Student-level operational link. | `enrollments`, `attendance`, `fees`, `student_marks`, `report_cards`, `student_leaves`, `parent_student_links`. |
| `parent_user_id` | Parent account link. | `parent_student_links`, `parent_teacher_meetings`. |

## Role Dependency View

| Role | Foundation Data They Depend On | Reason |
|---|---|---|
| Admin | All foundation tables | Admin configures and governs the school ERP. |
| Principal | `schools`, `academic_years`, `terms`, `grades`, `sections`, `subjects`, `grade_subjects`, `departments`, `rooms`, `holidays`, `working_day_configs`, `roles`, `permissions` | Principal needs school-wide academic and governance visibility. |
| Teacher | `academic_years`, `grades`, `sections`, `subjects`, `grade_subjects`, `staff_subjects`, `rooms`, `working_day_configs`, `holidays` | Teacher work is tied to assigned sections, subjects, timetable, attendance, and homework. |
| Parent | `academic_years`, `grades`, `sections`, `subjects`, `holidays` indirectly through linked student | Parent sees child academics, attendance, homework, fees, calendar, and reports. |
| Student | `academic_years`, `grades`, `sections`, `subjects` indirectly through enrollment | Student portal is future-facing but would depend on enrollment and academic setup. |
| Accountant | `academic_years`, `grades`, `fee_categories`, `fee_structures` | Fee setup usually depends on academic year and grade/class level. |
| Librarian | `roles`, `permissions`, `students`, `staffs` indirectly | Library issue/return depends on borrower identity and access rules. |

## Principal First-Time Setup View

From a Principal UI/UX perspective, the first-time setup should probably appear in this order:

```text
1. School Profile
2. Academic Year
3. Terms
4. Classes & Sections
5. Subjects
6. Class Subject Mapping
7. Departments
8. Rooms
9. Working Days
10. Holidays
11. Staff/Teacher Accounts
12. Student Admissions
```

This does not require a new backend `classes` table. It means the UI should present `grades + sections` in a Principal-friendly way.

## Notes For Future Review

- There is no main `classes` table; current class structure is `grades + sections`.
- `terms` exists in the backend foundation schema, but Principal UI exposure is not clearly visible yet.
- Role and permission documentation should be aligned with actual model fields if the current code remains the source of truth.
- Any future UI should show linked data clearly. For example, when viewing a section, show its grade, academic year, class teacher, room, enrolled students, timetable, and subjects.
