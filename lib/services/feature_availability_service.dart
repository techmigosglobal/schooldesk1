enum SchoolDeskFeature {
  adminStudents,
  adminStaff,
  adminFees,
  syllabusRecords,
  principalAnalytics,
  teacherResources,
  teacherLessonPlanner,
  teacherParentMeetings,
  parentStudentLeave,
  documents,
  reportsExports,
  studentPortal,
}

class FeatureAvailabilityState {
  final SchoolDeskFeature feature;
  final String label;
  final bool isAvailable;
  final String? reason;
  final String? recommendedAction;

  const FeatureAvailabilityState({
    required this.feature,
    required this.label,
    required this.isAvailable,
    this.reason,
    this.recommendedAction,
  });
}

class FeatureAvailabilityService {
  FeatureAvailabilityService._();

  static const Map<SchoolDeskFeature, FeatureAvailabilityState> _states = {
    SchoolDeskFeature.adminStudents: FeatureAvailabilityState(
      feature: SchoolDeskFeature.adminStudents,
      label: 'Student administration',
      isAvailable: true,
    ),
    SchoolDeskFeature.adminStaff: FeatureAvailabilityState(
      feature: SchoolDeskFeature.adminStaff,
      label: 'Teacher and staff',
      isAvailable: true,
    ),
    SchoolDeskFeature.adminFees: FeatureAvailabilityState(
      feature: SchoolDeskFeature.adminFees,
      label: 'Fees and finance',
      isAvailable: true,
    ),
    SchoolDeskFeature.syllabusRecords: FeatureAvailabilityState(
      feature: SchoolDeskFeature.syllabusRecords,
      label: 'Syllabus records',
      isAvailable: true,
      reason: 'Principal syllabus records read from the live syllabus backend.',
      recommendedAction:
          'Keep Principal read coverage in local Docker module verification.',
    ),
    SchoolDeskFeature.principalAnalytics: FeatureAvailabilityState(
      feature: SchoolDeskFeature.principalAnalytics,
      label: 'Principal analytics',
      isAvailable: true,
    ),
    SchoolDeskFeature.teacherResources: FeatureAvailabilityState(
      feature: SchoolDeskFeature.teacherResources,
      label: 'Teacher resources',
      isAvailable: false,
      reason: 'Backend not ready for resource storage and role-scoped files.',
      recommendedAction:
          'Track as backend hardening before enabling upload or publish actions.',
    ),
    SchoolDeskFeature.teacherLessonPlanner: FeatureAvailabilityState(
      feature: SchoolDeskFeature.teacherLessonPlanner,
      label: 'Lesson planner',
      isAvailable: false,
      reason: 'Backend lesson-plan contract is still partially verified.',
      recommendedAction:
          'Track the workflow until create, update, and parent visibility are verified.',
    ),
    SchoolDeskFeature.teacherParentMeetings: FeatureAvailabilityState(
      feature: SchoolDeskFeature.teacherParentMeetings,
      label: 'Parent-teacher meetings',
      isAvailable: false,
      reason: 'Backend not ready for the full PTM slot lifecycle in the UI.',
      recommendedAction:
          'Track create, book, cancel, and readback before enabling live booking.',
    ),
    SchoolDeskFeature.parentStudentLeave: FeatureAvailabilityState(
      feature: SchoolDeskFeature.parentStudentLeave,
      label: 'Student leave requests',
      isAvailable: true,
      reason: 'Backend-backed student leave submission and approval is wired.',
      recommendedAction:
          'Keep role-wise E2E coverage in the local Docker verifier.',
    ),
    SchoolDeskFeature.documents: FeatureAvailabilityState(
      feature: SchoolDeskFeature.documents,
      label: 'Documents and certificates',
      isAvailable: false,
      reason: 'Backend not ready for complete document request/export flows.',
      recommendedAction:
          'Track storage, download, and role-scoped visibility before enabling.',
    ),
    SchoolDeskFeature.reportsExports: FeatureAvailabilityState(
      feature: SchoolDeskFeature.reportsExports,
      label: 'Reports and exports',
      isAvailable: true,
      reason:
          'Report exports are persisted and downloaded through the VPS backend.',
      recommendedAction:
          'Keep Principal, Admin, Teacher, and Parent export coverage in release verification.',
    ),
    SchoolDeskFeature.studentPortal: FeatureAvailabilityState(
      feature: SchoolDeskFeature.studentPortal,
      label: 'Parent-managed student access',
      isAvailable: true,
      reason:
          'Students are intentionally accessed through linked Parent accounts with child switching.',
      recommendedAction:
          'Use Parent login and /me/students verification instead of separate Student accounts.',
    ),
  };

  static FeatureAvailabilityState stateFor(SchoolDeskFeature feature) {
    return _states[feature] ??
        FeatureAvailabilityState(
          feature: feature,
          label: feature.name,
          isAvailable: false,
          reason: 'Backend readiness has not been declared for this feature.',
          recommendedAction: 'Track this feature before enabling user actions.',
        );
  }
}
