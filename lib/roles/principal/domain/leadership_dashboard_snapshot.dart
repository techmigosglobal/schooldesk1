import 'package:schooldesk1/core/network/models/backend_models.dart';

class LeadershipDashboardCriticalSnapshot {
  const LeadershipDashboardCriticalSnapshot({
    required this.dashboard,
    this.school = const {},
    this.profile,
    this.cacheMetadata = const CacheMetadata(isStale: false),
  });

  final Map<String, dynamic> dashboard;
  final Map<String, dynamic> school;
  final UserResponse? profile;
  final CacheMetadata cacheMetadata;
}

class LeadershipDashboardOptionalSnapshot {
  const LeadershipDashboardOptionalSnapshot({
    required this.academicYears,
    required this.grades,
    required this.sections,
    required this.subjects,
    required this.feeStructures,
  });

  final List<AcademicYearModel> academicYears;
  final List<GradeModel> grades;
  final List<SectionModel> sections;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> feeStructures;
}

typedef LeadershipDashboardIdentity = ({
  Map<String, dynamic> school,
  UserResponse profile,
});
