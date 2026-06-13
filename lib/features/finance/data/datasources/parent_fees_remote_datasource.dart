import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/features/finance/data/models/payment_models.dart';

abstract class ParentFeesRemoteDataSource {
  Future<CreateRazorpayOrderResponse> createRazorpayOrder(
    CreateRazorpayOrderRequest request,
  );
  Future<Map<String, dynamic>> verifyRazorpayPayment(
    VerifyRazorpayPaymentRequest request,
  );
  Future<Map<String, dynamic>> getPaymentConfig();
  Future<List<Map<String, dynamic>>> getPaymentHistory();
  Future<Map<String, dynamic>> getReceipt(String receiptId);
}

class ParentFeesRemoteDataSourceImpl implements ParentFeesRemoteDataSource {
  ParentFeesRemoteDataSourceImpl();

  @override
  Future<CreateRazorpayOrderResponse> createRazorpayOrder(
    CreateRazorpayOrderRequest request,
  ) async {
    final response = await BackendApiClient.instance.dio.post(
      '/parents/fees/payment-orders',
      data: request.toJson(),
    );
    return CreateRazorpayOrderResponse.fromJson(response.data['data']);
  }

  @override
  Future<Map<String, dynamic>> verifyRazorpayPayment(
    VerifyRazorpayPaymentRequest request,
  ) async {
    final response = await BackendApiClient.instance.dio.post(
      '/parents/fees/verify-payment',
      data: request.toJson(),
    );
    return Map<String, dynamic>.from(response.data['data'] ?? {});
  }

  @override
  Future<Map<String, dynamic>> getPaymentConfig() async {
    final response = await BackendApiClient.instance.dio.get(
      '/fees/payment-config',
    );
    return Map<String, dynamic>.from(response.data['data'] ?? {});
  }

  @override
  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final response = await BackendApiClient.instance.dio.get(
      '/parents/fees/payments',
    );
    final data = Map<String, dynamic>.from(response.data['data'] ?? {});
    return (data['payments'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getReceipt(String receiptId) async {
    final response = await BackendApiClient.instance.dio.get(
      '/parents/fees/receipts/$receiptId',
    );
    return Map<String, dynamic>.from(response.data['data'] ?? {});
  }
}
