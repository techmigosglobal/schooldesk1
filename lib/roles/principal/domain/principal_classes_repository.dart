import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class PrincipalClassesRepository {
  Future<Map<String, dynamic>> loadOverview({bool forceRefresh = false});

  Future<List<AcademicYearModel>> loadAcademicYears({
    bool forceRefresh = false,
  });

  Future<PaginatedList<StaffModel>> loadStaff({
    int page = 1,
    int pageSize = 20,
    String? status,
  });

  Future<List<Map<String, dynamic>>> loadSubjects();

  Future<List<Map<String, dynamic>>> loadGradeSubjects({
    String? gradeId,
    String? sectionId,
  });

  Future<List<Map<String, dynamic>>> loadStaffSubjects({
    String? gradeId,
    String? sectionId,
  });

  Future<List<Map<String, dynamic>>> loadEvents();

  Future<List<Map<String, dynamic>>> loadNotifications();

  Future<Map<String, dynamic>> createClass({
    required String academicYearId,
    required String sectionName,
    required int capacity,
    String gradeId = '',
    String gradeName = '',
    int? gradeNumber,
    String classTeacherId = '',
    String coTeacherId = '',
    String roomNumber = '',
    String roomType = 'classroom',
    int roomCapacity = 0,
  });

  Future<Map<String, dynamic>> updateClass({
    required String sectionId,
    required String gradeId,
    required String academicYearId,
    required String sectionName,
    required int capacity,
    String gradeName = '',
    int? gradeNumber,
    String classTeacherId = '',
    String coTeacherId = '',
    String? roomNumber,
    String roomType = 'classroom',
    int roomCapacity = 0,
    List<Map<String, dynamic>> subjectMappings = const [],
  });

  Future<void> deleteClass({required String sectionId});

  Future<Map<String, dynamic>> updateSubject(
    String subjectId,
    Map<String, dynamic> payload,
  );

  Future<void> deleteSubject(String subjectId);

  Future<Map<String, dynamic>> createSubject(Map<String, dynamic> payload);

  Future<Map<String, dynamic>> saveSubjectMapping({
    required String subjectId,
    required String academicYearId,
    required String gradeId,
    required int periodsPerWeek,
    bool isMandatory = true,
    String sectionId = '',
    String teacherId = '',
    bool isPrimary = true,
    String assignmentId = '',
  });

  Future<List<Map<String, dynamic>>> loadFeeStructures({
    required String academicYearId,
    required String gradeId,
    String? sectionId,
  });

  Future<List<Map<String, dynamic>>> loadFeeCategories();

  Future<void> deleteFeeStructure(
    String structureId, {
    bool removePending = true,
  });

  Future<Map<String, dynamic>> createFeeStructure({
    required String academicYearId,
    required String gradeId,
    String sectionId = '',
    required String feeCategoryId,
    required double amount,
    int dueDay = 10,
    double lateFinePerDay = 0,
  });

  Future<Map<String, dynamic>> updateFeeStructure(
    String structureId, {
    String? academicYearId,
    String? gradeId,
    String? sectionId,
    String? feeCategoryId,
    double? amount,
    int? dueDay,
    double? lateFinePerDay,
  });

  Future<Map<String, dynamic>> applyFeeInvoiceSync(
    String structureId, {
    bool includePartiallyPaid = false,
  });

  Future<Map<String, dynamic>> createFeeCategory({
    required String categoryName,
    required String frequency,
  });
}
