# SchoolDesk Design Reference 01: EduManage Mobile Visual Direction

Source: user-provided image reference in chat.

This document translates the EduManage-style reference image into a SchoolDesk implementation guide. It should be used as a visual direction document, not as a literal clone. The goal is to keep SchoolDesk operational, backend-safe, and role-correct while giving the app the same feeling of clarity, friendliness, and modern mobile polish.

## What This Reference Is Doing Well

The reference uses a clean school-app pattern:

- Strong blue brand anchor.
- White mobile surfaces with very light blue background.
- Large, calm welcome states.
- Role-aware login and role-aware dashboards.
- Quick summary cards for daily status.
- Small square quick-action tiles with icons.
- Bottom navigation for frequent actions.
- Compact profile, attendance, notifications, chat, settings, timetable, assignments, results, and fees screens.
- Friendly use of semantic colors: green for present/success, red for absent/error, amber/orange for pending/leave, purple for secondary academic states.

The most important lesson for SchoolDesk is not only color. It is the information order:

1. Confirm where the user is.
2. Show the highest-priority status.
3. Offer the next likely actions.
4. Keep detailed records just below.
5. Always leave Home, Search, Notifications, and Profile easy to reach.

## SchoolDesk Adaptation Goal

Make Admin and Principal screens feel like the same product while preserving their different responsibilities.

- Admin experience: operational control, creation, updates, publishing, finance, records, and access.
- Principal experience: oversight, approvals, analytics, risk review, records, and governance.
- Shared experience: consistent topbar, drawer, bottom action bar, cards, lists, tabs, empty states, and wording.

This reference is best suited for the mobile-first role modules and shared tools. Tablet and desktop should keep SchoolDesk's existing persistent navigation shell, but inherit the same component language.

## Visual System To Adapt

### Color Direction

Use the current SchoolDesk tokens as the base.

- Primary blue: `#2457D6`
- Primary container: `#E6EDFF`
- Page background: `#F3F6FA`
- Surface: `#FFFFFF`
- Muted surface: `#F6F8FB`
- Border: `#E2E8F0`
- Text: `#101828`
- Muted text: `#667085`
- Success: `#15803D`
- Warning: `#B45309`
- Error: `#B42318`
- Info: `#2563EB`

Role accents should remain visible but not fragment the product:

- Principal: blue
- Admin: teal
- Teacher: purple
- Parent: green
- Student: orange, future/inactive until enabled

Design rule: blue is the product anchor; role colors are accents for portal identity, chips, and selected states.

### Typography

Keep the locally bundled Google Fonts path and use the current Inter/DM Sans style consistently.

- Page title: 20-24 px, weight 700
- Section title: 16-18 px, weight 700
- Card metric value: 22-28 px, weight 700
- Body: 13-15 px, weight 400-500
- Captions: 11-12 px, muted
- Buttons: 13-14 px, weight 600

Do not use viewport-based font sizing. Respect the app's text scaling limit and avoid clipped labels.

### Spacing And Shape

Use an 8-point rhythm:

- Screen side padding: 16 px mobile, 24 px tablet, 32 px desktop
- Card padding: 16 px
- Card gap: 12-16 px
- Section gap: 20-24 px
- Icon tile: 72-96 px wide on mobile, fixed min height
- Touch target: 44 px minimum, preferably 48-56 px
- Card radius: 8 px
- Button/control radius: 8 px
- Pills/chips: full pill radius

Avoid large decorative nested cards. Cards should represent data or actions, not entire page sections.

### Icon And Tile Style

Use Material or existing Flutter icons consistently:

- Quick action tile icon: colored square/soft rounded background, 28-32 px icon area.
- Metric card icon: small role/semantic icon at top-left or right.
- Row icon: 32-40 px soft square.
- Icon-only controls must have semantic labels and tooltips.

Use color-coded icon backgrounds:

- Blue: navigation, academics, dashboard
- Green: success, attendance present, paid
- Amber: pending, leave, upcoming
- Red: urgent, absent, overdue
- Purple: reports, achievements, secondary academic signals
- Teal: admin operations, finance health, staff/admin-owned actions

## Core Layout Pattern

Every role module should follow this order unless the workflow clearly requires another order.

1. App shell:
   - Topbar with drawer/back, page title, short context subtitle, search/refresh/notification/profile actions when useful.
   - Bottom action bar on mobile: Home, Search, Notifications, Profile.
   - Drawer for the full role module list.

2. Status block:
   - One role-aware overview card or compact KPI row.
   - The top card answers: "What needs my attention right now?"

3. Quick actions:
   - 2-6 tiles or buttons.
   - No hidden zero-size actions on mobile.
   - Overflow secondary actions into a "More" menu or bottom sheet.

4. Working content:
   - Tabs, filters, or search only where needed.
   - Lists use clear rows with status chips.
   - Empty states explain what is missing and the next action.

5. Detail/record area:
   - Recent records, history, audit signals, or export options.

## Screen Patterns To Implement

### Login

The reference uses role tabs on login. SchoolDesk should not copy that exactly because our backend resolves role access from the authenticated account.

Adaptation:

