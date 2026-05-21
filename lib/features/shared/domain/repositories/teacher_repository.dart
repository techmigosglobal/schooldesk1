import '../entities/teacher.dart';
import '../../../../core/utils/result.dart';

/// Abstract repository interface for teacher/staff operations.
abstract class TeacherRepository {
  Future<Result<List<Teacher>>> getTeachers({
    String? subject,
    String? status,
    String? searchQuery,
  });

  Future<Result<Teacher>> getTeacherById(String id);

  Future<Result<Teacher>> createTeacher(Teacher teacher);

  Future<Result<Teacher>> updateTeacher(Teacher teacher);

  Future<Result<void>> deleteTeacher(String id);

  Future<Result<List<Teacher>>> getTeachersByClass(
    String className,
    String section,
  );
}
