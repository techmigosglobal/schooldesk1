import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('database assigns fee invoices for new structures and students', () {
    final migration = File(
      'supabase/migrations/20260716164011_auto_assign_fee_invoices.sql',
    ).readAsStringSync();

    expect(migration, contains('fee_invoices_student_structure_key'));
    expect(migration, contains('ensure_fee_invoices_for_student'));
    expect(migration, contains('ensure_fee_invoices_for_structure'));
    expect(migration, contains('students_auto_assign_fee_invoices'));
    expect(migration, contains('structures_auto_assign_fee_invoices'));
    expect(migration, contains("s.status = 'active'"));
    expect(migration, contains('fs.academic_year_id = sec.academic_year_id'));
    expect(migration, contains('fs.grade_id = sec.grade_id'));
    expect(migration, contains("'June', 'July', 'August'"));
    expect(migration, contains("'January', 'February', 'March'"));
    expect(migration, contains('revoke all on function'));
    expect(migration, contains('Repair existing gaps'));
  });

  test('fee structures expose assignment health to the principal', () {
    final handler = File(
      'supabase/functions/api/handlers/fees.ts',
    ).readAsStringSync();
    final screen = File(
      'lib/features/finance/presentation/screens/principal_dashboard/principal_fee_structures.dart',
    ).readAsStringSync();

    expect(handler, contains('attachStructureAssignmentStats'));
    expect(handler, contains('eligible_student_count'));
    expect(handler, contains('invoiced_student_count'));
    expect(handler, contains('missing_invoice_count'));
    expect(screen, contains('All student fees are synced'));
    expect(screen, contains('students synced'));
    expect(screen, contains('_openEditForm'));
  });

  test('student writes invalidate fee and dashboard summaries', () {
    final studentsApi = File(
      'lib/core/network/api_modules/students_api.dart',
    ).readAsStringSync();
    final createStart = studentsApi.indexOf(
      'Future<StudentModel> createStudent',
    );
    final updateStart = studentsApi.indexOf('Future<void> updateStudent');
    final multipartStart = studentsApi.indexOf(
      'Future<MultipartFile> _multipartStudentFile',
    );

    expect(createStart, greaterThanOrEqualTo(0));
    expect(updateStart, greaterThan(createStart));
    expect(multipartStart, greaterThan(updateStart));
    final createSection = studentsApi.substring(createStart, updateStart);
    final updateSection = studentsApi.substring(updateStart, multipartStart);
    for (final source in [createSection, updateSection]) {
      expect(source, contains("r'/fees/structures'"));
      expect(source, contains("r'/fees/invoices'"));
      expect(source, contains("r'/principal/classes'"));
      expect(source, contains("r'/dashboard/'"));
    }
  });

  test('parent dashboard and fees use compact interactive cards', () {
    final dashboard = File(
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    ).readAsStringSync();
    final fees = File(
      'lib/features/finance/presentation/screens/parent_hub/parent_fee_hub.dart',
    ).readAsStringSync();

    expect(dashboard, contains('final columns = constraints.maxWidth >= 700'));
    expect(dashboard, contains('height: 72'));
    expect(dashboard, contains('Icons.chevron_right_rounded'));
    expect(fees, contains('_buildFeeSectionHeader'));
    expect(fees, contains("label: const Text('History')"));
    expect(fees, contains('Color(0xFFF4FBF8)'));
    expect(fees, contains('Icons.account_balance_wallet_rounded'));
  });
}
