import '../models/attendance_model.dart';
import 'api_service.dart';

class AttendanceService {
  AttendanceService({ApiService? api}) : _api = api ?? ApiService.instance;

  final ApiService _api;

  Future<void> mark({
    required String classId,
    required String date,
    required List<Map<String, dynamic>> attendance,
    String? subjectId,
    String? teacherId,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/attendance/mark',
      data: {
        'class_id': classId,
        'date': date,
        if (subjectId != null) 'subject_id': subjectId,
        if (teacherId != null) 'teacher_id': teacherId,
        'attendance': attendance,
      },
    );
  }

  Future<List<AttendanceModel>> byStudent(
    String studentId, {
    String? month,
    String? year,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/attendance/student/$studentId',
      queryParameters: {
        if (month != null) 'month': month,
        if (year != null) 'year': year,
      },
    );
    final data = response.data?['data'] as List? ?? const [];
    return data
        .map(
          (item) =>
              AttendanceModel.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<AttendanceModel>> byClass(String classId, {String? date}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/attendance/class/$classId',
      queryParameters: {if (date != null) 'date': date},
    );
    final data = response.data?['data'] as List? ?? const [];
    return data.expand((session) {
      final map = Map<String, dynamic>.from(session as Map);
      final rows = map['student_attendances'] as List? ?? const [];
      return rows.map(
        (row) => AttendanceModel.fromJson({
          ...Map<String, dynamic>.from(row as Map),
          'session': map,
        }),
      );
    }).toList();
  }

  Future<void> update(String id, {required String status, String? reason}) {
    return _api.patch<Map<String, dynamic>>(
      '/attendance/$id',
      data: {'status': status, if (reason != null) 'reason': reason},
    );
  }
}
