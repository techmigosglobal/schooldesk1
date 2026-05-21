import 'api_service.dart';

class NoticeService {
  NoticeService({ApiService? api}) : _api = api ?? ApiService.instance;

  final ApiService _api;

  Future<List<Map<String, dynamic>>> list() async {
    final response = await _api.get<Map<String, dynamic>>('/notices');
    final data = response.data?['data'] as List? ?? const [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> payload) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/notices',
      data: payload,
    );
    return Map<String, dynamic>.from(response.data!['data'] as Map);
  }

  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _api.patch<Map<String, dynamic>>(
      '/notices/$id',
      data: payload,
    );
    return Map<String, dynamic>.from(response.data?['data'] as Map? ?? {});
  }

  Future<void> delete(String id) => _api.delete('/notices/$id');
}
