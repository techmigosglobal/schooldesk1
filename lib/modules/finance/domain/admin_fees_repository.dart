import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class AdminFeesRepository {
  Future<List<Map<String, dynamic>>> loadFeeStructures();

  Future<Map<String, dynamic>> applyLateFineAdjustments();

  Future<PaginatedList<Map<String, dynamic>>> loadInvoicesPage({
    String? search,
    String? status,
    bool outstanding,
    int page,
    int pageSize,
  });

  Future<PaginatedList<Map<String, dynamic>>> loadPaymentsPage({
    int page = 1,
    int pageSize,
  });

  Future<PaginatedList<Map<String, dynamic>>> loadParentPaymentRequestsPage({
    String? status,
    int page,
    int pageSize,
  });

  Future<Map<String, dynamic>> decideParentPaymentRequest(
    String id, {
    required String status,
    String adminRemarks,
  });

  Future<List<Map<String, dynamic>>> loadFeeCategories();

  Future<PaginatedList<Map<String, dynamic>>> loadFeeConcessionsPage({
    int pageSize,
  });

  Future<Map<String, dynamic>> loadFeeDashboardSummary();

  Future<List<Map<String, dynamic>>> loadPaymentConfigs();

  Future<List<AcademicYearModel>> loadAcademicYears();

  Future<List<GradeModel>> loadGrades();

  Future<List<SectionModel>> loadSections();

  Future<Map<String, dynamic>> createRaw(
    String path,
    Map<String, dynamic> payload,
  );

  Future<Map<String, dynamic>> updateRaw(
    String path,
    Map<String, dynamic> payload,
  );

  Future<void> deleteRaw(String path);

  Future<void> deleteFeeStructure(
    String id, {
    required bool removePending,
  });

  Future<Map<String, dynamic>> createFeeStructure({
    required String academicYearId,
    required String gradeId,
    String sectionId,
    required String feeCategoryId,
    required double amount,
    String frequency,
    String feeType,
    String billingMode,
    int priority,
    bool isActive,
    int dueDay,
    double lateFinePerDay,
    String effectiveFrom,
    bool replaceExisting,
  });

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
  });

  Future<Map<String, dynamic>> applyFeeInvoiceSync(
    String id, {
    required bool includePartiallyPaid,
  });

  Future<List<Map<String, dynamic>>> loadTerms(String academicYearId);

  Future<Map<String, dynamic>> recordPayment(PaymentRequest request);

  Future<Map<String, dynamic>> queueReportExport(
    String path, {
    required String reportTitle,
    required String format,
    required String reportType,
    required String scope,
    Map<String, dynamic> parameters,
  });

  Future<Map<String, dynamic>> loadInvoiceDetail(String id);

  Future<Map<String, dynamic>> loadCurrentSchool();

  Future<List<Map<String, dynamic>>> loadRawList(
    String path, {
    Map<String, dynamic>? queryParameters,
  });
}
