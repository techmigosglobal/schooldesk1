import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/finance/presentation/screens/admin_fees_screen/fee_assignment_utils.dart';

void main() {
  group('fee assignment helpers', () {
    test('builds invoice generation payload for the selected scope', () {
      final payload = buildFeeAssignmentPayload(
        academicYearId: 'year-1',
        gradeId: 'grade-1',
        sectionId: 'section-1',
        dueDate: '2026-07-25',
        invoiceLabel: 'Term 1',
      );

      expect(payload['academic_year_id'], 'year-1');
      expect(payload['grade_id'], 'grade-1');
      expect(payload['section_id'], 'section-1');
      expect(payload['due_date'], '2026-07-25');
      expect(payload['invoice_label'], 'Term 1');
    });

    test('defaults the due date to 30 days from the reference date', () {
      final dueDate = defaultAssignmentDueDate(
        referenceDate: DateTime(2026, 7, 5),
      );

      expect(dueDate, '2026-08-04');
    });
  });
}
