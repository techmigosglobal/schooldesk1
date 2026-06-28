# Product Overview — Arish Ville School Management App

## Project Purpose
Arish Ville is a full-stack school management platform consisting of:
- A **Flutter mobile app** (cross-platform: Android + iOS) for school stakeholders
- A **Go (Gin) REST API backend** with PostgreSQL + Redis for data and caching
- Observability stack: Prometheus + Grafana for monitoring

The app digitizes school operations — attendance, fees, timetables, leave, homework, communication, documents — for a private school with a single tenant/school model.

## Target Users & Roles
| Role | Access Level | Key Responsibilities |
|------|-------------|---------------------|
| Principal | Full oversight | Approve leaves, monitor fees, manage staff, view analytics |
| Admin | Operations | Student/teacher admin, fees, timetables, exam scheduling |
| Teacher | Class-level | Attendance, homework, lesson plans, leave requests |
| Parent | Child-focused | View child's attendance, fees, homework, communicate with teacher |

## Key Features & Capabilities

### Cross-Role Features
- Role-based access control with JWT authentication
- Push notifications (Firebase FCM) for cross-role events
- In-app messaging and communication threads
- Document/certificate generation (PDF)
- School calendar with events and holidays

### Principal Module
- KPI dashboard (students, teachers, attendance, fees, complaints)
- Staff and student management with search/filter
- Fee monitoring and concession approvals
- Timetable creation with clash detection
- Syllabus progress monitoring
- Exam scheduling and results publishing
- Approval center (leave requests, disciplinary escalations)
- Complaint lifecycle management
- Communication center (circulars, urgent alerts)
- Audit logs and system monitoring

### Admin Module
- Student administration (add, promote, document upload)
- Staff/teacher administration with leave tracking
- Fee structure setup and payment recording
- Timetable and substitution management
- Exam administration and hall ticket generation
- Parent helpdesk with escalation to Principal
- User access management (create/lock/unlock accounts)
- Government compliance report exports

### Teacher Module
- Daily timetable and class roster
- Attendance marking (Present/Absent/Late/Half-Day) with correction requests
- Homework creation and submission tracking
- Daily lesson planner with syllabus completion tracking
- Student performance tracking and observations
- Student behavioral and academic notes
- Parent interaction (PTM scheduling, feedback logs)
- Leave management with substitute requests
- Study resource sharing
- Discipline/incident reporting

### Parent Module
- Multi-child switching (e.g., Arjun & Priya)
- Child academic progress (marks, remarks, report card download)
- Attendance calendar with absence/late records
- Homework list with deadlines
- School notices feed (circulars, holidays, emergencies)
- Teacher chat and PTM booking
- Fee management with payment recording and receipt download
- Leave/early-pickup requests
- Events RSVP and academic calendar
- Document download (ID card, bonafide certificate requests)

## Deployment Targets
- **Development**: Local Docker (FastAPI → Go backend on port 8080)
- **Staging/Production**: Railway.app (auto-detect from Dockerfile)
- **VPS Production**: Hostinger Ubuntu 24.04 with Docker + Traefik reverse proxy
- **Flutter build**: `--dart-define-from-file=env.json` for environment switching; HTTPS required for release builds

## App Identity
- App name: "Arish Ville Preschool"
- Version: 1.0.9+17
- Package: `schooldesk1`
- Fonts: DM Sans, IBM Plex Sans, Inter (bundled locally, no runtime fetching)
- Logo: `assets/branding/ArishVilleLogo.png`
