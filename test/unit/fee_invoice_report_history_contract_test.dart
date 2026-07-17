import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invoice generation remains usable when no installment terms exist', () {
    final source = File(
      'lib/features/finance/presentation/screens/principal_dashboard/principal_invoice_generate.dart',
    ).readAsStringSync();

    expect(source, contains("if (_selectedTermId.isNotEmpty) 'term_id'"));
    expect(source, contains('Installment Term (Optional)'));
    expect(source, contains('No terms configured'));
    expect(source, contains('No duplicate invoices were created'));
  });

  test('fee reports group component invoices into one student account', () {
    final source = File(
      'lib/features/finance/presentation/screens/principal_dashboard/principal_reports_v2.dart',
    ).readAsStringSync();

    expect(source, contains('List<Map<String, dynamic>> get _studentAccounts'));
    expect(source, contains("'invoices': <Map<String, dynamic>>[]"));
    expect(source, contains("'components': <String>[]"));
    expect(source, contains('invoices: _studentAccounts'));
    expect(source, contains(".join(' + ')"));
  });

  test(
    'fee statements use real student identity and stay separate from receipts',
    () {
      final reports = File(
        'lib/features/finance/presentation/screens/principal_dashboard/principal_reports_v2.dart',
      ).readAsStringSync();
      final pdf = File('lib/core/services/pdf_service.dart').readAsStringSync();
      final models = File(
        'lib/features/finance/presentation/screens/fee_shared/fee_models.dart',
      ).readAsStringSync();

      expect(reports, contains('FeeDocumentKind.accountStatement'));
      expect(reports, contains('rollNo: studentIdentifier(student)'));
      expect(
        reports,
        isNot(contains("rollNo: textValue(inv['invoice_number']")),
      );
      expect(reports, isNot(contains("parentName: 'Individual Report'")));
      expect(reports, isNot(contains("paymentMode: 'Fee Statement'")));
      expect(pdf, contains('enum FeeDocumentKind'));
      expect(pdf, contains("'FEE ACCOUNT STATEMENT'"));
      expect(pdf, contains("'FEE PAYMENT RECEIPT'"));
      expect(pdf, contains("if (!isAccountStatement) ...["));
      expect(models, contains('String studentIdentifier('));
      expect(
        models,
        contains("student['student_id_number'] ?? student['admission_number']"),
      );
    },
  );

  test(
    'invoice reads enrich student class data without widening parent scope',
    () {
      final handler = File(
        'supabase/functions/api/handlers/fees.ts',
      ).readAsStringSync();

      expect(handler, contains('current_section:sections(id, section_name'));
      expect(handler, contains('grade:grades(id, grade_name)'));
      expect(handler, contains('parentCanAccessStudent('));
      expect(
        handler,
        contains('parent invoice access requires a linked student'),
      );
    },
  );

  test(
    'parent offers one statement and receipts only for linked finalized payments',
    () {
      final hub = File(
        'lib/features/finance/presentation/screens/parent_hub/parent_fee_hub.dart',
      ).readAsStringSync();
      final history = File(
        'lib/features/finance/presentation/screens/parent_hub/parent_payment_history_v2.dart',
      ).readAsStringSync();
      final receipt = File(
        'lib/features/finance/presentation/screens/parent_hub/parent_receipt_view_v2.dart',
      ).readAsStringSync();

      expect(hub, contains("label: const Text('Statement')"));
      expect(hub, contains('Future<void> _openFeeStatement()'));
      expect(hub, contains('FeeDocumentKind.accountStatement'));
      expect(hub, contains('bool _hasLinkedReceipt('));
      expect(hub, isNot(contains("'receipt_number': fee['invoiceNumber']")));
      expect(
        history,
        contains('final hasLinkedReceipt = _hasLinkedReceipt(item)'),
      );
      expect(
        receipt,
        contains('Receipt is not available for this finalized payment yet.'),
      );
      expect(receipt, contains("'fee_component'"));
      expect(receipt, isNot(contains('// fallback load')));
    },
  );

  test('principal collection back flow is handled before route pop', () {
    final collector = File(
      'lib/features/finance/presentation/screens/principal_dashboard/principal_collect_fee.dart',
    ).readAsStringSync();

    expect(collector, contains('PopScope('));
    expect(collector, contains('void _handleWizardBack()'));
    expect(collector, contains('if (_selectedInvoiceId.isNotEmpty)'));
    expect(collector, contains('if (_selectedStudentId.isNotEmpty)'));
    expect(collector, contains('if (_selectedSectionLabel.isNotEmpty)'));
  });

  test('parent history shows finalized payments once and hides proof attempts', () {
    final history = File(
      'lib/features/finance/presentation/screens/parent_hub/parent_payment_history_v2.dart',
    ).readAsStringSync();
    final hub = File(
      'lib/features/finance/presentation/screens/parent_hub/parent_fee_hub.dart',
    ).readAsStringSync();

    expect(history, contains('completedPaymentIds'));
    expect(history, contains('completedPaymentSignatures'));
    expect(
      history,
      contains("{'approved', 'completed', 'paid'}.contains(requestStatus)"),
    );
    expect(history, contains('Approved payments and their receipts'));
    expect(hub, contains("requestStatus != 'clarification_required'"));
  });

  test('fee operations uses compact adaptive grids and tinted actions', () {
    final source = File(
      'lib/features/finance/presentation/screens/principal_dashboard/principal_fee_dashboard.dart',
    ).readAsStringSync();

    expect(source, contains('constraints.maxWidth >= 720 ? 4 : 2'));
    expect(source, contains('mainAxisExtent: 88'));
    expect(source, contains('constraints.maxWidth >= 720 ? 3 : 2'));
    expect(source, contains('mainAxisExtent: 58'));
    expect(source, contains('Color(0xFFF5F9FF)'));
    expect(source, contains('Color(0xFFFFF9F3)'));
    expect(source, isNot(contains("label: 'Generate Invoices'")));
  });

  test('receipt authorization signature is private and optional', () {
    final migration = File(
      'supabase/migrations/20260717034500_add_school_authorized_signature.sql',
    ).readAsStringSync();
    final schoolsHandler = File(
      'supabase/functions/api/handlers/schools.ts',
    ).readAsStringSync();
    final schoolProfile = File(
      'lib/features/profile/presentation/screens/school_profile_screen/school_profile_screen.dart',
    ).readAsStringSync();
    final pdf = File('lib/core/services/pdf_service.dart').readAsStringSync();

    expect(migration, contains('authorized_signature_path'));
    expect(migration, contains("'school-signatures'"));
    expect(migration, contains('false'));
    expect(schoolsHandler, contains('createSignedUrl(path, 3600)'));
    expect(schoolsHandler, contains('isSchoolAdministrator'));
    expect(schoolProfile, contains('uploadCurrentSchoolSignature'));
    expect(schoolProfile, contains('Receipt Authorization'));
    expect(pdf, contains('Uint8List? authorizedSignature'));
    expect(pdf, contains('does not require a physical signature'));
  });

  test('principal concessions adjust invoice balances through a real workflow', () {
    final migration = File(
      'supabase/migrations/20260717035649_fee_concession_workflow.sql',
    ).readAsStringSync();
    final handler = File(
      'supabase/functions/api/handlers/fees.ts',
    ).readAsStringSync();
    final dashboard = File(
      'lib/features/finance/presentation/screens/principal_dashboard/principal_fee_dashboard.dart',
    ).readAsStringSync();
    final workspace = File(
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
    ).readAsStringSync();
    final models = File(
      'lib/features/finance/presentation/screens/fee_shared/fee_models.dart',
    ).readAsStringSync();

    expect(migration, contains('sync_fee_concession_invoice'));
    expect(migration, contains('discount_amount = v_discount'));
    expect(migration, contains('Concession exceeds the outstanding'));
    expect(handler, contains('concession must not exceed the outstanding'));
    expect(handler, contains('method === "PATCH" || method === "PUT"'));
    expect(handler, contains('approved_by: user.id'));
    expect(
      handler,
      contains(
        'fee_structure:fee_structures(id, fee_category_id, category_id)',
      ),
    );
    expect(handler, contains('await attachFeeCategories('));
    expect(
      handler,
      isNot(
        contains(
          'fee_structure:fee_structures(id, fee_category:fee_categories(name))',
        ),
      ),
    );
    expect(dashboard, contains('AppRoutes.principalFeeConcessions'));
    expect(workspace, contains('Assign concession'));
    expect(
      workspace,
      contains('Concession applied and student balance updated'),
    );
    expect(workspace, contains('Concession removed and balance restored'));
    expect(models, contains("row['net_amount'] ?? row['total_amount']"));
  });
}
