import 'package:schooldesk1/features/shared/domain/entities/student.dart';
import 'package:schooldesk1/core/utils/result.dart';

/// Abstract repository interface for student operations.
/// Implementations should be API-backed in production.
abstract class StudentRepository {
  /// Fetch all students, optionally filtered by class/section.
  Future<Result<List<Student>>> getStudents({
    String? className,
    String? section,
    String? searchQuery,
  });

  /// Fetch a single student by ID.
  Future<Result<Student>> getStudentById(String id);

  /// Create a new student record.
  Future<Result<Student>> createStudent(Student student);

  /// Update an existing student record.
  Future<Result<Student>> updateStudent(Student student);

  /// Delete a student record.
  Future<Result<void>> deleteStudent(String id);

  /// Promote students to the next class.
  Future<Result<void>> promoteStudents(
    List<String> studentIds,
    String newClass,
    String newSection,
  );

  /// Get students with low attendance (below threshold).
  Future<Result<List<Student>>> getWeakAttendanceStudents({
    double threshold = 75.0,
  });
}
