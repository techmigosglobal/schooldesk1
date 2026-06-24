import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_api_sources.dart';
import 'backend_route_sources.dart';

void main() {
  test('principal fees module uses direct ownership language and APIs', () {
    final fees = File(
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
    ).readAsStringSync();
    final forms = File(
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart',
    ).readAsStringSync();
    final paymentDecision = File(
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_payment_request_decision_screen.dart',
    ).readAsStringSync();
    final combined = '$fees\n$forms\n$paymentDecision';

    expect(combined, contains('Create Fee Structure'));
    expect(combined, contains('Save Structure'));
    expect(combined, contains('Generate Invoices'));
    expect(combined, contains('Record Payment'));
    expect(combined, contains('Approve Payment'));
    expect(combined, contains('Reject Payment'));
    expect(combined, contains('All sections'));
    expect(combined, contains('section_id'));
    expect(combined, isNot(contains('Prepare Fee Structure Request')));
    expect(combined, isNot(contains('Submit Fee Structure for Approval')));
    expect(combined, isNot(contains('Submit Invoice Request')));
  });

  test('backend exposes audit-grade fee management contracts', () {
    final api = readBackendApiSources();
    final routes = readBackendRouteSources();
    final feeHandler = File(
      'school-backend/internal/handlers/fee.go',
    ).readAsStringSync();
    final feeModels = File(
      'school-backend/internal/models/fee.go',
    ).readAsStringSync();

    expect(routes, contains('fees.POST("/structures/rollover"'));
    expect(
      routes,
      contains('fees.POST("/structures/:id/invoice-sync/preview"'),
    );
    expect(routes, contains('fees.POST("/structures/:id/invoice-sync/apply"'));
    expect(routes, contains('fees.GET("/payment-configs"'));
    expect(routes, contains('fees.POST("/payment-configs"'));
    expect(routes, contains('fees.PUT("/payment-configs/:id"'));
    expect(routes, contains('fees.POST("/payment-configs/:id/qr"'));
    expect(
      routes,
      isNot(contains('NewFrontendRecordHandler("fees/concessions")')),
    );

    expect(api, contains('rolloverFeeStructures'));
    expect(api, contains('previewFeeInvoiceSync'));
    expect(api, contains('applyFeeInvoiceSync'));
    expect(api, contains('getPaymentConfigs'));
    expect(api, contains('createPaymentConfig'));
    expect(api, contains('updateScopedPaymentConfig'));
    expect(api, contains('uploadScopedPaymentQr'));

    expect(feeModels, contains('type ScopedPaymentSetting struct'));
    expect(feeModels, contains('PaymentConfigID'));
    expect(feeModels, contains('PaymentUPIID'));
    expect(feeModels, contains('PaymentQRImageURL'));
    expect(feeModels, contains('RequestedBy'));
    expect(feeModels, contains('DecidedBy'));
    expect(feeModels, contains('AdminRemarks'));

    expect(feeHandler, contains('func (h *FeeHandler) RolloverFeeStructures'));
    expect(feeHandler, contains('func (h *FeeHandler) PreviewFeeInvoiceSync'));
    expect(feeHandler, contains('func (h *FeeHandler) ApplyFeeInvoiceSync'));
    expect(
      feeHandler,
      contains('func (h *FeeHandler) GetScopedPaymentConfigs'),
    );
    expect(
      feeHandler,
      contains('func (h *FeeHandler) CreateScopedPaymentConfig'),
    );
    expect(feeHandler, contains('func (h *FeeHandler) DecideConcession'));
    expect(feeHandler, contains('resolvePaymentSettingForInvoice'));
    expect(feeHandler, isNot(contains('currentRole(c) == "admin"')));
    expect(feeHandler, isNot(contains('createPaymentDecisionApproval')));
  });
}
