import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'principal academic years support safe delete and selected-year summary',
    () {
      final source = File(
        'lib/features/academics/presentation/screens/academic_management_screen/principal_academic_years_screen.dart',
      ).readAsStringSync();

      expect(source, contains('_confirmAcademicYearDelete'));
      expect(source, contains('_confirmAcademicYearFinalDelete'));
      expect(source, contains('deleteAcademicYear('));
      expect(source, contains('cascadeConfirmed: true'));

      expect(source, contains('getAcademicYearSummary'));
      expect(source, contains('active_student_count'));
      expect(source, contains('fee_structure_names'));
      expect(source, isNot(contains('Export Data')));
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      expect(routes, isNot(contains('academicYearClasswiseExport')));
      expect(routes, isNot(contains('academicYearUsersExport')));
      expect(routes, isNot(contains('academicYearFeesExport')));
    },
  );

  test('academic year delete archives linked finance workflow rows first', () {
    final screen = File(
      'lib/features/academics/presentation/screens/academic_management_screen/academic_management_screen.dart',
    ).readAsStringSync();
    final academics = File(
      'supabase/functions/api/handlers/academics.ts',
    ).readAsStringSync();

    expect(screen, contains('scrollable: true'));
    expect(screen, contains('SingleChildScrollView'));
    expect(screen, contains('maxHeight: MediaQuery.sizeOf(ctx).height * 0.45'));
    expect(screen, contains('Wrap('));

    expect(academics, contains('deleteAcademicYearWorkflowRows'));
    expect(academics, contains('deleteInvoiceWorkflowRows'));
    expect(academics, contains('archived_academic_year'));
    expect(academics, contains('retained_invoices'));
    expect(academics, contains('cancelled_invoices'));
    expect(academics, contains('reversed_requests'));
    expect(academics, contains('status: "archived"'));
    expect(academics, isNot(contains('svc.from("fee_receipts").delete()')));
    expect(
      academics,
      isNot(contains('svc.from("parent_payment_requests").delete()')),
    );
    expect(academics, isNot(contains('svc.from("payments").delete()')));
    expect(academics, isNot(contains('svc.from("fee_invoices").delete()')));
    expect(academics, isNot(contains('svc.from("fee_concessions").delete()')));
  });

  test('principal academic year screens use adaptive text sizing', () {
    final source = File(
      'lib/features/academics/presentation/screens/academic_management_screen/principal_academic_years_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_ayResponsiveTextScale'));
    expect(source, contains('_ayFont('));
    expect(source, contains('copyWith(fontSize:'));
  });
}
