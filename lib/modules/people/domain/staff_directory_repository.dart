import 'dart:typed_data';

import 'package:schooldesk1/core/network/models/backend_models.dart';

class StaffDirectorySupport {
  const StaffDirectorySupport({
    required this.grades,
    required this.sections,
    required this.subjects,
    required this.staffSubjects,
    required this.users,
  });

  final List<GradeModel> grades;
  final List<SectionModel> sections;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> staffSubjects;
  final List<UserAccountModel> users;
}

abstract interface class StaffDirectoryRepository {
  Future<PaginatedList<StaffModel>> loadStaff({
    String? search,
    String? status,
    String? designation,
    int page = 1,
    int pageSize = 20,
  });

  Future<List<LeaveApplicationModel>> loadLeaveApplications();

  Future<StaffDirectorySupport> loadSupportData();

  Future<StaffModel> createStaff({
    required String firstName,
    required String lastName,
    String? staffCode,
    String? username,
    String? email,
    String? phone,
    String? designation,
    String? password,
    String accountRole = 'Teacher',
    String gender = 'unspecified',
    String? employmentType,
    String? joinDate,
    String? dateOfBirth,
    double basicSalary = 0,
    bool requestPrincipalApproval = false,
  });

  Future<void> updateStaff(
    String id, {
    required String firstName,
    required String lastName,
    String? staffCode,
    String? username,
    String? email,
    String? designation,
    String? phone,
    String? password,
    String accountRole = 'Teacher',
    String gender = 'unspecified',
    String? employmentType,
    String? joinDate,
    String? dateOfBirth,
    double basicSalary = 0,
  });

  Future<void> decideLeave(String id, {required String status});

  Future<void> deleteStaff(String id);

  Future<String> uploadStaffPhoto({
    required String staffId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  });

  Future<String> uploadStaffDocument({
    required String staffId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
    required String documentType,
  });

  Future<Map<String, dynamic>> createApprovalRequest({
    required String module,
    required String operationType,
    required String entityType,
    String entityId = '',
    String academicYearId = '',
    String status = 'draft',
    Map<String, dynamic> payload = const {},
    Map<String, dynamic> beforeSnapshot = const {},
    Map<String, dynamic> afterSnapshot = const {},
  });

  Future<Map<String, dynamic>> submitApprovalRequest(String id);

  Future<void> deleteStaffSubject(String id);

  Future<void> createStaffSubject(Map<String, dynamic> payload);

  Future<void> updateSection(String id, Map<String, dynamic> payload);
}
