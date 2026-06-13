# Teacher Module Phase 2 Core Workflow Report

Date: 2026-06-12

## 1. Files Modified

- `lib/core/services/role_access_service.dart`
- `lib/core/widgets/teacher_navigation.dart`
- `lib/features/academics/academics.dart`
- `lib/features/attendance/attendance.dart`
- `lib/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart`
- `lib/features/attendance/presentation/screens/teacher_attendance_history_screen/teacher_attendance_history_screen.dart`
- `lib/features/attendance/presentation/screens/teacher_attendance_screen/teacher_attendance_screen.dart`
- `lib/features/academics/presentation/screens/teacher_classes_screen/teacher_classes_screen.dart`
- `lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart`
- `lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_screen.dart`
- `lib/features/academics/presentation/screens/teacher_performance_screen/teacher_performance_screen.dart`
- `lib/features/academics/presentation/screens/teacher_mark_entry_screen/teacher_mark_entry_screen.dart`
- `lib/routes/app_routes.dart`
- `lib/routes/route_access_guard.dart`
- `lib/routes/schooldesk_screen_registry.dart`
- `test/unit/route_access_guard_test.dart`
- `test/unit/role_route_safety_contract_test.dart`

## 2. New Screens Added

- `TeacherTimetableScreen`
- `TeacherAttendanceHistoryScreen`

## 3. New Routes Added

- `AppRoutes.teacherTimetable` -> `/teacher-timetable-screen`
- `AppRoutes.teacherAttendanceHistory` -> `/teacher-attendance-history-screen`

## 4. Route Guard Changes

- Added Teacher access for `teacherTimetable`.
- Added Teacher access for `teacherAttendanceHistory`.
- Added both routes to the visible workflow route set and screen registry metadata.

## 5. RoleAccessService Changes

- Preserves all `assigned_classes` rows from `/dashboard/teacher`.
- Added helper getters:
  - `assignedTeacherClasses`
  - `primaryTeacherClass`
  - `teacherSectionIds`
  - `teacherSubjectIds`
  - `hasTeacherStaffLink`
  - `hasAssignedClasses`
  - `teacherScopeStatus`
- Existing getters remain in place for older screens.
- `/dashboard/teacher` mapping used in this phase:
  - `staff_id` -> `teacherStaffId`
  - `assigned_classes` -> all assigned class/section rows
  - assigned class `id` or `section_id` -> `teacherSectionIds`
  - assigned class `subject_id` or `subjects[]` -> `teacherSubjectIds`
  - `metrics.homework_due`, `metrics.homework_total`, `metrics.unread_messages` -> dashboard/homework/message counts

## 6. Dashboard Changes

- Shows staff-link and no-class empty states.
- Adds workflow cards for My Classes, Timetable, Attendance, Homework, Class Diary, and Marks Entry.
- Shows assigned class count, pending timetable/attendance count, homework summary, and message/announcement summary.

## 7. My Classes Changes

- Displays all assigned classes/sections.
- Each class card includes Attendance, Homework, Diary, and Performance actions.
- Keeps the primary class roster for existing behavior.
- Adds clear staff-link and no-assigned-class empty states.

## 8. Timetable Changes

- Added focused Teacher Timetable screen.
- Loads `GET /timetable/slots?staff_id=...` through existing API client.
- Supports Today/Week toggle.
- Supports class/section filter when multiple classes are assigned.
- Shows day, time, class/section, subject, and room/period labels.

## 9. Attendance Changes

- Added date, class/section, and period selection controls.
- Defaults to the selected date's assigned slot, falling back to current teacher class.
- Adds History action from the attendance screen.
- Keeps existing mark-all and per-student status flow.
- Does not add edit/reopen behavior.

## 10. Attendance History Changes

- Added view-only attendance history/review screen.
- Filters by class/section and selected date.
- Shows session period, submitted/pending status, present count, absent/late derived count, and total students.
- Displays: "Corrections must be requested through Admin/Principal."

## 11. Homework/Diary Separation Changes