- Keep one secure login form.
- Show a compact line: "Role access is resolved by the backend."
- Add subtle role chips below the form only as reassurance: Principal, Admin, Teacher, Parent.
- Use a blue brand panel for landing/onboarding and a white login form for input.
- Avoid requiring the user to select Principal/Admin manually before login.

### Dashboard

Use the reference's "welcome + overview + quick access" structure.

Admin dashboard:

- Header: "Admin Dashboard"
- Context: "Operations, finance, access, and communication"
- Overview cards:
  - Students
  - Staff
  - Classes
  - Fee collection
  - Pending dues
  - Pending requests/notices
- Quick actions:
  - Add student
  - Add staff
  - Record payment
  - Publish notice
  - Create timetable period
  - Open reports

Principal dashboard:

- Header: "Good morning, Principal" or "Principal Dashboard"
- Context: "Oversight, approvals, analytics, and school health"
- Overview cards:
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

Principal should not be pushed toward CRUD-first actions.

### Module List Rows

For modules like Students, Staff, Notifications, Documents, Helpdesk, Reports:

- Left icon in semantic color square.
- Main title, one-line subtitle.
- Right status chip or timestamp.
- Optional trailing action menu.
- Row height stable even when data changes.

Example row structure:

```text
[icon] Student Name
       Class / section / admission number
       Status chip: Active
       Trailing: more menu
```

### Forms

Reference forms are simple and spacious.

Adaptation:

- Group fields into 2-4 logical sections.
- Primary action fixed at bottom on mobile only when the form is long.
- Use full-width inputs on mobile.
- Use two-column fields on tablet/desktop.
- Show backend validation messages under the affected field.
- Do not hide required fields behind icons.

### Attendance And Calendar

Use the reference's segmented calendar style:

- Month row with previous/next.
- Present/Absent/Late/Leave legend.
- Selected day summary below.
- Principal/Admin analytics can show attendance as aggregate cards.
- Teacher/Parent can show day-by-day detail.

### Notifications

Use the reference's simple stacked notification list:

- Category tabs: All, Approvals, Fees, Exams, Circulars.
- Each item has icon, title, body preview, timestamp, unread state.
- Tap opens the mapped destination after access validation.
- Empty state: "No notifications yet" with a short role-aware sentence.

### Profile And Settings

Use the reference's compact profile style:

- Avatar, name, role, school context.
- Personal information as readable rows.
- Settings list with icons and chevrons.
- Notification preferences as toggles.
- Logout as a separate danger action at bottom.

## Admin And Principal Wording Contract

Use these labels consistently:

| Concept | Admin Label | Principal Label |
| --- | --- | --- |
| Student CRUD | Students | Student Oversight |
| Staff CRUD | Staff | Staff Oversight |
| Fees | Fees | Fee Monitoring |
| Timetable | Timetable | Timetable Records |
| Exams | Exams | Exam Records |
| Academics CRUD | Academic Management | Academic Records |
| Notices/messages | Communication | Communication Center |
| Tickets | Helpdesk | Complaints |
| Users/accounts | Access | Access & Permissions |
| Reports | Reports | Analytics / Reports |

Do not use `Principle` anywhere in visible UI.

## Direct Fixes Suggested By Current Screenshots

Use this reference to improve the issues found in the wireless QA folder:

- Replace Principal `Add student` with `Request review`, `View records`, or remove it if Principal is oversight-only for that workflow.
- Change Admin Students subtitle from "request student record changes for Principal approval" if Admin owns student CRUD.
- Change Admin Staff subtitle if Admin owns staff CRUD and only selected account creations require approval.
- Replace drawer `backend pending` badges with precise labels:
  - `Export pending`
  - `Backend partial`
  - `Read-only`
  - `Setup needed`
- Fix Admin Fees mobile action overflow so `Record payment` is visible in a menu or bottom sheet.
- Fix clipped long tab rows by using scrollable tabs with edge fade or shorter labels.
- Replace static-looking Global Search suggestions with backend-driven recent searches or label them as examples.
- Replace "No All Approvals" with "No approval requests".

## Component Checklist For Implementation

- `SchoolDeskModuleScaffold`
  - Add optional compact hero/status area.
  - Add overflow action menu for mobile top actions.
  - Keep bottom actions stable.

- `SchoolDeskNavigationDrawer`
  - Badge terminology cleanup.
  - Use role accent only for active item and portal identity.

- Dashboard cards
  - Standard metric card.
  - Standard quick action tile.
  - Standard attention card.

- List rows
  - Standard record row with icon, title, subtitle, status, trailing action.

- Empty states
  - Standard icon/title/body/action.
  - No awkward generated phrases.

- Tabs
  - Scrollable, clipped-safe, semantic labels.

## Acceptance Criteria

- All Admin and Principal screens use the same shell.
- All mobile screens keep Home, Search, Notifications, and Profile reachable unless a modal/form flow intentionally hides them.
- No visible text overlaps or clips at common mobile widths.
- No action has zero-size bounds in the UI tree.
- Admin owns operational workflows where the backend confirms ownership.
- Principal screens clearly read as oversight, analytics, records, and approvals.
- `flutter analyze` passes.
- Focused wording/design tests pass.
- Wireless device screenshots are refreshed after implementation.
