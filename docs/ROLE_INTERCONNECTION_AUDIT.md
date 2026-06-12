# Role Interconnection Audit

Date: 2026-06-12

## Principal To Teacher

- Principal oversees teacher-created attendance, homework, diary, timetable, exams, and class operations.
- Principal/Admin generates the staff attendance QR token; Teacher scans it for self punch-in.
- Staff punch-in creates notification logs for Principal/Admin.
- Teacher class and subject ownership is enforced before attendance or exam operations are accepted.

## Teacher To Parent

- Teacher communicates with class parents through `/message-conversations` and `/messages`.
- Teacher direct school communication also reads/sends through `/communications` where allowed.
- Homework, diary, PTM, marks, and attendance updates become parent-visible through linked-child workflows.
- Teacher communication UI now separates thread list and active chat on mobile to avoid crowded operation.

## Parent To Principal/Admin

- Parent submits fee payment requests; Admin/Principal review and decide.
- Admin decisions may generate Principal approval records depending on workflow state.
- Parent leave and homework submissions are visible to authorized school staff.
- Parent access is limited by parent-student links and school scope.

## Attendance QR Flow

- Principal/Admin: create/display staff QR token using `GET /attendance/staff/qr-token`.
- Teacher: scan QR using linked staff identity with `POST /attendance/staff/qr-scan`.
- Kiosk: scan QR using a school-scoped Kiosk account and submitted `staff_id`.
- Duplicate same-day punch-in remains idempotent and does not create extra attendance rows.

## Fee Installment Flow

- Principal/Admin creates fee structures with optional `installment_count`.
- If omitted or invalid, backend defaults to `3`.
- Invoice generation accepts selected `installment_count` and splits term-wise tuition accordingly.
- Parent sees generated invoices and pays/submits requests against installment balances.

## Communication Surfaces

- Legacy chat: `/message-conversations` plus `/messages`.
- Direct school communication: `/communications`.
- Announcements/notices and notification logs connect school broadcast and event routing.

## Shared Safeguards

- All role workflows depend on `AuthMiddleware` and `SchoolScopeMiddleware`.
- RBAC gates route access; handler-level ownership checks enforce student, parent, staff, class, and school relationships.
- Audit logs and notification logs record critical operational changes where handlers support them.

