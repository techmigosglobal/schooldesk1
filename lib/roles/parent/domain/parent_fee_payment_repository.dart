import 'dart:typed_data';

import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class ParentFeePaymentRepository {
  Future<List<Map<String, dynamic>>> loadChildren({int? refreshNonce});

  Future<List<Map<String, dynamic>>> loadStudentFees(
    String studentId, {
    int? refreshNonce,
  });

  Future<List<Map<String, dynamic>>> loadPaymentRequests({
    String? studentId,
  });

  Future<Map<String, dynamic>> loadReceiptPayload(String receiptId);

  Future<Map<String, dynamic>> loadCurrentSchool();

  Future<UserResponse> loadProfile();

  Future<Map<String, dynamic>> loadPaymentConfig({
    required String invoiceId,
    int? refreshNonce,
  });

  Future<Map<String, dynamic>> submitPaymentProof({
    required String invoiceId,
    required double amount,
    required String transactionRef,
    required String screenshotPath,
    required String screenshotName,
    Uint8List? screenshotBytes,
    String? screenshotMimeType,
    String remarks = '',
  });

  Future<Map<String, dynamic>> resubmitPaymentProof({
    required String id,
    required String transactionRef,
    required String screenshotPath,
    required String screenshotName,
    Uint8List? screenshotBytes,
    String? screenshotMimeType,
    String remarks = '',
  });
}
