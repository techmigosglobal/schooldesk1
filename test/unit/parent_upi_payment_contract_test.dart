import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Parent UPI payment proof contract', () {
    test('parent payment form is UPI proof driven and not Razorpay driven', () {
      final form = File(
        'lib/features/finance/presentation/screens/parent_fees_screen/parent_payment_request_form_screen.dart',
      ).readAsStringSync();
      final parentFees = File(
        'lib/features/finance/presentation/screens/parent_fees_screen/parent_fees_screen.dart',
      ).readAsStringSync();
      final parentDashboard = File(
        'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
      ).readAsStringSync();
      final principalApi = File(
        'lib/core/network/api_modules/principal_api.dart',
      ).readAsStringSync();
      final cacheInterceptor = File(
        'lib/core/network/api_modules/client_interceptors.dart',
      ).readAsStringSync();
      final datasource = File(
        'lib/features/finance/data/datasources/parent_fees_remote_datasource.dart',
      ).readAsStringSync();
      final models = File(
        'lib/features/shared/data/models/backend_models.dart',
      ).readAsStringSync();
      final feePaymentsApi = File(
        'lib/core/network/api_modules/fee_payments_api.dart',
      ).readAsStringSync();
      final formAndApi = '$form\n$feePaymentsApi';

      expect(form, contains('Pay by UPI'));
      expect(
        form,
        contains("static const List<String> _paymentModes = ['upi']"),
      );
      expect(form, isNot(contains("'cash'")));
      expect(form, isNot(contains("'bank_transfer'")));
      expect(form, contains('qr_flutter'));
      expect(form, contains('_proofPath'));
      expect(form, contains('PopScope('));
      expect(form, contains('cache_key'));
      expect(form, contains("request['proof_url']"));
      expect(formAndApi, contains('submitFeePaymentProof'));
      expect(formAndApi, contains('createFeePaymentIntent'));
      expect(formAndApi, contains('/fees/payments/intent'));
      expect(formAndApi, contains('/fees/payments/submit'));
      expect(formAndApi, contains('payment_request_id'));
      expect(formAndApi, contains('request_reference'));
      expect(formAndApi, contains('resubmitFeePaymentProof'));
      expect(formAndApi, contains(r'/fees/payments/$id/resubmit'));
      expect(formAndApi, contains('selected_months'));
      expect(formAndApi, contains('selected_month_names'));
      expect(formAndApi, contains('selected_terms'));
      expect(form, contains('Monthly'));
      expect(form, contains('Term-wise'));
      expect(form, contains('FilterChip'));
      expect(form, contains('Selected months:'));
      expect(form, contains('Submit payment proof?'));
      expect(form, contains('Book & Kit'));
      expect(models, contains('proof_url'));
      expect(
        form,
        contains(
          'Your payment proof will stay pending until the principal verifies it.',
        ),
      );
      expect(
        form,
        contains(
          'Your payment proof will stay pending until the principal verifies it.',
        ),
      );
      expect(form, contains('UTR'));
      expect(form, contains('Confirm Payment'));
      expect(form, contains('Pay Now'));
      expect(form, contains('Submit Payment for Verification'));
      expect(form, contains('LaunchMode.externalApplication'));
      expect(form, contains('_paymentIntent'));
      expect(form, contains('_intentReference'));
      expect(feePaymentsApi, contains('screenshot'));
      expect(form, contains('getPaymentConfig'));
      expect(form, contains(r'Payee: $_payeeName'));
      expect(form, contains("_text(_paymentConfig['qr_note'])"));
      expect(form, contains('No school UPI QR is configured yet.'));
      expect(formAndApi, contains('refreshNonce'));
      expect(formAndApi, contains("'updated_at'"));
      expect(
        cacheInterceptor,
        isNot(contains("clean.contains('/fees/payment-config')")),
      );
      expect(principalApi, contains('forceRefresh'));
      expect(parentFees, contains('WidgetsBindingObserver'));
      expect(parentFees, contains('Timer.periodic'));
      expect(parentFees, contains('_buildWorkflowActionCard'));
      expect(parentFees, contains('View Request Status'));
      expect(parentFees, contains('Resubmit Now'));
      expect(parentFees, contains('Pay now with UPI'));
      expect(parentFees, contains('Expanded('));
      expect(parentFees, contains('Flexible('));
      expect(parentFees, contains('textAlign: TextAlign.end'));
      expect(parentFees, contains('maxLines: 2'));
      expect(parentDashboard, contains('WidgetsBindingObserver'));
      expect(parentDashboard, contains('Timer.periodic'));
      expect(parentDashboard, contains('Fees & Status'));
      expect(form, isNot(contains('Razorpay')));
      expect(datasource, isNot(contains('Razorpay')));
    });

    test('backend exposes UPI config and payment proof fields', () {
      final handler = File(
        'school-backend/internal/handlers/fee.go',
      ).readAsStringSync();
      final model = File(
        'school-backend/internal/models/fee.go',
      ).readAsStringSync();
      final routes = File(
        'school-backend/internal/routes/routes.go',
      ).readAsStringSync();

      expect(handler, contains('"upi_enabled"'));
      expect(handler, contains('"upi_id"'));
      expect(handler, contains('"payee_name"'));
      expect(handler, contains('"qr_image_url"'));
      expect(handler, contains('"updated_at"'));
      expect(handler, contains('UpdatePaymentConfig'));
      expect(handler, contains('UploadPaymentQR'));
      expect(handler, contains('ProofURL'));
      expect(handler, contains('"payment_proofs"'));
      expect(
        handler,
        contains('proof_url is required for UPI payment requests'),
      );
      expect(model, contains('SchoolPaymentSetting'));
      expect(model, contains('ProofURL'));
      expect(routes, contains('/payment-config'));
      expect(routes, contains('/payment-config/qr'));
      expect(
        routes,
        contains('RBACMiddleware("Teacher", "Principal", "Parent")'),
      );
      expect(routes, isNot(contains('razorpay')));
    });

    test('principal proof review supports clarification and in-app preview', () {
      final decisionScreen = File(
        'lib/features/finance/presentation/screens/admin_fees_screen/admin_payment_request_decision_screen.dart',
      ).readAsStringSync();
      final requestsScreen = File(
        'lib/features/finance/presentation/screens/admin_fees_screen/admin_payment_requests_screen.dart',
      ).readAsStringSync();
      final monitoring = File(
        'lib/features/finance/presentation/screens/fee_monitoring_screen/fee_monitoring_screen.dart',
      ).readAsStringSync();

      expect(decisionScreen, contains('Request Clarification'));
      expect(decisionScreen, contains('clarification_required'));
      expect(decisionScreen, contains('Enter a clarification note.'));
      expect(decisionScreen, contains('_showProofDocumentPreview'));
      expect(
        decisionScreen,
        isNot(contains("package:url_launcher/url_launcher.dart")),
      );
      expect(decisionScreen, isNot(contains('launchUrl(')));
      expect(requestsScreen, contains('Clarification'));
      expect(requestsScreen, contains('pending_verification'));
      expect(monitoring, contains('Find It Faster'));
      expect(monitoring, contains('Review Parent Requests'));
      expect(monitoring, contains('Manual Fee Update'));
      expect(monitoring, contains('Reports'));
    });

    test(
      'principal can replace or delete fee structures without interval controls',
      () {
        final form = File(
          'lib/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart',
        ).readAsStringSync();
        final screen = File(
          'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
        ).readAsStringSync();
        final dto = File(
          'school-backend/internal/models/dto.go',
        ).readAsStringSync();
        final handler = File(
          'school-backend/internal/handlers/fee.go',
        ).readAsStringSync();
        final api = File(
          'lib/core/network/api_modules/fees_api.dart',
        ).readAsStringSync();

        expect(form, contains('Replace existing class/year fee structure'));
        expect(form, contains('_confirmReplaceExisting'));
        expect(api, contains('replace_existing'));
        expect(form, isNot(contains('Per installment')));
        expect(form, isNot(contains('Installments parents can pay')));

        expect(screen, contains('_deleteFeeStructure'));
        expect(screen, contains('Delete fee component'));
        expect(screen, contains('deleteFeeStructure('));
        expect(screen, contains('removePending: true'));

        expect(dto, contains('ReplaceExisting'));
        expect(handler, contains('ReplaceExisting'));
        expect(handler, contains('Delete(&models.FeeStructure{})'));
        expect(handler, contains('replace_existing'));
      },
    );

    test('fee structure delete clears unpaid fee rows but keeps paid history', () {
      final api = File(
        'lib/core/network/api_modules/fees_api.dart',
      ).readAsStringSync();
      final adminFees = File(
        'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
      ).readAsStringSync();
      final monitoring = File(
        'lib/features/finance/presentation/screens/fee_monitoring_screen/fee_monitoring_screen.dart',
      ).readAsStringSync();

      expect(api, contains('remove_pending'));
      expect(api, contains('removePending = true'));
      expect(
        adminFees,
        contains(
          'clears it from unpaid student invoices and pending parent requests',
        ),
      );
      expect(
        monitoring,
        contains(
          'removes it from unpaid student invoices and pending parent requests',
        ),
      );
      expect(adminFees, contains('deleteFeeStructure('));
      expect(adminFees, contains('removePending: true'));
      expect(monitoring, contains('_deleteFeeStructureBundle(bundle)'));
      expect(
        monitoring,
        contains('deleteFeeStructure(structureId, removePending: true)'),
      );
    });

    test('class hub fee save syncs unpaid invoices for parent and student views', () {
      final classHub = File(
        'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
      ).readAsStringSync();
      final form = File(
        'lib/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart',
      ).readAsStringSync();
      final monitoring = File(
        'lib/features/finance/presentation/screens/fee_monitoring_screen/fee_monitoring_screen.dart',
      ).readAsStringSync();

      expect(classHub, contains('final structureIdsToSync = <String>{};'));
      expect(classHub, contains('applyFeeInvoiceSync('));
      expect(classHub, contains('includePartiallyPaid: true'));
      expect(
        classHub,
        contains(
          'final created = await BackendApiClient.instance.createFeeStructure(',
        ),
      );
      expect(
        classHub,
        contains('structureIdsToSync.add(component.structureId)'),
      );
      expect(
        classHub,
        contains("final createdId = _classText(created['id']);"),
      );
      expect(
        form,
        contains(
          'final created = await BackendApiClient.instance.createFeeStructure(',
        ),
      );
      expect(form, contains("final createdId = _textValue(created['id']);"));
      expect(
        form,
        contains('await BackendApiClient.instance.applyFeeInvoiceSync('),
      );
      expect(monitoring, contains('final structureIdsToSync = <String>{};'));
      expect(monitoring, contains('await api.applyFeeInvoiceSync('));
    });

    test('parent payment flow presents fee item intervals', () {
      final parentFees = File(
        'lib/features/finance/presentation/screens/parent_fees_screen/parent_fees_screen.dart',
      ).readAsStringSync();
      final paymentSelection = File(
        'lib/features/finance/presentation/screens/parent_payment_screens/parent_payment_selection_screen.dart',
      ).readAsStringSync();
      final paymentForm = File(
        'lib/features/finance/presentation/screens/parent_fees_screen/parent_payment_request_form_screen.dart',
      ).readAsStringSync();

      expect(parentFees, contains('Book & Kit Fee'));
      expect(parentFees, contains('Tuition Fee'));
      expect(parentFees, contains('monthly_amount'));
      expect(parentFees, contains('term_amount'));
      expect(parentFees, contains('Pay fee'));
      expect(paymentSelection, contains('Select installment'));
      expect(paymentSelection, contains('installment'));
      expect(paymentForm, contains('Selected fee'));
      expect(paymentForm, contains('Monthly'));
      expect(paymentForm, contains('Term-wise'));
      expect(paymentForm, contains('Book & Kit'));
    });

    test('principal monitoring setup does not expose split decisions', () {
      final monitoring = File(
        'lib/features/finance/presentation/screens/fee_monitoring_screen/fee_monitoring_screen.dart',
      ).readAsStringSync();

      expect(monitoring, isNot(contains('Installment method')));
      expect(monitoring, isNot(contains('Monthly Payments')));
      expect(monitoring, contains('Book & Kit Fee'));
      expect(monitoring, contains('Tuition Fee'));
    });

    test(
      'Razorpay gateway code is removed from active app and backend config',
      () {
        final pubspec = File('pubspec.yaml').readAsStringSync();
        final backendMod = File('school-backend/go.mod').readAsStringSync();
        final env = File('school-backend/.env.example').readAsStringSync();

        expect(pubspec.toLowerCase(), isNot(contains('razorpay')));
        expect(backendMod.toLowerCase(), isNot(contains('razorpay')));
        expect(env.toLowerCase(), isNot(contains('razorpay')));
      },
    );
  });
}
