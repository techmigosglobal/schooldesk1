# Arish Ville — Desktop UI/UX Redesign Plan

> **Scope:** Windows 10/11-level desktop experience for all screens
> **Constraint:** Mobile UI remains 100% untouched — all changes are gated behind `DesktopBreakpoints.isDesktopWidth()`
> **Design Language:** Fluent Design-inspired (Windows 11 Mica/Acrylic materials, Segoe-like typography, 4px grid, subtle shadows, rounded corners 8px)

---

## Table of Contents

1. [Design System & Global Rules](#1-design-system--global-rules)
2. [Reusable Desktop Building Blocks](#2-reusable-desktop-building-blocks)
3. [Screen Inventory & Status](#3-screen-inventory--status)
4. [Phase 1 — Priority Screens (Week 1–2)](#4-phase-1--priority-screens-week-12)
5. [Phase 2 — Core Module Screens (Week 3–4)](#5-phase-2--core-module-screens-week-34)
6. [Phase 3 — Communication & Support (Week 5–6)](#6-phase-3--communication--support-week-56)
7. [Phase 4 — Polish & Edge Cases (Week 7–8)](#7-phase-4--polish--edge-cases-week-78)
8. [Desktop Navigation Architecture](#8-desktop-navigation-architecture)
9. [Global Desktop Enhancements](#9-global-desktop-enhancements)
10. [Testing Strategy](#10-testing-strategy)

---

## 1. Design System & Global Rules

### 1.1 Windows 11 Design Tokens

| Token | Value | Description |
|-------|-------|-------------|
| `sidebarWidth` | 280px (expanded) / 48px (collapsed) | Persistent left navigation |
| `titleBarHeight` | 32px | Custom window title bar |
| `contentMaxWidth` | 1440px | Max content area width |
| `gridGutter` | 16px | Gap between grid items |
| `cardRadius` | 8px | Standard card corner radius |
| `buttonRadius` | 6px | Button corner radius |
| `panelRadius` | 8px | Panel/card container radius |
| `shadowLevel1` | `0 2px 4px rgba(0,0,0,0.04)` | Subtle card shadow |
| `shadowLevel2` | `0 4px 12px rgba(0,0,0,0.08)` | Elevated card shadow |
| `shadowLevel3` | `0 8px 24px rgba(0,0,0,0.12)` | Modal/flyout shadow |
| `micaBackground` | `#F3F3F3` (light) / `#202020` (dark) | Window background |
| `acrylicSurface` | `rgba(255,255,255,0.7)` | Floating panels |
| `focusBorder` | `#0078D4` | Keyboard focus ring |

### 1.2 Mobile Isolation Rule

Every desktop change MUST be wrapped in one of these patterns:

```dart
// Pattern 1: LayoutBuilder gate (preferred for new desktop layouts)
LayoutBuilder(
  builder: (context, constraints) {
    if (DesktopBreakpoints.isDesktopWidth(constraints.maxWidth)) {
      return _DesktopLayout(); // NEW desktop layout
    }
    return _MobileLayout();    // EXISTING mobile layout (untouched)
  },
)

// Pattern 2: Platform + width gate (for platform-specific behavior)
if (DesktopPlatform.isDesktopLayout(context)) {
  return _DesktopWidget();
}
return _MobileWidget();
```

**Rule:** Never modify `_MobileLayout()` widgets. Only add new `_DesktopLayout()` branches.

### 1.3 Standard Desktop Layout Template

```dart
// Every screen follows this pattern:
Scaffold(
  backgroundColor: Colors.transparent,
  body: Row(
    children: [
      // Left: Persistent sidebar (provided by SchooldeskRouteFrame)
      // Right: Content area
      Expanded(
        child: Column(
          children: [
            // Optional: Breadcrumb bar / page header
            _PageHeader(title: '...', actions: [...]),
            // Content
            Expanded(
              child: _buildDesktopContent(context),
            ),
          ],
        ),
      ),
    ],
  ),
)
```

---

## 2. Reusable Desktop Building Blocks

### 2.1 Existing Widgets (Already Built)

| Widget | File | Purpose |
|--------|------|---------|
| `DesktopMasterDetailLayout` | `lib/core/widgets/desktop_master_detail_layout.dart` | List + detail side-by-side |
| `DesktopDataTable` | `lib/core/widgets/desktop_data_table.dart` | Sortable data table with headers |
| `DesktopSplitView` | `lib/core/widgets/desktop_split_view.dart` | Resizable split panels |
| `DesktopNavigationRail` | `lib/core/desktop/desktop_navigation_rail.dart` | Persistent sidebar |
| `DesktopToolbar` | `lib/core/desktop/desktop_toolbar.dart` | Custom title bar |
| `DesktopHoverInkWell` | `lib/core/desktop/desktop_hover_effects.dart` | Hover state effects |
| `DesktopHoverIconButton` | `lib/core/desktop/desktop_hover_effects.dart` | Icon button with hover |
| `DesktopFormWrapper` | `lib/core/widgets/desktop_form_wrapper.dart` | Multi-column form layout |
| `DesktopResponsiveGrid` | `lib/core/widgets/desktop_responsive_grid.dart` | Adaptive grid |
| `DesktopDashboardWidget` | `lib/core/widgets/desktop_dashboard_widget.dart` | Dashboard card layout |
| `KeyboardShortcutsManager` | `lib/core/desktop/keyboard_shortcuts_manager.dart` | ⌘K, Ctrl+R, etc. |

### 2.2 New Widgets to Create

| Widget | Purpose | Used By |
|--------|---------|---------|
| `DesktopPageHeader` | Consistent page title + breadcrumb + actions bar | All screens |
| `DesktopSearchFilterBar` | Search input + filter dropdowns + sort controls | List screens |
| `DesktopStatsRow` | Horizontal row of KPI stat cards | Dashboard, overview screens |
| `DesktopEmptyState` | Friendly empty state with illustration | All screens |
| `DesktopFormDialog` | Centered form dialog with backdrop | Create/edit forms |
| `DesktopConfirmationDialog` | Windows 11-style confirmation dialog | Delete actions |
| `DesktopToast` | Non-blocking notification toast | Success/error feedback |
| `DesktopContextMenu` | Right-click context menu | List rows |
| `DesktopTooltip` | Enhanced tooltip with rich content | All interactive elements |

---

## 3. Screen Inventory & Status

### Legend

| Status | Meaning |
|--------|---------|
| ✅ Done | Desktop layout fully implemented and polished |
| 🟡 Partial | Has `isDesktopWidth` check but layout needs improvement |
| 🔴 None | Mobile-only, no desktop layout |
| ⬜ N/A | Auth/onboarding screens (centered, work on all sizes) |

---

### 3.1 AUTHENTICATION MODULE

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 1 | `AuthLoginScreen` | `auth/auth_login_screen/auth_login_screen.dart` | 🟡 Partial | 4 | Split layout: left branding panel + right form. Mica background. |
| 2 | `LoginLoadingScreen` | `auth/login_loading_screen/login_loading_screen.dart` | ⬜ N/A | — | Centered spinner — works as-is |
| 3 | `OnboardingScreen` | `auth/onboarding_screen/onboarding_screen.dart` | ⬜ N/A | — | Centered wizard — works as-is |

---

### 3.2 SHELL / NAVIGATION

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 4 | `LandingPageScreen` | `shell/landing_page_screen/landing_page_screen.dart` | 🟡 Partial | 4 | Full-width hero + feature grid (4-col) |
| 5 | `GlobalSearchScreen` | `shell/global_search_screen/global_search_screen.dart` | 🔴 None | 1 | Spotlight-style centered search overlay (⌘K) |

---

### 3.3 DASHBOARD MODULE (Per Role)

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 6 | `PrincipalDashboardScreen` | `dashboard/principal_dashboard_screen/principal_dashboard_screen.dart` | 🟡 Partial | 1 | Polish existing 2-col: KPI row, module grid (5-col), setup panel, highlights sidebar |
| 7 | `AdminDashboardScreen` | `dashboard/admin_dashboard_screen/admin_dashboard_screen.dart` | 🟡 Partial | 2 | 2-col layout with stats, module cards, quick actions |
| 8 | `TeacherDashboardScreen` | `dashboard/teacher_dashboard_screen/teacher_dashboard_screen.dart` | 🟡 Partial | 1 | Polish existing: class hero, timetable feed, quick actions sidebar |
| 9 | `ParentDashboardScreen` | `dashboard/parent_dashboard_screen/parent_dashboard_screen.dart` | 🟡 Partial | 1 | Polish existing: school feed, child overview sidebar, quick access grid |
| 10 | `SuperAdminDashboardScreen` | `dashboard/super_admin_dashboard_screen/super_admin_dashboard_screen.dart` | 🟡 Partial | 2 | 2-col: school list table + system stats panel |

---

### 3.4 PEOPLE MODULE

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 11 | `StudentOversightScreen` | `people/student_oversight_screen/student_oversight_screen.dart` | 🟡 Partial | 1 | Master-detail: student list (DataTable) + detail panel with tabs |
| 12 | `AdminStudentsScreen` | `people/admin_students_screen/admin_students_screen.dart` | 🔴 None | 1 | DataTable with sort/filter, row click → detail panel |
| 13 | `StaffManagementScreen` | `people/staff_management_screen/staff_management_screen.dart` | 🔴 None | 1 | Master-detail: staff list (DataTable) + profile panel |
| 14 | `StaffFormScreen` | `people/staff_management_screen/staff_form_screen.dart` | 🔴 None | 2 | Centered 2-column form in `DesktopFormDialog` |
| 15 | `AdminTeachersScreen` | `people/admin_teachers_screen/admin_teachers_screen.dart` | 🔴 None | 2 | DataTable with columns: Name, Subject, Classes, Status |
| 16 | `GuardianDirectoryScreen` | `people/guardian_directory_screen/guardian_directory_screen.dart` | 🔴 None | 2 | Master-detail: parent list + child mapping panel |
| 17 | `AdminUserAccessScreen` | `people/admin_user_access_screen/admin_user_access_screen.dart` | 🔴 None | 2 | DataTable: User, Role, Status, Last Login |
| 18 | `AccountAccessFormScreen` | `people/admin_user_access_screen/account_access_form_screen.dart` | 🔴 None | 2 | Centered 2-col form dialog |
| 19 | `AccountChildAssignmentScreen` | `people/admin_user_access_screen/account_child_assignment_screen.dart` | 🔴 None | 2 | Split view: available users + assigned children |
| 20 | `ApprovalCenterScreen` | `people/approval_center_screen/approval_center_screen.dart` | 🔴 None | 2 | DataTable with approve/reject actions inline |

---

### 3.5 ACADEMICS MODULE

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 21 | `AcademicManagementScreen` | `academics/academic_management_screen/academic_management_screen.dart` | 🟡 Partial | 2 | Tab strip + DataTable per tab (Years, Subjects, Classes) |
| 22 | `PrincipalAcademicYearsScreen` | `academics/academic_management_screen/principal_academic_years_screen.dart` | 🔴 None | 2 | Master-detail: years list + year detail panel |
| 23 | `PrincipalAcademicYearDetailScreen` | `academics/academic_management_screen/principal_academic_years_screen.dart` | 🔴 None | 2 | Detail panel with sections grid |
| 24 | `AcademicYearFormScreen` | `academics/academic_management_screen/academic_management_form_screens.dart` | 🔴 None | 3 | Centered form dialog |
| 25 | `AcademicSubjectFormScreen` | `academics/academic_management_screen/academic_management_form_screens.dart` | 🔴 None | 3 | Centered form dialog |
| 26 | `AcademicClassFormScreen` | `academics/academic_management_screen/academic_management_form_screens.dart` | 🔴 None | 3 | Centered form dialog |
| 27 | `AcademicCurriculumFormScreen` | `academics/academic_management_screen/academic_management_form_screens.dart` | 🔴 None | 3 | Centered form dialog |
| 28 | `AcademicYearClasswiseExportScreen` | `academics/academic_management_screen/principal_academic_years_screen.dart` | 🔴 None | 3 | DataTable with export button |
| 29 | `AcademicYearUsersExportScreen` | `academics/academic_management_screen/principal_academic_years_screen.dart` | 🔴 None | 3 | DataTable with export button |
| 30 | `AcademicYearFeesExportScreen` | `academics/academic_management_screen/principal_academic_years_screen.dart` | 🔴 None | 3 | DataTable with export button |
| 31 | `AcademicInfoScreen` | `academics/academic_info_screen/academic_info_screen.dart` | 🔴 None | 3 | Read-only detail layout |
| 32 | `PrincipalClassesScreen` | `academics/principal_classes_screen/principal_classes_screen.dart` | 🟡 Partial | 2 | Master-detail: class list + section/student panel |
| 33 | `TeacherClassesScreen` | `academics/teacher_classes_screen/teacher_classes_screen.dart` | 🔴 None | 2 | Card grid (3-col) with class cards |
| 34 | `PrincipalSubjectsScreen` | `academics/principal_subjects_screen/principal_subjects_screen.dart` | 🔴 None | 2 | DataTable: Subject, Teachers, Classes |
| 35 | `AdminTimetableScreen` | `academics/admin_timetable_screen/admin_timetable_screen.dart` | 🟡 Partial | 3 | Full-width timetable grid (7-col × rows) |
| 36 | `AdminTimetableGenerationFormScreen` | `academics/admin_timetable_screen/admin_timetable_form_screens.dart` | 🔴 None | 3 | Centered form dialog |
| 37 | `AdminTimetablePeriodFormScreen` | `academics/admin_timetable_screen/admin_timetable_form_screens.dart` | 🔴 None | 3 | Centered form dialog |
| 38 | `AdminTimetableSubstitutionFormScreen` | `academics/admin_timetable_screen/admin_timetable_form_screens.dart` | 🔴 None | 3 | Centered form dialog |
| 39 | `TeacherTimetableScreen` | `academics/teacher_timetable_screen/teacher_timetable_screen.dart` | 🔴 None | 3 | Full-width weekly grid |
| 40 | `ParentTimetableScreen` | `academics/parent_timetable_screen/parent_timetable_screen.dart` | 🔴 None | 3 | Full-width weekly grid |
| 41 | `PrincipalLessonPlannerScreen` | `academics/principal_lesson_planner_screen.dart` | 🔴 None | 3 | Master-detail: planner list + lesson detail |
| 42 | `TeacherLessonPlannerScreen` | `academics/lesson_planner_screen.dart` | 🔴 None | 3 | Master-detail: lesson list + editor panel |
| 43 | `ParentLessonPlannerScreen` | `academics/parent_lesson_planner_screen/parent_lesson_planner_screen.dart` | 🔴 None | 3 | Read-only detail view |
| 44 | `TeacherStudentNotesScreen` | `academics/teacher_student_notes_screen/teacher_student_notes_screen.dart` | 🔴 None | 3 | Master-detail: student list + notes panel |

---

### 3.6 ATTENDANCE MODULE

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 45 | `PrincipalAttendanceScreen` | `attendance/principal_attendance_screen/principal_attendance_screen.dart` | 🔴 None | 1 | Master-detail: class selector + attendance table with stats |
| 46 | `AdminAttendanceScreen` | `attendance/admin_attendance_screen/admin_attendance_screen.dart` | 🔴 None | 1 | DataTable: Date, Class, Present, Absent, Rate |
| 47 | `TeacherAttendanceScreen` | `attendance/teacher_attendance_screen/teacher_attendance_screen.dart` | 🔴 None | 1 | Student list with present/absent toggle + summary bar |
| 48 | `TeacherAttendanceHistoryScreen` | `attendance/teacher_attendance_history_screen/teacher_attendance_history_screen.dart` | 🔴 None | 2 | DataTable: Date, Class, Present, Absent, Rate |
| 49 | `TeacherMyAttendanceScreen` | `attendance/teacher_my_attendance_screen/teacher_my_attendance_screen.dart` | 🔴 None | 2 | Calendar view + punch-in/out status card |
| 50 | `ParentAttendanceScreen` | `attendance/parent_attendance_screen/parent_attendance_screen.dart` | 🔴 None | 2 | Calendar heatmap + attendance stats |
| 51 | `KioskQrAttendanceScreen` | `attendance/kiosk_qr_attendance_screen/kiosk_qr_attendance_screen.dart` | 🔴 None | — | Full-screen QR scanner (no desktop needed) |

---

### 3.7 FINANCE MODULE

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 52 | `AdminFeesScreen` | `finance/admin_fees_screen/admin_fees_screen.dart` | 🔴 None | 1 | Tab strip + DataTable per tab |
| 53 | `FeeCollectScreen` | `finance/fee_collect_screen/fee_collect_screen.dart` | 🔴 None | 1 | Master-detail: student search + fee breakdown + payment form |
| 54 | `FeeStructuresScreen` | `finance/fee_structures_screen/fee_structures_screen.dart` | 🔴 None | 1 | DataTable: Structure, Amount, Classes, Status |
| 55 | `FeeHomeScreen` | `finance/fee_home_screen/fee_home_screen.dart` | 🔴 None | 2 | 2-col: stats cards + quick actions |
| 56 | `FeeLedgerScreen` | `finance/fee_ledger_screen/fee_ledger_screen.dart` | 🔴 None | 2 | DataTable: Date, Student, Amount, Mode, Receipt |
| 57 | `FeeReportsScreen` | `finance/fee_reports_screen/fee_reports_screen.dart` | 🔴 None | 2 | Charts + data tables side by side |
| 58 | `FeePaymentConfigScreen` | `finance/fee_payment_config_screen/fee_payment_config_screen.dart` | 🔴 None | 3 | Settings form layout |
| 59 | `AdminFeeStructureFormScreen` | `finance/admin_fees_screen/admin_fee_form_screens.dart` | 🔴 None | 3 | Centered 2-col form dialog |
| 60 | `AdminInvoiceGenerationFormScreen` | `finance/admin_fees_screen/admin_fee_form_screens.dart` | 🔴 None | 3 | Centered form dialog |
| 61 | `AdminPaymentRecordFormScreen` | `finance/admin_fees_screen/admin_fee_form_screens.dart` | 🔴 None | 3 | Centered form dialog |
| 62 | `AdminPaymentRequestsScreen` | `finance/admin_fees_screen/admin_payment_requests_screen.dart` | 🔴 None | 1 | DataTable: Student, Amount, Date, Status, Actions |
| 63 | `AdminPaymentRequestDecisionScreen` | `finance/admin_fees_screen/admin_payment_request_decision_screen.dart` | 🔴 None | 1 | Split: request details + approve/reject form |

---

### 3.8 HOMEWORK MODULE

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 64 | `TeacherHomeworkScreen` | `homework/teacher_homework_screen/teacher_homework_screen.dart` | 🔴 None | 3 | Master-detail: homework list + detail panel |
| 65 | `TeacherHomeworkFormScreen` | `homework/teacher_homework_screen/teacher_homework_form_screens.dart` | 🔴 None | 3 | Centered 2-col form dialog |
| 66 | `TeacherHomeworkSubmissionsScreen` | `homework/teacher_homework_screen/teacher_homework_form_screens.dart` | 🔴 None | 3 | DataTable: Student, Submitted, Status |
| 67 | `ParentHomeworkScreen` | `homework/parent_homework_screen/parent_homework_screen.dart` | 🔴 None | 3 | Card list with status badges |
| 68 | `ParentHomeworkSubmissionScreen` | `homework/parent_homework_screen/parent_homework_submission_screen.dart` | 🔴 None | 3 | Detail view + upload form |

---

### 3.9 LEAVE MODULE

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 69 | `TeacherLeaveScreen` | `leave/teacher_leave_screen/teacher_leave_screen.dart` | 🔴 None | 3 | DataTable: Date, Type, Status, Actions |
| 70 | `TeacherLeaveRequestFormScreen` | `leave/teacher_leave_screen/teacher_leave_request_form_screen.dart` | 🔴 None | 3 | Centered form dialog |
| 71 | `ParentLeaveScreen` | `leave/parent_leave_screen/parent_leave_screen.dart` | 🔴 None | 3 | DataTable: Date, Child, Type, Status |
| 72 | `ParentLeaveRequestFormScreen` | `leave/parent_leave_screen/parent_leave_request_form_screen.dart` | 🔴 None | 3 | Centered form dialog |

---

### 3.10 COMMUNICATION MODULE

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 73 | `PrincipalChatCommunicationsScreen` | `communication/principal_chat_communications_screen/principal_chat_communications_screen.dart` | 🔴 None | 3 | Master-detail: conversation list + chat panel (like Teams) |
| 74 | `TeacherCommunicationScreen` | `communication/teacher_communication_screen/teacher_communication_screen.dart` | 🔴 None | 3 | Master-detail: conversation list + chat panel |
| 75 | `ParentTeacherChatScreen` | `communication/parent_teacher_chat_screen/parent_teacher_chat_screen.dart` | 🔴 None | 3 | Master-detail: conversation list + chat panel |
| 76 | `NotificationCenterScreen` | `communication/notification_center_screen/notification_center_screen.dart` | 🔴 None | 2 | Master-detail: notification list + detail panel |
| 77 | `ComplaintManagementScreen` | `communication/complaint_management_screen/complaint_management_screen.dart` | 🔴 None | 3 | DataTable: Title, Type, Status, Date, Actions |
| 78 | `TeacherComplaintScreen` | `communication/teacher_complaint_screen/teacher_complaint_screen.dart` | 🔴 None | 3 | DataTable: My complaints with status |
| 79 | `ParentComplaintScreen` | `communication/parent_complaint_screen/parent_complaint_screen.dart` | 🔴 None | 3 | DataTable: My complaints with status |
| 80 | `IssueScreen` | `communication/issue_screen.dart` | 🔴 None | 3 | Master-detail: issue list + detail with comments |
| 81 | `PrincipalEventApprovalScreen` | `communication/principal_event_approval_screen.dart` | 🔴 None | 2 | DataTable: Event, Requester, Date, Status, Approve/Reject |
| 82 | `TeacherEventPostScreen` | `communication/event_post_screen.dart` | 🔴 None | 3 | Centered form dialog |
| 83 | `TeacherPTMScreen` | `communication/teacher_ptm_screen/teacher_ptm_screen.dart` | 🔴 None | 3 | DataTable: PTM slots with bookings |
| 84 | `ParentPTMBookingScreen` | `communication/parent_ptm_booking_screen/parent_ptm_booking_screen.dart` | 🔴 None | 3 | Available slots grid + booking form |
| 85 | `TeacherParentInteractionScreen` | `communication/teacher_parent_interaction_screen/teacher_parent_interaction_screen.dart` | 🔴 None | 3 | Master-detail: parent list + interaction log |
| 86 | `HomeworkMessagingScreen` | `communication/homework_messaging_screen/homework_messaging_screen.dart` | 🔴 None | 3 | Chat-style layout |

---

### 3.11 CALENDAR MODULE

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 87 | `EventsCalendarScreen` | `calendar/events_calendar_screen/events_calendar_screen.dart` | 🔴 None | 2 | Full-width month/week/day view + event list sidebar |
| 88 | `ParentCalendarScreen` | `calendar/parent_calendar_screen/parent_calendar_screen.dart` | 🔴 None | 2 | Calendar view + child's events panel |

---

### 3.12 DOCUMENTS MODULE

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 89 | `AdminDocumentsScreen` | `documents/admin_documents_screen/admin_documents_screen.dart` | 🔴 None | 3 | DataTable: Name, Type, Uploaded, Size, Actions |
| 90 | `TeacherDocumentsScreen` | `documents/teacher_documents_screen/teacher_documents_screen.dart` | 🔴 None | 3 | DataTable: Name, Type, Date |
| 91 | `ParentDocumentsScreen` | `documents/parent_documents_screen/parent_documents_screen.dart` | 🔴 None | 3 | Card grid with preview |
| 92 | `IdCardGenerationScreen` | `documents/id_card_generation_screen/id_card_generation_screen.dart` | 🔴 None | 3 | Split: student selector + card preview |

---

### 3.13 REPORTS MODULE

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 93 | `AdminReportsScreen` | `reports/admin_reports_screen/admin_reports_screen.dart` | 🔴 None | 2 | Charts grid + filter bar |
| 94 | `PrincipalAnalyticsScreen` | `reports/principal_analytics_screen/principal_analytics_screen.dart` | 🔴 None | 2 | Dashboard-style charts layout |
| 95 | `ReportsAnalyticsScreen` | `reports/reports_analytics_screen/reports_analytics_screen.dart` | 🔴 None | 2 | Charts + data tables |

---

### 3.14 PROFILE MODULE

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 96 | `ProfileManagementScreen` | `profile/profile_management_screen/profile_management_screen.dart` | 🔴 None | 4 | 2-col: avatar + form fields |
| 97 | `AppSettingsScreen` | `profile/settings_screen/settings_screen.dart` | 🔴 None | 4 | 2-col: settings categories + detail |
| 98 | `SchoolProfileScreen` | `profile/school_profile_screen/school_profile_screen.dart` | 🔴 None | 3 | 2-col: logo/banner + form fields |

---

### 3.15 SHARED MODULE

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 99 | `SchoolGalleryScreen` | `shared/school_gallery_screen/school_gallery_screen.dart` | 🔴 None | 3 | Photo grid (4-col masonry) |
| 100 | `HelpScreen` | `shared/help_screen/help_screen.dart` | 🔴 None | 4 | 2-col: TOC sidebar + content area |

---

### 3.16 MONITORING MODULE

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 101 | `PrincipalAuditLogsScreen` | `monitoring/principal_audit_logs_screen.dart` | 🔴 None | 4 | DataTable: Timestamp, User, Action, Details |
| 102 | `SystemMonitorScreen` | `monitoring/system_monitor_screen.dart` | 🔴 None | 4 | 2-col: system stats + action buttons |

---

### 3.17 HEALTH MODULE

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 103 | `ParentHealthUpdateScreen` | `health/parent_health_update_screen/parent_health_update_screen.dart` | 🔴 None | 4 | Detail view with health metrics |

---

### 3.18 BULK IMPORT

| # | Screen | File | Desktop Status | Phase | Desktop Improvement |
|---|--------|------|----------------|-------|---------------------|
| 104 | `BulkImportScreen` | `presentation/admin_bulk_import_screen/bulk_import_screen.dart` | 🔴 None | 3 | Drag-drop zone + preview table |

---

## 4. Phase 1 — Priority Screens (Week 1–2)

> **Goal:** Make the most-used screens feel native on desktop. These are the screens users interact with daily.

### 4.1 Screen-by-Screen Specifications

#### Screen 6: Principal Dashboard (Polish)
**Current:** Has 2-column layout but module grid is 5-col cards.
**Target:** Windows 11 Settings-style dashboard.

```
┌──────────┬──────────────────────────────────────────────────────┐
│          │ ┌──────────────────────────────────────────────────┐ │
│ Sidebar  │ │ Hello, John                                      │ │
│          │ │ Welcome back!                    🔔 3  ❓       │ │
│ 🏠 Dash  │ ├──────────────────────────────────────────────────┤ │
│ 👥 Stu   │ │ 🔍 Search students, staff, fees...     ⌘K      │ │
│ 👨‍🏫 Staff │ ├──────────┬──────────┬──────────┬────────────────┤ │
│ 💰 Fees  │ │ Students │ Staff    │ Classes  │ Pending        │ │
│ 📅 Cal   │ │   342    │   28     │   12     │   5            │ │
│ 📝 Home  │ ├──────────┴──────────┴──────────┴────────────────┤ │
│ 💬 Chat  │ │                                                  │ │
│          │ │ ACADEMICS                              5×3 grid  │ │
│          │ │ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐       │ │
│          │ │ │Acad │ │Stu  │ │Staff│ │Pare │ │Class│       │ │
│          │ │ │Year │ │     │ │Mgmt │ │nts  │ │ Hub │       │ │
│          │ │ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘       │ │
│          │ │ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐       │ │
│          │ │ │Atten│ │Subje│ │Time │ │Lsson│ │Fees │       │ │
│          │ │ │dance│ │cts  │ │table│ │Plan │ │     │       │ │
│          │ │ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘       │ │
│          │ │ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐               │ │
│          │ │ │Calen│ │Event│ │Gall │ │Chat │               │ │
│          │ │ │dar  │ │Appr │ │ery  │ │     │               │ │
│          │ │ └─────┘ └─────┘ └─────┘ └─────┘               │ │
│          │ ├──────────────────────────────┬──────────────────┤ │
│          │ │ SCHOOL SETUP                 │ TODAY'S HIGHLIGHTS│ │
│          │ │ ▓▓▓▓▓▓▓▓▓▓▓░░░░ 78%        │ 📋 Attendance    │ │
│          │ │ ✅ School Registration       │ 📅 Events (3)    │ │
│          │ │ ✅ Academic Year             │ ⚠️ Fee pending   │ │
│          │ │ ✅ Classes & Sections        │ 📝 Homework      │ │
│          │ │ ⬜ Subjects Setup            │                  │ │
│          │ └──────────────────────────────┴──────────────────┘ │
└──────────┴──────────────────────────────────────────────────────┘
```

**Changes:**
- KPI stats row: 4 gradient cards with hover elevation
- Module grid: 5-col with hover scale + shadow
- Setup progress: left panel with progress bar
- Highlights: right sidebar card
- All wrapped in `SingleChildScrollView` with `LayoutBuilder`

---

#### Screen 9: Teacher Dashboard (Polish)
**Current:** Has 2-column layout with class hero panel.
**Target:** Polished with better spacing, hover effects.

```
┌──────────┬──────────────────────────────────────────────────────┐
│          │ ┌──────────────────────────────────────────────────┐ │
│ Sidebar  │ │ 🟢 CLASSROOM ACTIVE                             │ │
│          │ │ Good day, Sarah                                  │ │
│ 🏠 Dash  │ │ CLASS 5-A                                        │ │
│ 📋 Class │ │ Mathematics                                     │ │
│ 📅 Time  │ │ [My Login] [Attendance] [Timetable]             │ │
│ ✅ Atten │ ├──────────────────────────────────────────────────┤ │
│ 📖 Lesson│ │ Quick Actions              │ Action Queue        │ │
│ 📝 Home  │ │ ┌──────┐ ┌──────┐ ┌──────┐│ ┌─────────────────┐│ │
│ 📆 Leave │ │ │Class │ │Time  │ │Atten ││ │Mark Attendance  ││ │
│ 💬 Chat  │ │ │      │ │table │ │dance ││ │⚠ 2 pending      ││ │
│          │ │ └──────┘ └──────┘ └──────┘│ └─────────────────┘│ │
│          │ │ ┌──────┐ ┌──────┐ ┌──────┐│ ┌─────────────────┐│ │
│          │ │ │Lesson│ │Home  │ │Leave ││ │Track Leave      ││ │
│          │ │ │Plan  │ │work  │ │      ││ │📝 Admin         ││ │
│          │ │ └──────┘ └──────┘ └──────┘│ └─────────────────┘│ │
│          │ ├────────────────────────────┴─────────────────────┤ │
│          │ │ TODAY FEED                                       │ │
│          │ │ 🟢 09:00  Self Attendance - Punch-in 08:45      │ │
│          │ │ 📘 09:30  Math - Class 5-A                      │ │
│          │ │ 📘 10:30  Science - Class 4-B                   │ │
│          │ └──────────────────────────────────────────────────┘ │
└──────────┴──────────────────────────────────────────────────────┘
```

**Changes:**
- Hero panel: gradient background, stat pills, action buttons
- Quick actions: 2-col grid with hover states
- Feed panel: timeline-style items with color coding
- Sidebar: action queue with urgency badges

---

#### Screen 11: Student Oversight (Master-Detail)
**Current:** Has `DesktopMasterDetailLayout` but needs polish.
**Target:** Windows Explorer-style master-detail.

```
┌──────────┬──────────────────────┬──────────────────────────────┐
│          │ 🔍 Search...  Filter │ STUDENT DETAILS              │
│ Sidebar  │ ─────────────────────│                              │
│          │ Name    Class  Att%  │ 👤 Alice Johnson             │
│ 🏠 Dash  │ ─────────────────────│ Class: 5-A                   │
│ 👥 Stu   │ Alice   5-A    92%  │ Attendance: 92%              │
│ 👨‍🏫 Staff │ Bob     4-B    88%  │ Fee Balance: ₹15,000         │
│ 💰 Fees  │ Carol   3-A    95%  │ Parent: Mr. Johnson          │
│ 📅 Cal   │ Diana   5-B    91%  │                              │
│          │ Edward  4-A    87%  │ [Edit] [Attendance] [Fees]   │
│          │ Fiona   3-B    94%  │                              │
│          │ George  5-A    90%  │ ┌──────────────────────────┐ │
│          │ Hannah  4-B    86%  │ │ ATTENDANCE               │ │
│          │ ...     ...    ...  │ │ Mon ✅ Tue ✅ Wed ⬜     │ │
│          │                    │ │ Thu ✅ Fri ✅             │ │
│          │ Showing 1-25 of 342│ └──────────────────────────┘ │
└──────────┴──────────────────────┴──────────────────────────────┘
```

**Changes:**
- Master panel: `DesktopDataTable` with sortable columns
- Detail panel: tabs (Overview, Attendance, Fees, Notes)
- Search bar: debounced input with filter chips
- Row hover: subtle background highlight
- Keyboard: arrow keys to navigate list

---

#### Screen 13: Staff Management (Master-Detail)
**Current:** No desktop layout.
**Target:** Same master-detail pattern as Students.

```
┌──────────┬──────────────────────┬──────────────────────────────┐
│          │ 🔍 Search...  Filter │ STAFF PROFILE                │
│ Sidebar  │ ─────────────────────│                              │
│          │ Name     Role    Sub │ 👤 Sarah Williams            │
│ 👥 Staff │ ─────────────────────│ Role: Teacher                │
│          │ Sarah    Teach   Math│ Subject: Mathematics         │
│          │ James    Teach   Sci │ Classes: 5-A, 4-B            │
│          │ Emily    Admin   --  │ Status: Active               │
│          │ Michael  Teach   Eng │ Attendance: 95%              │
│          │ ...                  │                              │
│          │                    │ [Edit] [Timetable] [Notes]   │
│          │ + Add Staff        │                              │
└──────────┴──────────────────────┴──────────────────────────────┘
```

**Changes:**
- `DesktopMasterDetailLayout` with `DesktopDataTable`
- Master: sortable columns (Name, Role, Subject)
- Detail: profile card + tabs (Details, Classes, Attendance)
- "Add Staff" button in page header

---

#### Screen 45: Principal Attendance (Master-Detail)
**Current:** No desktop layout.
**Target:** Class selector + attendance table.

```
┌──────────┬──────────────────────┬──────────────────────────────┐
│          │ ATTENDANCE           │ CLASS 5-A — March 15, 2026   │
│ Sidebar  │                      │                              │
│          │ Select Class:        │ ☑ Alice Johnson    Present   │
│ 🏠 Dash  │ ┌─────────────────┐  │ ☑ Bob Smith        Present   │
│ 👥 Stu   │ │ 5-A  (28)    ▼ │  │ ☐ Carol Davis      Absent    │
│ 📅 Atten │ │ 5-B  (26)      │  │ ☑ Diana Wilson     Present   │
│ 💰 Fees  │ │ 4-A  (30)      │  │ ☑ Edward Brown     Present   │
│          │ │ ...             │  │ ☐ Fiona Taylor     Absent    │
│          │ └─────────────────┘  │ ...                          │
│          │                      │                              │
│          │ TODAY'S SUMMARY      │ Present: 25/28 (89%)         │
│          │ ┌─────┬─────┬─────┐  │ [Save Attendance]            │
│          │ │Pres │Abs  │Rate │  │                              │
│          │ │ 25  │  3  │ 89% │  │                              │
│          │ └─────┴─────┴─────┘  │                              │
└──────────┴──────────────────────┴──────────────────────────────┘
```

---

#### Screen 52: Admin Fees (Tab + DataTable)
**Current:** No desktop layout.
**Target:** Tab strip with DataTable per tab.

```
┌──────────┬──────────────────────────────────────────────────────┐
│          │ FEES MANAGEMENT                                      │
│ Sidebar  │ ┌──────────┬──────────┬──────────┬──────────┐       │
│          │ │Structures│ Invoices │ Payments │ Requests │       │
│ 💰 Fees  │ └──────────┴──────────┴──────────┴──────────┘       │
│          │                                                      │
│          │ 🔍 Search...    Filter ▼    Sort ▼                   │
│          │ ───────────────────────────────────────────────────  │
│          │ │ Name        │ Amount  │ Classes    │ Status    │  │
│          │ │ ────────────│─────────│────────────│───────────│  │
│          │ │ Tuition     │ ₹15,000 │ 5-A, 5-B   │ Active    │  │
│          │ │ Lab Fee     │ ₹2,000  │ All Science│ Active    │  │
│          │ │ Transport   │ ₹3,000  │ All        │ Active    │  │
│          │ │ Sports      │ ₹1,500  │ All        │ Inactive  │  │
│          │                                                      │
│          │ Showing 1-4 of 4                    [+ Add Structure]│
└──────────┴──────────────────────────────────────────────────────┘
```

---

#### Screen 53: Fee Collect (Master-Detail)
**Current:** No desktop layout.
**Target:** Student search + fee breakdown.

```
┌──────────┬──────────────────────┬──────────────────────────────┐
│          │ FEE COLLECTION       │ PAYMENT DETAILS              │
│ Sidebar  │                      │                              │
│ 💰 Fees  │ 🔍 Search student... │ 👤 Alice Johnson (5-A)       │
│          │ ─────────────────────│                              │
│          │ Alice   5-A  ₹15K   │ OUTSTANDING                  │
│          │ Bob     4-B  ₹12K   │ Tuition:   ₹15,000          │
│          │ Carol   3-A  ₹18K   │ Lab Fee:    ₹2,000          │
│          │ Diana   5-B  ₹14K   │ Transport:  ₹3,000          │
│          │ ...                  │ ─────────────────            │
│          │                    │ TOTAL:     ₹20,000           │
│          │                    │                              │
│          │                    │ PAYMENT                      │
│          │                    │ Amount: [₹________]          │
│          │                    │ Mode:   [Cash ▼]             │
│          │                    │ Date:   [Today]              │
│          │                    │                              │
│          │                    │ [Record Payment] [Print]     │
└──────────┴──────────────────────┴──────────────────────────────┘
```

---

## 5. Phase 2 — Core Module Screens (Week 3–4)

### 5.1 Screens in This Phase

| # | Screen | Desktop Pattern | Key Components |
|---|--------|----------------|----------------|
| 7 | Admin Dashboard | 2-col layout | Stats cards, module grid, quick actions |
| 10 | Super Admin Dashboard | 2-col layout | School list table, system stats |
| 14 | Staff Form | Centered form dialog | 2-col form layout |
| 15 | Admin Teachers | DataTable | Sortable table with role filter |
| 16 | Guardian Directory | Master-detail | Parent list + child mapping |
| 17 | Admin User Access | DataTable | User, role, status, last login |
| 18 | Account Access Form | Centered form dialog | Role assignment form |
| 19 | Account Child Assignment | Split view | Available users + assigned children |
| 20 | Approval Center | DataTable | Approve/reject inline actions |
| 21 | Academic Management | Tab strip + DataTable | Years, subjects, classes tabs |
| 22-23 | Academic Years | Master-detail | Year list + detail panel |
| 32 | Principal Classes | Master-detail | Class list + section/student panel |
| 33 | Teacher Classes | Card grid | 3-col class cards |
| 34 | Principal Subjects | DataTable | Subject, teachers, classes |
| 46 | Admin Attendance | DataTable | Date, class, present, absent, rate |
| 47 | Teacher Attendance | Student list + toggles | Present/absent with summary |
| 48-50 | Attendance History | DataTable | Historical attendance records |
| 54 | Fee Structures | DataTable | Structure, amount, classes |
| 56-58 | Fee Ledger/Reports/Config | DataTable + Charts | Financial data views |
| 62-63 | Payment Requests | DataTable + Decision | Approve/reject workflow |
| 76 | NotificationCenter | Master-detail | Notification list + detail |
| 81 | Event Approval | DataTable | Approve/reject events |
| 87-88 | Calendar | Full-width calendar | Month/week/day views |
| 93-95 | Reports | Charts + DataTable | Analytics dashboards |

---

## 6. Phase 3 — Communication & Support (Week 5–6)

### 6.1 Screens in This Phase

| # | Screen | Desktop Pattern | Key Components |
|---|--------|----------------|----------------|
| 24-30 | Academic Forms | Centered form dialogs | Multi-column form layouts |
| 35-44 | Timetable/Lesson Planner | Full-width grids | Weekly timetable, planner lists |
| 59-61 | Fee Form Screens | Centered form dialogs | Fee structure, invoice forms |
| 64-68 | Homework | Master-detail | Homework list + submission view |
| 69-72 | Leave | DataTable | Leave requests with status |
| 73-75 | Chat/Messaging | Master-detail (chat) | Conversation list + chat panel |
| 77-80 | Complaints/Issues | DataTable | Complaint management |
| 82-86 | Events/PTM/Interactions | DataTable + Forms | Event and PTM management |
| 89-92 | Documents | DataTable / Card grid | Document management |
| 104 | Bulk Import | Drag-drop + preview | File upload with preview |

---

## 7. Phase 4 — Polish & Edge Cases (Week 7–8)

### 7.1 Screens in This Phase

| # | Screen | Desktop Pattern | Key Components |
|---|--------|----------------|----------------|
| 1-3 | Auth/Onboarding | Split layout | Branding + form |
| 4 | Landing Page | Full-width hero | Feature grid |
| 5 | Global Search | Spotlight overlay | Centered search |
| 96 | Profile Management | 2-col | Avatar + form |
| 97 | Settings | 2-col | Categories + detail |
| 98 | School Profile | 2-col | Logo + form fields |
| 99 | School Gallery | Photo grid | 4-col masonry |
| 100 | Help Screen | 2-col | TOC + content |
| 101-102 | Monitoring | DataTable + Stats | Audit logs, system monitor |
| 103 | Health Update | Detail view | Health metrics |

---

## 8. Desktop Navigation Architecture

### 8.1 Sidebar Structure (Per Role)

```
PRINCIPAL PORTAL:
├── Dashboard
├── Academics
│   ├── Academic Years
│   ├── Classes
│   ├── Subjects
│   ├── Timetable
│   └── Lesson Planners
├── People
│   ├── Students
│   ├── Staff
│   ├── Parents
│   └── User Access
├── Finance
│   ├── Fee Structures
│   ├── Fee Collection
│   ├── Payment Requests
│   └── Fee Reports
├── Attendance
│   ├── Mark Attendance
│   └── Attendance Reports
├── Communication
│   ├── Messages
│   ├── Notifications
│   ├── Event Approvals
│   └── Issues
├── Calendar
├── Documents
├── Reports
└── Settings

TEACHER PORTAL:
├── Dashboard
├── My Classes
├── Timetable
├── Attendance
├── Lesson Planner
├── Homework
├── Leaves
├── Communication
└── Profile

PARENT PORTAL:
├── Dashboard
├── Child Overview
├── Attendance
├── Homework
├── Timetable
├── Fees
├── Leaves
├── Calendar
├── Communication
└── Gallery
```

### 8.2 Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘K` / `Ctrl+K` | Open global search |
| `⌘R` / `Ctrl+R` | Refresh current screen |
| `⌘,` / `Ctrl+,` | Open settings |
| `⌘N` / `Ctrl+N` | Create new (context-dependent) |
| `⌘F` / `Ctrl+F` | Focus search/filter |
| `Escape` | Close dialog / go back |
| `←` / `→` | Navigate master-detail panels |
| `↑` / `↓` | Navigate list items |

---

## 9. Global Desktop Enhancements

### 9.1 Window Title Bar
- ✅ Already implemented (custom title bar with min/max/close)
- **Enhancement:** Add breadcrumb text showing current screen

### 9.2 Context Menus
- Right-click on list rows → Edit, Delete, View Details
- Right-click on sidebar items → Pin, Hide

### 9.3 Drag & Drop
- Fee payments: drag payment proof to upload
- Documents: drag files to upload
- Bulk import: drag CSV/Excel files

### 9.4 Print Support
- Fee receipts: print directly from desktop
- Reports: print with Ctrl+P
- ID cards: batch print

### 9.5 System Integration
- Toast notifications for real-time updates
- File picker for document uploads
- Copy/paste support in forms

---

## 10. Testing Strategy

### 10.1 Desktop Layout Tests

Every modified screen must have:

```dart
testWidgets('Desktop layout renders correctly at 1280px', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(1280, 800)),
        child: const MyScreen(),
      ),
    ),
  );
  // Verify desktop-specific widgets exist
  expect(find.byType(DesktopDataTable), findsOneWidget);
  // Verify mobile widgets do NOT exist
  expect(find.byType(BottomNavigationBar), findsNothing);
});
```

### 10.2 Responsive Breakpoint Tests

```dart
testWidgets('Layout switches between mobile and desktop', (tester) async {
  // Test at mobile width
  await tester.pumpWidget(_buildScreen(width: 400));
  expect(find.byType(MobileLayout), findsOneWidget);

  // Test at desktop width
  await tester.pumpWidget(_buildScreen(width: 1280));
  expect(find.byType(DesktopLayout), findsOneWidget);
});
```

### 10.3 Visual Regression Tests

Use `flutter_test` golden tests to capture desktop layouts:

```dart
testWidgets('Principal dashboard desktop snapshot', (tester) async {
  await tester.pumpWidget(_buildDesktopApp());
  await expectLater(
    find.byType(PrincipalDashboardScreen),
    matchesGoldenFile('goldens/principal_dashboard_desktop.png'),
  );
});
```

---

## Summary Statistics

| Metric | Count |
|--------|-------|
| Total screens | 104 |
| Screens with desktop layout (existing) | 10 |
| Screens needing desktop layout | 94 |
| New reusable widgets to create | 9 |
| Estimated total effort | ~160 hours |
| Phases | 4 (8 weeks) |
| Mobile screens modified | **0** (all gated behind `isDesktopWidth`) |

---

## Priority Order (Implementation Sequence)

```
PHASE 1 (Week 1-2): 10 screens — Highest impact, daily use
  → Principal Dashboard, Teacher Dashboard, Parent Dashboard
  → Student Oversight, Staff Management, Admin Students
  → Principal Attendance, Admin Fees, Fee Collect, Fee Structures

PHASE 2 (Week 3-4): 25 screens — Core module screens
  → All remaining People, Finance, Attendance, Calendar, Reports screens

PHASE 3 (Week 5-6): 35 screens — Communication & forms
  → All Chat, Homework, Leave, Document, Timetable screens

PHASE 4 (Week 7-8): 24 screens — Polish & edge cases
  → Auth, Profile, Settings, Gallery, Help, Monitoring
```

---

*Document created: July 13, 2026*
*Last updated: July 13, 2026*
*Status: Ready for review*
