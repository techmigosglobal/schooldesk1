import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parent dashboard has one canonical child-scoped source', () {
    final screen = File(
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    ).readAsStringSync();
    final handler = File(
      'supabase/functions/api/handlers/dashboard.ts',
    ).readAsStringSync();

    expect(screen, contains("api.getDashboard('parent'"));
    expect(screen, isNot(contains('api.getMyStudents(')));
    expect(screen, isNot(contains('api.getCurrentSchool(')));
    expect(screen, contains("_metricNumber(child['unread_messages'])"));
    expect(screen, isNot(contains("child['pending_fee_balance'] ?? metrics")));
    expect(handler, contains('async function parentDashboardResponse'));
    expect(handler, contains('.eq("parent_user_id", user.id)'));
    expect(
      handler,
      contains('text(student.status).toLowerCase() === "active"'),
    );
    expect(handler, contains('unread_messages: unreadMessagesByStudent'));
    expect(
      handler,
      contains(
        'if (dashRole === "parent") {\n      return parentDashboardResponse',
      ),
    );
  });

  test('parent notifications retain authorized child context end to end', () {
    final communications = File(
      'supabase/functions/api/handlers/communications.ts',
    ).readAsStringSync();
    final attendance = File(
      'supabase/functions/api/handlers/attendance.ts',
    ).readAsStringSync();
    final fees = File(
      'supabase/functions/api/handlers/fees.ts',
    ).readAsStringSync();
    final resolver = File(
      'lib/core/services/notification_route_resolver.dart',
    ).readAsStringSync();
    final push = File(
      'lib/core/services/push_notification_service.dart',
    ).readAsStringSync();
    final center = File(
      'lib/features/communication/presentation/screens/notification_center_screen/notification_center_screen.dart',
    ).readAsStringSync();

    expect(communications, contains('.eq("school_id", school)'));
    expect(communications, contains('linkedStudentIds'));
    expect(communications, contains(r'student_id.in.(${linkedStudentIds.join'));
    expect(attendance, contains('student_id: delivery.studentId'));
    expect(
      attendance,
      contains('eq("role_name", "parent").eq("is_active", true)'),
    );
    expect(fees, contains('event_type: "fee_invoice_generated"'));
    expect(fees, contains('student_id: invoiceStudentId'));
    expect(resolver, contains("'selected_student_id': studentId"));
    expect(push, contains('ParentChildSelectionService.saveStudentId'));
    expect(
      center,
      contains('ParentChildSelectionService.saveStudentId(notif.studentId)'),
    );
  });

  test('parent chat uses the selected authorized child and one list request', () {
    final chat = File(
      'lib/features/communication/presentation/screens/parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
    ).readAsStringSync();

    expect(chat, contains('ParentChildSelectionService.indexFor'));
    expect(
      chat,
      contains('api.getUnifiedChatConversations(studentId: selectedStudent)'),
    );
    expect(chat, isNot(contains("type: 'parent_teacher'")));
    expect(chat, isNot(contains("type: 'principal_parent'")));
  });

  test('principal chat loads one unified conversation list per refresh', () {
    final chat = File(
      'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
    ).readAsStringSync();

    expect(chat, contains('api.getUnifiedChatConversations(monitor: true)'));
    expect(chat, isNot(contains("type: 'parent_teacher'")));
    expect(chat, isNot(contains("type: 'principal_teacher'")));
    expect(chat, isNot(contains("type: 'principal_parent'")));
  });

  test('PTM is retired from active routes, navigation, and calendar loading', () {
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final parentNav = File(
      'lib/core/widgets/parent_navigation.dart',
    ).readAsStringSync();
    final teacherNav = File(
      'lib/core/widgets/teacher_navigation.dart',
    ).readAsStringSync();
    final gateway = File('supabase/functions/api/index.ts').readAsStringSync();
    final communications = File(
      'supabase/functions/api/handlers/communications.ts',
    ).readAsStringSync();
    final processor = File(
      'supabase/functions/notification-processor/index.ts',
    ).readAsStringSync();
    final calendar = File(
      'lib/features/calendar/presentation/screens/events_calendar_screen/events_calendar_screen.dart',
    ).readAsStringSync();

    expect(routes, isNot(contains('parentPTMBooking')));
    expect(routes, isNot(contains('teacherParentInteraction')));
    expect(parentNav, isNot(contains('PTM')));
    expect(teacherNav, isNot(contains('PTM')));
    expect(
      gateway,
      isNot(contains('path.startsWith("/parent-teacher-meetings")')),
    );
    expect(communications, isNot(contains('parent_teacher_meetings')));
    expect(communications, isNot(contains('/teacher/ptm-slots')));
    expect(processor, contains('retired_ptm_feature'));
    expect(calendar, isNot(contains('_PrincipalEvent.fromPtmApi')));
  });
}
