import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Parent Razorpay payment contract', () {
    test('processing screen sends student_id when creating Razorpay orders', () {
      final source = File(
        'lib/features/finance/presentation/screens/parent_payment_screens/parent_payment_processing_screen.dart',
      ).readAsStringSync();

      expect(source, contains('CreateRazorpayOrderRequest('));
      expect(source, contains('studentId:'));
    });

    test('parent datasource uses parent-owned payment endpoints', () {
      final source = File(
        'lib/features/finance/data/datasources/parent_fees_remote_datasource.dart',
      ).readAsStringSync();

      expect(source, contains('/parents/fees/payment-orders'));
      expect(source, contains('/parents/fees/verify-payment'));
      expect(source, contains('/parents/fees/payments'));
      expect(source, contains('/parents/fees/receipts/'));
    });

    test('parent payment history and receipt screens are backend-driven', () {
      final history = File(
        'lib/features/finance/presentation/screens/parent_payment_screens/parent_payment_history_screen.dart',
      ).readAsStringSync();
      final receipt = File(
        'lib/features/finance/presentation/screens/parent_payment_screens/receipt_view_screen.dart',
      ).readAsStringSync();

      expect(history, contains('getPaymentHistory('));
      expect(history, isNot(contains('Mock data')));
      expect(receipt, contains('getReceipt('));
      expect(receipt, isNot(contains('Mock invoice items')));
    });
  });
}
