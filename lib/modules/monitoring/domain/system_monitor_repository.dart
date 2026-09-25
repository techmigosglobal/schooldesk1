abstract interface class SystemMonitorRepository {
  Future<Map<String, dynamic>> loadErrorEvents({
    String? status,
    int pageSize = 50,
  });

  Future<Map<String, dynamic>> loadRetentionMetrics();

  Future<Map<String, dynamic>> resolveErrorEvent(
    String id, {
    String resolutionNote,
  });

  Future<void> deleteResolvedErrorEvent(String id);

  Future<Map<String, dynamic>> updateRetentionSettings({
    required int warningKeepDays,
    required int resolvedKeepDays,
    required int resolvedFatalKeepDays,
    required int maxRawEvents,
  });

  Future<Map<String, dynamic>> previewResolvedCleanup({DateTime? before});

  Future<Map<String, dynamic>> clearResolvedCleanup({DateTime? before});

  Future<Map<String, dynamic>> backupDatabase();

  Future<void> restoreDatabase(Map<String, dynamic> dump);

  Future<Map<String, dynamic>> wipeDatabase();
}
