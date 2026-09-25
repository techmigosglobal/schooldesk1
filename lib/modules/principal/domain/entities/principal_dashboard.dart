import 'package:schooldesk1/modules/principal/domain/entities/setup_step.dart';

/// Principal dashboard entity — domain object.
class PrincipalDashboard {
  final String principalName;
  final String schoolName;
  final String schoolBoard;
  final String schoolLogoUrl;
  final String schoolBannerUrl;
  final int totalStudents;
  final int totalStaff;
  final int totalClasses;
  final int pendingApprovals;
  final double attendancePct;
  final int attendancePresent;
  final int attendanceMarked;
  final double collectionPct;
  final double totalPaid;
  final int unreadNotifications;
  final List<SetupStep> setupSteps;

  const PrincipalDashboard({
    required this.principalName,
    required this.schoolName,
    required this.schoolBoard,
    required this.schoolLogoUrl,
    required this.schoolBannerUrl,
    required this.totalStudents,
    required this.totalStaff,
    required this.totalClasses,
    required this.pendingApprovals,
    required this.attendancePct,
    required this.attendancePresent,
    required this.attendanceMarked,
    required this.collectionPct,
    required this.totalPaid,
    required this.unreadNotifications,
    required this.setupSteps,
  });

  PrincipalDashboard copyWith({
    String? principalName,
    String? schoolName,
    String? schoolBoard,
    String? schoolLogoUrl,
    String? schoolBannerUrl,
    int? totalStudents,
    int? totalStaff,
    int? totalClasses,
    int? pendingApprovals,
    double? attendancePct,
    int? attendancePresent,
    int? attendanceMarked,
    double? collectionPct,
    double? totalPaid,
    int? unreadNotifications,
    List<SetupStep>? setupSteps,
  }) {
    return PrincipalDashboard(
      principalName: principalName ?? this.principalName,
      schoolName: schoolName ?? this.schoolName,
      schoolBoard: schoolBoard ?? this.schoolBoard,
      schoolLogoUrl: schoolLogoUrl ?? this.schoolLogoUrl,
      schoolBannerUrl: schoolBannerUrl ?? this.schoolBannerUrl,
      totalStudents: totalStudents ?? this.totalStudents,
      totalStaff: totalStaff ?? this.totalStaff,
      totalClasses: totalClasses ?? this.totalClasses,
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      attendancePct: attendancePct ?? this.attendancePct,
      attendancePresent: attendancePresent ?? this.attendancePresent,
      attendanceMarked: attendanceMarked ?? this.attendanceMarked,
      collectionPct: collectionPct ?? this.collectionPct,
      totalPaid: totalPaid ?? this.totalPaid,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      setupSteps: setupSteps ?? this.setupSteps,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PrincipalDashboard &&
        other.principalName == principalName &&
        other.schoolName == schoolName &&
        other.schoolBoard == schoolBoard &&
        other.schoolLogoUrl == schoolLogoUrl &&
        other.schoolBannerUrl == schoolBannerUrl &&
        other.totalStudents == totalStudents &&
        other.totalStaff == totalStaff &&
        other.totalClasses == totalClasses &&
        other.pendingApprovals == pendingApprovals &&
        other.attendancePct == attendancePct &&
        other.attendancePresent == attendancePresent &&
        other.attendanceMarked == attendanceMarked &&
        other.collectionPct == collectionPct &&
        other.totalPaid == totalPaid &&
        other.unreadNotifications == unreadNotifications &&
        _setupStepsEqual(other.setupSteps, setupSteps);
  }

  @override
  int get hashCode => Object.hash(
    principalName,
    schoolName,
    schoolBoard,
    schoolLogoUrl,
    schoolBannerUrl,
    totalStudents,
    totalStaff,
    totalClasses,
    pendingApprovals,
    attendancePct,
    attendancePresent,
    attendanceMarked,
    collectionPct,
    totalPaid,
    unreadNotifications,
    Object.hashAll(setupSteps),
  );

  bool _setupStepsEqual(List<SetupStep> left, List<SetupStep> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }
}
