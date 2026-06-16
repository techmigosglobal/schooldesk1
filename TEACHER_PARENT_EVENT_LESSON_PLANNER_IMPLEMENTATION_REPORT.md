# Teacher, Parent, Event & Lesson Planner — Implementation Report

**Date:** 2026-06-16  
**Build status:** ✅ `flutter build apk --debug` — passed with zero errors

---

## Summary of All Tasks

### TASK 1 — Teacher Module: Exams/Marks Removed ✅
- `TeacherDrawer` has no exam, marks, or marks-entry navigation items.
- `deprecatedProtectedRoutes` in `route_access_guard.dart` blocks `teacherPerformance`, `teacherMarkEntry`, `teacherStudentNotes`, `teacherDiscipline`, `teacherParentInteraction`, `teacherPTM`.
- Teacher Quick Action grid does **not** contain Exams or Marks.
- Principal/Admin exam routes (`principalExams`, `adminExams`, `examsResults`) are untouched.

### TASK 2 — Timetable: Full-Day Class View ✅
**File rewritten:** `lib/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart`

New 3-card layout:
- **Card 1 — Today's Assigned Class:** Large teal card showing class name, date, and all today's subjects as chips.
- **Card 2 — Quick Actions:** Attendance, Homework, Lesson Planner, Event Post action chips.
- **Card 3 — Today's Periods:** Period-by-period list (read-only, no period-teacher switching).

### TASK 3 — Teacher Event Posts ✅
- `TeacherEventPostScreen` with Create + Status tabs.
- Destinations: Parent Home Feed, School Gallery, Public Landing Page (checkboxes).
- Status: Draft / Pending / Approved / Rejected (with rejection reason).
- Backend: `POST /api/v1/event-posts`, `GET /api/v1/event-posts/teacher`.

### TASK 4 — Gallery Feature ✅
- `SchoolGalleryScreen` accessible to teacher, principal, admin, parent.
- Shows only `approval_status = approved` posts with `SCHOOL_GALLERY` destination.
- Grid layout (1/2/3 columns responsive), image preview, detail modal.
- Route: `/school-gallery-screen` — registered in all four roles' route guards.

### TASK 5 — Parent Home Feed (Google Classroom style) ✅
- `ParentDashboardScreen` fetches and merges: event posts, lesson planners, homework.
- Feed capped at 10 items with "View More" redirect to Gallery.
- Approval-filtered: only approved event posts visible.

### TASK 6 — Landing Page Events ✅
- Backend: `GET /api/v1/landing/events` (unauthenticated, public fields only).
- Returns only `approval_status = approved` + `SCHOOL_LANDING` destination posts.
- No internal approval fields exposed.

### TASK 7 — Lesson Planner ✅
**Teacher:** Upload weekly plan (class/section, date range, attachment URL, note). Mark as complete.  
**Parent:** `ParentLessonPlannerScreen` — shows planners for linked child's class/section.  
**Principal:** `GET /api/v1/lesson-planners/principal` with grade filter.  
**Notification:** Completing a planner notifies parents of that section.

### TASK 8 — Homework End-of-Day Reminder ✅
- After 15:00 with zero homework: `AlertDialog` shown in `TeacherDashboardScreen`.
- "Add Homework" navigates to homework screen. "No homework" marks dismissed for the day.
- Dismissed state stored in `SharedPreferences` per calendar date.
- Homework is optional — no forced validation.

### TASK 9 — Kiosk QR Refresh Every 5 Seconds ✅
- Backend: `staffQRRefreshSeconds = 5` in `attendance.go`.
- Frontend countdown timer cancels on `dispose()` (no leak).
- **Added label:** "QR refreshes every 5 seconds" shown below the countdown timer.

### TASK 10 — Notifications ✅
- Principal: notified on new event post submission.
- Teacher: notified on event post approved/rejected.
- Parent: notified on new approved parent-home post, lesson planner completed, homework added.
- Uses existing `NotificationLog` in-app system + push queue.

### TASK 11 — Navigation and Role Access ✅

| Role | Menu items | Blocked |
|------|-----------|---------|
| Teacher | Dashboard, My Classes, Timetable, My Attendance, Attendance, Homework, Study Materials, Event Posts, Lesson Planner, Gallery, Communication, Leave, Reports | Exams, Marks, Marks Entry |
| Principal | All core modules + **Event Approvals** (newly added) | — |
| Parent | Home, Academic Progress, Attendance, Homework, Diary, **Lesson Planner** (newly added), Gallery, Notices, Chat, Fees, Leave, Calendar, Documents | — |

### TASK 12 — API Routes ✅

All routes verified registered in `school-backend/internal/routes/routes.go`:

