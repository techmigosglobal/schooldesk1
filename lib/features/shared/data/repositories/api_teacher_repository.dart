import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/features/shared/domain/entities/teacher.dart';
import 'package:schooldesk1/features/shared/domain/repositories/teacher_repository.dart';
import 'package:schooldesk1/features/shared/data/repositories/api_repository_utils.dart';

class ApiTeacherRepository implements TeacherRepository {
  ApiTeacherRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<List<Teacher>>> getTeachers({
    String? subject,
    String? status,
    String? searchQuery,
  }) {
    return guardApi(() async {
      final page = await _api.getStaff(
        status: textValue(status).isEmpty ? null : status,
        page: 1,
        pageSize: 500,
      );
      final query = textValue(searchQuery).toLowerCase();
      return page.data
          .where((staff) {
            if (query.isEmpty) return true;
            return [
              staff.fullName,
              staff.staffCode,
              staff.email,
              staff.phone,
              staff.designation,
            ].join(' ').toLowerCase().contains(query);
          })
          .map(_toTeacher)
          .toList();
    });
  }

  @override
  Future<Result<Teacher>> getTeacherById(String id) {
    return guardApi(() async => _toTeacher(await _api.getStaffMember(id)));
  }

  @override
  Future<Result<Teacher>> createTeacher(Teacher teacher) {
    return guardApi(() async {
      final names = _splitName(teacher.name);
      final created = await _api.createStaff(
        firstName: names.first,
        lastName: names.last,
        staffCode: teacher.employeeId,
        email: teacher.email,
        phone: teacher.phone,
        designation: teacher.designation,
        joinDate: _dateString(teacher.joinDate),
      );
      return _toTeacher(created);
    });
  }

  @override
  Future<Result<Teacher>> updateTeacher(Teacher teacher) {
    return guardApi(() async {
      final names = _splitName(teacher.name);
      await _api.updateStaff(
        teacher.id,
        firstName: names.first,
        lastName: names.last,
        staffCode: teacher.employeeId,
        email: teacher.email,
        phone: teacher.phone,
        designation: teacher.designation,
        joinDate: _dateString(teacher.joinDate),
      );
      return _toTeacher(await _api.getStaffMember(teacher.id));
    });
  }

  @override
  Future<Result<void>> deleteTeacher(String id) {
    return guardApi(() => _api.deleteStaff(id));
  }

  @override
  Future<Result<List<Teacher>>> getTeachersByClass(
    String className,
    String section,
  ) {
    return getTeachers(status: 'active');
  }

  Teacher _toTeacher(StaffModel model) {
    return Teacher(
      id: model.id,
      name: model.fullName,
      employeeId: model.staffCode,
      email: model.email ?? '',
      phone: model.phone ?? '',
      subject: model.departmentName ?? model.designation ?? 'General',
      designation: model.designation ?? '',
      photoUrl: model.photoUrl,
      status: model.status,
      joinDate: parseDate(model.joinDate),
    );
  }

  ({String first, String last}) _splitName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return (first: 'Staff', last: '');
    }
    return (
      first: parts.first,
      last: parts.length > 1 ? parts.skip(1).join(' ') : '',
    );
  }

  String _dateString(DateTime value) =>
      value.toIso8601String().split('T').first;
}
