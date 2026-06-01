# SchoolDesk — Flutter School Management App

A modern Flutter-based mobile application for school management, supporting four roles: Principal, Admin, Teacher, and Parent.

## 📋 Prerequisites

- Flutter SDK (^3.38.4)
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- Android SDK / Xcode (for iOS development)

## 🛠️ Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Run the application:
```bash
flutter run
```

## Local Docker Backend

1. Start the Go API, PostgreSQL, and Redis:

```bash
docker compose up -d
```

2. Verify the API is healthy:

```bash
curl http://127.0.0.1:8080/health
```

3. For a wireless Android device, forward the device port to the local Docker API:

```bash
adb reverse tcp:8080 tcp:8080
```

4. Run Flutter against the local Docker API:

```bash
cp env.local.example.json env.json
flutter run --dart-define-from-file=env.json
```

After local verification succeeds, the same Go API stack is the deployment path
for the Hostinger VPS environment.

### Optional Prometheus + Grafana

Start the observability overlay with the local backend:

```bash
docker compose -f docker-compose.yml -f docker-compose.observability.yml --profile observability up -d
```

Prometheus is available at `http://127.0.0.1:9090`; Grafana is available at
`http://127.0.0.1:3000` with `admin` / `schooldesk-admin` unless overridden by
`GRAFANA_ADMIN_USER` and `GRAFANA_ADMIN_PASSWORD`. The provisioned dashboard is
`SchoolDesk API Overview`.

Verify the full local observability stack:

```bash
scripts/verify-observability.sh
```

For Hostinger/VPS, keep Grafana and Prometheus bound to `127.0.0.1` and access
them through SSH tunnels unless a protected reverse proxy is explicitly added.
Details are in `docs/observability-runbook.md`.

## Switching Backend Targets

The app changes backend linkage through `API_BASE_URL`; no Dart code should be
edited when switching between local Docker and Hostinger.

For local Docker:

```bash
cp env.local.example.json env.json
flutter run --dart-define-from-file=env.json
```

For Hostinger after the API domain is live:

```bash
cp env.hostinger.example.json env.hostinger.json
# edit env.hostinger.json and replace https://api.yourdomain.com/api
flutter run --dart-define-from-file=env.hostinger.json
```

Release builds must use HTTPS:

```bash
flutter build apk --release --dart-define-from-file=env.hostinger.json
```

For the Hostinger "Ubuntu 24.04 with Docker and Traefik" template, deploy the
backend with:

```bash
cp deploy/hostinger-traefik.env.example .env
# edit .env with real secrets, API_HOST, and ALLOWED_ORIGINS
docker compose -f docker-compose.hostinger-traefik.yml up -d --build
```

To validate the compose file without copying over your local `.env`, run:

```bash
SCHOOLDESK_ENV_FILE=deploy/hostinger-traefik.env.example \
docker compose --env-file deploy/hostinger-traefik.env.example \
  -f docker-compose.hostinger-traefik.yml config
```

## 📁 Project Structure

```
flutter_app/
├── android/            # Android-specific configuration
├── ios/                # iOS-specific configuration
├── lib/
│   ├── app/            # App bootstrap, providers, and module registry
│   ├── core/           # Config, network, services, theme, and shared widgets
│   ├── features/       # Feature-first modules with domain-owned screens
│   ├── routes/         # Application routing
│   └── main.dart       # Application entry point
├── assets/             # Static assets (images, fonts, etc.)
├── pubspec.yaml        # Project dependencies and configuration
└── README.md           # Project documentation
```

## 🎨 Theming

This project includes a comprehensive theming system:

```dart
ThemeData theme = Theme.of(context);
Color primaryColor = theme.colorScheme.primary;
```

## 📱 Responsive Design

The app is built with responsive design using the Sizer package:

```dart
Container(
  width: 50.w,
  height: 20.h,
  child: Text('Responsive Container'),
)
```

## 📦 Deployment

```bash
# For Android
flutter build apk --release

# For iOS
flutter build ios --release
```

---

## 🧪 Application Testing Workflow

A complete end-to-end testing guide for SchoolDesk across all four roles and their cross-role integrations.

---

### 🏫 Starting Point — Landing Page