- Homework screen title and copy now focus on assignments/submission review.
- Removed visible no-homework diary logging from Homework.
- Homework now links to Class Diary for teaching log/no-homework entries.
- Existing Class Diary functionality remains intact.

## 12. Marks Entry Changes

- Exam schedules are filtered by assigned section IDs and subject IDs where available.
- Empty schedule state now says: "No exam schedules assigned for marks entry."
- Marks cannot exceed schedule max marks before submit.
- Existing absent/exempted handling remains.
- Success state remains direct save: "Marks submitted successfully!"

## 13. Student Performance Changes

- Added Enter Marks action.
- Keeps Student Notes action.
- Adds explicit no marks-based data state so student lists do not look like fabricated analytics.

## 14. Empty/Error States Added

- Teacher account not linked to staff.
- No classes assigned yet.
- No timetable assigned yet.
- No attendance sessions found.
- No homework yet.
- No exam schedules assigned for marks entry.
- No marks-based performance data yet.

## 15. Tests Added/Updated

- Updated `test/unit/route_access_guard_test.dart` for Teacher Timetable and Attendance History.
- Updated `test/unit/role_route_safety_contract_test.dart` to require drawer visibility for the new Phase 2 routes.

## 16. Test Results

Command:

```text
flutter test test/unit/route_access_guard_test.dart test/unit/role_route_safety_contract_test.dart
```

Result:

```text
All tests passed! 19 tests.
```

Flutter also emitted the existing iOS CocoaPods/SPM migration warning before running tests.

## 17. Scoped Analyze Result

Command:

```text
dart analyze lib/core/services/role_access_service.dart lib/core/widgets/teacher_navigation.dart lib/features/academics/academics.dart lib/features/attendance/attendance.dart lib/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart lib/features/attendance/presentation/screens/teacher_attendance_history_screen/teacher_attendance_history_screen.dart lib/features/attendance/presentation/screens/teacher_attendance_screen/teacher_attendance_screen.dart lib/features/academics/presentation/screens/teacher_classes_screen/teacher_classes_screen.dart lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_screen.dart lib/features/academics/presentation/screens/teacher_performance_screen/teacher_performance_screen.dart lib/features/academics/presentation/screens/teacher_mark_entry_screen/teacher_mark_entry_screen.dart lib/routes/app_routes.dart lib/routes/route_access_guard.dart lib/routes/schooldesk_screen_registry.dart test/unit/route_access_guard_test.dart test/unit/role_route_safety_contract_test.dart
```

Result:

```text
No issues found!
```

Full-project `flutter analyze` was not run because Phase 1 documented an unrelated existing issue in `lib/presentation/admin_bulk_import_screen/bulk_import_screen.dart:64:39`.

## 18. Manual Testing Checklist

Manual app/device navigation was not run in this implementation pass. QA should verify:

- Teacher Login -> Dashboard
- Dashboard -> My Classes
- My Classes -> Timetable
- My Classes -> Attendance
- Attendance -> select class/period/date
- Attendance -> submit attendance
- Attendance -> Attendance History
- Dashboard/My Classes -> Homework
- Homework -> Create Homework
- Homework -> Class Diary
- Dashboard/My Classes -> Marks Entry
- Marks Entry -> Student Performance
- Drawer works from touched Teacher screens
- Bottom navigation remains Home, Classes, Attendance, Homework, Profile
- Empty states are understandable for unlinked staff, no class, no timetable, no students, no homework, and no exam schedule

## 19. Remaining Issues for Phase 3

- Consolidate duplicate PTM surfaces.
- Add true Study Materials workflow.
- Add deeper class-detail screen only if product requires it.
- Improve direct deep-link context loading for form routes beyond clean error states.
- Add richer attendance review if backend exposes per-student attendance records safely.
- Decide whether Teacher Reports needs a teacher-safe report-card viewer/generator.

## 20. Screenshots Needed

- Teacher Dashboard
- My Classes with multiple assigned classes
- Teacher Timetable Today and Week filters
- Attendance selection and student marking
- Attendance History
- Homework assignment list
- Class Diary
- Marks Entry schedule empty state and mark-entry table
- Student Performance no-data and marks-data states
