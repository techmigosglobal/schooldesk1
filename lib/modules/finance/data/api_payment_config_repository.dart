import 'dart:typed_data';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/finance/domain/payment_config_repository.dart';

class ApiPaymentConfigRepository implements PaymentConfigRepository {
  ApiPaymentConfigRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Map<String, dynamic>> loadConfig({
    String invoiceId = '',
    int? refreshNonce,
  }) => _api.getPaymentConfig(
    invoiceId: invoiceId,
    refreshNonce: refreshNonce,
  );

  @override
  Future<Map<String, dynamic>> updateConfig({
    required String upiId,
    required String payeeName,
    required String qrNote,
    required String qrImageUrl,
  }) => _api.updatePaymentConfig(
    upiId: upiId,
    payeeName: payeeName,
    qrNote: qrNote,
    qrImageUrl: qrImageUrl,
  );

  @override
  Future<Map<String, dynamic>> uploadQr({
    required String path,
    required String fileName,
    Uint8List? fileBytes,
    String? mimeType,
  }) => _api.uploadPaymentQr(
    path: path,
    fileName: fileName,
    fileBytes: fileBytes,
    mimeType: mimeType,
  );

  static ApiPaymentConfigRepository get legacyDefault =>
      ApiPaymentConfigRepository(BackendApiClient.instance);
}
