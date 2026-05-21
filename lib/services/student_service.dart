import '../models/attendance_model.dart';
import '../models/fee_model.dart';
import '../models/grade_model.dart';
import '../models/student_model.dart';
import 'api_service.dart';

class StudentService {
  StudentService({ApiService? api}) : _api = api ?? ApiService.instance;

  final ApiService _api;

  Future<List<StudentModel>> list({int page = 1, int limit = 20}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/students',
      queryParameters: {'page': page, 'limit': limit},
    );
    return _list(response.data).map(StudentModel.fromJson).toList();
  }

  Future<StudentModel> get(String id) async {
    final response = await _api.get<Map<String, dynamic>>('/students/$id');
    return StudentModel.fromJson(_data(response.data));
  }

  Future<StudentModel> create(StudentModel student) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/students',
      data: student.toJson(),
    );
    return StudentModel.fromJson(_data(response.data));
  }

  Future<StudentModel> update(String id, Map<String, dynamic> patch) async {
    final response = await _api.patch<Map<String, dynamic>>(
      '/students/$id',
      data: patch,
    );
    return StudentModel.fromJson(_data(response.data));
  }

  Future<void> delete(String id) => _api.delete('/students/$id');

  Future<List<AttendanceModel>> attendance(String id) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/students/$id/attendance',
    );
    return _list(response.data).map(AttendanceModel.fromJson).toList();
  }

  Future<List<GradeModel>> grades(String id) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/students/$id/grades',
    );
    return _list(response.data).map(GradeModel.fromJson).toList();
  }

  Future<List<FeeModel>> fees(String id) async {
    final response = await _api.get<Map<String, dynamic>>('/students/$id/fees');
    return _list(response.data).map(FeeModel.fromJson).toList();
  }
}

Map<String, dynamic> _data(Map<String, dynamic>? response) {
  return Map<String, dynamic>.from(response?['data'] as Map? ?? {});
}

List<Map<String, dynamic>> _list(Map<String, dynamic>? response) {
  final data = response?['data'];
  if (data is List) {
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return const [];
}
