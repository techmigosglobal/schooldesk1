# Parent Role Workflow Audit

Date: 2026-06-12

## Role Summary

The Parent role is a linked-child self-service role. Parent access is restricted to children connected through parent-student links and to parent-facing operations such as fees, attendance, homework submissions, leave requests, communication, documents, calendar, and academic progress.

## Navigation And Screens

- Dashboard: `AppRoutes.parentDashboard`
- Fees and payment requests
- Attendance summary
- Homework and submissions
- Communication and parent-teacher chat
- Leave requests
- Calendar, documents, notices, timetable, exams, report cards, academic progress

## Backend Operations

- Dashboard: `GET /dashboard/parent`
- Child fees: `GET /fees/invoices`, parent payment request creation
- Attendance: child attendance summary and records
- Homework: read assigned homework and submit child work
- Leave: create student leave applications and view decisions
- Communication: parent-teacher meetings, message conversations, messages, notices

## Current Verification Notes

- Parent fee views consume generated invoices and show installment-style rows from backend invoices.
- Parent invoice visibility is scoped through parent-student links.
- Parent payment request decisions remain Admin/Principal owned after submission.
- Communication remains split between legacy conversations/messages and Tables.md `/communications` where applicable.

## Key Risks And Boundaries

- Parent must not read another child's attendance, fee invoices, homework, or report records.
- Parent-created records should remain requests/submissions, not direct administrative mutations.
- Payment status must update only through approved payment request or authorized payment verification flows.

