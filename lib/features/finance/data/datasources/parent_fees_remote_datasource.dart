// lib/features/finance/data/datasources/parent_fees_remote_datasource.dart

import 'package:dio/dio.dart';
import 'package:schooldesk1/core/network/api_modules/http_client.dart';
import '../models/payment_models.dart';

abstract class ParentFeesRemoteDataSource {
  Future<List<StudentInfo>> getMyStudents();
  Future<FeeSummary> getStudentFeeSummary(String studentId);
  Future<CreatePaymentOrderResponse> createPaymentOrder(
    String studentId,
    List<String> invoiceIds,
  );
  Future<VerifyPaymentResponse> verifyPayment(VerifyPaymentRequest request);
  Future<PaymentHistoryResponse> getPaymentHistory({
    int page = 1,
    int pageSize = 10,
  });
  Future<ReceiptDetails> getReceipt(String receiptId);
}

class ParentFeesRemoteDataSourceImpl implements ParentFeesRemoteDataSource {
  final HttpClient httpClient;

  ParentFeesRemoteDataSourceImpl({required this.httpClient});

  @override
  Future<List<StudentInfo>> getMyStudents() async {
    try {
      final response = await httpClient.get('/parents/me/students');
      final data = response.data as Map<String, dynamic>;
      final students = (data['data']['students'] as List)
          .map((item) => StudentInfo.fromJson(item as Map<String, dynamic>))
          .toList();
      return students;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<FeeSummary> getStudentFeeSummary(String studentId) async {
    try {
      final response =
          await httpClient.get('/parents/students/$studentId/fees/summary');
      final data = response.data as Map<String, dynamic>;
      return FeeSummary.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<CreatePaymentOrderResponse> createPaymentOrder(
    String studentId,
    List<String> invoiceIds,
  ) async {
    try {
      final response = await httpClient.post(
        '/parents/fees/payment-orders',
        data: {
          'student_id': studentId,
          'invoice_ids': invoiceIds,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return CreatePaymentOrderResponse.fromJson(
          data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<VerifyPaymentResponse> verifyPayment(
      VerifyPaymentRequest request) async {
    try {
      final response = await httpClient.post(
        '/parents/fees/verify-payment',
        data: {
          'payment_order_id': request.paymentOrderId,
          'razorpay_order_id': request.razorpayOrderId,
          'razorpay_payment_id': request.razorpayPaymentId,
          'razorpay_signature': request.razorpaySignature,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return VerifyPaymentResponse.fromJson(
          data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<PaymentHistoryResponse> getPaymentHistory({
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await httpClient.get(
        '/parents/fees/payments',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return PaymentHistoryResponse.fromJson(
          data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<ReceiptDetails> getReceipt(String receiptId) async {
    try {
      final response =
          await httpClient.get('/parents/fees/receipts/$receiptId');
      final data = response.data as Map<String, dynamic>;
      return ReceiptDetails.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.response?.data is Map<String, dynamic>) {
      final error = e.response!.data['error'] ?? 'An error occurred';
      return Exception(error);
    }
    return Exception(e.message ?? 'Network error');
  }
}