| Endpoint | Auth |
|----------|------|
| `POST /api/v1/event-posts` | Teacher |
| `GET /api/v1/event-posts/teacher` | Teacher |
| `GET /api/v1/event-posts/pending` | Admin, Principal |
| `POST /api/v1/event-posts/:id/approve` | Admin, Principal |
| `POST /api/v1/event-posts/:id/reject` | Admin, Principal |
| `GET /api/v1/event-posts/gallery` | All roles |
| `GET /api/v1/event-posts/home-feed` | Parent |
| `GET /api/v1/landing/events` | Public |
| `POST /api/v1/lesson-planners` | Teacher |
| `GET /api/v1/lesson-planners/teacher` | Teacher |
| `POST /api/v1/lesson-planners/:id/complete` | Teacher |
| `GET /api/v1/lesson-planners/parent` | Parent |
| `GET /api/v1/lesson-planners/principal` | Principal, Admin |
| `GET /api/v1/attendance/kiosk/qr-token` | Kiosk (TTL=5s) |

---

## Changed Files

### Flutter (lib/)
| File | Change |
|------|--------|
| `lib/core/widgets/staff_qr_attendance_panel.dart` | Added "QR refreshes every 5 seconds" label below countdown |
| `lib/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart` | Rewritten — full-day class card + subjects + quick actions at top |
| `lib/core/widgets/app_navigation.dart` | Added Event Approvals item to principal Communication section |
| `lib/core/widgets/parent_navigation.dart` | Added Lesson Planner item under Child Academics |
| `lib/features/academics/presentation/screens/parent_lesson_planner_screen/parent_lesson_planner_screen.dart` | **New** — parent-facing lesson planner list screen |
| `lib/features/academics/academics.dart` | Added export for `parent_lesson_planner_screen` |
| `lib/routes/app_routes.dart` | Added `parentLessonPlanner` constant + route builder |
| `lib/routes/route_access_guard.dart` | Added `parentLessonPlanner` to parent-allowed routes |
| `lib/routes/schooldesk_screen_registry.dart` | Registered `/parent-lesson-planner-screen` metadata |
| `lib/features/shared/presentation/screens/school_gallery_screen.dart` | Fixed `surfaceContainerHighest` → `panelMuted` (build error) |

### Previously implemented (prior sessions — verified present)
| File | Feature |
|------|---------|
| `lib/features/communication/presentation/screens/event_post_screen.dart` | Teacher event post create + status |
| `lib/features/communication/presentation/screens/principal_event_approval_screen.dart` | Principal approve/reject |
| `lib/features/academics/presentation/screens/lesson_planner_screen.dart` | Teacher lesson planner upload + complete |
| `lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart` | Google Classroom-style parent feed |
| `lib/core/widgets/teacher_navigation.dart` | Teacher drawer — no exams |
| `school-backend/internal/handlers/event_post.go` | All event post CRUD + approval endpoints |
| `school-backend/internal/handlers/lesson_planner.go` | All lesson planner endpoints + parent notification |
| `school-backend/internal/models/event_post.go` | EventPost model + destinations + status enums |
| `school-backend/internal/models/lesson_planner.go` | LessonPlanner model + status |
| `school-backend/internal/routes/routes.go` | All API routes registered |
| `school-backend/internal/database/database.go` | EventPost + LessonPlanner in autoMigrate |

---

## Build Verification

```
flutter build apk --debug
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```
Zero Dart/Flutter errors. Only pre-existing Gradle/CocoaPods warnings (unrelated to this feature set).

---

## Pending Manual QA Checklist

### Teacher
- [ ] Login as Teacher → confirm no Exams/Marks anywhere
- [ ] Open Timetable → confirm full-day class card at top with subjects + quick action chips
- [ ] Create event post (Parent Home destination) → Submit for approval
- [ ] Create event post (Gallery destination) → Submit for approval
- [ ] Upload weekly lesson planner → Mark as complete → confirm parent notification created
- [ ] After 15:00 with no homework → confirm end-of-day dialog appears
- [ ] Add homework from dialog → confirm subject dropdown loads
- [ ] Skip homework from dialog → confirm no error

### Principal
- [ ] Open drawer → confirm "Event Approvals" item present in Communication section
- [ ] Approve parent-home post → confirm it appears in parent feed
- [ ] Approve gallery post → confirm it appears in gallery
- [ ] Reject post with reason → confirm teacher sees rejection reason

### Parent
- [ ] Open Home → confirm Google Classroom-style feed (max 10 posts)
- [ ] Confirm "View More" redirects to Gallery
- [ ] Open drawer → confirm "Lesson Planner" item present
- [ ] Open Lesson Planner → confirm child's class plans visible
- [ ] Confirm approved home-feed posts appear; gallery-only posts do not
- [ ] Confirm lesson planner completion notification received

### Kiosk
- [ ] Open Kiosk QR screen → confirm "QR refreshes every 5 seconds" label visible
- [ ] Confirm QR changes every 5 seconds
- [ ] Navigate away → confirm no timer leak (no duplicate API calls)
