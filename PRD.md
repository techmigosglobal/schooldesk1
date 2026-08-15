# SchoolDesk — Product Requirements Document (Role-Based)

**Version:** 2.0  
**Status:** Canonical product definition  
**Product:** SchoolDesk — School ERP (Flutter mobile-first + limited web portal)  
**Business model:** One school, multiple branches  
**Backend:** Supabase (PostgreSQL + Edge Functions + Realtime)  
**Last updated:** August 2026  

---

## Table of Contents

1. [Product Definition](#1-product-definition)
2. [Core Product Principles](#2-core-product-principles)
3. [Role Overview & Access Matrix](#3-role-overview--access-matrix)
4. [Role 1 — Principal](#4-role-1--principal)
5. [Role 2 — Coordinator](#5-role-2--coordinator)
6. [Role 3 — Teacher (Class Teacher & Co-Teacher)](#6-role-3--teacher-class-teacher--co-teacher)
7. [Role 4 — Parent](#7-role-4--parent)
8. [Shared Cross-Role Features](#8-shared-cross-role-features)
9. [Feature Implementation Audit](#9-feature-implementation-audit)
10. [Data, Security & Privacy](#10-data-security--privacy)
11. [UX & Accessibility Requirements](#11-ux--accessibility-requirements)
12. [Current Scope vs. Future Scope](#12-current-scope-vs-future-scope)
13. [Known Issues & Release Gates](#13-known-issues--release-gates)
14. [Acceptance Criteria](#14-acceptance-criteria)
15. [Source-of-Truth Implementation Locations](#15-source-of-truth-implementation-locations)

---

## 1. Product Definition

SchoolDesk is a backend-backed school ERP that manages one school across multiple branches. It handles school governance, people management, academics, attendance, communication, fees, documents, reports, admissions, and the public school website.

**Platform delivery:**
- **Flutter mobile application** — the complete operational product for all roles
- **Web portal** — intentionally limited to Principal and Coordinator leadership workflows only
- **Public school website** — content managed via the app/portal, rendered publicly

**Authoritative rule:** Supabase data and server-side authorization are always authoritative. The UI must never present mock data as live school data, silently hide backend failures, or grant access based only on client-selected roles or branch parameters.

---

## 2. Core Product Principles

| Principle | Description |
|-----------|-------------|
| **Backend authority** | Supabase data and Edge Function server-side authorization are the single source of truth. No client-only role or branch trust. |
| **Branch isolation** | Every read, write, export, upload, and report is scoped to the authenticated user's active branch. |
| **Explicit states** | Every surface must show Loading, Empty, Error, Retry, Success, Conflict, and Permission-Denied states visibly. |
| **Role clarity** | Users see only workflows their authenticated role and branch permit. Navigation is role-scoped at session level. |
| **Mobile completeness** | All roles have a fully operational mobile experience. Web is limited to leadership. |
| **Safe operations** | Financial history, identity data, documents, and access changes require auditable, atomic, recoverable operations. |
| **Immutable finance** | Financial history is immutable. Corrections must be auditable atomic reversals, never physical row deletes. |
| **No demo data in production** | Demo role selection for QA must not bypass production authorization or inject data into live school records. |

---

## 3. Role Overview & Access Matrix

### 3.1 Role Summary

| Role | Scope | Mobile | Web |
|------|-------|--------|-----|
| **Principal** | Entire school; switches between branches; owns all governance + fees | Full operations | Full leadership portal including Fees |
| **Coordinator** | One assigned branch; operates like Principal without Fees access | Full operations except Fees | Same as Principal minus Fees |
| **Class Teacher** | Assigned classes; primary class owner; marks attendance, posts diary | Yes | No |
| **Co-Teacher** | Supporting role in assigned classes; limited write access | Yes | No |
| **Parent** | Linked child(ren); family-facing workflows | Yes | No |
| **Super Admin** | Platform-level school, access, monitoring, issue & audit administration | Yes (system scope) | No current school portal |
| **Kiosk User** | QR-based attendance capture only | Kiosk screen only | No |

### 3.2 Branch Access Rules

- **Principal:** Can access all branches; must select one active branch before viewing or mutating branch-scoped data. Cross-branch roll-up dashboards are future scope.
- **Coordinator:** Assigned to exactly one branch; cannot switch branches; all operations are automatically scoped to the assigned branch.
- **Teacher:** Operates within their assigned classes; branch context is derived from class assignment.
- **Parent:** Operates within the branch where their linked child is enrolled.

### 3.3 Role Naming Conventions

- **Coordinator** is the current product name for the former "Admin" role. "Admin" must not appear in new UI, navigation, documentation, or permission labels.
- Legacy database and API values may use "admin" internally for compatibility; the product-facing term is always "Coordinator."
- **Class Teacher** and **Co-Teacher** are sub-types of the Teacher role. Both share the `teacher` auth role but differ in ownership permissions on a per-class basis.

---

## 4. Role 1 — Principal

### 4.1 Identity & Context

- Authenticates via Principal sign-in flow (`/principal-login-screen`)
- Session resolves role and branch membership from server-controlled data
- Must select an active branch before any branch-scoped operation
- Receives a Principal Dashboard as first authenticated screen (`/principal-dashboard-screen`)

### 4.2 Dashboard

**Features:**
- School-wide KPI summary for the selected branch (students, attendance rate, fee collection, pending approvals)
- Quick-action tiles: Attendance Overview, Pending Approvals, Fee Monitoring, Recent Complaints
- Branch selector — visible only to Principal; switching branch invalidates all cached reads
- Notification badge for pending approvals, payment requests, complaints, and system alerts
- Real-time invalidation subscription via Supabase Realtime (invalidation signals only; clients refresh through scoped APIs)

**Implementation status:** IMPLEMENTED (`/principal-dashboard-screen`, `dashboard.ts` handler)

### 4.3 Governance

#### 4.3.1 School Profile
- View and edit school name, logo, contact details, address, motto, and branch-level settings
- Upload signed authorized signature for receipts and reports
- **Status:** IMPLEMENTED (`/principal-school-profile-screen`)

#### 4.3.2 User Management & Access Permissions
- Create, edit, deactivate, and delete user accounts (Principal, Coordinator, Teacher, Parent, Kiosk)
- Assign roles, branch memberships, and class assignments
- Assign children to parent accounts (explicit relationship, never name-based guessing)
- View and manage access permissions per user
- All account mutations are audited
- **Status:** IMPLEMENTED (`/principal-user-management-screen`, `users.ts` + `access.ts` handlers)

#### 4.3.3 Approval Center
- Review and action all pending approval requests (leave, event posts, payment requests, etc.)
- Approval history with audit trail
- **Status:** IMPLEMENTED (`/approval-center-screen`, `approvals.ts` handler)

#### 4.3.4 Audit Logs
- View all security-sensitive actions, finance operations, branch changes, imports, exports, approvals, and account changes
- Filterable by date, user, event type, and module
- **Status:** IMPLEMENTED (`/principal-audit-logs-screen`, `activity.ts` handler)

### 4.4 People Management

#### 4.4.1 Staff & Teacher Directory
- Staff list with search, filter by role/class/status
- Staff profile: personal info, documents, assigned classes, attendance record
- Create, edit, and manage staff records
- Staff document upload and management (private, signed URL access)
- **Status:** IMPLEMENTED (`/staff-management-screen`, `staff.ts` handler)

#### 4.4.2 Student Directory & Oversight
- Student list with search, filter by class/section/status/academic year
- Student profile: personal info, guardians, documents, photo, admission details, lifecycle status
- Admission operations: new student intake, status transitions
- Manual student spreadsheet pull/push (Google Sheets controlled fallback)
- CSV fallback import where implemented
- Exclude QA/test accounts from operational totals
- **Status:** IMPLEMENTED (`/student-oversight-screen`, `students.ts` handler)

#### 4.4.3 Parent/Guardian Directory
- Parent list with search and filter
- Guardian profiles with linked child assignments
- **Status:** IMPLEMENTED (`/guardian-directory-screen`, `principal.ts` handler)

#### 4.4.4 Admission Inquiries
- View and manage admission inquiry submissions from the public website
- Change inquiry status (new, contacted, enrolled, rejected)
- **Status:** IMPLEMENTED (`/admission-inquiries-screen`, `principal.ts` handler)

### 4.5 Academics

#### 4.5.1 Class Hub
- Create and manage grades, sections, and class configurations
- Assign class teachers and co-teachers per section
- Map subjects to classes and academic years
- Set room assignments
- Academic year and term management
- Curriculum creation and management
- **Status:** IMPLEMENTED (`/principal-classes-screen`, `academics.ts` handler)

#### 4.5.2 Subjects
- Create, edit, and manage subjects
- **Status:** IMPLEMENTED (`/principal-subjects-screen`)

#### 4.5.3 Timetable Management
- **Class-first workflow:** Class is the primary object; class teacher is locked per class
- Create, edit, and preview timetable slots per class per day
- Slot types: `regular`, `teaching`, `break`, `free` (break/free do not require a subject)
- Manual slot editor: subject, start time, end time, room, slot type
- **Preview before publish:** All manual changes must be previewed before publishing
- **Copy Day:** Replaces target-day rows, then creates copied rows from source day; requires target selection and confirmation
- Export timetable from the class workflow
- **Status:** IMPLEMENTED (`/principal-timetable-screen`, `timetable.ts` handler)

#### 4.5.4 Lesson Planners
- View and manage lesson planners for all classes in the branch
- **Status:** IMPLEMENTED (`/principal-lesson-planner-screen`)

#### 4.5.5 Academic Records & Reports
- Academic year detail, classwise export, users-wise export, fees export
- **Status:** IMPLEMENTED (`/academic-management-screen`, `reports.ts` handler)

### 4.6 Attendance (Principal Oversight)

- **Overview:** Branch-level attendance dashboard, session list, and daily summary
- **Corrections:** Reopen closed sessions, apply attendance corrections with audit trail
- **Reminders:** Send attendance reminders to teachers who have not completed marking
- **History & Audit:** View full attendance history per student, per class, per date
- **Exports:** Export attendance data (CSV, PDF)
- **Staff attendance:** View staff check-in/check-out records and attendance logs
- **Status:** IMPLEMENTED (`/principal-attendance-screen`, `attendance.ts` handler)

### 4.7 Finance (Principal Only — Coordinator Excluded Entirely)

> WARNING: The Coordinator must not see, navigate to, query, or mutate any Fees feature. This exclusion applies to navigation, direct routes, dashboard actions, reports, and API responses.

#### 4.7.1 Fee Structures
- Create and manage fee categories (tuition, transport, daycare, etc.)
- Create fee structures with installment schedules per academic year per class
- **Status:** IMPLEMENTED (`/principal/fee-structures`, `/fee-structures-screen`, `fees.ts` handler)

#### 4.7.2 Fee Ledger & Student Invoices
- View student fee ledger: outstanding, paid, and overdue balances
- Invoice generation and management
- Fee concessions: apply, review, and audit concessions per student
- Balance-first display (total due shown before payment history)
- **Status:** IMPLEMENTED (`/fee-ledger-screen`, `/fee-monitoring-screen`, `fees.ts` handler)

#### 4.7.3 Payment Recording (Offline/Cash)
- Record cash/offline payments against student invoices
- Payment must be idempotent, atomic, auditable, and secure
- Automatic receipt snapshot generation on payment confirmation
- **Status:** IMPLEMENTED (`/principal/collect-fee`, `/fee-collect-screen`, `fees.ts` handler)

#### 4.7.4 Payment Requests & Proofs
- Review parent-submitted payment requests with uploaded proof images
- Approve or reject payment requests with reason
- View payment request history and decisions
- **Status:** IMPLEMENTED (`/principal/payment-requests`, `fees.ts` handler)

#### 4.7.5 Receipts & Finance Documents
- View and download payment receipts per student per payment
- Private finance documents served through authorized signed URLs only
- **Status:** IMPLEMENTED (`fees.ts` handler, `20260729173723_automatic_payment_receipt_snapshots.sql`)

#### 4.7.6 Payment Configuration
- Configure payment methods accepted by the school (offline, QR, bank transfer)
- **Status:** IMPLEMENTED (`/principal/payment-config`, `fees.ts` handler)

#### 4.7.7 Finance Safety Rules
- Financial history is **immutable**; no physical deletion of payment rows, receipts, or finance snapshots
- A correction or reversal must be an auditable, atomic operation
- The current payment-delete path that physically deletes rows is a **known critical issue** (see Section 13)

### 4.8 Communications

- **Messages / Chat:** Leadership-to-all, leadership-to-teacher, leadership-to-parent conversations
- **Complaints:** View, manage, and respond to complaints from parents and teachers
- **Event Posts & School Feed:** Create, edit, delete, and approve school posts and announcements
- **School Post Approvals:** Review teacher-submitted event posts; approve or reject
- **Calendar & Events:** Create and manage school calendar events
- **Gallery:** Upload and manage school photo/video gallery; set public gallery visibility
- **Notification Preferences:** Manage push notification settings
- **Status:** IMPLEMENTED (`/communication-center-screen`, `/principal-chat-communications-screen`, `communications.ts` handler)

### 4.9 Documents & Records

- Upload and manage school-level documents
- ID card generation for students and staff
- Report generation and exports (PDF, CSV)
- **Status:** IMPLEMENTED (`/principal-documents-screen`, `/id-card-generation-screen`, `uploads.ts` + `report_pdf.ts`)

### 4.10 System Monitoring

- System health monitor (error events, API response summaries)
- Available to Principal within the mobile app
- **Status:** IMPLEMENTED (`/system-monitor-screen`, `monitoring.ts` handler)

### 4.11 Web Portal (Principal)

The web portal provides a limited operational surface for desktop access:

| Module | Available |
|--------|-----------|
| Overview (Dashboard) | YES |
| Students | YES |
| Parents | YES |
| Teachers | YES |
| Classes & Subjects | YES |
| Timetables | YES |
| Reports | YES |
| Admission Inquiries | YES |
| Public Website | YES |
| Fees | YES (Principal only) |

---

## 5. Role 2 — Coordinator

### 5.1 Identity & Context

- Authenticates via Principal/Coordinator sign-in flow
- Assigned to exactly **one branch**; cannot switch branches
- Dashboard is the first authenticated screen (`/coordinator-dashboard-screen`)
- Coordinator is the product term for the former "Admin" role; never show "Admin" in UI

### 5.2 Scope of Access

The Coordinator has identical operational access to the Principal within their assigned branch, **with the sole exception that all Finance/Fees features are completely excluded.**

**Explicitly excluded from Coordinator:**
- Navigation items for Fees
- Dashboard cards related to fees or payment collection
- Any API responses from fee-related endpoints
- Report exports that include financial data
- Any payment-related approval workflows

### 5.3 Dashboard

- Branch KPI summary (students, attendance, pending approvals, recent communications)
- Quick-action tiles (same as Principal, minus any fee-related actions)
- **Status:** IMPLEMENTED (`/coordinator-dashboard-screen`)

### 5.4 Governance (Coordinator)

- User management within the assigned branch (same as Principal)
- School profile management (same as Principal)
- Approval Center (non-finance approvals)
- Audit logs for branch-scoped actions
- **Status:** IMPLEMENTED (shared screens, branch-scoped)

### 5.5 People Management (Coordinator)

- Staff directory, profiles, and documents (branch-scoped)
- Student directory, oversight, admissions, and student profile management (branch-scoped)
- Guardian directory
- Admission inquiries for the assigned branch (no Principal approval required)
- **Status:** IMPLEMENTED (branch-isolated, `x-schooldesk-branch-id` header enforced)

### 5.6 Academics (Coordinator)

All academics features identical to Principal, scoped to assigned branch:
- Class Hub, Subjects, Timetable, Lesson Planners, Academic Records
- **Status:** IMPLEMENTED

### 5.7 Attendance (Coordinator)

All attendance oversight features identical to Principal, scoped to assigned branch:
- Overview, corrections, reminders, history, audit, exports
- **Status:** IMPLEMENTED

### 5.8 Communications (Coordinator)

All communications features identical to Principal, scoped to assigned branch:
- Messages, Complaints, Event Posts, Calendar, Gallery
- **Status:** IMPLEMENTED

### 5.9 Documents & Records (Coordinator)

- School documents and records (branch-scoped)
- ID card generation, report generation and exports
- **Status:** IMPLEMENTED

### 5.10 Public Website (Coordinator)

- Coordinator can manage public website content for their assigned branch
- Admission inquiries from the public website route to the Coordinator's queue
- No Principal approval required for ordinary website operations
- **Status:** IMPLEMENTED (`website.ts` handler)

### 5.11 Web Portal (Coordinator)

| Module | Available |
|--------|-----------|
| Overview (Dashboard) | YES |
| Students | YES |
| Parents | YES |
| Teachers | YES |
| Classes & Subjects | YES |
| Timetables | YES |
| Reports | YES |
| Admission Inquiries | YES |
| Public Website | YES |
| Fees | NOT VISIBLE, NOT ACCESSIBLE, NOT QUERYABLE |

---

## 6. Role 3 — Teacher (Class Teacher & Co-Teacher)

### 6.1 Identity & Context

- Authenticates via Teacher sign-in flow (`/teacher-login-screen`)
- Teacher dashboard is first authenticated screen (`/teacher-dashboard-screen`)
- Branch context derived from class assignments; teacher cannot switch branches
- Teacher workflow is **mobile-only** (no web portal in current scope)

### 6.2 Class Teacher vs. Co-Teacher

| Capability | Class Teacher | Co-Teacher |
|------------|---------------|------------|
| Marks student attendance for the class | YES — Full | YES — Can mark |
| Owns the class timetable view | YES — Primary | View only |
| Posts Diary (homework/assignments) | YES | YES |
| Receives class-level communications | YES | YES |
| Visible as "class teacher" on student profiles | YES | NO |
| Lesson planner: create/edit | YES | Limited |
| Attendance correction requests | YES — Can request | NO |

**Rule:** The Class Teacher is the primary owner of a class section. One Class Teacher is assigned per section per academic year. Co-Teachers are supporting assignments and do not hold primary ownership. Both share the `teacher` auth role in the database; ownership is enforced via the `is_class_teacher` flag on the class assignment record.

### 6.3 Dashboard

- Today's schedule (timetable for the current day)
- Pending attendance sessions requiring action
- Unread communications and complaints badge
- Leave balance summary
- Quick links: Mark Attendance, Post Diary, My Classes
- **Status:** IMPLEMENTED (`/teacher-dashboard-screen`, `dashboard.ts` handler)

### 6.4 My Classes & Class Roster

- View all assigned classes and sections
- Class roster: student list with photos, names, roll numbers, and attendance status
- Navigate to class-specific workflows (attendance, diary, lesson planner)
- **Status:** IMPLEMENTED (`/teacher-classes-screen`, `teacher_scope.ts` handler)

### 6.5 Timetable

- View personal timetable for the week (teacher-perspective view, not class-first)
- Shows all assigned periods across all classes
- View-only (editing is Principal/Coordinator only)
- **Status:** IMPLEMENTED (`/teacher-timetable-screen`, `timetable.ts` handler)

### 6.6 Student Attendance

- Mark attendance for permitted classes and sessions only
- Present/Absent/Late with optional note
- View attendance history for the class
- Request attendance correction (subject to Principal/Coordinator approval)
- Cannot reopen sessions independently (requires Principal/Coordinator)
- **Status:** IMPLEMENTED (`/teacher-attendance-screen`, `/teacher-attendance-history-screen`, `attendance.ts` handler)

### 6.7 Personal Attendance (Staff Attendance)

- View own attendance record (check-in/check-out log)
- Punch-in and punch-out for daily attendance
- **Status:** IMPLEMENTED (`/teacher-my-attendance-screen`, `attendance.ts` handler)

### 6.8 Diary (Homework/Assignments)

NOTE: The app uses "Dairy" in some UI labels but the correct product term is **Diary**. This label inconsistency is a known UI issue that must be corrected.

- Create Diary entries: title, description, due date, subject, class/section
- Attach files (images, PDFs) to Diary entries
- View submissions from parents/students
- Add feedback/comments on submissions
- Edit and delete own Diary entries (before submissions are received)
- **Status:** IMPLEMENTED (`/teacher-homework-screen`, `homework.ts` handler)

### 6.9 Lesson Planner

- Create and edit lesson plans per subject per class
- Attach resources, objectives, and notes
- View lesson plans published by the school leadership
- **Status:** IMPLEMENTED (`/teacher-lesson-planner-screen`)

### 6.10 Academic Calendar

- View school calendar: events, holidays, PTM dates, exam schedules
- Calendar is read-only for teachers (events created by Principal/Coordinator)
- **Status:** IMPLEMENTED (`/teacher-calendar-screen`, `calendar.ts` handler)

### 6.11 Communication

- Parent chat: initiate or respond to parent-initiated conversations
- Complaints: submit and view complaints
- Event posts: create event posts (subject to approval by Principal/Coordinator)
- School feed: view approved school-wide posts
- **Status:** IMPLEMENTED (`/teacher-communication-screen`, `/teacher-complaints-screen`, `communications.ts` handler)

### 6.12 Leave Management

- View leave balance (casual, sick, earned, etc.)
- Submit leave requests with dates, type, and reason
- View leave request status (pending, approved, rejected)
- **Status:** IMPLEMENTED (`/teacher-leave-screen`, `/teacher-leave-screen/request`, `leave.ts` handler)

### 6.13 Documents

- View and download school-issued documents (circulars, payslips, policies)
- **Status:** IMPLEMENTED (`/teacher-documents-screen`, `uploads.ts` handler)

### 6.14 Event Posts

- Create and submit event posts (photos, videos, text)
- Posts are held for Principal/Coordinator approval before becoming visible school-wide
- View post approval status
- **Status:** IMPLEMENTED (`/teacher-event-posts-screen`, `communications.ts` handler)

---

## 7. Role 4 — Parent

### 7.1 Identity & Context

- Authenticates via Parent sign-in flow (`/parent-login-screen`)
- Parent dashboard is first authenticated screen (`/parent-dashboard-screen`)
- A parent account can be linked to **one or more children**
- All data is scoped to the linked child(ren) and the branch they are enrolled in
- Parent workflow is **mobile-only** (no web portal in current scope)

### 7.2 Dashboard

- Linked child selector (if multiple children are enrolled)
- Today's attendance status for the selected child
- Fee balance summary (outstanding amount and next due date)
- Unread message and complaint badges
- Quick links: Attendance, Diary, Fees, Teacher Chat
- **Status:** IMPLEMENTED (`/parent-dashboard-screen`, `dashboard.ts` handler)

### 7.3 Child Attendance

- View daily attendance status for the linked child (Present / Absent / Late)
- View attendance history and monthly summary
- **Status:** IMPLEMENTED (`/parent-attendance-screen`, `attendance.ts` handler)

### 7.4 Diary (Homework/Assignments)

- View Diary entries assigned to the linked child (by class/subject)
- Submit homework/assignment (file upload, text response)
- View teacher feedback and comments on submissions
- **Status:** IMPLEMENTED (`/parent-homework-screen`, `/parent-homework-screen/submit`, `homework.ts` handler)

### 7.5 Lesson Planner

- View lesson plan for the linked child's class
- Read-only
- **Status:** IMPLEMENTED (`/parent-lesson-planner-screen`)

### 7.6 Health Updates

- View health records and health alerts posted for the linked child
- Health reminders (birthday, vaccination, medical notes)
- **Status:** IMPLEMENTED (`/parent-health-screen`, `health_reminders.ts` handler)

### 7.7 Teacher Chat

- Initiate or respond to chat conversations with the class teacher
- Group chat limited to parent and teacher scope
- Class teacher and co-teacher are both visible in the chat
- **Status:** IMPLEMENTED (`/parent-teacher-chat-screen`, `communications.ts` handler)

### 7.8 Complaints

- Submit complaints to the school
- View complaint status and school response
- **Status:** IMPLEMENTED (`/parent-complaints-screen`, `communications.ts` handler)

### 7.9 Fees & Payments

#### 7.9.1 Fee Overview
- View current fee balance for the linked child: outstanding, paid, overdue
- Invoice and installment breakdown
- **Status:** IMPLEMENTED (`/parent/fees`, `/parent-fees-screen`, `fees.ts` handler)

#### 7.9.2 Payment Request Submission
- Submit a payment request with uploaded proof (screenshot, receipt photo)
- Payment request is routed to Principal for review and approval
- **Status:** IMPLEMENTED (`/parent-fees-screen/payment`, `fees.ts` handler)

#### 7.9.3 Payment History
- View all submitted payment requests and their status (pending, approved, rejected)
- **Status:** IMPLEMENTED (`/parent/payment-history`, `fees.ts` handler)

#### 7.9.4 Receipt Download
- Download or view digital receipt for approved payments
- Receipts served through authorized signed URLs
- **Status:** IMPLEMENTED (`/parent/receipt`, `fees.ts` handler)

### 7.10 Student Leave Requests

- Submit leave requests for the linked child (date range, reason, type)
- View leave request status (pending, approved, rejected)
- Approval routed to the Class Teacher or Principal/Coordinator
- **Status:** IMPLEMENTED (`/parent-leave-screen`, `/parent-leave-screen/request`, `leave.ts` handler)

### 7.11 Academic Calendar

- View school calendar: events, holidays, PTM dates, exam schedules
- Read-only
- **Status:** IMPLEMENTED (`/parent-calendar-screen`, `calendar.ts` handler)

### 7.12 Documents

- View and download school-issued documents for the linked child
- **Status:** IMPLEMENTED (`/parent-documents-screen`, `uploads.ts` handler)

### 7.13 Child Timetable

- View the class timetable for the linked child
- Read-only
- **Status:** IMPLEMENTED (`/parent-timetable-screen`, `timetable.ts` handler)

---

## 8. Shared Cross-Role Features

| Feature | Principal | Coordinator | Teacher | Parent |
|---------|-----------|-------------|---------|--------|
| Notifications center | YES | YES | YES | YES |
| Push notifications (FCM) | YES | YES | YES | YES |
| Profile & Settings | YES | YES | YES | YES |
| Global search | YES | YES | YES | NO |
| School gallery (view) | YES | YES | YES | YES |
| Help & Tutorials | YES | YES | YES | YES |
| Diary messaging thread | YES | YES | YES | YES |

### 8.1 Notifications

- Push notifications via Firebase Cloud Messaging (FCM)
- In-app notification center (`/notification-center-screen`)
- Notifications are role-scoped, branch-scoped, class-scoped, and parent-child-scoped
- Birthday alerts for students (push to parents and class teachers)
- Health reminders delivered to parents
- **Status:** IMPLEMENTED (`notifications.ts` handler, `notification-processor` Edge Function)

### 8.2 Public Website

The public school website includes:
- Home / landing page
- About, mission, programs, and campus/safety information
- Admissions information and inquiry submission form
- Gallery and media (photos, videos)
- News, events, and public posts/ticker
- Contact and enquiry submission

**Content management:** Principal manages content for the selected branch; Coordinator manages content for the assigned branch. Public enquiry submissions must be protected and enter the operational admission workflow.

**Status:** IMPLEMENTED (`website.ts` handler, `20260720090000_school_website_content.sql`)

---

## 9. Feature Implementation Audit

### 9.1 Principal Features — Audit

| Feature | Route / Handler | Implemented | Notes |
|---------|----------------|-------------|-------|
| Principal Dashboard | `/principal-dashboard-screen` | YES | Live KPIs |
| Branch Selector | Dashboard header | YES | Invalidates cache on switch |
| School Profile | `/principal-school-profile-screen` | YES | |
| User Management | `/principal-user-management-screen` | YES | Create/Edit/Deactivate |
| Approval Center | `/approval-center-screen` | YES | |
| Audit Logs | `/principal-audit-logs-screen` | YES | |
| Staff Directory | `/staff-management-screen` | YES | |
| Student Oversight | `/student-oversight-screen` | YES | |
| Parent Directory | `/guardian-directory-screen` | YES | |
| Admission Inquiries | `/admission-inquiries-screen` | YES | |
| Class Hub | `/principal-classes-screen` | YES | |
| Subjects | `/principal-subjects-screen` | YES | |
| Timetable | `/principal-timetable-screen` | YES | Class-first, Preview, Copy Day |
| Lesson Planners | `/principal-lesson-planner-screen` | YES | |
| Attendance Overview | `/principal-attendance-screen` | YES | |
| Fee Structures | `/principal/fee-structures` | YES | |
| Fee Ledger | `/fee-ledger-screen` | YES | Balance-first |
| Record Payment | `/principal/collect-fee` | YES | Idempotent, atomic |
| Payment Requests | `/principal/payment-requests` | YES | Approve/Reject |
| Fee Concessions | `/principal/fee-concessions` | YES | |
| Payment Config | `/principal/payment-config` | YES | |
| Communications | `/communication-center-screen` | YES | |
| Messages / Chat | `/principal-chat-communications-screen` | YES | Realtime |
| Complaints | `/complaint-management-screen` | YES | |
| Event Posts & Approvals | `/principal-event-posts-screen` | YES | |
| Calendar | `/events-calendar-screen` | YES | |
| Gallery | Embedded in communications | YES | |
| Documents & Records | `/principal-documents-screen` | YES | Signed URL access |
| ID Card Generation | `/id-card-generation-screen` | YES | |
| Reports & Analytics | `/reports-analytics-screen` | YES | |
| System Monitor | `/system-monitor-screen` | YES | |
| Academic Years | `/academic-management-screen` | YES | |
| Sheets Pull/Push | Embedded in student oversight | YES | Pull-first contract |

### 9.2 Coordinator Features — Audit

| Feature | Status | Notes |
|---------|--------|-------|
| All Principal features (except Fees) | YES | Branch-isolated |
| Fees hidden from navigation | YES | RLS + backend enforced |
| Fees hidden from dashboard | YES | |
| Fees API rejected for Coordinator | YES | Server-side role check |
| Branch auto-assigned (no switcher) | YES | |

### 9.3 Teacher Features — Audit

| Feature | Route | Implemented | Notes |
|---------|-------|-------------|-------|
| Teacher Dashboard | `/teacher-dashboard-screen` | YES | |
| My Classes & Roster | `/teacher-classes-screen` | YES | |
| Teacher Timetable | `/teacher-timetable-screen` | YES | View only |
| Student Attendance | `/teacher-attendance-screen` | YES | Per-class, per-session |
| Attendance History | `/teacher-attendance-history-screen` | YES | |
| My Attendance (Staff) | `/teacher-my-attendance-screen` | YES | Punch in/out |
| Diary — Create | `/teacher-homework-screen/form` | YES | |
| Diary — Submissions | `/teacher-homework-screen/submissions` | YES | |
| Lesson Planner | `/teacher-lesson-planner-screen` | YES | |
| Academic Calendar | `/teacher-calendar-screen` | YES | Read-only |
| Communication | `/teacher-communication-screen` | YES | |
| Complaints | `/teacher-complaints-screen` | YES | |
| Event Posts | `/teacher-event-posts-screen` | YES | Pending approval flow |
| Leave — View Balance | `/teacher-leave-screen` | YES | |
| Leave — Apply | `/teacher-leave-screen/request` | YES | |
| Documents | `/teacher-documents-screen` | YES | Read-only |
| Class Teacher flag | Class assignment record | YES | `is_class_teacher` field |
| Co-Teacher access | Shared class assignment | YES | Scoped permissions |

### 9.4 Parent Features — Audit

| Feature | Route | Implemented | Notes |
|---------|-------|-------------|-------|
| Parent Dashboard | `/parent-dashboard-screen` | YES | |
| Child Attendance | `/parent-attendance-screen` | YES | |
| Diary — View | `/parent-homework-screen` | YES | |
| Diary — Submit | `/parent-homework-screen/submit` | YES | File upload |
| Lesson Planner | `/parent-lesson-planner-screen` | YES | Read-only |
| Health Updates | `/parent-health-screen` | YES | |
| Teacher Chat | `/parent-teacher-chat-screen` | YES | Realtime |
| Complaints | `/parent-complaints-screen` | YES | |
| Fee Overview | `/parent/fees` | YES | Balance-first |
| Submit Payment Request | `/parent-fees-screen/payment` | YES | Proof upload |
| Payment History | `/parent/payment-history` | YES | |
| Receipt Download | `/parent/receipt` | YES | Signed URL |
| Student Leave Request | `/parent-leave-screen/request` | YES | |
| Academic Calendar | `/parent-calendar-screen` | YES | Read-only |
| Documents | `/parent-documents-screen` | YES | Signed URL |
| Child Timetable | `/parent-timetable-screen` | YES | Read-only |

### 9.5 Features Not Yet Implemented (Current Gaps)

| Feature | Role(s) | Priority | Notes |
|---------|---------|----------|-------|
| PTM (Parent-Teacher Meeting) booking | Parent, Teacher | Medium | Schema exists; UI not built |
| PTM availability management | Teacher | Medium | Schema exists; UI not built |
| Teacher web portal | Teacher | Low | Explicitly future scope |
| Parent web portal | Parent | Low | Explicitly future scope |
| Cross-branch aggregate dashboards | Principal | Low | Future scope |
| Automated Google Sheets sync | Principal, Coordinator | Low | Manual pull-first only |
| Email / WhatsApp notifications | All | Low | Future scope |
| Multi-school tenancy | Super Admin | Low | Future scope |

---

## 10. Data, Security & Privacy

### 10.1 Authorization Rules

- Enforce role and branch authorization in Edge Functions and database RLS policies
- Never trust a role or branch value supplied only by query string, URL path, or client state
- The `x-schooldesk-branch-id` header is set by the authenticated client but validated server-side against the user's allowed branches
- Service-role keys must never appear in Flutter bundles, web bundles, migrations, or source fallbacks

### 10.2 Secrets Management

- No privileged secrets, webhook secrets, QR secrets, Google private keys, or password defaults in source
- Rotate any privileged credential that has appeared in source or migration history before production use
- The Kiosk QR secret must be configured through deployment secrets and must fail closed when missing

### 10.3 Data Privacy

- Student, staff, parent, payment proof, finance, and school documents are private unless the specific asset is explicitly public
- Use signed, time-limited URLs for all private document access (Supabase Storage)
- The `school-assets` bucket must not list publicly; private records must be behind private storage policies
- Do not expose password values in logs, exports, notifications, or browser storage

### 10.4 Audit & Compliance

- Record security-sensitive actions, finance operations, branch changes, imports, exports, approvals, and account changes in audit logs
- Enable leaked-password protection
- Review all SECURITY DEFINER functions, execute grants, search paths, storage policies, RLS policies, and public bucket listing

---

## 11. UX & Accessibility Requirements

- Dashboard is the first authenticated screen for every role
- Navigation is role-scoped and branch-scoped; unauthorized routes show permission-denied, not blank screens
- Mobile layouts must work on small Android phones, tablets, and supported iOS sizes
- Web layouts must work at desktop and narrow responsive widths without hiding actions or data
- Forms must provide labels, validation messages, focus visibility, keyboard access, and clear success/error feedback
- Tables must provide search, filters, empty states, loading skeletons, and recoverable errors
- Destructive or irreversible actions require confirmation dialogs that explain consequences
- Complex workflows use full-screen or clearly scoped surfaces
- Visual QA must use current rendered mobile and web evidence; source inspection alone cannot certify visual quality

---

## 12. Current Scope vs. Future Scope

### 12.1 Current Scope

- Complete Flutter mobile role inventory (Principal, Coordinator, Teacher, Parent, Kiosk, Super Admin)
- Principal-only Fees with full audit and immutable history
- One-school, multi-branch operation with one active branch at a time
- Limited Principal/Coordinator web portal
- Public website and admission enquiries
- Manual, pull-first, student-only Google Sheets exchange
- CSV fallback import where already implemented
- Backend-backed security, branch isolation, auditability, and visible failure states
- Supabase Realtime invalidation for dashboards, attendance, fees, and chat
- Push notifications via FCM for all roles
- Role-guided Help & Tutorials per role

### 12.2 Future Scope

- Web portals for Teacher and Parent
- Web attendance, communications, homework, leave, health, PTM, and full mobile parity
- PTM booking and availability management (schema exists, UI pending)
- Automatic or scheduled Google Sheets synchronization
- Two-way automatic conflict resolution beyond the manual pull-first workflow
- Multi-school tenancy
- Cross-branch aggregate dashboards and reports
- Email, WhatsApp, and other external communication channels

---

## 13. Known Issues & Release Gates

| # | Issue | Severity | Module |
|---|-------|----------|--------|
| 1 | The former hardcoded privileged fallback token was removed from the current working tree. It was present in commit `a70af07`; production rotation, deployment verification, and repository-history remediation remain required before this item is closed. | CRITICAL | Sheets / Security |
| 2 | Dashboard authorization must reject a lower-privileged user requesting another role's dashboard path. | CRITICAL | Auth / Dashboard |
| 3 | Supabase security-advisor warnings: SECURITY DEFINER wrappers, mutable search paths, public storage listing, disabled leaked-password protection, RLS initialization plans, permissive-policy overlap, duplicate index. | CRITICAL | Security / DB |
| 4 | The `school-assets` bucket is used by student documents and avatars; private records must move behind private storage and signed access. | CRITICAL | Storage / Security |
| 5 | Shared mobile role-access loading risks collapsing backend failures into empty data. Failure and empty states must remain distinguishable and retryable. | HIGH | All roles / Error handling |
| 6 | Web branch-switch failure must show an actionable error instead of silently returning to the previous state. | HIGH | Web / Coordinator, Principal |
| 7 | Integration test suites contain manual/TODO stubs. Static checks do not prove real login, branch isolation, role handoffs, CRUD, payment, import, or device workflows. | HIGH | Testing |
| 8 | Current worktree contains a payment-delete path that physically deletes payment-related rows. Conflicts with immutable-financial-history requirement. Must become an audited atomic reversal or be removed. | CRITICAL | Finance / Principal |
| 9 | A browser/device walkthrough or screenshot set is required for final responsive, accessibility, and visual QA sign-off. | MEDIUM | QA |
| 10 | UI label inconsistency: "Dairy" is used in some screens where "Diary" is the correct product term. Must be normalized across all teacher and parent screens. | MEDIUM | Teacher / Parent |

---

## 14. Acceptance Criteria

### 14.1 Functional

- Principal can select each branch and operate only within the selected branch
- Coordinator is restricted to the assigned branch and cannot access Fees in any surface
- Teacher can access only permitted mobile workflows and only for assigned classes
- Parent can access only data linked to their enrolled child(ren)
- Principal-only finance paths reject Coordinator, Teacher, Parent, and unauthenticated requests at the server
- Student, parent, staff, class, timetable, attendance, admission, website, and report workflows use live backend data
- Spreadsheet pull-first, stale-conflict, no-delete, one-branch, preview, and row-result behavior is proven

### 14.2 Security & Data

- No privileged secrets or predictable production fallbacks remain in source or client artifacts
- Role spoofing, branch spoofing, cross-branch reads/writes, public document access, and unauthorized RPC execution are denied
- Storage, RLS, function grants, search paths, and authentication settings have passing reviewed evidence
- Finance operations preserve immutable history and produce auditable reversals

### 14.3 Verification

- `flutter analyze --no-pub` passes
- `deno check supabase/functions/api/index.ts` passes
- `bun run typecheck` and `bun test` pass for the web portal
- Flutter tests run serially where required by the workspace
- Supabase migration lint passes and all advisor findings are dispositioned
- Live smoke tests cover: Principal, Coordinator, Teacher (Class and Co-Teacher), Parent, Kiosk, mobile, web, branch switching, Fees restrictions, website editing, admissions, and manual student spreadsheet exchange
- Current rendered screenshots or device walkthrough evidence attached for responsive and accessibility review

---

## 15. Source-of-Truth Implementation Locations

| Component | Path |
|-----------|------|
| Flutter application | `lib/` |
| Flutter route inventory | `lib/routes/schooldesk_screen_registry.dart` |
| Flutter API facade | `lib/core/network/` |
| Flutter features | `lib/features/` |
| Web application | `schooldesk-web/` |
| Supabase Edge API entry | `supabase/functions/api/index.ts` |
| Supabase API handlers | `supabase/functions/api/handlers/` |
| Supabase schema and RLS | `supabase/migrations/` |
| Automated tests | `test/`, `integration_test/`, `schooldesk-web/tests/` |
| Assets and policy | `assets/policy/admin_principal_ownership_matrix.json` |
| Operation ownership policy | `lib/core/services/operation_ownership_policy.dart` |
