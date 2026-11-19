class ParentAttendanceSnapshot {
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> records;
  final List<Map<String, dynamic>> leaveRequests;
  final String? partialError;
  final bool fromCache;
  final DateTime? cacheStoredAt;
  final Set<String> failedSections;

  const ParentAttendanceSnapshot({
    required this.summary,
    required this.records,
    required this.leaveRequests,
    this.partialError,
    this.fromCache = false,
    this.cacheStoredAt,
    this.failedSections = const {},
  });
}
