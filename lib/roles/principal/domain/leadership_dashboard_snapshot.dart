import 'package:schooldesk1/core/network/models/backend_models.dart';

class LeadershipDashboardCriticalSnapshot {
  const LeadershipDashboardCriticalSnapshot({
    required this.dashboard,
    required this.school,
    required this.profile,
  });

  final Map<String, dynamic> dashboard;
  final Map<String, dynamic> school;
  final UserResponse profile;
}

class LeadershipDashboardOptionalSnapshot {
  const LeadershipDashboardOptionalSnapshot({
    required this.academicYears,
    required this.grades,
    required this.sections,
    required this.subjects,
    required this.staff,
    required this.students,
    required this.feeStructures,
    required this.notifications,
    required this.staffAttendanceSummary,
    required this.recentSchoolActivity,
  });

  final List<AcademicYearModel> academicYears;
  final List<GradeModel> grades;
  final List<SectionModel> sections;
  final List<Map<String, dynamic>> subjects;
  final PaginatedList<StaffModel> staff;
  final PaginatedList<StudentModel> students;
  final List<Map<String, dynamic>> feeStructures;
  final List<Map<String, dynamic>> notifications;
  final Map<String, dynamic> staffAttendanceSummary;
  final List<Map<String, dynamic>> recentSchoolActivity;
}
