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

      expect(form, contains('Pay by UPI'));
      expect(form, contains('qr_flutter'));
      expect(form, contains('proofUrl'));
      expect(models, contains('proof_url'));
      expect(form, contains('Fees will be updated in 12-24 hrs'));
      expect(form, contains('UTR'));
      expect(form, contains('/uploads'));
      expect(form, contains('getPaymentConfig'));
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
