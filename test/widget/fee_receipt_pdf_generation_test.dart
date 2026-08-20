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

  testWidgets('normalizes historical receipt aliases into the formal layout', (
    tester,
  ) async {
    final bytes = await PdfService.getInstance()
        .generatePaymentReceiptFromPayload({
          'receipt_snapshot': {
            'legacy_receipt_number': 'OLD-001',
            'amount': 1250,
            'payment_mode': 'Cash',
            'paid_at': '2026-08-19T10:00:00Z',
            'transaction_reference': 'COUNTER-7',
            'student_snapshot': {
              'student_name': 'Historical Student',
              'class_section': 'Nursery - A',
              'admission_number': 'ADM-7',
            },
            'items': [
              {'name': 'Tuition Fee', 'amount': 1250},
            ],
          },
          'academic_year_label': '2026-27',
          'billing_period': 'August 2026',
        });

    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  testWidgets('invoice previews use the same formal receipt document', (
    tester,
  ) async {
    final bytes = await PdfService.getInstance().generateFeeReceipt(
      documentKind: FeeDocumentKind.feeInvoice,
      receiptNo: 'FEE-AUTO-001',
      studentName: 'Invoice Student',
      className: 'LKG - A',
      rollNo: 'ADM-001',
      parentName: '',
      feeItems: const [
        {'description': 'Books & Kit', 'amount': 10000.0},
      ],
      totalAmount: 10000,
      paidAmount: 0,
      balance: 10000,
      paymentMode: 'Invoice',
      paymentDate: DateTime(2026, 8, 19),
      schoolName: 'Arish Ville Preschool',
      schoolAddress: 'School Address',
      academicYear: '2026-27',
      feePeriod: 'August 2026',
    );

    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
