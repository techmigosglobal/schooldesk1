import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('generates a valid PDF receipt ready for sharing', (
    tester,
  ) async {
    final bytes = await PdfService.getInstance().generateFeeReceipt(
      receiptNo: 'RCP-SMOKE-001',
      studentName: 'Test Student',
      className: 'Playgroup - A',
      rollNo: 'STU-001',
      parentName: 'Test Parent',
      feeItems: const [
        {'description': 'Book & Kit Fee', 'amount': 12.0},
      ],
      totalAmount: 12,
      paidAmount: 12,
      balance: 0,
      paymentMode: 'UPI',
      paymentDate: DateTime(2026, 7, 14, 10, 56),
      schoolName: 'School',
      schoolAddress: 'Test Address',
    );

    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  testWidgets('generates a separate account statement document', (
    tester,
  ) async {
    final bytes = await PdfService.getInstance().generateFeeReceipt(
      documentKind: FeeDocumentKind.accountStatement,
      receiptNo: 'STMT-STU-001',
      studentName: 'Test Student',
      className: 'Playgroup - A',
      rollNo: 'STU-001',
      parentName: 'Ignored for statements',
      feeItems: const [
        {
          'description': 'Tuition',
          'amount': 10.0,
          'status': 'Paid ₹6 · Due ₹4',
        },
        {
          'description': 'Books & Kit',
          'amount': 10.0,
          'status': 'Paid ₹0 · Due ₹10',
        },
      ],
      totalAmount: 20,
      paidAmount: 6,
      balance: 14,
      paymentMode: 'This is intentionally not shown',
      paymentDate: DateTime(2026, 7, 14, 10, 56),
      schoolName: 'School',
      schoolAddress: 'Test Address',
    );

    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
