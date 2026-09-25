import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migrated role screens use typed repository state rendering', () {
    const paths = [
      'lib/features/attendance/presentation/screens/principal_attendance_screen/principal_attendance_screen.dart',
      'lib/features/academics/presentation/screens/principal_subjects_screen/principal_subjects_screen.dart',
      'lib/features/communication/presentation/screens/principal_event_approval_screen.dart',
      'lib/features/academics/presentation/screens/teacher_classes_screen/teacher_classes_screen.dart',
      'lib/features/attendance/presentation/screens/teacher_attendance_history_screen/teacher_attendance_history_screen.dart',
      'lib/features/leave/presentation/screens/teacher_leave_screen/teacher_leave_screen.dart',
      'lib/features/finance/presentation/screens/fee_payment_config_screen/fee_payment_config_screen.dart',
      'lib/features/health/presentation/screens/parent_health_update_screen/parent_health_update_screen.dart',
      'lib/features/academics/presentation/screens/parent_lesson_planner_screen/parent_lesson_planner_screen.dart',
      'lib/features/academics/presentation/screens/parent_timetable_screen/parent_timetable_screen.dart',
      'lib/features/communication/presentation/screens/teacher_complaint_screen/teacher_complaint_screen.dart',
      'lib/features/communication/presentation/screens/parent_complaint_screen/parent_complaint_screen.dart',
      'lib/features/finance/presentation/screens/principal_dashboard/principal_payment_config.dart',
      'lib/features/monitoring/presentation/screens/principal_audit_logs_screen.dart',
      'lib/features/documents/presentation/screens/teacher_documents_screen/teacher_documents_screen.dart',
      'lib/features/documents/presentation/screens/parent_documents_screen/parent_documents_screen.dart',
      'lib/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart',
      'lib/features/academics/presentation/screens/academic_info_screen/academic_info_screen.dart',
      'lib/features/academics/presentation/screens/principal_lesson_planner_screen.dart',
      'lib/features/documents/presentation/screens/id_card_generation_screen/id_card_generation_screen.dart',
      'lib/features/attendance/presentation/screens/parent_attendance_screen/parent_attendance_screen.dart',
      'lib/features/finance/presentation/screens/parent_hub/parent_receipt_view_v2.dart',
      'lib/features/finance/presentation/screens/parent_hub/parent_payment_history_v2.dart',
      'lib/features/leave/presentation/screens/parent_leave_screen/parent_leave_screen.dart',
      'lib/features/homework/presentation/screens/parent_homework_screen/parent_homework_screen.dart',
      'lib/features/calendar/presentation/screens/parent_calendar_screen/parent_calendar_screen.dart',
      'lib/features/attendance/presentation/screens/teacher_my_attendance_screen/teacher_my_attendance_screen.dart',
      'lib/features/homework/presentation/screens/parent_homework_screen/parent_homework_submission_screen.dart',
      'lib/features/finance/presentation/screens/principal_dashboard/principal_fee_dashboard.dart',
      'lib/features/attendance/presentation/screens/admin_attendance_screen/admin_attendance_screen.dart',
      'lib/features/monitoring/presentation/screens/system_monitor_screen.dart',
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_payment_requests_screen.dart',
      'lib/features/documents/presentation/screens/admin_documents_screen/admin_documents_screen.dart',
      'lib/features/people/presentation/screens/admin_students_screen/admin_students_screen.dart',
      'lib/features/people/presentation/screens/admin_teachers_screen/admin_teachers_screen.dart',
      'lib/features/people/presentation/screens/approval_center_screen/approval_center_screen.dart',
      'lib/features/people/presentation/screens/admin_user_access_screen/admin_user_access_screen.dart',
      'lib/features/attendance/presentation/screens/teacher_attendance_screen/teacher_attendance_screen.dart',
      'lib/features/finance/presentation/screens/fee_home_screen/fee_home_screen.dart',
      'lib/features/finance/presentation/screens/fee_ledger_screen/fee_ledger_screen.dart',
      'lib/features/people/presentation/screens/student_oversight_screen/student_oversight_screen.dart',
      'lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart',
      'lib/features/dashboard/presentation/screens/admin_dashboard_screen/admin_dashboard_screen.dart',
      'lib/features/profile/presentation/screens/profile_management_screen/profile_management_screen.dart',
      'lib/features/profile/presentation/screens/school_profile_screen/school_profile_screen.dart',
      'lib/features/profile/presentation/screens/settings_screen/settings_screen.dart',
      'lib/features/shell/presentation/screens/global_search_screen/global_search_screen.dart',
      'lib/features/calendar/presentation/screens/events_calendar_screen/events_calendar_screen.dart',
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
      'lib/features/finance/presentation/screens/parent_hub/parent_fee_hub.dart',
      'lib/features/finance/presentation/screens/principal_dashboard/principal_fee_structures.dart',
      'lib/features/finance/presentation/screens/principal_dashboard/principal_payment_requests.dart',
      'lib/features/finance/presentation/screens/principal_dashboard/principal_collect_fee.dart',
      'lib/features/finance/presentation/screens/fee_collect_screen/fee_collect_screen.dart',
      'lib/features/communication/presentation/screens/parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
      'lib/features/communication/presentation/screens/notification_center_screen/notification_center_screen.dart',
      'lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart',
      'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
      'lib/features/communication/presentation/screens/complaint_management_screen/complaint_management_screen.dart',
      'lib/features/communication/presentation/screens/event_post_screen.dart',
      'lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_screen.dart',
      'lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_form_screens.dart',
      'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
      'lib/features/people/presentation/screens/guardian_directory_screen/guardian_directory_screen.dart',
      'lib/features/communication/presentation/screens/issue_screen.dart',
      'lib/features/academics/presentation/screens/lesson_planner_screen.dart',
      'lib/features/academics/presentation/screens/academic_management_screen/academic_management_screen.dart',
      'lib/features/academics/presentation/screens/academic_management_screen/principal_academic_years_screen.dart',
      'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart',
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
      'lib/features/reports/presentation/screens/admin_reports_screen/admin_reports_screen.dart',
      'lib/features/reports/presentation/screens/principal_analytics_screen/principal_analytics_screen.dart',
      'lib/features/reports/presentation/screens/reports_analytics_screen/reports_analytics_screen.dart',
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_payment_request_decision_screen.dart',
      'lib/features/finance/presentation/screens/parent_hub/parent_payment_flow.dart',
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart',
      'lib/features/academics/presentation/screens/academic_management_screen/academic_management_form_screens.dart',
      'lib/features/leave/presentation/screens/parent_leave_screen/parent_leave_request_form_screen.dart',
      'lib/features/leave/presentation/screens/teacher_leave_screen/teacher_leave_request_form_screen.dart',
      'lib/features/attendance/presentation/screens/kiosk_qr_attendance_screen/kiosk_qr_attendance_screen.dart',
      'lib/features/auth/presentation/screens/login_loading_screen/login_loading_screen.dart',
      'lib/features/shell/presentation/screens/landing_page_screen/landing_page_screen.dart',
      'lib/features/people/presentation/screens/admin_user_access_screen/account_access_form_screen.dart',
      'lib/features/people/presentation/screens/admin_user_access_screen/account_child_assignment_screen.dart',
      'lib/features/people/presentation/screens/admission_inquiries_screen.dart',
      'lib/features/people/presentation/screens/staff_management_screen/staff_form_screen.dart',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(source, contains('RepositoryState<'), reason: path);
      expect(source, contains('SchoolDeskRepositoryStateView<'), reason: path);
      expect(source, isNot(contains('bool _loading =')), reason: path);
      expect(source, isNot(contains('String? _error')), reason: path);
    }
  });

  test('migrated screens do not access the legacy data service directly', () {
    const paths = [
      'lib/features/academics/presentation/screens/academic_info_screen/academic_info_screen.dart',
      'lib/features/academics/presentation/screens/academic_management_screen/academic_management_screen.dart',
      'lib/features/academics/presentation/screens/academic_management_screen/academic_management_form_screens.dart',
      'lib/features/dashboard/presentation/screens/admin_dashboard_screen/admin_dashboard_screen.dart',
      'lib/features/documents/presentation/screens/id_card_generation_screen/id_card_generation_screen.dart',
      'lib/features/reports/presentation/screens/reports_analytics_screen/reports_analytics_screen.dart',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('BackendDataService')), reason: path);
    }
  });
}
