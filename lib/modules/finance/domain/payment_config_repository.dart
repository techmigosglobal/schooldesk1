import 'dart:typed_data';

abstract interface class PaymentConfigRepository {
  Future<Map<String, dynamic>> loadConfig({
    String invoiceId = '',
    int? refreshNonce,
  });

  Future<Map<String, dynamic>> updateConfig({
    required String upiId,
    required String payeeName,
    required String qrNote,
    required String qrImageUrl,
  });

  Future<Map<String, dynamic>> uploadQr({
    required String path,
    required String fileName,
    Uint8List? fileBytes,
    String? mimeType,
  });
}
