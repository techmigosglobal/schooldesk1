import '../entities/fee_record.dart';
import '../../../../core/utils/result.dart';

/// Abstract repository interface for fee operations.
abstract class FeeRepository {
  Future<Result<List<FeeRecord>>> getFeeRecords({
    String? studentId,
    String? className,
    String? status,
  });

  Future<Result<FeeRecord>> getFeeRecordById(String id);

  Future<Result<FeeRecord>> createFeeRecord(FeeRecord record);

  Future<Result<FeeRecord>> updateFeeRecord(FeeRecord record);

  Future<Result<FeeRecord>> recordPayment({
    required String feeRecordId,
    required double amount,
    required String paymentMode,
    String? remarks,
  });

  Future<Result<List<FeeRecord>>> getPendingDues({String? className});

  Future<Result<Map<String, double>>> getFeeCollectionSummary({
    required DateTime fromDate,
    required DateTime toDate,
  });
}
