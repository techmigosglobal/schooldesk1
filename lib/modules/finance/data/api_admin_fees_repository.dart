import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/finance/domain/admin_fees_repository.dart';

class ApiAdminFeesRepository implements AdminFeesRepository {
  ApiAdminFeesRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<List<Map<String, dynamic>>> loadFeeStructures() =>
      _api.getFeeStructures();

  @override
  Future<Map<String, dynamic>> applyLateFineAdjustments() =>
      _api.applyLateFineAdjustments();

  @override
  Future<PaginatedList<Map<String, dynamic>>> loadInvoicesPage({
    String? search,
    String? status,
    bool outstanding = false,
    int page = 1,
    int pageSize = 20,
  }) => _api.getInvoicesPage(
    search: search,
    status: status,
    outstanding: outstanding,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<PaginatedList<Map<String, dynamic>>> loadPaymentsPage({
    int page = 1,
    int pageSize = 20,
  }) => _api.getPaymentsPage(page: page, pageSize: pageSize);

  @override
  Future<PaginatedList<Map<String, dynamic>>> loadParentPaymentRequestsPage({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) => _api.getParentPaymentRequestsPage(
    status: status,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<Map<String, dynamic>> decideParentPaymentRequest(
    String id, {
    required String status,
    String adminRemarks = '',
  }) => _api.decideParentPaymentRequest(
    id,
    status: status,
    adminRemarks: adminRemarks,
  );

  @override
  Future<List<Map<String, dynamic>>> loadFeeCategories() =>
      _api.getFeeCategories();

  @override
  Future<PaginatedList<Map<String, dynamic>>> loadFeeConcessionsPage({
    int pageSize = 20,
  }) => _api.getFeeConcessionsPage(pageSize: pageSize);

  @override
  Future<Map<String, dynamic>> loadFeeDashboardSummary() =>
      _api.getFeeDashboardSummary();

  @override
  Future<List<Map<String, dynamic>>> loadPaymentConfigs() =>
      _api.getPaymentConfigs();

  @override
  Future<List<AcademicYearModel>> loadAcademicYears() =>
      _api.getAcademicYears();

  @override
  Future<List<GradeModel>> loadGrades() => _api.getGrades();

  @override
  Future<List<SectionModel>> loadSections() => _api.getSections();

  @override
  Future<Map<String, dynamic>> createRaw(
    String path,
    Map<String, dynamic> payload,
  ) => _api.createRaw(path, payload);

  @override
  Future<Map<String, dynamic>> updateRaw(
    String path,
    Map<String, dynamic> payload,
  ) => _api.updateRaw(path, payload);

  @override
  Future<void> deleteRaw(String path) => _api.deleteRaw(path);

  @override
  Future<void> deleteFeeStructure(
    String id, {
    required bool removePending,
  }) => _api.deleteFeeStructure(id, removePending: removePending);

  @override
  Future<Map<String, dynamic>> createFeeStructure({
    required String academicYearId,
    required String gradeId,
    String sectionId = '',
    required String feeCategoryId,
    required double amount,
    String frequency = 'term',
    String feeType = '',
    String billingMode = '',
    int priority = 0,
    bool isActive = true,
    int dueDay = 10,
    double lateFinePerDay = 0,
    String effectiveFrom = '',
    bool replaceExisting = false,
  }) => _api.createFeeStructure(
    academicYearId: academicYearId,
    gradeId: gradeId,
    sectionId: sectionId,
    feeCategoryId: feeCategoryId,
    amount: amount,
    frequency: frequency,
    feeType: feeType,
    billingMode: billingMode,
    priority: priority,
    isActive: isActive,
    dueDay: dueDay,
    lateFinePerDay: lateFinePerDay,
    effectiveFrom: effectiveFrom,
    replaceExisting: replaceExisting,
  );

  @override
  Future<Map<String, dynamic>> updateFeeStructure(
    String id, {
    String? academicYearId,
    String? gradeId,
    String? sectionId,
    String? feeCategoryId,
    double? amount,
    String? frequency,
    String? feeType,
    String? billingMode,
    int? priority,
    bool? isActive,
    int? dueDay,
    double? lateFinePerDay,
    String? effectiveFrom,
  }) => _api.updateFeeStructure(
    id,
    academicYearId: academicYearId,
    gradeId: gradeId,
    sectionId: sectionId,
    feeCategoryId: feeCategoryId,
    amount: amount,
    frequency: frequency,
    feeType: feeType,
    billingMode: billingMode,
    priority: priority,
    isActive: isActive,
    dueDay: dueDay,
    lateFinePerDay: lateFinePerDay,
    effectiveFrom: effectiveFrom,
  );

  @override
  Future<Map<String, dynamic>> applyFeeInvoiceSync(
    String id, {
    required bool includePartiallyPaid,
  }) => _api.applyFeeInvoiceSync(
    id,
    includePartiallyPaid: includePartiallyPaid,
  );

  @override
  Future<List<Map<String, dynamic>>> loadTerms(String academicYearId) =>
      _api.getTerms(academicYearId);

  @override
  Future<Map<String, dynamic>> recordPayment(PaymentRequest request) =>
      _api.recordPayment(request);

  @override
  Future<Map<String, dynamic>> queueReportExport(
    String path, {
    required String reportTitle,
    required String format,
    required String reportType,
    required String scope,
    Map<String, dynamic> parameters = const {},
  }) => _api.createReportExport(
    path,
    reportTitle: reportTitle,
    format: format,
    reportType: reportType,
    scope: scope,
    parameters: parameters,
  );

  @override
  Future<Map<String, dynamic>> loadInvoiceDetail(String id) =>
      _api.getInvoiceDetail(id);

  @override
  Future<Map<String, dynamic>> loadCurrentSchool() => _api.getCurrentSchool();

  @override
  Future<List<Map<String, dynamic>>> loadRawList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) => _api.getRawList(path, queryParameters: queryParameters);

  static ApiAdminFeesRepository get legacyDefault =>
      ApiAdminFeesRepository(BackendApiClient.instance);
}
