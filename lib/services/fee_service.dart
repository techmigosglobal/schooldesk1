import '../models/fee_model.dart';
import 'api_service.dart';

class FeeService {
  FeeService({ApiService? api}) : _api = api ?? ApiService.instance;

  final ApiService _api;

  Future<List<FeeModel>> list() async {
    final response = await _api.get<Map<String, dynamic>>('/fees');
    final data = response.data?['data'] as List? ?? const [];
    return data
        .map((e) => FeeModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<FeeModel> assign(Map<String, dynamic> payload) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/fees/assign',
      data: payload,
    );
    return FeeModel.fromJson(
      Map<String, dynamic>.from(response.data!['data'] as Map),
    );
  }

  Future<void> pay(String feeId, Map<String, dynamic> payload) async {
    await _api.patch<Map<String, dynamic>>('/fees/$feeId/pay', data: payload);
  }

  Future<List<FeeModel>> byStudent(String studentId) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/fees/student/$studentId',
    );
    final data = response.data?['data'] as List? ?? const [];
    return data
        .map((e) => FeeModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<FeeModel>> overdue() async {
    final response = await _api.get<Map<String, dynamic>>('/fees/overdue');
    final data = response.data?['data'] as List? ?? const [];
    return data
        .map((e) => FeeModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> stats() async {
    final response = await _api.get<Map<String, dynamic>>('/fees/stats');
    return Map<String, dynamic>.from(response.data?['data'] as Map? ?? {});
  }

  Future<void> queueReminder({String? studentId, String? message}) async {
    await _api.post<Map<String, dynamic>>(
      '/fees/reminders',
      data: {
        if (studentId != null) 'student_id': studentId,
        if (message != null) 'message': message,
      },
    );
  }
}
