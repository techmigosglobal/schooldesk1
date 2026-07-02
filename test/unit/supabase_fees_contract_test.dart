import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fees handler supports slash fees aliases used by Flutter', () {
    final source = File(
      'supabase/functions/api/handlers/fees.ts',
    ).readAsStringSync();

    expect(source, contains('feesPath.startsWith("/categories")'));
    expect(source, contains('feesPath.startsWith("/structures")'));
    expect(source, contains('feesPath.startsWith("/invoices")'));
    expect(source, contains('feesPath.startsWith("/payments")'));
    expect(source, contains('feesPath.startsWith("/payment-requests")'));
    expect(source, contains('feesPath === "/payment-config"'));
  });

  test(
    'fees handler includes payment intent submit resubmit and config flows',
    () {
      final source = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();

      expect(source, contains('seg === "intent"'));
      expect(source, contains('seg === "submit"'));
      expect(source, contains('/resubmit'));
      expect(source, contains('/payment-config/qr'));
      expect(source, contains('/payment-configs'));
      expect(source, contains('/payment-configs/'));
      expect(source, contains('invoice-sync'));
      expect(source, contains('late-fines'));
    },
  );

  test(
    'students handler exposes student fees route and avoids Dart string helpers',
    () {
      final source = File(
        'supabase/functions/api/handlers/students.ts',
      ).readAsStringSync();

      expect(source, contains('sub === "fees"'));
      expect(source, contains('fee_invoices'));
      expect(source, isNot(contains('.isNotEmpty')));
      expect(source, isNot(contains('.isEmpty')));
    },
  );

  test('parent fee history datasource uses Supabase fee payment routes', () {
    final source = File(
      'lib/features/finance/data/datasources/parent_fees_remote_datasource.dart',
    ).readAsStringSync();

    expect(source, contains("'/fees/payments'"));
    expect(source, contains('getMyStudents()'));
    expect(source, contains("queryParameters: {'student_id': studentId}"));
    expect(source, isNot(contains('/parents/fees/payments')));
    expect(source, isNot(contains('/parents/fees/receipts')));
  });
}
