// Repository seam intentionally stays abstract for provider/test overrides.
// ignore_for_file: one_member_abstracts

abstract interface class AdminReportsRepository {
  Future<Map<String, dynamic>> requestExport({
    required String reportTitle,
    required String format,
  });
}
