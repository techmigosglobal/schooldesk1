// A named boundary keeps diagnostics transport overrideable in notification UI.
// ignore_for_file: one_member_abstracts

abstract interface class NotificationDiagnosticsRepository {
  Future<Map<String, dynamic>> runPushDiagnostics();
}
