# SchoolDesk Design Reference 02: EduVerse Behance Case Study Adaptation

Source: Behance project `School Management System App - Case Study` / `EduVerse`.

Primary reference URL:
https://www.behance.net/gallery/238899849/School-Management-System-App-Case-Study

Downloaded reference image pack:
`docs/design-references/eduverse-behance-images/`

The image pack contains 30 direct Behance CDN project-module images, saved from the highest public variant exposed in the page HTML (`max_3840_webp`). See `index.md` and `manifest.json` in that folder for source URLs, byte counts, and hashes.

This document captures the design principles, UX process, visual patterns, and SchoolDesk adaptation plan from the Behance case study. This is the stronger reference and should guide the next full UI/UX implementation wave.

## What The Case Study Is About

EduVerse is presented as a comprehensive school management mobile app for Admin, Teacher, Student, and Guardian users. The case study states that the app is intended to reduce workload, improve communication, make school tasks easier, and keep learning operations connected.

The project is useful for SchoolDesk because it does not only show polished screens. It shows a design process:

- Overview and goal.
- User background and personas.
- Role-specific pain points.
- Problems and proposed solutions.
- Storyboards for real situations.
- User flow for each role.
- Wireframes before final UI.
- Final designs by role.
- Desktop view.
- Lessons learned.

The most important principle is this: design every screen from the user's real daily job, not from a generic module list.

## Case Study Principles To Adopt

### 1. Role-Specific Work, Shared Product Language

EduVerse gives each role a different dashboard and task order, but keeps the same visual system.

SchoolDesk adaptation:

- Admin: operations and CRUD.
- Principal: oversight, approvals, analytics, records, and governance.
- Teacher: class execution and parent/student communication.
- Parent: child visibility and school communication.
- Student: future/inactive unless enabled.

The shell, typography, cards, status chips, tabs, and bottom actions must feel shared across all roles.

### 2. Pain-Point Led Feature Design

The case study starts from pain points:

- Confusing schedules.
- Hard-to-track homework and announcements.
- Parents needing a simple system.
- Teachers losing time to manual records.
- Communication being indirect or inconsistent.

SchoolDesk adaptation:

- Admin screens should reduce operational time.
- Principal screens should reduce uncertainty and expose risk.
- Teacher screens should reduce repeated communication and class paperwork.
- Parent screens should reduce "I did not know" situations.

Every screen should answer:

- What is the user trying to decide?
- What is the fastest next action?
- What data must be visible before acting?
- What can be safely hidden behind details?

### 3. Dashboard As Daily Command Center

EduVerse dashboard pattern:

- Greeting or role title.
- Today's overview.
- Next class / pending tasks / attendance.
- Quick Access.
- Recent notices/events/messages.

SchoolDesk adaptation:

- Admin dashboard = "Operational Overview".
- Principal dashboard = "Executive Oversight".
- Teacher dashboard = "Today's Classes".
- Parent dashboard = "Child Overview".

Do not make dashboards only KPI boards. A school dashboard should combine status, next action, and recent communication.

### 4. Glance, Action, Record

The Behance screens repeatedly use this flow:

1. Glance: summary metric, next event, urgent status.
2. Action: button, quick tile, or filter.
3. Record: detailed list or history.

SchoolDesk should make this a module contract:

- Fees: collection glance, record payment/create structure action, invoice/payment records.
- Attendance: attendance glance, mark/correct/export action, sessions/records.
- Timetable: class/day glance, add period/substitution action, schedule records.
- Approval Center: pending count glance, approve/reject action, audit/history records.
- Communication: published status glance, compose action, sent history.

### 5. Progressive Detail Instead Of Crowding

EduVerse avoids putting every data point at the top. It uses tabs, filters, cards, and lists.

SchoolDesk adaptation:

- Keep topbar actions to 2 primary actions on mobile.
- Move extra actions into a `More` menu or bottom sheet.
- Use tabs only when they represent real workflows.
- Use filters below the tab row, not mixed into the topbar.
- Make each row tappable for details where possible.

### 6. Cross-Role Continuity

The case study connects Admin, Teacher, Student, and Guardian around the same school events: attendance, routine, notices, homework, exams, reports, and communication.

SchoolDesk adaptation:

- A notice created by Admin should look like a notice in Parent, Teacher, Principal, and Notifications.
- A fee record in Admin should look like the same status in Principal Fee Monitoring and Parent Fees.
- A timetable created by Admin should become read-only records for Principal and relevant views for Teacher/Parent.
- A complaint/helpdesk item should connect Admin Helpdesk and Principal Complaints with consistent status labels.

