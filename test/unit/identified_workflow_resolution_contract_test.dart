import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('fee edits sync linked invoices and tuition is monthly', () {
    final fees = source('supabase/functions/api/handlers/fees.ts');
    final form = source(
      'lib/features/finance/presentation/screens/admin_fees_screen/'
      'admin_fee_form_screens.dart',
    );
    final payment = source(
      'lib/features/finance/presentation/screens/parent_hub/'
      'parent_payment_flow.dart',
    );

    expect(fees, contains('async function feeInvoiceSyncPlan'));
    expect(fees, contains('applyFeeInvoiceSyncPlan'));
    expect(fees, contains('synced_invoice_count: synced'));
    expect(fees, contains('skipped_partial_count'));
    expect(
      fees,
      contains(
        'const billingMode = feeType === "tuition" ? "monthly" : "one_time"',
      ),
    );
    expect(fees, contains('billing_mode: row.billingMode'));
    expect(form, contains("return 'monthly';"));
    expect(payment, contains('double get _remainingBalance'));
    expect(payment, contains('Future<void> _proceedToPay()'));
    expect(payment, contains('amount > _remainingBalance'));
  });

  test(
    'pending fee proofs are distinct and fee screens refresh on notices',
    () {
      final principal = source('supabase/functions/api/handlers/principal.ts');
      final classHub = source(
        'lib/features/academics/presentation/screens/'
        'principal_classes_screen/principal_classes_screen.dart',
      );
      final parentHub = source(
        'lib/features/finance/presentation/screens/parent_hub/'
        'parent_fee_hub.dart',
      );

      expect(principal, contains('pendingFeeProofsBySection'));
      expect(principal, contains('fees_pending_verification_amount'));
      expect(principal, contains('fees_pending_verification_students'));
      expect(classHub, contains('proof pending review'));
      expect(classHub, contains('NotificationService.getInstance()'));
      expect(parentHub, contains('NotificationService.getInstance()'));
      expect(parentHub, contains('_onNotificationsChanged'));
    },
  );

  test(
    'receipt views prefer the canonical payment method and real identity',
    () {
      final receipt = source(
        'lib/features/finance/presentation/screens/parent_hub/'
        'parent_receipt_view_v2.dart',
      );
      final principalCard = source(
        'lib/features/finance/presentation/screens/principal_dashboard/'
        'principal_payment_requests.dart',
      );
      final documents = source(
        'lib/features/documents/presentation/screens/'
        'parent_documents_screen/parent_documents_screen.dart',
      );

      expect(receipt, contains("receipt['payment_method']"));
      expect(receipt, contains("pr['payment_method']"));
      expect(principalCard, contains("r['payment_method']"));
      expect(receipt, contains('api.getCurrentSchool()'));
      expect(receipt, contains('api.getProfile()'));
      expect(documents, contains('schoolName:'));
      expect(documents, contains('parentName: _parentName'));
      expect(documents, contains('rollNo: rollNo'));
    },
  );

  test('calendar uses academic years, interactive parent grid, and push', () {
    final calendar = source(
      'lib/features/calendar/presentation/screens/events_calendar_screen/'
      'events_calendar_screen.dart',
    );
    final routes = source('lib/routes/app_routes.dart');
    final parentCalendar = source(
      'lib/features/calendar/presentation/screens/'
      'parent_calendar_screen/parent_calendar_screen.dart',
    );
    final handler = source('supabase/functions/api/handlers/calendar.ts');

    expect(calendar, isNot(contains('DateTime(2026')));
    expect(calendar, contains('TableCalendar<_PrincipalEvent>'));
    expect(calendar, contains('onDaySelected: _selectDay'));
    expect(calendar, contains('showModalBottomSheet<void>'));
    expect(parentCalendar, contains('TableCalendar<Map<String, dynamic>>'));
    expect(
      parentCalendar,
      contains('onDaySelected: (selectedDay, focusedDay)'),
    );
    expect(
      routes,
      contains(
        'const EventsCalendarScreen(portal: SchoolCalendarPortal.parent)',
      ),
    );
    expect(handler, contains('notifyEventAudience'));
    expect(handler, contains('triggerPushProcessing(ids)'));
  });

  test('legacy homework messages push and leave decisions are idempotent', () {
    final chat = source('supabase/functions/api/handlers/communications.ts');
    final messaging = source('lib/core/services/messaging_service.dart');
    final leave = source('supabase/functions/api/handlers/leave.ts');
    final approvals = source(
      'lib/features/people/presentation/screens/approval_center_screen/'
      'approval_center_screen.dart',
    );
    final parentChat = source(
      'lib/features/communication/presentation/screens/'
      'parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
    );

    expect(chat, contains('New homework message'));
    expect(chat, contains('resolveChatNotificationTarget'));
    expect(messaging, isNot(contains('_triggerNotification')));
    expect(parentChat, isNot(contains('Desktop view coming soon')));
    expect(approvals, isNot(contains('triggerLeaveStatusAlert')));
    expect(leave, contains('.eq("status", "pending")'));
    expect(leave, contains('Leave Recall Confirmed'));
    expect(leave, contains('event_type: "leave_recalled"'));
  });

  test('documents notify parents and issue submission is parent-safe', () {
    final uploads = source('supabase/functions/api/handlers/uploads.ts');
    final adminDocuments = source(
      'lib/features/documents/presentation/screens/'
      'admin_documents_screen/admin_documents_screen.dart',
    );
    final issues = source('supabase/functions/api/handlers/issues.ts');
    final issueScreen = source(
      'lib/features/communication/presentation/screens/issue_screen.dart',
    );
    final routes = source('lib/routes/app_routes.dart');

    expect(adminDocuments, contains("createRaw('/student-documents'"));
    expect(uploads, contains('notifyStudentDocumentParents'));
    expect(uploads, contains('teacherAssignedSectionIds'));
    expect(uploads, contains('fee receipts cannot be deleted by parents'));
    expect(uploads, contains('student_document_uploaded'));
    expect(
      issues,
      contains('new Set(["principal", "coordinator", "teacher", "parent"])'),
    );
    expect(issues, contains('/issues/with-attachments'));
    expect(issues, contains('uploadedPaths'));
    expect(issues, contains('remove(uploadedPaths)'));
    expect(issueScreen, isNot(contains('file.path!')));
    expect(issueScreen, contains('Choose up to five files'));
    expect(routes, contains('IssueScreen(role: IssueScreenRole.parent)'));
  });

  test(
    'desktop screens contain live workflows and role navigation exposes them',
    () {
      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final parentNavigation = source(
        'lib/core/widgets/parent_navigation.dart',
      );
      final navigation = source('lib/core/widgets/app_navigation.dart');
      final routeFrame = source('lib/core/widgets/schooldesk_route_frame.dart');

      for (final file in dartFiles) {
        expect(
          file.readAsStringSync(),
          isNot(contains('Desktop view coming soon')),
          reason: '${file.path} must not replace the live screen on Windows',
        );
      }
      expect(parentNavigation, contains('route: AppRoutes.parentComplaints'));
      expect(navigation, contains('route: AppRoutes.superAdminDashboard'));
      expect(routeFrame, contains('case AppRoutes.academicManagement:'));
    },
  );
}
