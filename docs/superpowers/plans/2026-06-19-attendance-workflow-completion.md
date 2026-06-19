# Attendance Workflow Completion Plan

## Goal

Complete the student attendance module across Teacher, Principal, and Parent roles so each role has a clear responsibility boundary and the data lifecycle is explicit.

## Scope

- Teacher records only their assigned class for the day, saves draft or submits final, and requests correction after lock.
- Principal monitors class/period status, reviews student-wise rows, reopens with reason, sends reminders, exports register, and views audit context.
- Parent sees only their own child attendance with today status, monthly summary, day-wise/period-wise rows, and leave requests.

## Implementation Steps

1. Backend lifecycle
   - Add attendance session lifecycle fields: `draft`, `submitted`, `reopened`, `needs_review`, `corrected`; compute `not_started` for missing sessions.
   - Keep `is_finalized` for backward compatibility and lock behavior.
   - Support draft marking through `finalize: false`; submit through `finalize: true`.
   - Require `reason` for Absent, Late, Leave, and Half Day.
   - Add teacher correction request endpoint and principal reopen metadata.

2. Backend parent data
   - Return parent-safe day-wise and period-wise attendance rows from actual student attendance records.
   - Include leave and half-day counts.
   - Merge approved leave requests into summary/day data when attendance rows do not already exist.

3. Flutter teacher UI
   - Stop creating sessions on screen open.
   - Create sessions only when saving draft or submitting final.
   - Add statuses: Present, Absent, Late, Leave, Half Day.
   - Capture and send `reason` for non-present statuses.
   - Add Save Draft, Submit Final, and Request Correction.

4. Flutter principal UI
   - Rename to Student Attendance Monitor.
   - Show status language and counts.
   - Add Reopen Attendance, Send Reminder, Export Class Register, and Audit Trail actions.
   - Keep staff check-in language separate.

5. Flutter parent UI
   - Rename to My Child Attendance.
   - Load actual attendance records.
   - Build calendar and timeline from day-wise/period-wise rows.
   - Add tappable day detail.

6. Verification
   - Add focused backend handler tests and Flutter contract tests.
   - Run targeted `go test`, `flutter test`, and `dart analyze` for touched files.
