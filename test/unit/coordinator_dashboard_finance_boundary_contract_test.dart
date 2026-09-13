import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coordinator dashboard returns an operations DTO before fee queries', () {
    final handler = File(
      'supabase/functions/api/handlers/dashboard.ts',
    ).readAsStringSync();
    final dto = File(
      'supabase/functions/api/lib/dashboard_dto.ts',
    ).readAsStringSync();

    final coordinatorResponse = handler.indexOf(
      'if (!financeAuthorized) {\n      return ok(coordinatorDashboardDto(operations));',
    );
    final financeQueries = handler.indexOf('fee_dashboard_summary');

    expect(coordinatorResponse, greaterThanOrEqualTo(0));
    expect(financeQueries, greaterThan(coordinatorResponse));
    expect(handler, contains('approvalRequestsQuery.not('));
    expect(handler, contains('"fee","fees","finance","payment"'));
    expect(handler, isNot(contains('const [invoices, paidInvoices, parentPaymentRequests] = await Promise.all')));

    final coordinatorTypeStart = dto.indexOf(
      'export type CoordinatorDashboardDto',
    );
    final financeTypeStart = dto.indexOf('export type FinanceDashboardInput');
    expect(coordinatorTypeStart, greaterThanOrEqualTo(0));
    expect(financeTypeStart, greaterThan(coordinatorTypeStart));
    final coordinatorType = dto.substring(
      coordinatorTypeStart,
      financeTypeStart,
    );
    expect(coordinatorType, isNot(contains('fee')));
    expect(dto, contains('export type FinanceDashboardDto'));
    expect(dto, contains('pending_fee_balance'));
  });
}
