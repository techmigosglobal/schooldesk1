import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/features/shared/domain/entities/student.dart';
import 'package:schooldesk1/features/shared/domain/repositories/student_repository.dart';
import 'package:schooldesk1/features/shared/data/repositories/api_repository_utils.dart';

class ApiStudentRepository implements StudentRepository {
  ApiStudentRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<Student>>> getStudents({
    String? className,
    String? section,
    String? searchQuery,
  }) {
    return guardApi(() async {
      final page = await _api.getStudents(
        sectionId: _sectionFilter(section),
        page: 1,
        pageSize: 500,
      );
      final query = textValue(searchQuery).toLowerCase();
      return page.data
          .where((student) {
            if (query.isEmpty) return true;
            final haystack = [
              student.fullName,
              student.admissionNumber,
              student.studentCode,
            ].join(' ').toLowerCase();
            return haystack.contains(query);
          })
          .map(_toStudent)
          .toList();
    });
  }

  @override
  Future<Result<Student>> getStudentById(String id) {
    return guardApi(() async => _toStudent(await _api.getStudent(id)));
  }

  @override
  Future<Result<Student>> createStudent(Student student) {
    return guardApi(() async {
      final names = _splitName(student.name);
      final created = await _api.createStudent(
        firstName: names.first,
        lastName: names.last,
        dateOfBirth: _dateString(student.dateOfBirth, '2010-01-01'),
        gender: 'unspecified',
        admissionNumber: student.admissionNumber,
        studentCode: student.rollNumber,
        currentSectionId: student.section,
        status: student.status.toLowerCase(),
      );
      return _toStudent(created);
    });
  }

  @override
  Future<Result<Student>> updateStudent(Student student) {
    return guardApi(() async {
      final names = _splitName(student.name);
      await _api.updateStudent(
        student.id,
        firstName: names.first,
        lastName: names.last,
        dateOfBirth: _dateString(student.dateOfBirth, '2010-01-01'),
        gender: 'unspecified',
        admissionNumber: student.admissionNumber,
        studentCode: student.rollNumber,
        currentSectionId: student.section,
        status: student.status.toLowerCase(),
      );
      return _toStudent(await _api.getStudent(student.id));
    });
  }

  @override
  Future<Result<void>> deleteStudent(String id) {
    return guardApi(() => _api.deleteStudent(id));
  }

  @override
  Future<Result<void>> promoteStudents(
    List<String> studentIds,
    String newClass,
    String newSection,
  ) {
    return guardApi(() async {
      for (final id in studentIds) {
        final current = await _api.getStudent(id);
        await _api.updateStudent(
          id,
          firstName: current.firstName,
          lastName: current.lastName,
          dateOfBirth: current.dateOfBirth ?? '2010-01-01',
          gender: current.gender ?? 'unspecified',
          admissionNumber: current.admissionNumber,
          studentCode: current.studentCode,
          currentSectionId: newSection,
          status: current.status,
        );
      }
    });
  }

  @override
  Future<Result<List<Student>>> getWeakAttendanceStudents({
    double threshold = 75.0,
  }) {
    return guardApi(() async {
      final page = await _api.getStudents(page: 1, pageSize: 500);
      return page.data
          .where((student) => student.attendancePercent < threshold)
          .map(_toStudent)
          .toList();
    });
  }

  Student _toStudent(StudentModel model) {
    final section = model.currentSection;
    final grade = section['grade'];
    final gradeName = grade is Map ? textValue(grade['grade_name']) : '';
    final sectionName = textValue(section['section_name']);
    return Student(
      id: model.id,
      name: model.fullName,
      admissionNumber: model.admissionNumber,
      rollNumber: model.studentCode,
      className: gradeName,
      section: model.currentSectionId ?? sectionName,
      parentName: model.primaryGuardianName,
      parentPhone: model.primaryGuardianPhone,
      photoUrl: model.photoUrl,
      dateOfBirth: DateTime.tryParse(model.dateOfBirth ?? ''),
      status: model.status,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String? _sectionFilter(String? section) {
    final value = textValue(section);
    return value.isEmpty ? null : value;
  }

  ({String first, String last}) _splitName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return (first: 'Student', last: '');
    }
    return (
      first: parts.first,
      last: parts.length > 1 ? parts.skip(1).join(' ') : '',
    );
  }

  String _dateString(DateTime? value, String fallback) {
    return value?.toIso8601String().split('T').first ?? fallback;
  }
}
