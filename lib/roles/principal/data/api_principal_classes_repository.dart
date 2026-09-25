import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/roles/principal/domain/principal_classes_repository.dart';

class ApiPrincipalClassesRepository implements PrincipalClassesRepository {
  ApiPrincipalClassesRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Map<String, dynamic>> loadOverview({bool forceRefresh = false}) =>
      _api.getPrincipalClassesOverview(forceRefresh: forceRefresh);

  @override
  Future<List<AcademicYearModel>> loadAcademicYears({
    bool forceRefresh = false,
  }) => _api.getAcademicYears(forceRefresh: forceRefresh);

  @override
  Future<PaginatedList<StaffModel>> loadStaff({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) => _api.getStaff(page: page, pageSize: pageSize, status: status);

  @override
  Future<List<Map<String, dynamic>>> loadSubjects() =>
      _api.getRawList('/subjects', queryParameters: const {'page_size': 100});

  @override
  Future<List<Map<String, dynamic>>> loadGradeSubjects({
    String? gradeId,
    String? sectionId,
  }) => _api.getRawList(
    '/grade-subjects',
    queryParameters: {
      if (gradeId != null && gradeId.isNotEmpty) 'grade_id': gradeId,
      if (sectionId != null && sectionId.isNotEmpty) 'section_id': sectionId,
      'page_size': 100,
    },
  );

  @override
  Future<List<Map<String, dynamic>>> loadStaffSubjects({
    String? gradeId,
    String? sectionId,
  }) => _api.getRawList(
    '/staff-subjects',
    queryParameters: {
      if (gradeId != null && gradeId.isNotEmpty) 'grade_id': gradeId,
      if (sectionId != null && sectionId.isNotEmpty) 'section_id': sectionId,
      'page_size': 100,
    },
  );

  @override
  Future<List<Map<String, dynamic>>> loadEvents() => _api.getEvents();

  @override
  Future<List<Map<String, dynamic>>> loadNotifications() =>
      _api.getNotifications();

  @override
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
  }) => _api.createPrincipalClass(
    academicYearId: academicYearId,
    sectionName: sectionName,
    capacity: capacity,
    gradeId: gradeId,
    gradeName: gradeName,
    gradeNumber: gradeNumber,
    classTeacherId: classTeacherId,
    coTeacherId: coTeacherId,
    roomNumber: roomNumber,
    roomType: roomType,
    roomCapacity: roomCapacity,
  );

  @override
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
  }) => _api.updatePrincipalClassSetup(
    sectionId: sectionId,
    gradeId: gradeId,
    gradeName: gradeName,
    gradeNumber: gradeNumber,
    academicYearId: academicYearId,
    sectionName: sectionName,
    capacity: capacity,
    classTeacherId: classTeacherId,
    coTeacherId: coTeacherId,
    roomNumber: roomNumber,
    roomType: roomType,
    roomCapacity: roomCapacity,
    subjectMappings: subjectMappings,
  );

  @override
  Future<void> deleteClass({required String sectionId}) async {
    await _api.deletePrincipalClass(sectionId: sectionId);
  }

  @override
  Future<Map<String, dynamic>> updateSubject(
    String subjectId,
    Map<String, dynamic> payload,
  ) => _api.updateRaw('/subjects/$subjectId', payload);

  @override
  Future<void> deleteSubject(String subjectId) =>
      _api.deleteRaw('/subjects/$subjectId');

  @override
  Future<Map<String, dynamic>> createSubject(Map<String, dynamic> payload) =>
      _api.createRaw('/subjects', payload);

  @override
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
  }) => _api.savePrincipalSubjectMapping(
    subjectId: subjectId,
    academicYearId: academicYearId,
    gradeId: gradeId,
    periodsPerWeek: periodsPerWeek,
    isMandatory: isMandatory,
    sectionId: sectionId,
    teacherId: teacherId,
    isPrimary: isPrimary,
    assignmentId: assignmentId,
  );

  @override
  Future<List<Map<String, dynamic>>> loadFeeStructures({
    required String academicYearId,
    required String gradeId,
    String? sectionId,
  }) => _api.getFeeStructures(
    academicYearId: academicYearId,
    gradeId: gradeId,
    sectionId: sectionId,
  );

  @override
  Future<List<Map<String, dynamic>>> loadFeeCategories() =>
      _api.getFeeCategories();

  @override
  Future<void> deleteFeeStructure(
    String structureId, {
    bool removePending = true,
  }) => _api.deleteFeeStructure(structureId, removePending: removePending);

  @override
  Future<Map<String, dynamic>> createFeeStructure({
    required String academicYearId,
    required String gradeId,
    String sectionId = '',
    required String feeCategoryId,
    required double amount,
    int dueDay = 10,
    double lateFinePerDay = 0,
  }) => _api.createFeeStructure(
    academicYearId: academicYearId,
    gradeId: gradeId,
    sectionId: sectionId,
    feeCategoryId: feeCategoryId,
    amount: amount,
    dueDay: dueDay,
    lateFinePerDay: lateFinePerDay,
  );

  @override
  Future<Map<String, dynamic>> updateFeeStructure(
    String structureId, {
    String? academicYearId,
    String? gradeId,
    String? sectionId,
    String? feeCategoryId,
    double? amount,
    int? dueDay,
    double? lateFinePerDay,
  }) => _api.updateFeeStructure(
    structureId,
    academicYearId: academicYearId,
    gradeId: gradeId,
    sectionId: sectionId,
    feeCategoryId: feeCategoryId,
    amount: amount,
    dueDay: dueDay,
    lateFinePerDay: lateFinePerDay,
  );

  @override
  Future<Map<String, dynamic>> applyFeeInvoiceSync(
    String structureId, {
    bool includePartiallyPaid = false,
  }) => _api.applyFeeInvoiceSync(
    structureId,
    includePartiallyPaid: includePartiallyPaid,
  );

  @override
  Future<Map<String, dynamic>> createFeeCategory({
    required String categoryName,
    required String frequency,
  }) =>
      _api.createFeeCategory(categoryName: categoryName, frequency: frequency);

  static ApiPrincipalClassesRepository get legacyDefault =>
      ApiPrincipalClassesRepository(BackendApiClient.instance);
}