## SchoolDesk Role Model

Behance roles:

- Admin
- Teacher
- Student
- Guardian

SchoolDesk roles:

- Principal
- Admin
- Teacher
- Parent
- Student is currently future/inactive in the current app direction.

Principal is not directly represented in the Behance case study, so SchoolDesk must add a governance role.

### Principal UX Definition

Principal is the "school health and approval" role.

Primary jobs:

- Review pending approvals.
- Monitor fee risk and attendance risk.
- View staff and student records.
- See timetable/exam/academic records without owning day-to-day CRUD.
- Track communication, complaints, events, reports, and analytics.

Principal should feel calm, high-level, and decision-oriented.

Avoid:

- Principal-first create/edit/delete flows for operational records unless backend ownership confirms it.
- Crowded operational forms.
- Admin-like wording such as "Manage Everything".

### Admin UX Definition

Admin is the "operations control" role.

Primary jobs:

- Manage students, staff, classes, timetable, exams, academics, fees, documents, access, and reports.
- Publish notices and communicate operational updates.
- Handle helpdesk and documents.
- Keep data clean and current.

Admin should feel efficient, dense enough for repeated work, and action-ready.

Avoid:

- Hiding primary CRUD actions.
- Saying all Admin changes require Principal approval unless this is true for that exact backend workflow.
- Overly decorative student-app layouts that slow operational work.

## Information Architecture Adaptation

### Mobile Bottom Navigation

Use the same four global actions everywhere possible:

- Home
- Search
- Notifications
- Profile

The drawer remains the complete module list. The bottom bar is for common global movement, not every module.

### Drawer Grouping

Principal:

- Overview
  - Dashboard
  - School Profile
  - Access & Permissions
- Oversight
  - Student Oversight
  - Staff Oversight
  - Approval Center
- Academic Records
  - Timetable Records
  - Syllabus Records
  - Exam Records
  - Academic Records
- Finance
  - Fee Monitoring
- Communication
  - Communication Center
  - Complaints
  - Calendar
- Reports
  - Reports
  - Analytics

Admin:

- Overview
  - Dashboard
- Administration
  - Students
  - Staff
  - Attendance
- Finance
  - Fees
- Academics
  - Timetable
  - Exams
  - Academic Management
- Communication
  - Communication
  - Helpdesk
- Records
  - Documents
  - Access
  - Reports
- School Info
  - ID Cards

Teacher and Parent can later follow the Behance role pattern more closely.

## Screen Contracts

### Admin Dashboard

Case-study inspiration:

- Admin has a dashboard with total students, teachers, today's classes, pending notices, upcoming events, and quick access.

SchoolDesk target:

- Title: `Admin Dashboard`
- Subtitle: `Live school operations, finance, access, and communication health.`
- Cards:
  - Students
  - Staff
  - Classes
  - Fee collected
  - Pending dues
  - Pending requests/notices
- Quick actions:
  - Add student
  - Add staff
  - Record payment
  - Publish notice
  - Create timetable
  - Open reports
- Recent sections:
  - Pending approvals/actions
  - Upcoming events
  - Recent payments
  - Notices sent

### Principal Dashboard

Case-study adaptation:

- Same command-center pattern, but for governance.

SchoolDesk target:

- Title: `Principal Dashboard`
- Subtitle: `School-wide analytics, approval pressure, finance and attendance health.`
- Cards:
  - Pending approvals
  - Urgent notices
  - Upcoming events
  - Attendance health
  - Fee risk
  - Staff signals
- Quick actions:
  - Approval Center
  - Analytics
  - Fee Monitoring
  - Communication Center
  - Complaints
  - Calendar
- Recent sections:
  - Attention signals
  - Latest approvals
  - Fee risk by class
  - Attendance exceptions

### Admin Students

Case-study principle:

- Admin owns management.

SchoolDesk target:

- Title: `Students`
- Subtitle: `Create, update, and maintain student records.`
- Primary actions:
  - Add student
  - Import/export if available
  - Refresh
- Tabs:
  - All Students
  - Admissions
  - Transfers
- Filters:
  - Search
  - Class
  - Status
- Row:
  - Student name
  - Class/section
  - Admission number
  - Status
  - More actions

