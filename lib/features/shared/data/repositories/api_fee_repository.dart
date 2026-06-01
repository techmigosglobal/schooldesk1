import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/features/shared/domain/entities/fee_record.dart';
import 'package:schooldesk1/features/shared/domain/repositories/fee_repository.dart';
import 'package:schooldesk1/features/shared/data/repositories/api_repository_utils.dart';

class ApiFeeRepository implements FeeRepository {
  ApiFeeRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<FeeRecord>>> getFeeRecords({
    String? studentId,
    String? className,
    String? status,
  }) {
    return guardApi(() async {
      final rows = await _api.getInvoices(studentId: studentId, status: status);
      return rows.map(_toFeeRecord).toList();
    });
  }

  @override
  Future<Result<FeeRecord>> getFeeRecordById(String id) {
    return guardApi(() async {
      final row = await _api.getRawMap('/fees/invoices/$id');
      return _toFeeRecord(row);
    });
  }

  @override
  Future<Result<FeeRecord>> createFeeRecord(FeeRecord record) {
    return guardApi(() async {
      final row = await _api.createRaw('/fees/invoices', {
        'student_id': record.studentId,
        'invoice_number': record.receiptNumber ?? '',
        'due_date': _dateString(record.dueDate),
        'total_amount': record.amount,
        'paid_amount': record.paidAmount,
        'balance': record.pendingAmount,
        'status': record.status.toLowerCase(),
      });
      return _toFeeRecord(row);
    });
  }

  @override
  Future<Result<FeeRecord>> updateFeeRecord(FeeRecord record) {
    return guardApi(() async {
      final row = await _api.updateRaw('/fees/invoices/${record.id}', {
        'due_date': _dateString(record.dueDate),
        'total_amount': record.amount,
        'paid_amount': record.paidAmount,
        'balance': record.pendingAmount,
        'status': record.status.toLowerCase(),
      });
      return _toFeeRecord(row);
    });
  }

  @override
  Future<Result<FeeRecord>> recordPayment({
    required String feeRecordId,
    required double amount,
    required String paymentMode,
    String? remarks,
  }) {
    return guardApi(() async {
      await _api.recordPayment(
        PaymentRequest(
          invoiceId: feeRecordId,
          receiptNumber: 'RCPT-${DateTime.now().millisecondsSinceEpoch}',
          amountPaid: amount,
          paymentDate: _dateString(DateTime.now()),
          paymentMode: paymentMode,
          transactionId: remarks,
        ),
      );
      final row = await _api.getRawMap('/fees/invoices/$feeRecordId');
      return _toFeeRecord(row);
    });
  }

  @override
  Future<Result<List<FeeRecord>>> getPendingDues({String? className}) {
    return getFeeRecords(status: 'pending');
  }

  @override
  Future<Result<Map<String, double>>> getFeeCollectionSummary({
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    return guardApi(() async {
      final rows = await _api.getInvoices();
      final records = rows.map(_toFeeRecord).toList();
      final collected = records.fold<double>(
        0,
        (sum, record) => sum + record.paidAmount,
      );
      final pending = records.fold<double>(
        0,
        (sum, record) => sum + record.pendingAmount,
      );
      return {'collected': collected, 'pending': pending};
    });
  }

  FeeRecord _toFeeRecord(Map<String, dynamic> row) {
    final student = _map(row['student']);
    final total = doubleValue(
      row['total_amount'] ?? row['net_amount'] ?? row['amount'],
    );
    final paid = doubleValue(row['paid_amount']);
    final dueDate = parseDate(row['due_date'], fallback: DateTime.now());
    return FeeRecord(
      id: textValue(row['id']),
      studentId: textValue(row['student_id'] ?? student['id']),
      studentName: textValue(
        row['student_name'] ??
            student['full_name'] ??
            [
              textValue(student['first_name']),
              textValue(student['last_name']),
            ].where((part) => part.isNotEmpty).join(' '),
      ),
      className: textValue(row['class'] ?? row['section_name']),
      feeType: textValue(row['fee_type'] ?? row['invoice_number'] ?? 'Fees'),
      amount: total,
      paidAmount: paid,
      dueDate: dueDate,
      paidDate: DateTime.tryParse(textValue(row['paid_date'])),
      status: textValue(row['status']).isEmpty
          ? 'pending'
          : textValue(row['status']),
      receiptNumber: textValue(row['invoice_number']),
      paymentMode: textValue(row['payment_mode']),
      remarks: textValue(row['remarks']),
    );
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String _dateString(DateTime value) =>
      value.toIso8601String().split('T').first;
}
