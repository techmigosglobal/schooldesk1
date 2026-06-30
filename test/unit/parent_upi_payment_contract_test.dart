import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Parent UPI payment proof contract', () {
    test('parent payment form is UPI proof driven and not Razorpay driven', () {
      final form = File(
        'lib/features/finance/presentation/screens/parent_fees_screen/parent_payment_request_form_screen.dart',
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
      expect(form, contains('qr_flutter'));
      expect(form, contains('_proofPath'));
      expect(formAndApi, contains('submitFeePaymentProof'));
      expect(formAndApi, contains('createFeePaymentIntent'));
      expect(formAndApi, contains('/fees/payments/intent'));
      expect(formAndApi, contains('/fees/payments/submit'));
      expect(formAndApi, contains('payment_request_id'));
      expect(formAndApi, contains('request_reference'));
      expect(formAndApi, contains('resubmitFeePaymentProof'));
      expect(formAndApi, contains(r'/fees/payments/$id/resubmit'));
      expect(formAndApi, contains('selected_months'));
      expect(formAndApi, contains('selected_terms'));
      expect(form, contains('Monthly'));
      expect(form, contains('Term-wise'));
      expect(form, contains('Book & Kit'));
      expect(models, contains('proof_url'));
      expect(form, contains('Fees will be updated in 12-24 hrs'));
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
        expect(screen, contains('deleteFeeStructure(id)'));

        expect(dto, contains('ReplaceExisting'));
        expect(handler, contains('ReplaceExisting'));
        expect(handler, contains('Delete(&models.FeeStructure{})'));
        expect(handler, contains('replace_existing'));
      },
    );

    test('fee structure delete preserves generated invoices and payments', () {
      final api = File(
        'lib/core/network/api_modules/fees_api.dart',
      ).readAsStringSync();
      final adminFees = File(
        'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
      ).readAsStringSync();
      final monitoring = File(
        'lib/features/finance/presentation/screens/fee_monitoring_screen/fee_monitoring_screen.dart',
      ).readAsStringSync();

      expect(api, isNot(contains('remove_pending')));
      expect(api, isNot(contains('removePending')));
      expect(
        adminFees,
        contains('existing invoices and payments are not changed'),
      );
      expect(
        monitoring,
        contains('existing invoices and payments are not changed'),
      );
      expect(adminFees, isNot(contains('Remove from unpaid invoices')));
      expect(
        monitoring,
        isNot(contains('Remove from unpaid student invoices')),
      );
      expect(adminFees, contains('deleteFeeStructure(id)'));
      expect(monitoring, contains('_deleteFeeStructureBundle(bundle)'));
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