If a specific student action needs Principal approval, say that only at action level, not as a blanket screen subtitle.

### Principal Student Oversight

SchoolDesk target:

- Title: `Student Oversight`
- Subtitle: `Review student records, admissions, transfers, and exception signals.`
- Primary actions:
  - View records
  - Open approvals
  - Export summary if available
- No default `Add student` action unless Principal truly owns that workflow.
- Tabs:
  - Overview
  - Admissions
  - Transfers
  - Exceptions

### Admin Staff

SchoolDesk target:

- Title: `Staff`
- Subtitle: `Create staff profiles, assign roles, and maintain staff records.`
- Actions:
  - Add staff
  - Export
  - Refresh
- Filters:
  - Department
  - Status
  - Role

If teacher/parent account creation can optionally request Principal approval, put that inside the create flow as a switch or approval status, not in the screen subtitle.

### Principal Staff Oversight

SchoolDesk target:

- Title: `Staff Oversight`
- Subtitle: `Review staff records, attendance, and approval-sensitive updates.`
- Actions:
  - View records
  - Open approvals
  - Export summary

### Fees

Behance payment section uses a clear due/paid flow.

Admin Fees target:

- Top: collected, pending, overdue, this month.
- Actions:
  - New structure
  - Generate invoices
  - Record payment
  - More
- Fix mobile topbar overflow. `Record payment` must not have zero-size bounds.
- Tabs:
  - Fee Structure
  - Pending Dues
  - Payments
  - Reports

Principal Fee Monitoring target:

- Read/monitor focused.
- Cards:
  - Total billed
  - Collected
  - Pending
  - Overdue
  - Collection rate
- Tabs:
  - Overview
  - Student Fees
  - Fee Structure
  - Payments
  - Risk
- Avoid create/payment actions unless explicitly allowed.

### Timetable

Behance routine screens emphasize where and when the class happens.

Admin Timetable target:

- Class selector.
- Weekday selector.
- Period cards with subject, teacher, room, time.
- Actions:
  - Add period
  - Generate suggestions
  - Substitution
  - More

Principal Timetable Records target:

- Read-only records and advice requests.
- Actions:
  - Raise Advice
  - Generate suggestions if supported
  - Open alerts

### Reports And Analytics

Behance reports emphasize exportable insight plus charts.

Admin Reports target:

- Generated report list.
- Compliance tab.
- Exports visible but not visually dominant.
- Do not show static/fake report numbers unless backed by real data.

Principal Analytics target:

- Attendance, fee collection, staff performance, alerts.
- Show real backend values only.
- Empty or pending sections should state the backend record type that is missing.

### Communication, Helpdesk, Complaints

Behance stresses reliable notices and communication.

Admin Communication target:

- Compose notice.
- Templates.
- Sent history.
- Delete/unpublish only where backend supports it.
- Audience clarity: role, class, section, all-school.

Principal Communication Center target:

- Publish/review circulars and urgent notices.
- Monitor communication reach and urgent alerts.

Admin Helpdesk target:

- Parent ticket intake and operational response.
- Status: Open, In Progress, Resolved, Escalated.

Principal Complaints target:

- Escalated issues and school-level concerns.
- Status and resolution health.

## Component System

### Dashboard Overview Card

Use for high-level counts and status.

Required fields:

- Icon
- Label
- Value
- Short context
- Optional trend
- Optional route

Visual:

- White surface.
- 8 px radius.
- 1 px border.
- Soft shadow only on interactive cards.
- Left icon square or top-right status.

### Attention Card

Use for Principal and Admin signals.

Required fields:

- Title
- Short explanation
- 2-4 metrics
- Primary action

### Quick Action Tile

Required fields:

- Icon
- Label
- Route/action
- Optional status count

Rules:

- 2 columns on mobile.
- 3-4 columns on wider screens.
- Stable min height.
- Avoid long labels; use tooltips or subtitle only if needed.

### Status Chip

Use consistent chip names:

- Active
- Inactive
- Pending
- Approved
- Rejected
- Resolved
- Escalated
- Paid
- Due
- Overdue
- Present
- Absent
- Late
- Leave

### Empty State

Use natural language:

- Good: `No approval requests`
- Good: `No attendance sessions yet`
- Good: `No notifications yet`
- Avoid: `No All Approvals`

Structure:

- Icon
- Title
- One short sentence
- Optional action

## Responsive Adaptation

### Mobile

