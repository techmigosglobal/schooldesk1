# Parent-Managed Student Access Blueprint

This is not a separate Student-account implementation contract. For the current
production release, students are represented inside the Parent login through
linked children and child switching. The Flutter route registry intentionally
does not include active Student routes.

## Current UX Focus

- Today view: timetable, current period, homework due, exam reminders, and
  notices for the selected linked child.
- Learning progress: subject cards, marks, attendance, teacher feedback, and
  downloadable reports through Parent screens.
- Parent-owned actions: submit homework evidence, message teachers, view diary
  notes, request documents, and submit linked-child leave or fee requests.

## Shell Expectations

- Use the same `SchoolDeskTheme` tokens as Principal, Admin, Teacher, and Parent.
- Mobile starts with the Parent dashboard and a clear linked-child selector.
- Tablet and desktop use the adaptive SchoolDesk shell with compact navigation.
- Unavailable student-facing workflows must stay disabled unless a real
  Parent-scoped backend endpoint exists.

## Activation Rule

Do not add `/student-dashboard-screen`, Student auth users, or other separate
Student routes for this production release. A future Student login would require
a separate product approval and all of the following:

- Student role in backend auth/RBAC.
- Student-scoped dashboard endpoint.
- Student-linked timetable, homework, attendance, marks, notices, and document
  endpoints.
- Manual QA accounts and test cases in the role-module matrix.
