import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parent context, fee decisions, and homework notices retain child scope', () {
    final selector = File(
      'lib/core/widgets/parent_child_selector.dart',
    ).readAsStringSync();
    final receipt = File(
      'lib/features/finance/presentation/screens/parent_hub/parent_receipt_view_v2.dart',
    ).readAsStringSync();
    final paymentHistory = File(
      'lib/features/finance/presentation/screens/parent_hub/parent_payment_history_v2.dart',
    ).readAsStringSync();
    final homework = File(
      'supabase/functions/api/handlers/homework.ts',
    ).readAsStringSync();
    final fees = File(
      'supabase/functions/api/handlers/fees.ts',
    ).readAsStringSync();
    final resolver = File(
      'lib/core/services/notification_route_resolver.dart',
    ).readAsStringSync();

    expect(selector, contains("'Class \$grade'"));
    expect(selector, contains("'Section \$section'"));
    expect(receipt, contains("receipt['receipt_number']"));
    expect(receipt, contains('crossAxisAlignment: CrossAxisAlignment.start'));
    expect(paymentHistory, contains('ParentChildSelectionService.indexFor'));
    expect(homework, contains('assignedStudentIds'));
    expect(homework, contains('parent_user_id, student_id'));
    expect(homework, contains('student_id: link.student_id'));
    expect(homework, contains('text(hw.created_by)'));
    expect(fees, contains('Failed to write fee in-app notifications'));
    expect(fees, contains('Failed to write parent fee in-app notification'));
    expect(fees, contains('receipt: receiptsById.get'));
    expect(resolver, contains("'student_id': data['student_id'].toString().trim()"));
  });
}
