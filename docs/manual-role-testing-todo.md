# SchoolDesk Manual Testing Guide

> **Purpose:** This document tells you exactly what to check in the SchoolDesk app, screen by screen, role by role. Each item has a plain-English description of what the feature does and what "passing" looks like.
>
> **How to use:** Open the app on the target device. Log in as the role listed. Follow each checklist item. Mark `[x]` when it works. If something fails, add `BUG:` after the item with what went wrong. If you can't test it (missing data/account), add `BLOCKED:` after the item.

---

## Table of Contents

- [Before You Start — Environment Setup](#before-you-start--environment-setup)
- [Sign In & Authentication](#sign-in--authentication-test-first--all-roles)
- [Principal / Admin Role](#principal--admin-role--feature-by-feature-guide)
- [Teacher Role](#teacher-role--feature-by-feature-guide)
- [Parent Role](#parent-role--feature-by-feature-guide)
- [Kiosk Role](#kiosk-role--feature-by-feature-guide)
- [Cross-Role Workflows](#cross-role-workflows--end-to-end-tests)
- [Regression & Reliability Checks](#regression--reliability-checks-all-roles)

---

## Before You Start — Environment Setup

These are prerequisites. Make sure all of these are confirmed before testing any role.

| # | Check | How to verify |
|---|-------|---------------|
| 1 | Backend is live | Open `https://schooldesk1-production.up.railway.app/api` in a browser — you should see a response (not a timeout) |
| 2 | Test accounts exist | You need login credentials for: **Principal**, **Teacher**, **Parent**, and **Kiosk** |
| 3 | Fresh session | Clear app data or use incognito/private mode so old login state doesn't interfere |
| 4 | Both layouts | Test on a **phone** (small screen) AND a **tablet/desktop** (wide screen) for at least the main dashboard of each role |

---

## Sign In & Authentication (Test First — All Roles)

Before testing any specific role, verify the login system works for everyone.

### How Sign In Works

When you open the app, you land on the **Landing Page** — this is the public welcome screen. From there, you pick your role (Principal, Teacher, Parent, or Kiosk) and enter your credentials.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Landing page loads** | Open the app. You see the SchoolDesk welcome screen with school branding (logo, school name). No crash. |
| 2 | **Principal login** | Tap the Principal login option. Enter principal credentials. You should land on the **Principal Dashboard** (see "Hello, School Principal" greeting with school name and stats). |
| 3 | **Teacher login** | Log out first. Tap the Teacher login option. Enter teacher credentials. You should land on the **Teacher Dashboard** (see greeting with teacher name, assigned class, and quick actions like "My QR Check-in" and "Student Attendance"). |
| 4 | **Parent login** | Log out first. Tap the Parent login option. Enter parent credentials. You should land on the **Parent Dashboard** (see "School Feed" with child selector and summary cards for Attendance, Homework, Fees, Messages). |
| 5 | **Kiosk login** | Log out first. Tap the Kiosk login option. Enter kiosk credentials. You should land on the **QR Attendance Kiosk** screen (see a large QR code with a countdown timer). |
| 6 | **Wrong password** | On any login screen, enter a wrong password. You should see a clear error message (like "Invalid credentials") and stay on the login screen — no crash, no navigation to a dashboard. |
| 7 | **Sign out** | From any role's dashboard, find the sign-out button (usually in the profile or settings area). After signing out, you should be back at the Landing Page or login screen. Your old dashboard should not be visible. |
| 8 | **Resume after close** | Close the app completely (swipe it away from recent apps). Reopen it. You should land on your role's dashboard (if you were still logged in) or the login screen (if the session expired). |
| 9 | **Route protection** | If you know a URL/route for a role you don't have access to (e.g., a parent trying to open the principal dashboard route), the app should redirect you away — not show you content from the wrong role. |

---

## Principal / Admin Role — Feature-by-Feature Guide

Log in as Principal. You'll see the **Principal Dashboard** — a scrollable home screen with these sections: header (school name/logo), module grid (13 clickable tiles), today's stats, action queue, and setup checklist.

---

### 1. Principal Dashboard

**What it shows:** A welcome header with your school name and logo, a grid of module tiles you can tap to navigate, today's attendance and fee stats, an action queue (Review Attendance, Event Approvals, etc.), and a "Go Live Progress" setup checklist.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Dashboard loads** | After login, the dashboard appears within 10 seconds. You see your name, school name, school logo, and module tiles (Academic Years, Students, Staff Management, etc.). |
| 2 | **Module tiles navigate** | Tap each tile (Academic Years, Students, Staff Management, Guardians, Class Hub, Attendance, Subjects, Lesson Planners, Fees, Calendar, Event Approvals, Timetable, Message Oversight). Each should open a new screen with data. Tap the back button to return. |
| 3 | **Today stats show data** | The "Today" section shows Attendance percentage and Fees collection percentage. Numbers should be real (not all zeros unless it's a brand new school). |
| 4 | **Action queue works** | Tap each item in "Principal Action Queue" (Review Attendance, Correction Requests, Event Approvals, Fee Requests, Access Approvals). Each should open the correct screen. |
| 5 | **Setup checklist** | The "Go Live Progress" section shows setup steps (School Registration, Academic Year Setup, etc.) with green checkmarks for completed items and blue for pending. Tap a pending step — it should open the relevant screen to complete it. |
| 6 | **Bottom navigation** | The bottom bar has 4 tabs: Home, Search, Alerts, Profile. Tap each — Search opens Global Search, Alerts opens Notifications, Profile opens Profile screen. Home returns to dashboard. |
| 7 | **Pull to refresh** | Swipe down on the dashboard. It should refresh data (loading spinner appears, then data updates). |
| 8 | **Mobile layout** | On a phone, the module grid should show 2 columns. No text overflow, no overlapping cards. Everything fits within the screen width. |

---

### 2. School Profile (Governance)

**What it does:** Lets the principal view and edit school information (name, address, logo, board affiliation, principal name, etc.).

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Open School Profile** | From the dashboard, find and tap the School Profile option (or navigate via sidebar). The screen loads showing school details. |
| 2 | **View existing data** | If the school has been set up, you should see fields like school name, address, board, school type, principal name. |
| 3 | **Edit and save** | Change the school name to something new (e.g., add " Test" at the end). Tap Save. Go back and reopen — the new name should persist. |
| 4 | **Logo upload** | If logo upload is enabled, try uploading a logo image. The school logo should update on the dashboard header. |

---

### 3. Access Permissions / User Management (Governance)

**What it does:** Shows all user accounts (teachers, parents, students). Lets you create new accounts, edit existing ones, and assign children to parent accounts.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **List accounts** | Open the screen. You should see a list of existing user accounts (teachers, parents, students). |
| 2 | **Create a new account** | Tap "Create Account" or the + button. Fill in the form (name, email, role). Submit. The new account should appear in the list. |
| 3 | **Edit an account** | Tap an existing account. Edit a field (like the name). Save. The change should persist when you reopen. |
| 4 | **Assign children to parent** | Open a parent account. Find "Assign Children" option. Link a student to this parent. Save. The parent should now see that child's data when they log in. |
| 5 | **Account status** | Check if accounts can be activated/deactivated. If you deactivate an account, that user should not be able to log in. |

---

### 4. Staff Management (People)

**What it does:** Lists all school staff (teachers, admin, etc.). Lets you add, edit, or remove staff members.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Staff list loads** | Open Staff Management. You should see a list of staff members with names and roles. |
| 2 | **Add a staff member** | Tap the add button. Fill in the form (name, role, contact details, subjects assigned). Submit. The new staff member should appear in the list. |
| 3 | **Edit a staff member** | Tap an existing staff member. Change something (like phone number). Save. The change should persist. |
| 4 | **Delete/deactivate** | Try deleting or deactivating a staff member. The action should complete safely (no crash). The staff member should be removed or marked inactive. |

---

### 5. Student Oversight (Students)

**What it does:** Lists all enrolled students. Lets you add individual students or bulk-import them.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Student list loads** | Open Student Oversight. You should see a list of students with names, classes, and other details. |
| 2 | **Add a student** | Tap add/import. Fill in student details (name, class, parent link). Save. The student appears in the list. |
| 3 | **Edit a student** | Tap an existing student. Edit a field. Save. Change persists. |
| 4 | **Class assignment** | Check that students are assigned to the correct class/section and that this is reflected in the student detail view. |

---

### 6. Parents & Guardians Directory (People)

**What it does:** Shows all parent/guardian accounts and which children they are linked to.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Guardian list loads** | Open the Guardians screen. You should see a list of parent/guardian accounts. |
| 2 | **Guardian-child links** | Tap a guardian. You should see which children are linked to them. The children listed should be correct. |

---

### 7. Class Hub (Academics)

**What it does:** Shows all classes/sections/grades. Lets you create new classes and manage subjects per class.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Class list loads** | Open Class Hub. You should see a list of grades/sections/classes. |
| 2 | **Create a class** | Tap add. Enter class name, section, grade. Save. The new class appears in the list. |
| 3 | **Edit a class** | Tap an existing class. Edit the name or details. Save. Change persists. |
| 4 | **Class details** | Tap a class to see its details — assigned teacher, subjects, number of students. |

---

### 8. Subjects (Academics)

**What it does:** Lists all subjects taught at the school. Lets you create, edit, and assign subjects.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Subject list loads** | Open Subjects. You should see a list of subjects. |
| 2 | **Create a subject** | Tap add. Enter subject name and details. Save. New subject appears. |
| 3 | **Edit a subject** | Tap an existing subject. Edit the name. Save. Change persists. |

---

### 9. Academic Years (Academics)

**What it does:** Manages academic years, terms, and curriculum. This is where you define the school's academic calendar.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Academic years list** | Open Academic Years. You should see a list of academic years (e.g., "2025-2026"). |
| 2 | **Create an academic year** | Tap add. Enter year name, start/end dates. Save. New year appears. |
| 3 | **Year detail view** | Tap an academic year. You should see related classes, terms, and curriculum info. |
| 4 | **Export options** | From an academic year, try Classwise Export, Users Export, and Fees Export. Each should generate a downloadable file. |

---

### 10. Timetable (Academics)

**What it does:** Shows and manages the school's class timetable — which teacher teaches which subject in which class at what time.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Timetable loads** | Open Timetable. You should see a grid or list of class periods with times, subjects, and teachers. |
| 2 | **Create/edit a slot** | Add a new timetable entry (class, subject, teacher, time). Save. The entry appears in the timetable. Edit an existing entry — change persists. |

---

### 11. Lesson Planners (Academics)

**What it does:** Shows lesson plans submitted by teachers. The principal can review and monitor them.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Lesson plans list** | Open Lesson Planners. You should see a list of lesson plans submitted by teachers. |
| 2 | **View a plan** | Tap a lesson plan. You should see the topic, subject, class, and plan details. |

---

### 12. Attendance (Academics)

**What it does:** Shows attendance data for both students and staff. The principal can view daily attendance, review exceptions, and export records.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Attendance dashboard loads** | Open Attendance. You should see a summary — total present, absent, percentage. |
| 2 | **View class attendance** | Select a class and date. You should see which students were present/absent/late for that day. |
| 3 | **View staff attendance** | Switch to staff attendance view. You should see teacher/staff attendance records. |
| 4 | **QR staff attendance** | If teachers have scanned the kiosk QR, their attendance should appear here with punch-in times. |
| 5 | **Attendance correction** | If there's a "reopen" or "correction" action available, try it. The attendance record should update. |
| 6 | **Export** | Tap export/download. A CSV or PDF file should download with the attendance data. |

---

### 13. Exams (Academics)

**What it does:** Manages school exams — creating exams, scheduling them, and entering marks for students.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Exam list loads** | Open Exams. You should see a list of exams (e.g., "Mid-Term", "Final"). |
| 2 | **Create an exam** | Tap add. Enter exam name, type, and details. Save. The exam appears in the list. |
| 3 | **Schedule an exam** | From an exam, add a schedule (subject, date, time). Save. The schedule appears. |
| 4 | **Enter marks** | Open marks entry for an exam. Enter marks for students. Save. The marks should persist. |

---

### 14. Fees / Fee Monitoring (Finance)

**What it does:** Shows the school's fee collection status — how much has been paid, what's pending, and individual student fee records.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Fee dashboard loads** | Open Fees. You should see a summary of total fees due, collected, and pending. |
| 2 | **Fee structures visible** | You should see fee categories/structures (e.g., "Tuition Fee", "Lab Fee"). |
| 3 | **Payment requests list** | Open Payment Requests. You should see requests submitted by parents. |
| 4 | **Approve a request** | Tap a pending payment request. Review the details. Tap "Approve". The request status should change to "Approved". |
| 5 | **Reject a request** | Tap a pending payment request. Tap "Reject". Enter a reason. The request status should change to "Rejected" with the reason saved. |
| 6 | **Export** | Try exporting fee data. A file should download with correct data. |

---

### 15. Communication & Calendar

**What it does:** Manages school broadcasts/notices, event approvals, complaint tracking, and the school calendar.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Broadcasts/Notices** | Open Broadcasts & Notices. You should see a list of past notices. Try creating a new notice — enter title, message, and target audience (all parents, all teachers, etc.). Save. The notice should appear in the list. |
| 2 | **Event Approvals** | Open Event Approvals. You should see event posts submitted by teachers that need your approval. |
| 3 | **Approve an event** | Tap a pending event. Review the title, description, and any media. Tap "Approve". The event should now appear in the School Gallery and parent feed. |
| 4 | **Reject an event** | Tap a pending event. Tap "Reject". Enter a reason. The event status changes to "Rejected". |
| 5 | **Complaints** | Open Complaints/Helpdesk. You should see a list of complaints. Tap one to view details and update status. |
| 6 | **Calendar** | Open Events Calendar. You should see school events on a calendar view. Try creating a new event — enter title, date, description. Save. The event appears on the calendar. |
| 7 | **Message Oversight** | Open Message Oversight. You should see a summary of parent-teacher communication activity. |

---

### 16. Reports & Documents

**What it does:** Provides analytics, report generation, ID card generation, and report card generation.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Reports Analytics** | Open Reports. You should see charts or summaries of attendance, fees, and other metrics. |
| 2 | **Principal Analytics** | Open Analytics. You should see attendance trends, fee collection trends, and staff activity data. |
| 3 | **ID Card Generation** | Open ID Cards. Select a student or batch. Generate. A downloadable/printable ID card should appear with correct student photo and details. |
| 4 | **Report Card Generator** | Open Report Cards. Select a student and term. Generate. A report card with marks/grades should be downloadable. |
| 5 | **Export files** | Generated files should have correct student names, school name, and data — not placeholder text. |

---

### 17. System Monitor

**What it does:** Shows operational/backend health status — API status, server health, deployment info.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **System Monitor loads** | Open System Monitor. You should see backend health status, API connection info, and system operational status. |

---

### 18. Settings & Profile (Shared — All Roles)

**What they do:** Settings lets you configure app preferences. Profile shows your account details and allows editing.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Settings loads** | Open Settings (from bottom nav or sidebar). You should see available preferences (theme, notifications, language if supported). |
| 2 | **Save a setting** | Change a setting (e.g., toggle a switch). Save. The change should persist when you reopen Settings. |
| 3 | **Profile loads** | Open Profile (from bottom nav or sidebar). You should see your name, email, role, and other account details. |
| 4 | **Edit profile** | If editable, change your name or other details. Save. The change should persist. |

> **Note:** Settings and Profile are shared across all roles. Test them for Principal, Teacher, and Parent. The Kiosk role has no access to these screens.

---

## Teacher Role — Feature-by-Feature Guide

Log in as Teacher. You'll see the **Teacher Dashboard** — shows your assigned class, today's timetable, quick action tiles, metrics (classes, attendance, homework, messages), and an action queue.

---

### 1. Teacher Dashboard

**What it shows:** Your name, assigned class and subject, quick action buttons (My QR Check-in, Student Attendance, Timetable), today's timetable, and action queue items.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Dashboard loads** | After login, you see your name, assigned class, and today's subjects. No crash. |
| 2 | **Quick actions navigate** | Tap "My QR Check-in" → opens My Attendance screen. Tap "Student Attendance" → opens student attendance screen. Tap "Timetable" → opens timetable screen. |
| 3 | **Quick action grid** | Tap each tile: My Classes, Timetable, Student Attendance, Diary, Lesson Planner, Event Posts, Gallery, Reports. Each opens the correct screen. |
| 4 | **Metrics show data** | The metrics row shows: Classes (number), Attendance (marked/pending), Practice (homework due/total), Messages (count). Numbers should be reasonable. |
| 5 | **Action queue** | The "Today Action Queue" shows: Mark Student Attendance, Record Class Diary, Post Homework, Review PTM Slots, Track Leave. Tap each — opens the correct screen. |
| 6 | **Today feed** | The "Today Feed" shows your current timetable periods with subject names. Tap a period — it should open the Homework/Diary screen. |
| 7 | **End-of-day reminder** | If you log in after 3 PM and haven't posted homework today, a dialog should pop up asking "Would you like to add homework?" Tap "Add Homework" → opens Homework screen. Tap "Dismiss" → dialog closes. |
| 8 | **Notifications** | Tap the bell icon in the top-right. Opens Notification Center showing unread notifications. |
| 9 | **Profile** | Tap the person icon in the top-right. Opens your Profile screen with your details. |

---

### 2. My QR Check-in (Staff Attendance)

**What it does:** Lets you punch in your own attendance by scanning a QR code displayed on the Kiosk screen.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Open My Attendance** | Tap "My QR Check-in" on the dashboard. The My Attendance screen opens. |
| 2 | **Camera/scanner opens** | The screen should show a camera viewfinder or QR scanner interface. |
| 3 | **Scan Kiosk QR** | Point the camera at the Kiosk's QR code (you may need a second device or the Kiosk running on another screen). The scan should register. |
| 4 | **Punch-in confirmed** | After a successful scan, your attendance status should update to show your punch-in time. |
| 5 | **Duplicate scan** | Try scanning the same QR again. It should NOT create a duplicate attendance record for the same day. You should see a message like "Already punched in" or the scan is ignored. |
| 6 | **Expired QR** | Wait for the Kiosk QR to refresh (it changes every 7 seconds). Try scanning an old/expired QR. You should see a clear error message — not a crash. |
| 7 | **Refresh status** | Tap the refresh button on My Attendance. It should reload your current backend attendance state. |

---

### 3. Student Attendance

**What it does:** Lets you mark attendance (present/absent/late) for students in your assigned class.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Student list loads** | Open Student Attendance. You should see a list of students in your assigned class with their names. |
| 2 | **Mark attendance** | For each student, tap to toggle between Present, Absent, and Late. The status should visually change (color-coded or with icons). |
| 3 | **Submit attendance** | After marking all students, tap Submit/Save. The attendance should be saved to the backend. A confirmation message should appear. |
| 4 | **Attendance History** | Open Attendance History. You should see a list of past attendance records by date. Tap a date to see that day's attendance details. |
| 5 | **Empty state** | If there's no attendance history yet, the empty state should show a clear message like "No attendance records yet" — not a blank screen. |

---

### 4. My Classes

**What it does:** Shows the classes and sections assigned to you as a teacher.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Class list loads** | Open My Classes. You should see a list of your assigned classes/sections. |
| 2 | **Class details** | Tap a class. You should see details like the class name, section, number of students, and assigned subjects. |

---

### 5. Teacher Timetable

**What it does:** Shows your weekly timetable — which periods you have, what subjects, and in which classes.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Timetable loads** | Open Teacher Timetable. You should see a grid or list of your weekly periods. |
| 2 | **Today highlighted** | Today's column/row should be visually highlighted or at the top. |
| 3 | **Period details** | Each period should show: time, subject, class. |

---

### 6. Class Diary

**What it does:** Lets you record what was taught in each class period — the "diary" of your teaching day.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Diary list loads** | Open Class Diary. You should see a list of diary entries (or an empty state). |
| 2 | **Create a diary entry** | Tap add. Enter what was taught, the subject, class, and any notes. Save. The entry appears in the list. |
| 3 | **Edit a diary entry** | Tap an existing entry. Edit the notes. Save. Change persists. |

---

### 7. Homework / Diary Practice

**What it does:** Lets you create homework assignments for your class, and review submissions from students.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Homework list loads** | Open Homework/Diary. You should see a list of homework assignments you've created. |
| 2 | **Create homework** | Tap add. Fill in: title, subject, class, description, due date. Save. The homework appears in the list. |
| 3 | **View submissions** | Tap an existing homework item. You should see a "Submissions" option. Tap it to see which students have submitted. |
| 4 | **Review submission** | Tap a student's submission. You should see what they submitted and can mark it as reviewed. |

---

### 8. Lesson Planner

**What it does:** Lets you create and manage weekly lesson plans — what topics you'll cover and when.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Lesson plans list** | Open Lesson Planner. You should see a list of your lesson plans. |
| 2 | **Create a plan** | Tap add. Enter topic, subject, class, date range, and notes. Save. The plan appears. |
| 3 | **Edit a plan** | Tap an existing plan. Edit the details. Save. Change persists. |

---

### 9. Event Posts

**What it does:** Lets you create event/gallery posts (photos, announcements) that go to the principal for approval before appearing in the school feed.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Event posts list** | Open Event Posts. You should see your past posts and their approval status. |
| 2 | **Create an event post** | Tap add. Enter title, description, attach a photo/video (if supported). Submit. The post should appear with status "Pending Approval". |

---

### 10. Student Performance, Notes & Discipline (Academics)

**What they do:** Let you record observations about students — performance ratings, behavioral notes, and discipline records.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Student Performance** | Open Student Performance. You should see a list of students and their academic performance data. |
| 2 | **Student Notes** | Open Student Notes. You should see notes for students. Try adding a note — enter student, observation, and save. |
| 3 | **Student Discipline** | Open Student Discipline. You should see discipline records. Try adding a record — enter student, incident description, and save. |

---

### 11. Communication (Teacher)

**What it does:** Lets you send messages to parents, manage PTM (Parent-Teacher Meeting) slots, and view school notices.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Communication hub** | Open Communication. You should see options for parent messages, staff chats, and school notices. |
| 2 | **Send a message** | Open parent messages. Select a parent. Type a message and send. The message should appear in the conversation. |
| 3 | **Receive a message** | Have a parent send a message to you. It should appear in your Communication screen. |
| 4 | **PTM slots** | Open Parent Interaction / PTM. You should see PTM slot management. Try creating a time slot. Save. The slot should be visible to parents. |
| 5 | **School notices** | Open the notices section. You should see announcements from the principal/admin. |

---

### 12. Leave Requests (Teacher)

**What it does:** Lets you apply for leave and track the status of your requests.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Leave list loads** | Open Leave. You should see your past leave requests and their statuses (Pending, Approved, Rejected). |
| 2 | **Apply for leave** | Tap "Apply Leave" or add. Fill in: leave type, dates, reason. Submit. The request appears in the list with status "Pending". |
| 3 | **Leave balance** | If the feature is available, you should see your remaining leave balance. |

---

### 13. Reports (Teacher)

**What it does:** Shows class summaries and lets you export teaching reports.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Reports screen loads** | Open Reports. You should see summary data about your classes. |
| 2 | **Export** | Try exporting a report. A CSV or PDF file should download with your class data. |

---

### 14. Teacher Calendar

**What it does:** Shows school events on a calendar from the teacher's perspective.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Calendar loads** | Open Calendar. You should see a monthly calendar with school events marked on dates. |
| 2 | **Event details** | Tap a date with an event. You should see event details (title, time, description). |

---

### 15. Settings & Profile (Teacher)

> See [Settings & Profile section](#18-settings--profile-shared--all-roles) above. Test the same items for the Teacher role.

---

## Parent Role — Feature-by-Feature Guide

Log in as Parent. You'll see the **Parent Dashboard** — shows "School Feed" (approved event posts), a child selector (if you have multiple children), summary cards (Attendance, Homework, Fees, Messages), and quick shortcut chips.

---

### 1. Parent Dashboard

**What it shows:** A scrollable feed of approved school event posts at the top, a child selector pill (if multiple children), summary metric cards for the selected child, and quick shortcut chips (Attendance, Homework, Pay Fees, Leave, PTM, Documents).

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Dashboard loads** | After login, you see "School Feed" with event posts, your child's name in the selector, and summary cards. |
| 2 | **No linked student state** | If the parent account has no linked children, you should see a clear message: "No linked students — Ask the school admin to link students to this parent account." Not a blank screen or crash. |
| 3 | **Child selector** | If you have multiple children, tap the child selector pill. A dropdown should appear with all your children. Select a different child — the summary cards should update to show that child's data. |
| 4 | **Summary cards navigate** | Tap Attendance card → opens Parent Attendance screen. Tap Homework → opens Homework screen. Tap Fees → opens Fees screen. Tap Messages → opens Teacher Chat screen. |
| 5 | **Shortcut chips** | Tap each chip: Attendance, Homework, Pay Fees, Leave, PTM, Documents. Each opens the correct screen. |
| 6 | **School Feed** | Scroll through the feed. You should see approved event posts with titles, descriptions, dates, and media (if any). If no posts exist, you should see "No posts yet — School events and activity posts will appear here once published." |
| 7 | **Drawer navigation** | Open the sidebar drawer (swipe from left or tap hamburger menu). You should see navigation items for all parent modules. Tap each — it opens the correct screen. |
| 8 | **Mobile layout** | On a phone, everything should fit within the screen. No overflow, no overlapping cards. |

---

### 2. Academic Progress

**What it does:** Shows your child's marks, grades, and academic performance over time.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Progress screen loads** | Open Academic Progress. You should see marks/grades for your child organized by subject and exam. |
| 2 | **Child data correct** | If you have multiple children, the screen should show data for the currently selected child. |

---

### 3. Attendance (Parent View)

**What it does:** Shows your child's attendance history — which days they were present, absent, or late.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Attendance loads** | Open Attendance. You should see a summary (attendance percentage) and a history of daily attendance records. |
| 2 | **Calendar view** | If a calendar view is available, days should be color-coded (green = present, red = absent, yellow = late). |
| 3 | **History list** | Below the calendar, you should see a list of attendance records with dates and statuses. |

---

### 4. Homework (Parent View)

**What it does:** Shows homework assigned to your child. Lets you view details and submit homework on behalf of your child.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Homework list loads** | Open Homework. You should see a list of active and past homework assignments for your child. |
| 2 | **View homework details** | Tap a homework item. You should see: title, subject, description, due date, and teacher name. |
| 3 | **Submit homework** | Tap "Submit" on a homework item. Upload a file or enter a response. Submit. The submission should be saved. |
| 4 | **Submission confirmation** | After submitting, the homework item should show "Submitted" status. |

---

### 5. Class Diary (Parent View)

**What it does:** Shows the teacher's diary entries — what was taught each day in your child's class.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Diary loads** | Open Class Diary. You should see diary entries organized by date. |
| 2 | **Entry details** | Tap an entry. You should see what was taught, the subject, and any notes from the teacher. |

---

### 6. Lesson Planner (Parent View)

**What it does:** Shows published lesson plans — what topics the teacher plans to cover.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Lesson planner loads** | Open Lesson Planner. You should see a list of published lesson plans for your child's class. |

---

### 7. Timetable (Parent View)

**What it does:** Shows your child's class timetable — which subjects are taught at what times.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Timetable loads** | Open Timetable. You should see a weekly grid showing your child's periods, subjects, and times. |

---

### 8. School Notices (Parent View)

**What it does:** Shows school-wide announcements and notices.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Notices list loads** | Open School Notices. You should see a list of notices with titles, dates, and content. |
| 2 | **Notice details** | Tap a notice. You should see the full message content. |

---

### 9. Teacher Chat & PTM (Communication)

**What it does:** Lets you message your child's teachers and book Parent-Teacher Meeting (PTM) slots.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Chat list loads** | Open Teacher Chat. You should see a list of teachers you can message (your child's teachers). |
| 2 | **Send a message** | Select a teacher. Type a message and send. It should appear in the conversation. |
| 3 | **Receive a message** | Have a teacher send you a message. It should appear in your chat. |
| 4 | **PTM booking** | Open PTM Booking. You should see available meeting slots. Select a slot and book it. The booking should be confirmed. |

---

### 10. Fees (Finance)

**What it does:** Shows your child's fee status — what's due, what's paid — and lets you submit payment requests.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Fees screen loads** | Open Fees. You should see a list of fee items with amounts, due dates, and payment status. |
| 2 | **Select payment** | Tap "Pay" or select a fee item to pay. You should see a payment selection screen showing the amount. |
| 3 | **Submit payment request** | Fill in payment details (amount, payment method, reference). Submit. The request should appear in your payment history with status "Pending". |
| 4 | **Receipt view** | Open Payments & Receipts. You should see past payments and receipts. Tap one — you should see details and an option to download/view the receipt. |

---

### 11. Leave Requests (Parent — for Student)

**What it does:** Lets you submit leave requests for your child (e.g., sick day, family event).

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Leave list loads** | Open Leave Requests. You should see past leave requests for your child and their statuses. |
| 2 | **Submit a leave request** | Tap "Request Leave". Fill in: student name, dates, reason. Submit. The request appears with status "Pending". |
| 3 | **Status updates** | After the principal approves/rejects, the status should update when you reopen the screen. |

---

### 12. Calendar (Parent View)

**What it does:** Shows school events on a calendar.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Calendar loads** | Open Calendar. You should see a monthly calendar with school events marked on dates. |
| 2 | **Event details** | Tap a date with an event. You should see event details (title, time, description). |

---

### 13. Documents (Parent View)

**What it does:** Shows documents shared by the school — report cards, certificates, circulars, etc.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Documents list loads** | Open Documents. You should see a list of available documents. |
| 2 | **Download/view** | Tap a document. You should be able to view it or download it. |

---

### 14. Exam Schedule (Parent View)

**What it does:** Shows upcoming exams scheduled for your child.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Exam schedule loads** | Open Exam Schedule. You should see a list of upcoming exams with dates, subjects, and times. |
| 2 | **Exam details** | Tap an exam. You should see details like subject, date, time, and any instructions. |

---

### 15. Discipline (Parent View)

**What it does:** Shows discipline records for your child — any behavioral notes or incidents recorded by teachers.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Discipline screen loads** | Open Discipline. You should see a list of discipline records for your child (or an empty state if none exist). |
| 2 | **Record details** | Tap a record. You should see the incident description, date, and teacher who recorded it. |

---

### 16. Health Update (Parent View)

**What it does:** Lets you submit health information about your child (allergies, conditions, medications).

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Health screen loads** | Open Health Update. You should see existing health info for your child (if any). |
| 2 | **Submit health info** | Enter health details (allergies, conditions). Save. The info should persist when you reopen. |

---

### 17. Settings & Profile (Parent)

> See [Settings & Profile section](#18-settings--profile-shared--all-roles) above. Test the same items for the Parent role.

---

## Kiosk Role — Feature-by-Feature Guide

Log in as Kiosk. You should be taken **directly** to the **QR Attendance Kiosk** screen — no dashboard, no sidebar, no other screens.

---

### QR Attendance Kiosk

**What it does:** Displays a large QR code that teachers scan with their phones to punch in their staff attendance. The QR refreshes automatically every 7 seconds for security.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Direct to Kiosk** | After kiosk login, you should land directly on the QR Attendance screen. No other screens or navigation options should be visible. |
| 2 | **QR code displays** | A large QR code should be visible in the center of the screen. It should be scannable (clear, high contrast). |
| 3 | **Countdown timer** | Below the QR, you should see a countdown timer starting at 7 seconds and counting down: 7, 6, 5, 4, 3, 2, 1, 0. |
| 4 | **QR refreshes** | When the timer reaches 0, the QR code should change (new code) and the timer should reset to 7 and start counting down again. |
| 5 | **Multiple refresh cycles** | Watch for at least 10 consecutive refresh cycles (about 70 seconds). The QR and timer should continue working without crashing or freezing. |
| 6 | **Manual refresh button** | There should be a "Refresh QR" button. Tap it — a new QR code should appear immediately and the timer should reset to 7. |
| 7 | **Recent scans list** | After a teacher scans the QR, their name and scan time should appear in a "Recent Scans" list on the kiosk screen. |
| 8 | **Export QR log** | Tap "Export" or "Download Log". A CSV file should download with today's scan records (teacher name, time, QR ID). |
| 9 | **No back navigation** | Try to navigate back (press back button or gesture). You should NOT be able to leave the kiosk screen to access other roles. |
| 10 | **Sign out** | Find the sign-out option. After signing out, you should be back at the login screen. The QR screen should not be accessible without logging in again. |
| 11 | **Teacher scan works after refreshes** | After the QR has refreshed multiple times, have a teacher scan the current QR. It should work — the scan should register successfully. |

---

## Cross-Role Workflows — End-to-End Tests

These tests verify that features work across multiple roles together. You'll need to switch between accounts (or use multiple devices).

---

### Workflow 1: Staff Attendance (Kiosk → Teacher → Principal)

This tests the full staff attendance flow: Kiosk displays QR → Teacher scans → Principal sees the record.

| # | Step | Expected result |
|---|------|----------------|
| 1 | Log in as **Kiosk** | QR Attendance Kiosk screen appears with live QR. |
| 2 | Log in as **Teacher** on a second device | Teacher Dashboard loads. |
| 3 | Teacher taps "My QR Check-in" | My Attendance screen opens with camera/scanner. |
| 4 | Teacher scans the Kiosk's QR code | Scan registers. Teacher sees "Punched in at [time]". |
| 5 | Log in as **Principal** | Principal Dashboard loads. |
| 6 | Principal opens Attendance → Staff Attendance | The teacher's attendance record should appear with the correct punch-in time. |

---

### Workflow 2: Student Attendance (Teacher → Principal → Parent)

This tests: Teacher marks attendance → Principal sees it → Parent sees it.

| # | Step | Expected result |
|---|------|----------------|
| 1 | Log in as **Teacher** | Teacher Dashboard loads. |
| 2 | Teacher opens Student Attendance | Student list loads for assigned class. |
| 3 | Teacher marks students Present/Absent/Late and submits | Attendance saved. Confirmation message shown. |
| 4 | Log in as **Principal** | Principal opens Attendance → Class Attendance → selects the same class/date. The attendance records should match what the teacher submitted. |
| 5 | Log in as **Parent** | Parent opens Attendance. The child's attendance record for today should reflect what the teacher marked. |

---

### Workflow 3: Homework (Teacher → Parent → Teacher)

This tests: Teacher creates homework → Parent sees and submits → Teacher reviews.

| # | Step | Expected result |
|---|------|----------------|
| 1 | Log in as **Teacher** | Teacher opens Homework. Creates a new assignment (title, subject, description, due date). Saves. |
| 2 | Log in as **Parent** | Parent opens Homework. The new assignment should appear in the list. |
| 3 | Parent taps "Submit" on the homework | Uploads a file or enters a response. Submits. Status changes to "Submitted". |
| 4 | Log in as **Teacher** | Teacher opens Homework → taps the assignment → taps "Submissions". The parent's submission should appear. |

---

### Workflow 4: Leave Request (Parent → Principal → Parent)

This tests: Parent submits leave → Principal approves → Parent sees status update.

| # | Step | Expected result |
|---|------|----------------|
| 1 | Log in as **Parent** | Parent opens Leave Requests. Taps "Request Leave". Fills in dates and reason. Submits. Status = "Pending". |
| 2 | Log in as **Principal** | Principal opens the approval area or Leave Requests. The parent's request should appear. |
| 3 | Principal approves the request | Status changes to "Approved". |
| 4 | Log in as **Parent** | Parent opens Leave Requests. The request status should now show "Approved". |

---

### Workflow 5: Fee Payment (Principal sets up → Parent pays → Principal approves)

This tests: Principal configures fees → Parent submits payment → Principal approves.

| # | Step | Expected result |
|---|------|----------------|
| 1 | Log in as **Principal** | Principal opens Fees. Creates or verifies a fee structure exists for the student's class. |
| 2 | Log in as **Parent** | Parent opens Fees. Sees the fee due. Taps "Pay" or "Submit Payment". Fills in payment details. Submits. Status = "Pending". |
| 3 | Log in as **Principal** | Principal opens Payment Requests. The parent's request appears. |
| 4 | Principal approves the request | Status changes to "Approved". |
| 5 | Log in as **Parent** | Parent opens Fees / Payments & Receipts. The payment status should show "Approved" and a receipt should be available. |

---

### Workflow 6: Event Post (Teacher → Principal → Parent)

This tests: Teacher creates event post → Principal approves → Parent sees it in feed.

| # | Step | Expected result |
|---|------|----------------|
| 1 | Log in as **Teacher** | Teacher opens Event Posts. Creates a new post (title, description, photo). Submits. Status = "Pending Approval". |
| 2 | Log in as **Principal** | Principal opens Event Approvals. The teacher's post should appear in the pending list. |
| 3 | Principal approves the post | Status changes to "Approved". |
| 4 | Log in as **Parent** | Parent opens Dashboard. The approved post should appear in the School Feed. |

---

### Workflow 7: Messaging & Homework Feedback (Teacher ↔ Parent)

This tests: Teacher sends message → Parent receives → Parent replies → Teacher receives. Also covers homework feedback messaging.

| # | Step | Expected result |
|---|------|----------------|
| 1 | Log in as **Teacher** | Teacher opens Communication → Parent Messages. Selects a parent. Types and sends a message. |
| 2 | Log in as **Parent** | Parent opens Teacher Chat. The teacher's message should appear. |
| 3 | Parent types and sends a reply | Message sends successfully. |
| 4 | Log in as **Teacher** | Teacher opens the conversation. The parent's reply should appear. |

---

### Workflow 8: Account Creation & Access Control

This tests: Principal creates accounts → Users log in → Role access is enforced.

| # | Step | Expected result |
|---|------|----------------|
| 1 | Log in as **Principal** | Principal opens Access Permissions. Creates a new Teacher account (name, email, password). |
| 2 | Log out. Log in as the **new Teacher** | Teacher Dashboard loads. The new teacher can access teacher screens. |
| 3 | Principal creates a new **Parent** account | Account created successfully. |
| 4 | Principal assigns a child to the parent | Parent can now see that child's data. |
| 5 | Log in as the **new Parent** | Parent Dashboard loads. The child appears in the selector. Summary cards show that child's data. |
| 6 | **Role access test** | As a Teacher, try to manually navigate to a Principal-only route (if possible). The app should redirect to the Teacher Dashboard or show an access error. Same for Parent trying to access Teacher/Principal routes. |

---

## Android Push Notifications & Scheduled Reports

Use an Android build with notification permission allowed and a signed-in device token registered for the test user.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **Teacher QR scan → Principal push** | Teacher scans the Kiosk QR successfully. Principal receives a push notification. Tapping it opens Principal Attendance. |
| 2 | **Daily staff attendance report** | After the 6:00 PM IST worker schedule, Principal receives a daily staff attendance summary notification. Tapping it opens Principal Attendance. |
| 3 | **Monthly staff attendance report** | On the last calendar day after 6:15 PM IST, Principal receives a monthly staff attendance summary notification. Tapping it opens Principal Attendance. |
| 4 | **Teacher event post submitted** | Teacher submits an event post for approval. Principal receives a push notification. Tapping it opens Event Approvals. |
| 5 | **Event post approved/rejected** | Principal approves or rejects the post. Only the submitting teacher receives a push notification. Tapping it opens Teacher Event Posts. |
| 6 | **Weekly lesson planner digest** | After the Friday 6:30 PM IST worker schedule, Principal receives a submitted/missing lesson planner summary. Tapping it opens Principal Lesson Planner. |
| 7 | **No kiosk push** | Kiosk user does not receive push notifications; it only displays/refreshes QR attendance. |
| 8 | **No duplicate scheduled reports** | Restart the worker or wait through another scheduler pass. Principal should not receive duplicate daily/monthly/weekly report notifications for the same period. |

---

## Regression & Reliability Checks (All Roles)

Run these checks for **each role** (Principal, Teacher, Parent, Kiosk) to catch common issues.

| # | What to test | What "pass" looks like |
|---|-------------|----------------------|
| 1 | **App survives refresh** | Close and reopen the app (or refresh in browser). The dashboard should reload without showing a blank screen or error. |
| 2 | **Backend errors are clear** | If the backend is down or slow, you should see a clear error message with a Retry button — not a blank screen or infinite spinner. |
| 3 | **Empty states are clear** | When there's no data (no homework, no notices, no attendance), the screen should show a friendly empty state message — not a blank white screen or fake/placeholder data shown as real data. |
| 4 | **Forms validate required fields** | Try submitting a form with empty required fields. You should see validation errors (red text or highlights) — the form should not submit. |
| 5 | **Save buttons prevent duplicates** | Tap a Save/Submit button multiple times quickly. Only one submission should go through (button should disable or show loading). |
| 6 | **Lists refresh after changes** | After creating, editing, or deleting an item, the list should update to reflect the change without needing a manual refresh. |
| 7 | **Exports produce usable files** | Download a CSV/PDF. Open it. The file should have correct data, readable formatting, and the school/student names should be accurate. |
| 8 | **Search/filter works** | Use any search or filter feature. If there are no results, you should see "No results found" — not a crash. |
| 9 | **Long content doesn't overflow** | If a student has a very long name, or a class has a long label, the text should truncate with "..." — not overflow outside its container. |
| 10 | **Session expiry is clean** | If your session expires (or you log out), you should not see stale data from the previous role. The app should redirect to login cleanly. |

---

## Test Run Sign-Off Log

| Date | Tester | Role/Area Tested | Build/Commit | Result | Notes |
|------|--------|-----------------|--------------|--------|-------|
| 2026-06-22 | | Kiosk QR refresh | a170ee4 | Passed | User confirmed kiosk feature is working |
| | | | | | |
| | | | | | |
