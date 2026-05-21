import '../models/grade_model.dart';
import 'api_service.dart';

class GradeService {
  GradeService({ApiService? api}) : _api = api ?? ApiService.instance;

  final ApiService _api;

  Future<void> bulk(List<Map<String, dynamic>> grades, {String? scheduleId}) {
    return _api.post<Map<String, dynamic>>(
      '/grades/bulk',
      data: {
        if (scheduleId != null) 'schedule_id': scheduleId,
        'grades': grades,
      },
    );
  }

  Future<List<GradeModel>> byStudent(String studentId) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/grades/student/$studentId',
    );
    final data = response.data?['data'] as List? ?? const [];
    return data
        .map((e) => GradeModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<GradeModel>> byClass(String classId, {String? examType}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/grades/class/$classId',
      queryParameters: {if (examType != null) 'examType': examType},
    );
    final data = response.data?['data'] as List? ?? const [];
    return data
        .map((e) => GradeModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> update(String id, Map<String, dynamic> payload) {
    return _api.patch<Map<String, dynamic>>('/grades/$id', data: payload);
  }
}
