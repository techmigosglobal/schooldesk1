import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('principal academic years support safe delete and export download', () {
    final source = File(
      'lib/features/academics/presentation/screens/academic_management_screen/principal_academic_years_screen.dart',
    ).readAsStringSync();
    final api = File(
      'lib/core/network/api_modules/communications_api.dart',
    ).readAsStringSync();

    expect(source, contains('_confirmAcademicYearDelete'));
    expect(source, contains('_confirmAcademicYearFinalDelete'));
    expect(source, contains('deleteAcademicYear('));
    expect(source, contains('cascadeConfirmed: true'));

    expect(source, contains("values: const ['csv', 'xlsx', 'pdf']"));
    expect(source, isNot(contains("values: const ['csv', 'excel', 'pdf']")));

    expect(source, contains('ShareExportService'));
    expect(source, contains('downloadReportExport'));
    expect(api, contains('Future<Uint8List> downloadReportExport'));
    expect(api, contains('EnvConfig.apiOrigin'));
  });

  test('academic year delete clears linked finance workflow rows first', () {
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
    expect(academics, contains('svc.from("fee_receipts").delete()'));
    expect(academics, contains('svc.from("parent_payment_requests").delete()'));
    expect(academics, contains('svc.from("payments").delete()'));
    expect(academics, contains('svc.from("fee_invoices").delete()'));
    expect(academics, contains('svc.from("fee_concessions").delete()'));
    expect(academics, contains('deleted_invoices'));
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
