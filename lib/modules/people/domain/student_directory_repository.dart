import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class StudentDirectoryRepository {
  Future<List<GradeModel>> loadGrades({bool forceRefresh = false});

  Future<List<SectionModel>> loadSections({bool forceRefresh = false});

  Future<PaginatedList<StudentModel>> loadStudents({
    String? search,
    String? sectionId,
    int page = 1,
    int pageSize = 20,
  });

  Future<PaginatedList<UserAccountModel>> loadParentAccounts({
    int page = 1,
    int pageSize = 20,
  });

  Future<PaginatedList<Map<String, dynamic>>> loadGuardianDirectory({
    int page = 1,
    int pageSize = 20,
  });

  Future<UserAccountModel> createParentAccount({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String phone,
    bool isActive = true,
  });

  Future<StudentModel> createStudent({
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String gender,
    String? admissionNumber,
    String? studentCode,
    String? currentSectionId,
    String? parentUserId,
    bool requireParentLink = false,
    String? admissionDate,
    String status = 'active',
  });

  Future<void> updateStudent(
    String id, {
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String gender,
    String? admissionNumber,
    String? studentCode,
    String? currentSectionId,
    String? parentUserId,
    bool requireParentLink = false,
    String? admissionDate,
    String status = 'active',
  });

  Future<void> deleteStudent(String id);

  Future<void> deleteUser(String id, {bool permanent = false});

  Future<void> setStudentParent({
    required String studentId,
    String? parentUserId,
  });

  Future<void> linkGuardianToStudent({
    required String studentId,
    required String guardianId,
    bool isPrimary = false,
    bool canPickup = false,
  });

  Future<Map<String, dynamic>> createRaw(
    String path,
    Map<String, dynamic> payload,
  );
}
