# Principal Role Workflow Audit

Date: 2026-06-12

## Role Summary

The Principal role is the school-level approval, oversight, and operations owner. The frontend route guard allows principal-only and shared management routes, while the backend grants Principal access to dashboard, academic, attendance, fees, communication, people, reports, and approval workflows through RBAC and school-scoped handlers.

## Navigation And Screens

- Dashboard: `AppRoutes.principalDashboard`
- Academics: classes, subjects, exams, timetable, syllabus monitoring, command center
- Attendance: student/staff attendance oversight and staff QR display
- Communication: chat communications, notifications, notices, PTM visibility
- Finance: fee monitoring, fee structures, invoice generation, payment request decisions
- People: staff, students, guardians, approvals, user access
- Reports/profile/settings: analytics, report generation, school profile, settings

## Backend Operations

- Dashboard: `GET /dashboard/principal`
- Attendance: `GET /attendance/staff`, `GET /attendance/staff/qr-token`, staff manual marking, reports exports
- Fees: categories, structures, invoice generation, invoices, payments, payment requests
- Academics: classes, subjects, timetable, exams, report cards, homework/diary oversight
- Communication: `/communications`, `/message-conversations`, `/messages`, announcements, notifications
- People and approvals: users, staff, students, guardians, approval requests, class/student approvals

## Current Verification Notes

- Principal can generate staff attendance QR tokens; scan remains blocked for Principal and is delegated to Teacher or Kiosk.
- Principal/Admin fee setup supports `installment_count`; omitted or invalid values default to `3`.
- Principal fee generation can split term-wise tuition into selected installments.
- Principal communication uses the school-scoped direct communication contract on `/communications`.

## Key Risks And Boundaries

- Principal access must remain school scoped through `SchoolScopeMiddleware`.
- Principal can approve operational changes but should not bypass parent/student ownership checks.
- Staff QR token display must remain Principal/Admin only; scan recording is intentionally separated.
- Fee payment decisions initiated by Admin may require Principal approval depending on approval workflow state.

