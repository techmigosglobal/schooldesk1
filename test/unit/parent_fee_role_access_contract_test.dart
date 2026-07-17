import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parent fee screens use only the linked-child invoice endpoint', () {
    final hub = File(
      'lib/features/finance/presentation/screens/parent_hub/parent_fee_hub.dart',
    ).readAsStringSync();
    final history = File(
      'lib/features/finance/presentation/screens/parent_hub/parent_payment_history_v2.dart',
    ).readAsStringSync();

    expect(hub, contains('getParentStudentFees('));
    expect(history, contains('getParentStudentFees(studentId)'));
    expect(hub, isNot(contains('getInvoices(')));
    expect(history, isNot(contains('getInvoices(')));
  });

  test(
    'linked-child fees include payments while global invoices stay guarded',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();
      final parentRouteStart = source.indexOf(
        'if (/^\\/parent\\/students\\/[^/]+\\/fees\$/.test(path)',
      );
      final paymentRequestsStart = source.indexOf(
        'if (feesPath.startsWith("/payment-requests"))',
      );
      expect(parentRouteStart, greaterThanOrEqualTo(0));
      expect(paymentRequestsStart, greaterThan(parentRouteStart));
      final parentRoute = source.substring(
        parentRouteStart,
        paymentRequestsStart,
      );

      expect(parentRoute, contains('parentCanAccessStudent('));
      expect(parentRoute, contains('payments(*)'));
      expect(parentRoute, contains('.eq("student_id", studentId)'));

      expect(source, contains('feesPath.startsWith("/invoices")'));
      expect(source, contains('return fail("principal access required", 403)'));
      expect(source, contains('feesPath === "/invoices"'));
      expect(source, contains('requestedInvoiceStudentId'));
      expect(source, contains('isParentLinkedInvoiceRead'));
      expect(
        source,
        contains('parent invoice access requires a linked student'),
      );
      expect(source, contains('Student does not belong to a linked child'));
      expect(source, contains('q = q.eq("parent_user_id", user.id)'));
      expect(
        source,
        contains('return fail("admin or principal access required", 403)'),
      );
    },
  );
}