- Drawer for full navigation.
- Bottom action bar for Home, Search, Notifications, Profile.
- Topbar maximum: two direct actions plus overflow.
- Cards single column or two compact cards.
- Filters in horizontal chips or bottom sheet.

### Tablet

- Navigation rail or drawer depending on width.
- 2-column content.
- KPI cards in 2-3 columns.
- Forms in 2 columns.

### Desktop/Web

Behance shows a desktop view with persistent side navigation, top search, notification/profile, and broader dashboard panels.

SchoolDesk target:

- Persistent side navigation.
- Topbar with portal context, page title, search, notifications, profile.
- Dashboard grid:
  - KPI row
  - Quick access grid
  - Main working panel
  - Secondary insights panel
- No oversized mobile-style hero cards on desktop admin screens.

## Direct Gaps From Current SchoolDesk Wireless QA

| Area | Current Evidence | Required Improvement |
| --- | --- | --- |
| Principal Student Oversight | Shows `Add student` | Make oversight/read/review first unless backend confirms Principal CRUD |
| Admin Students | Subtitle says changes go for Principal approval | Rewrite to Admin-owned CRUD wording; approval only at action level |
| Admin Staff | Subtitle says account changes go for Principal approval | Rewrite to staff/profile ownership; approval only where exact workflow requires it |
| Drawer badges | Helpdesk/Documents/Reports/ID Cards say backend pending but open | Replace with exact availability state |
| Admin Fees | `Record payment` has zero-size bounds on mobile | Move into visible action row or overflow menu |
| Long tabs | Analytics/Fees tabs clip on right edge | Use scrollable tabs with safe padding and shorter labels |
| Global Search | Static-looking suggestions | Use backend recent/popular items or label as examples |
| Approval Center | Empty phrase `No All Approvals` | Change to `No approval requests` |
| ID Cards | Class chips use generic 1A/1B while records use Play Group/Nursery | Source classes from backend or hide generic chips |

## Implementation Plan

### Wave 1: Design Contract Cleanup

- Update visible wording for Admin and Principal ownership.
- Fix awkward empty states.
- Fix `backend pending` labels to precise availability.
- Fix mobile topbar overflow and zero-size actions.
- Add tests for the wording contract and visible action contract.

### Wave 2: Shared Component Upgrade

- Enhance `SchoolDeskModuleScaffold` with:
  - mobile action overflow
  - compact status header slot
  - consistent bottom action layout
  - page semantic label verification
- Create reusable:
  - metric card
  - quick action tile
  - attention card
  - status chip
  - empty state
  - record row

### Wave 3: Admin And Principal Dashboard Refresh

- Apply command-center pattern to Admin Dashboard.
- Apply governance overview pattern to Principal Dashboard.
- Keep all data backend-driven.
- Preserve current routes and RBAC.

### Wave 4: Module-by-Module Polish

Priority order:

1. Admin Fees
2. Admin Students
3. Admin Staff
4. Admin Timetable
5. Admin Reports
6. Principal Student Oversight
7. Principal Approval Center
8. Principal Fee Monitoring
9. Principal Analytics
10. Principal Communication/Complaints

### Wave 5: Teacher And Parent Alignment

After Admin/Principal are stable, adapt the Behance Teacher/Guardian patterns:

- Teacher as daily classroom execution.
- Parent as child overview, fees, notices, teacher chat, attendance, homework.

## Design QA Checklist

Run this after implementation:

- `flutter analyze`
- Focused wording tests
- Widget tests for shell/topbar/bottom actions
- Route access tests
- Wireless Android screenshots for:
  - Admin dashboard
  - Admin Students
  - Admin Staff
  - Admin Fees
  - Admin Timetable
  - Admin Reports
  - Principal dashboard
  - Principal Student Oversight
  - Principal Approval Center
  - Principal Fee Monitoring
  - Principal Analytics
  - Global Search
  - Notifications
  - Profile
- Check UI tree for:
  - no zero-size primary actions
  - no clipped title text
  - no `Principle`
  - no awkward empty state phrases
  - no fake/static data presented as backend truth

## Non-Negotiables

- Do not disturb backend/API/RBAC contracts during visual work.
- Do not add mock data to make a screen look full.
- Do not copy the Behance visual assets directly.
- Use the case study as a system of principles and patterns.
- Keep Admin operational and Principal governance-focused.
- Keep mobile usable before adding desktop polish.
- Refresh dated screenshot evidence after each meaningful UI wave.
