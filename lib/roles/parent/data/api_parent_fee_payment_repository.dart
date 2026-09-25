import 'dart:typed_data';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/roles/parent/domain/parent_fee_payment_repository.dart';

class ApiParentFeePaymentRepository implements ParentFeePaymentRepository {
  ApiParentFeePaymentRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<List<Map<String, dynamic>>> loadChildren({int? refreshNonce}) {
    return _api.getMyStudents(refreshNonce: refreshNonce);
  }

  @override
  Future<List<Map<String, dynamic>>> loadStudentFees(
    String studentId, {
    int? refreshNonce,
  }) {
    return _api.getParentStudentFees(
      studentId,
      refreshNonce: refreshNonce,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadPaymentRequests({
    String? studentId,
  }) {
    return _api.getParentPaymentRequests(studentId: studentId);
  }

  @override
  Future<Map<String, dynamic>> loadReceiptPayload(String receiptId) {
    return _api.getFeeReceiptPayload(receiptId);
  }

  @override
  Future<Map<String, dynamic>> loadCurrentSchool() => _api.getCurrentSchool();

  @override
  Future<UserResponse> loadProfile() => _api.getProfile();

  @override
  Future<Map<String, dynamic>> loadPaymentConfig({
    required String invoiceId,
    int? refreshNonce,
  }) => _api.getPaymentConfig(
    invoiceId: invoiceId,
    refreshNonce: refreshNonce,
  );

  @override
  Future<Map<String, dynamic>> submitPaymentProof({
    required String invoiceId,
    required double amount,
    required String transactionRef,
    required String screenshotPath,
    required String screenshotName,
    Uint8List? screenshotBytes,
    String? screenshotMimeType,
    String remarks = '',
  }) => _api.submitParentPaymentRequestProof(
    invoiceId: invoiceId,
    amount: amount,
    transactionRef: transactionRef,
    screenshotPath: screenshotPath,
    screenshotName: screenshotName,
    screenshotBytes: screenshotBytes,
    screenshotMimeType: screenshotMimeType,
    remarks: remarks,
  );

  @override
  Future<Map<String, dynamic>> resubmitPaymentProof({
    required String id,
    required String transactionRef,
    required String screenshotPath,
    required String screenshotName,
    Uint8List? screenshotBytes,
    String? screenshotMimeType,
    String remarks = '',
  }) => _api.resubmitFeePaymentProof(
    id: id,
    transactionRef: transactionRef,
    screenshotPath: screenshotPath,
    screenshotName: screenshotName,
    screenshotBytes: screenshotBytes,
    screenshotMimeType: screenshotMimeType,
    remarks: remarks,
  );

  static ApiParentFeePaymentRepository get legacyDefault =>
      ApiParentFeePaymentRepository(BackendApiClient.instance);
}
