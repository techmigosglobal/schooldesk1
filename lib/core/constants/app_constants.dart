/// Application-wide constants — single source of truth for magic values.
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'SchoolDesk';
  static const String appVersion = '1.0.0';
  static const String schoolName = 'Public School';
  static const String schoolTagline = 'Shaping Curious Minds for Tomorrow';
  static const String schoolAddress = 'Hyderabad, Telangana, India';
  static const String schoolPhone = '+91-9876543210';
  static const String schoolEmail = 'info@publichighschool.edu.in';
  static const int establishedYear = 2008;
  static const String board = 'CBSE';
  static const String academicYear = '2025–26';

  // Roles
  static const String rolePrincipal = 'principal';
  static const String roleAdmin = 'admin';
  static const String roleTeacher = 'teacher';
  static const String roleParent = 'parent';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Timeouts (milliseconds)
  static const int apiTimeoutMs = 30000;
  static const int cacheExpiryHours = 24;

  // UI
  static const double defaultBorderRadius = 12.0;
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 10.0;
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  // Attendance Status
  static const String attendancePresent = 'Present';
  static const String attendanceAbsent = 'Absent';
  static const String attendanceLate = 'Late';
  static const String attendanceHalfDay = 'Half-Day';
  static const String attendanceLeave = 'Leave';

  // Fee Status
  static const String feePaid = 'Paid';
  static const String feePending = 'Pending';
  static const String feeOverdue = 'Overdue';
  static const String feePartial = 'Partial';

  // Leave Status
  static const String leavePending = 'Pending';
  static const String leaveApproved = 'Approved';
  static const String leaveRejected = 'Rejected';

  // Complaint Status
  static const String complaintOpen = 'Open';
  static const String complaintInProgress = 'In Progress';
  static const String complaintResolved = 'Resolved';
  static const String complaintClosed = 'Closed';

  // Exam Status
  static const String examScheduled = 'Scheduled';
  static const String examOngoing = 'Ongoing';
  static const String examCompleted = 'Completed';
  static const String examCancelled = 'Cancelled';

  // Homework Status
  static const String homeworkPending = 'Pending';
  static const String homeworkSubmitted = 'Submitted';
  static const String homeworkGraded = 'Graded';
  static const String homeworkOverdue = 'Overdue';
}
