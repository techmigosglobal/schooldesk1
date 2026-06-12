# Teacher Role Workflow Audit

Date: 2026-06-12

## Role Summary

The Teacher role is focused on assigned class operations: attendance, homework, diary, PTM, communication, syllabus, marks, student notes, and teacher self-attendance. Backend access is constrained by staff linkage, class/subject assignment, parent-student relationships, and school scope.

## Navigation And Screens

- Dashboard: `AppRoutes.teacherDashboard`
- Student attendance: `AppRoutes.teacherAttendance`
- Staff self-attendance and QR scan: `AppRoutes.teacherMyAttendance`
- Communication: `AppRoutes.teacherCommunication`
- Homework, diary, discipline, marks, performance, syllabus, student notes, leave, PTM

## Backend Operations

- Dashboard: `GET /dashboard/teacher`
- Student attendance: attendance sessions and marks for teacher-owned sections/subjects
- Staff QR attendance: `POST /attendance/staff/qr-scan`, `GET /attendance/staff/me/today`
- Communication: `/message-conversations`, `/messages`, `/communications`
- Homework/diary/PTM: shared CRUD with teacher ownership checks
- Academics: exams and mark entry where teacher owns the section/subject

## Communication UX Status

- Teacher communication now uses a responsive chat workspace.
- Desktop/tablet shows a thread rail and active chat pane side by side.
- Mobile shows either the thread list or the selected chat, with a back button and sticky composer.
- Existing backend contracts are preserved:
  - Parent/class chat: `/message-conversations` and `/messages`
  - Direct school messages: `/communications`

## Current Verification Notes

- `flutter analyze` passes after the communication screen refactor.
- Teacher QR scanning keeps the existing linked-staff path.
- Teacher cannot scan for arbitrary staff unless authenticated as the dedicated Kiosk role.

## Key Risks And Boundaries

- Teacher visibility must stay limited to assigned sections, subjects, linked class parents, and school-scoped communication targets.
- Teacher communication should not expose Admin/Principal-only user lists.
- QR attendance must continue rejecting unlinked Teacher accounts.

