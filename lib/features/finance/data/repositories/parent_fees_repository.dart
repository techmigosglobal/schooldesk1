// lib/features/finance/data/repositories/parent_fees_repository.dart

import 'package:fpdart/fpdart.dart';
import 'package:schooldesk1/core/error/failure.dart';
import '../datasources/parent_fees_remote_datasource.dart';
import '../models/payment_models.dart';

abstract class ParentFeesRepository {
  Future<Either<Failure, List<StudentInfo>>> getMyStudents();
  Future<Either<Failure, FeeSummary>> getStudentFeeSummary(String studentId);
  Future<Either<Failure, CreatePaymentOrderResponse>> createPaymentOrder(
    String studentId,
    List<String> invoiceIds,
  );
  Future<Either<Failure, VerifyPaymentResponse>> verifyPayment(
    VerifyPaymentRequest request,
  );
  Future<Either<Failure, PaymentHistoryResponse>> getPaymentHistory({
    int page = 1,
    int pageSize = 10,
  });
  Future<Either<Failure, ReceiptDetails>> getReceipt(String receiptId);
}

class ParentFeesRepositoryImpl implements ParentFeesRepository {
  final ParentFeesRemoteDataSource remoteDataSource;

  ParentFeesRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<StudentInfo>>> getMyStudents() async {
    try {
      final students = await remoteDataSource.getMyStudents();
      return right(students);
    } on Exception catch (e) {
      return left(_handleException(e));
    }
  }

  @override
  Future<Either<Failure, FeeSummary>> getStudentFeeSummary(
      String studentId) async {
    try {
      final summary = await remoteDataSource.getStudentFeeSummary(studentId);
      return right(summary);
    } on Exception catch (e) {
      return left(_handleException(e));
    }
  }

  @override
  Future<Either<Failure, CreatePaymentOrderResponse>> createPaymentOrder(
    String studentId,
    List<String> invoiceIds,
  ) async {
    try {
      final response =
          await remoteDataSource.createPaymentOrder(studentId, invoiceIds);
      return right(response);
    } on Exception catch (e) {
      return left(_handleException(e));
    }
  }

  @override
  Future<Either<Failure, VerifyPaymentResponse>> verifyPayment(
    VerifyPaymentRequest request,
  ) async {
    try {
      final response = await remoteDataSource.verifyPayment(request);
      return right(response);
    } on Exception catch (e) {
      return left(_handleException(e));
    }
  }

  @override
  Future<Either<Failure, PaymentHistoryResponse>> getPaymentHistory({
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final history = await remoteDataSource.getPaymentHistory(
        page: page,
        pageSize: pageSize,
      );
      return right(history);
    } on Exception catch (e) {
      return left(_handleException(e));
    }
  }

  @override
  Future<Either<Failure, ReceiptDetails>> getReceipt(String receiptId) async {
    try {
      final receipt = await remoteDataSource.getReceipt(receiptId);
      return right(receipt);
    } on Exception catch (e) {
      return left(_handleException(e));
    }
  }

  Failure _handleException(Exception e) {
    if (e is Exception) {
      final message = e.toString().replaceAll('Exception: ', '');
      
      if (message.contains('401') || message.contains('Unauthorized')) {
        return UnauthorizedFailure(message);
      } else if (message.contains('404') || message.contains('not found')) {
        return NotFoundFailure(message);
      } else if (message.contains('400') || message.contains('validation')) {
        return ValidationFailure(message);
      } else if (message.contains('Network') || message.contains('timeout')) {
        return NetworkFailure(message);
      } else if (message.contains('Server') || message.contains('500')) {
        return ServerFailure(message);
      }
    }
    
    return GeneralFailure(e.toString());
  }
}
