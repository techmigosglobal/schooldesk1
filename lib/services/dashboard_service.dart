import 'api_service.dart';

class DashboardService {
  DashboardService({ApiService? api}) : _api = api ?? ApiService.instance;

  final ApiService _api;

  Future<Map<String, dynamic>> load(String role) async {
    final response = await _api.get<Map<String, dynamic>>('/dashboard/$role');
    return Map<String, dynamic>.from(response.data?['data'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> admin() => load('admin');

  Future<Map<String, dynamic>> teacher() => load('teacher');

  Future<Map<String, dynamic>> student() => load('student');
}
