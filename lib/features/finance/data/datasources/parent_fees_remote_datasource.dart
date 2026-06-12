import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/features/finance/data/models/payment_models.dart';

abstract class ParentFeesRemoteDataSource {
  Future<CreateRazorpayOrderResponse> createRazorpayOrder(
      CreateRazorpayOrderRequest request);
  Future<void> verifyRazorpayPayment(VerifyRazorpayPaymentRequest request);
  Future<Map<String, dynamic>> getPaymentConfig();
}

class ParentFeesRemoteDataSourceImpl implements ParentFeesRemoteDataSource {
  ParentFeesRemoteDataSourceImpl();

  @override
  Future<CreateRazorpayOrderResponse> createRazorpayOrder(
      CreateRazorpayOrderRequest request) async {
    final response = await BackendApiClient.instance.dio.post(
      '/fees/razorpay/order',
      data: request.toJson(),
    );
    return CreateRazorpayOrderResponse.fromJson(response.data['data']);
  }

  @override
  Future<void> verifyRazorpayPayment(
      VerifyRazorpayPaymentRequest request) async {
    await BackendApiClient.instance.dio.post(
      '/fees/razorpay/verify',
      data: request.toJson(),
    );
  }

  @override
  Future<Map<String, dynamic>> getPaymentConfig() async {
    final response = await BackendApiClient.instance.dio.get(
      '/fees/payment-config',
    );
    return Map<String, dynamic>.from(response.data['data'] ?? {});
  }
}
