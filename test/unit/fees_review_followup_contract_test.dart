import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fees review follow-up contracts', () {
    test(
      'admin fees uses backend batch late-fine sync before loading invoices',
      () {
        final api = File(
          'lib/core/network/api_modules/fees_api.dart',
        ).readAsStringSync();
        final admin = File(
          'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
        ).readAsStringSync();

        expect(api, contains('applyLateFineAdjustments'));
        expect(api, contains('/fees/invoices/late-fines/apply'));
        expect(admin, contains('await api.applyLateFineAdjustments()'));
        expect(
          admin,
          isNot(
            contains(
              'Future<List<Map<String, dynamic>>> _applyLateFineAdjustments',
            ),
          ),
        );
        expect(admin, isNot(contains('fineAmount: expectedFine')));
      },
    );

    test(
      'parent fee breakdown totals invoice item amounts, not invoice totals',
      () {
        final parent = File(
          'lib/features/finance/presentation/screens/parent_fees_screen/parent_fees_screen.dart',
        ).readAsStringSync();
        final start = parent.indexOf(
          'List<Map<String, dynamic>> _feeTypeBreakdown()',
        );
        final end = parent.indexOf(
          'Future<void> _openPaymentRequestForm',
          start,
        );
        final breakdown = parent.substring(start, end);

        expect(breakdown, contains('_feeTypeBreakdown()'));
        expect(breakdown, contains("final items = fee['items'];"));
        expect(breakdown, contains("item['amount']"));
        expect(breakdown, contains("fee['amount']"));
        expect(breakdown, isNot(contains("fee['totalAmount']")));
      },
    );

    test('fees audit bugs stay resolved across backend and active routes', () {
      final parentFeesHandler = File(
        'school-backend/internal/handlers/parent_fees.go',
      ).readAsStringSync();
      final feeHandler = File(
        'school-backend/internal/handlers/fee.go',
      ).readAsStringSync();
      final receiptView = File(
        'lib/features/finance/presentation/screens/parent_payment_screens/receipt_view_screen.dart',
      ).readAsStringSync();
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      final guard = File(
        'lib/routes/route_access_guard.dart',
      ).readAsStringSync();
      final registry = File(
        'lib/routes/schooldesk_screen_registry.dart',
      ).readAsStringSync();
      final financeBarrel = File(
        'lib/features/finance/finance.dart',
      ).readAsStringSync();
      final adminFees = File(
        'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
      ).readAsStringSync();

      expect(parentFeesHandler, contains('"pending", "partial", "overdue"'));
      expect(parentFeesHandler, contains('Where("parent_id = ?", userID)'));
      expect(parentFeesHandler, contains('"school_name"'));
      expect(receiptView, contains("_text(receipt['school_name']"));
      expect(receiptView, isNot(contains("'Arish Ville'")));
      expect(feeHandler, contains('if meta.feeType == "tuition" {'));
      expect(
        feeHandler,
        isNot(contains('meta.feeType == "tuition" && invoice.Balance > 0')),
      );

      expect(routes, isNot(contains('feePaymentReceipt')));
      expect(guard, isNot(contains('feePaymentReceipt')));
      expect(registry, isNot(contains('/fee-payment-receipt-screen')));
      expect(financeBarrel, isNot(contains('fee_payment_receipt_screen')));

      expect(adminFees, contains('AppRoutes.principalFeeStructureForm'));
      expect(adminFees, contains('AppRoutes.principalInvoiceGenerationForm'));
      expect(adminFees, contains('AppRoutes.principalPaymentRecordForm'));
      expect(adminFees, isNot(contains('AppRoutes.feePaymentReceipt')));
    });
  });
}
