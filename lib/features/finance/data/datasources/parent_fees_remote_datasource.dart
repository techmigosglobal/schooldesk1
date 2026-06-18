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
