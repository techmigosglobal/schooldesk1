import 'package:schooldesk1/core/network/backend_api_client.dart';

abstract class ParentFeesRemoteDataSource {
  Future<Map<String, dynamic>> getPaymentConfig();
  Future<List<Map<String, dynamic>>> getPaymentHistory();
  Future<Map<String, dynamic>> getReceipt(String receiptId);
}

class ParentFeesRemoteDataSourceImpl implements ParentFeesRemoteDataSource {
  ParentFeesRemoteDataSourceImpl();

  @override
  Future<Map<String, dynamic>> getPaymentConfig() async {
    final response = await BackendApiClient.instance.dio.get(
      '/fees/payment-config',
    );
    return Map<String, dynamic>.from(response.data['data'] ?? {});
  }

  @override
  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final children = await BackendApiClient.instance.getMyStudents();
    final rows = <Map<String, dynamic>>[];
    for (final child in children) {
      final studentId = '${child['id'] ?? child['student_id'] ?? ''}'.trim();
      if (studentId.isEmpty) continue;
      final response = await BackendApiClient.instance.dio.get(
        '/fees/payments',
        queryParameters: {'student_id': studentId},
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      final payments = data['data'] is List ? data['data'] as List : const [];
      rows.addAll(payments.whereType<Map>().map(_paymentHistoryRow));
    }
    rows.sort(
      (a, b) => '${b['paid_at'] ?? ''}'.compareTo('${a['paid_at'] ?? ''}'),
    );
    return rows;
  }

  @override
  Future<Map<String, dynamic>> getReceipt(String receiptId) async {
    final payments = await getPaymentHistory();
    final match = payments.where((payment) {
      return '${payment['receipt_id'] ?? ''}' == receiptId ||
          '${payment['id'] ?? ''}' == receiptId;
    });
    if (match.isEmpty) {
      throw Exception('Receipt is not available for this transaction yet.');
    }
    return match.first;
  }

  Map<String, dynamic> _paymentHistoryRow(Map<dynamic, dynamic> row) {
    final payment = Map<String, dynamic>.from(row);
    final receipts = payment['fee_receipts'] is List
        ? payment['fee_receipts'] as List
        : const [];
    final receipt = receipts.whereType<Map>().isNotEmpty
        ? Map<String, dynamic>.from(receipts.whereType<Map>().first)
        : const <String, dynamic>{};
    final invoice = payment['invoice'] is Map
        ? Map<String, dynamic>.from(payment['invoice'] as Map)
        : const <String, dynamic>{};
    final student = payment['student'] is Map
        ? Map<String, dynamic>.from(payment['student'] as Map)
        : const <String, dynamic>{};
    return {
      ...payment,
      'receipt_id': receipt['id'] ?? payment['id'] ?? '',
      'receipt_no':
          receipt['receipt_number'] ??
          payment['receipt_number'] ??
          payment['reference_number'] ??
          payment['id'] ??
          '',
      'school_name': invoice['school_name'] ?? 'School',
      'payment_mode': payment['payment_method'] ?? payment['payment_mode'],
      'paid_at': payment['paid_at'] ?? receipt['issued_at'],
      'student_name':
          payment['student_name'] ??
          '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim(),
      'invoice_id': payment['invoice_id'] ?? invoice['id'],
      'invoice_number': invoice['invoice_number'] ?? payment['invoice_number'],
      'fee_type': invoice['fee_type'] ?? payment['fee_type'],
    };
  }
}
