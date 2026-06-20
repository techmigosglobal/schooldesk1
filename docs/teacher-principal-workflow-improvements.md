# Teacher Principal Workflow Improvements

This checklist tracks the teacher and principal role workflow fixes. Mark items only after implementation and verification.

## Attendance Accuracy

- [x] Stop defaulting teacher attendance rows to Present.
- [x] Add a local Not Marked state for untouched students.
- [x] Keep All Present as an explicit teacher action.
- [x] Block final submission until every student is marked.
- [x] Save drafts with only explicitly marked students.
- [x] Hydrate saved attendance rows when a draft, submitted, reopened, or corrected session is loaded.
- [x] Show incomplete or partially marked sessions clearly in the principal monitor.
- [x] Replace raw subject/staff IDs with readable labels in principal attendance detail.
- [x] Align backend audit action tests with save_draft, submit, reopen, and correction_request.

## Daily Workflows

- [x] Add a teacher daily action surface for attendance, diary, homework, PTM, and leave status.
- [x] Add a principal daily action queue for pending attendance, corrections, event approvals, leave, fees, and account approvals.
- [x] Improve empty states when teacher class, timetable, or subject assignment is missing.

## Role Handoffs

- [x] Verify principal class/subject/class-teacher setup flows into teacher classes, timetable, attendance, and lesson planner.
- [x] Make correction/reopen flow easy to understand from both teacher and principal screens.
- [x] Ensure event post submission, principal approval, and calendar/gallery visibility are clearly connected.

## Communication

- [x] Reduce overlap between Communication, Chat Communications, Diary Feedback, and Homework Messaging labels.
- [x] Keep teacher labels task-based and principal labels oversight-based.

## Performance

- [x] Remove one-by-one enrollment loading from teacher attendance or replace it with a bulk/data-included path.

## Verification

- [x] Add source contract coverage for no default Present attendance behavior.
- [x] Add/adjust backend attendance API tests for audit and lifecycle behavior.
- [x] Run targeted Flutter attendance tests.
- [x] Run targeted backend attendance tests.
- [x] Run `flutter analyze`.
