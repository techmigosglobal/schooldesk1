import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';

void main() {
  test('uses finalized payment rows when invoice paid total is stale', () {
    final invoice = normalizeInvoice({
      'id': 'invoice-1',
      'student_id': 'student-1',
      'total_amount': 1000,
      'paid_amount': 0,
      'balance': 1000,
      'payments': [
        {'amount_paid': 400, 'status': 'completed'},
        {'amount_paid': 100, 'status': 'approved'},
        {'amount_paid': 999, 'status': 'pending'},
        {'amount_paid': 999, 'status': 'voided'},
      ],
    });

    expect(invoice['paid'], 500.0);
  });

  test('does not lower a server paid total when payment rows are partial', () {
    final invoice = normalizeInvoice({
      'id': 'invoice-2',
      'student_id': 'student-2',
      'total_amount': 1000,
      'paid_amount': 750,
      'balance': 250,
      'payments': [
        {'amount_paid': 500, 'status': 'completed'},
      ],
    });

    expect(invoice['paid'], 750.0);
  });
}