1. Launch the app — verify the landing page loads with school name, hero section, and all sections (About, Academics, Admissions, Faculty, Gallery, Notices, Contact)
2. Scroll through all sections — confirm no overflow or layout issues
3. Locate the **portal login buttons** at the bottom — Principal, Admin, Teacher, Parent

---

### 👨‍💼 Role 1 — Principal

#### Login
- Tap **Principal Login**
- Verify dashboard loads with KPI cards (students, teachers, attendance, fees, complaints)

#### Dashboard
- Tap each KPI card — confirm it navigates to the relevant module
- Check the notification bell — verify pending approvals appear

#### Academic Year Management
- Create a new academic year → activate it → verify it reflects across modules

#### Staff Management
- Add a new teacher (name, subject, class) → save → verify they appear in the staff list
- Edit the teacher's details → confirm changes persist after navigating away
- Search for the teacher by name

#### Student Oversight
- Filter students by class → open a student profile
- Add a disciplinary note → verify it saves
- Check weak student alerts and topper list

#### Fee Monitoring
- View class-wise fee structure
- Check pending dues dashboard — verify student names and amounts
- Approve a concession request

#### Timetable Management
- Create a new timetable period → save → check for clash detection
- Assign a substitute teacher → verify the change reflects

#### Syllabus Monitoring
- Open a class → mark a topic as completed
- Check syllabus progress percentage updates

#### Exams & Results
- Create an exam schedule → approve it
- Publish marks → verify results dashboard shows toppers and weak areas

#### Approval Center *(cross-role integration check)*
- Verify teacher leave requests appear here (submitted in Teacher role)
- Approve one → reject another with a remark
- Check audit log for both actions

#### Complaint Management
- Create a complaint ticket (category: facilities)
- Assign it → change status to In Progress → resolve it

#### Communication Center
- Create a circular → publish it
- Send an urgent alert → verify it appears in Parent notices (check after testing Parent role)

#### Events & Calendar
- Add a school event with a date → add a holiday
- Check reminders are set

#### Reports
- Generate an attendance report → export as PDF
- Generate a fee report → export as CSV

---

### 🗂️ Role 2 — Admin

#### Login
- Go back to landing page → tap **Admin Login**
- Verify operations dashboard loads with KPI grid and system alerts

#### Student Administration
- Add a new student with class/section/roll number → save
- Upload a document (Aadhaar/TC) → verify it attaches to the profile
- Promote the student to the next class

#### Teacher/Staff Administration
- Add a new staff member → assign subject and class
- Record a leave entry for the staff → check leave balance updates

#### Attendance Administration
- View today's attendance for a class
- Correct an attendance record → verify the correction saves
- Check if teacher-submitted correction requests appear here *(cross-role integration)*

#### Fees & Finance
- Set up a fee structure for a class
- Record a cash payment for a student → generate a receipt
- Check pending dues list — verify it matches Principal's fee monitoring view

#### Timetable & Scheduling
- Create a class timetable → assign teachers to periods
- Add a substitution → verify clash detection triggers if conflict exists

#### Exam Administration
- Create an exam → generate a hall ticket
- Set a seating plan → allocate invigilators

#### Communication Management
- Draft a fee reminder notice → send it
- Create a holiday alert → verify it appears in Parent notices *(cross-role check)*

#### Parent Helpdesk
- Open a parent query ticket *(submitted from Parent role)*
- Respond to it → escalate one to Principal
- Verify escalated ticket appears in Principal complaints

#### Document/Certificate Management
- Generate a bonafide certificate for a student
- Process a TC request → mark as issued

#### User & Access Management
- Create a teacher account → assign role permissions
- Lock a user account → unlock it
- Check activity log

#### Reports & Compliance
- Generate an admissions report → export as PDF
- Generate a government compliance export → verify formatting

---

### 📚 Role 3 — Teacher

#### Login
- Go back to landing page → tap **Teacher Login**
- Verify dashboard loads with today's timetable, pending tasks, and announcements

#### My Classes
- View assigned classes and sections
- Open a class → browse student list with grades and attendance

#### Attendance
- Mark attendance for a class: mark some Present, Absent, Late, Half-Day
- Use bulk mark all present → then correct one individual
- Submit a correction request for a past record → verify it appears in Admin attendance screen *(cross-role check)*

