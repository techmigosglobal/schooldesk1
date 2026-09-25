import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path;

  String source(String relativePath) =>
      File('$root/$relativePath').readAsStringSync();

  test('parent dashboard exposes child-scoped overview values', () {
    final handler = source('supabase/functions/api/handlers/dashboard.ts');
    final screen = source(
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    );

    expect(handler, contains('attendance_pct: attendancePct ?? null'));
    expect(handler, contains('homework_due: homeworkDueByStudent'));
    expect(handler, contains('pending_fee_balance: feeBalanceByStudent'));
    expect(handler, contains('metrics: { ...base.metrics, unread_messages'));
    expect(screen, contains("value: _percentage(child['attendance_pct'])"));
    expect(screen, contains("value: _metricNumber(child['homework_due'])"));
    expect(screen, contains("label: 'Unread Messages'"));
    expect(screen, contains('_ParentChildTopSwitcher('));
  });

  test('parent home keeps a tall feed and compact overview cards', () {
    final screen = source(
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    );

    expect(
      screen,
      contains('final columns = constraints.maxWidth >= 700 ? 4 : 2'),
    );
    expect(screen, contains('height: 72'));
  });

  test('parent payments remain balance-first and fee-type governed', () {
    final paymentFlow = source(
      'lib/features/finance/presentation/screens/parent_hub/parent_payment_flow.dart',
    );
    final paymentRepository = source(
      'lib/roles/parent/data/api_parent_fee_payment_repository.dart',
    );
    final handler = source('supabase/functions/api/handlers/fees.ts');

    expect(paymentFlow, contains('double get _remainingBalance'));
    expect(paymentFlow, contains('amount > _remainingBalance'));
    expect(paymentFlow, contains('submitPaymentProof'));
    expect(paymentRepository, contains('submitParentPaymentRequestProof'));
    expect(handler, contains('billing_mode'));
  });

  test('shared chrome retains Help with parent-local toolbar actions', () {
    final scaffold = source('lib/core/widgets/erp_module_scaffold.dart');

    expect(scaffold, contains("if (_role == 'parent')"));
    expect(scaffold, contains("tooltip: 'Help'"));
    expect(scaffold, contains('class _ToolbarProfileButton'));
    expect(scaffold, contains('width: 30'));
  });
}
