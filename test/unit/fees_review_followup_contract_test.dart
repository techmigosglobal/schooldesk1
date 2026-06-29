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
  });
}
