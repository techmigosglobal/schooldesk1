class ParentAttendanceSnapshot {
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> records;
  final List<Map<String, dynamic>> leaveRequests;
  final String? partialError;

  const ParentAttendanceSnapshot({
    required this.summary,
    required this.records,
    required this.leaveRequests,
    this.partialError,
  });
}
