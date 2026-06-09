# SchoolDesk FastAPI Database Schema

The FastAPI backend uses UUID string primary keys, school scope, audit metadata, and soft-delete fields for operational records.

## Goal & Task Tables

- `goals`: Principal-owned operational goals with `draft`, `active`, `completed`, and `archived` states.
- `goal_key_results`: measurable key results attached to a goal.
- `tasks`: operational tasks linked to a goal or standalone, with assignee, scope, priority, progress, evidence, blocker, and status fields.
- `task_checklist_items`: ordered checklist items for task execution.
- `task_comments`: internal comments and optional evidence URLs.

## Supporting Tables

- `schools`, `users`, `roles`, `permissions`, `role_permissions`, `user_roles`, `sections`
- `academic_years`, `academic_terms`, `grades`, `subjects`, and `rooms`: DB-backed school catalog records used by setup, timetable, attendance, exam, and class views.
- `staff`: staff directory rows linked to login-capable `users` when credentials are supplied.
- `students`: student directory rows with current section references and soft-delete status.
- `leave_types`, `leave_balances`, and `leave_applications`: staff leave catalog, balance, and Principal-decided request records.
- `student_leave_applications`: Parent-submitted student leave requests decided by Principal.
- `audit_logs`: records goal/task creation, updates, progress, comments, checklist changes, close, reopen, and archive actions.
- `notification_logs`: records task assignment notifications.
- `approval_requests`: generic Principal approval ledger for Admin-initiated operations. It stores requested payload/snapshots and decision notes. Marking a request as applied records the state only; it does not auto-apply sensitive module mutations.

Money fields are not part of this module. Future fee/payment modules must use PostgreSQL `NUMERIC`, never float.