#### Homework
- Create a homework assignment with a deadline and instructions
- View submission status — mark one as submitted
- Edit the homework details → verify changes save

#### Lesson Planner
- Add a daily lesson plan for a subject
- Tap a syllabus topic to toggle it as completed
- Verify syllabus progress updates in Principal's syllabus monitoring *(cross-role check)*

#### Student Performance
- View marks trend for a student
- Add an observation (academic issue or strength) → recommend support
- Check weak student alerts

#### Student Notes
- Add a behavior note for a student (priority: High)
- Add an academic note → verify both appear in the notes list

#### Communication
- View inbox — check if Admin/Principal notices appear
- Send a class update notice

#### Parent Interaction
- Schedule a PTM slot with a time and date
- Verify the slot appears in Parent's PTM booking screen *(cross-role check)*
- Record a parent feedback log

#### Leave Management
- Apply for a leave (sick leave, 2 days) with substitute request
- Verify the request appears in Principal's Approval Center *(cross-role check)*
- Check leave balance after submission

#### Resources
- Upload a study note with a title and subject
- Add a video reference link
- Share a resource → verify it's accessible

#### Discipline / Incidents
- Report a classroom incident
- Escalate it to Admin and Principal
- Verify it appears in Principal's complaint management *(cross-role check)*

#### Reports
- Generate a class attendance report
- Generate a homework completion report → export

---

### 👨‍👩‍👧 Role 4 — Parent

#### Login
- Go back to landing page → tap **Parent Login**
- Verify dashboard loads with child summary card, today's attendance, homework due, and fee alerts

#### Multi-Child Switching
- Switch between Arjun and Priya using the child switcher
- Verify dashboard data updates for each child

#### Child Academic Progress
- View subject-wise marks and progress bars
- Check teacher remarks
- Download a report card

#### Attendance
- View attendance calendar for the current month
- Check late arrival and absence records
- Submit a sick leave request for the child

#### Homework
- View pending homework list — check deadlines and instructions
- Switch to submitted tab — verify previously done work shows

#### School Notices
- Check if Admin/Principal circulars appear here *(cross-role check)*
- Acknowledge a notice → verify it's marked as read
- Filter notices by type (holiday, emergency, event)

#### Teacher Communication
- Open a message thread with the class teacher
- Send a query message
- Book a PTM slot from teacher's available slots *(cross-role check with Teacher PTM)*

#### Fee Management
- View pending fee dues and due dates
- Record a payment → download the receipt
- View payment history and fee structure

#### Leave Requests
- Submit an early pickup request
- Check approval status — verify it appears in Admin and Teacher views *(cross-role check)*

#### Events & Calendar
- View academic calendar — check exam dates and holidays
- RSVP to a school event

#### Documents & Certificates
- Download the child's ID card
- Request a bonafide certificate → verify it appears in Admin's document management *(cross-role check)*

---

### 🔁 Cross-Role Integration Checklist

| Action | Created By | Should Appear In |
|---|---|---|
| Teacher applies leave | Teacher | Principal Approval Center |
| Teacher marks discipline | Teacher | Principal Complaints |
| Teacher schedules PTM | Teacher | Parent PTM booking |
| Admin publishes notice | Admin | Parent notices feed |
| Parent submits leave | Parent | Admin & Teacher |
| Parent raises helpdesk ticket | Parent | Admin Helpdesk |
| Admin escalates ticket | Admin | Principal Complaints |
| Principal approves leave | Principal | Teacher Leave status |

---

### 📱 Responsiveness Spot Checks

- Test each dashboard on a small phone (360px width) — verify no text overflow
- Test forms (add student, add teacher, leave request) — confirm fields don't crowd
- Test KPI grids on tablet — verify cards use wider layout
- Test drawer navigation on both sizes — confirm it opens/closes smoothly
- Test all dialogs and bottom sheets — verify they scroll when content is tall

---

## 🙏 Acknowledgments
- Built with [Rocket.new](https://rocket.new)
- Powered by [Flutter](https://flutter.dev) & [Dart](https://dart.dev)
- Styled with Material Design

Built with ❤️ on Rocket.new
