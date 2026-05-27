/// Legacy key names retained only for migration-safe references.
class StorageKeys {
  StorageKeys._();

  // Session
  static const String currentRole = 'session_current_role';
  static const String currentUserId = 'session_current_user_id';
  static const String authToken = 'session_auth_token';
  static const String isLoggedIn = 'session_is_logged_in';

  // Principal
  static const String students = 'principal_students';
  static const String feeStructures = 'principal_fee_structures';
  static const String studentFees = 'principal_student_fees';
  static const String concessionRequests = 'principal_concession_requests';
  static const String timetable = 'principal_timetable';
  static const String substituteRequests = 'principal_substitute_requests';
  static const String syllabusData = 'principal_syllabus_data';
  static const String examSchedule = 'principal_exam_schedule';
  static const String examResults = 'principal_exam_results';
  static const String complaints = 'principal_complaints';
  static const String circulars = 'principal_circulars';
  static const String notices = 'principal_notices';
  static const String events = 'principal_events';
  static const String holidays = 'principal_holidays';

  // Academic Management
  static const String academicYears = 'academic_years';
  static const String academicSubjects = 'academic_subjects';
  static const String academicClasses = 'academic_classes';
  static const String academicCurriculum = 'academic_curriculum';
  static const String activeAcademicYear = 'active_academic_year';
  static const String sharedCurriculum = 'shared_curriculum';

  // Admin
  static const String adminStudents = 'admin_students';
  static const String adminTeachers = 'admin_teachers';
  static const String adminLeaveRequests = 'admin_leave_requests';
  static const String adminAttendanceRecords = 'admin_attendance_records';
  static const String adminAttendanceExceptions = 'admin_attendance_exceptions';
  static const String adminFeeStructures = 'admin_fee_structures';
  static const String adminPendingDues = 'admin_pending_dues';
  static const String adminRecentPayments = 'admin_recent_payments';
  static const String adminExams = 'admin_exams';
  static const String adminSeatings = 'admin_seatings';

  // Teacher
  static const String teacherAttendance = 'teacher_attendance';
  static const String teacherHomework = 'teacher_homework';
  static const String teacherSyllabus = 'teacher_syllabus';
  static const String teacherWeeklyPlan = 'teacher_weekly_plan';
  static const String teacherNotes = 'teacher_notes';
  static const String teacherLeaveRequests = 'teacher_leave_requests';
  static const String teacherDiscipline = 'teacher_discipline';
  static const String teacherPtmSlots = 'teacher_ptm_slots';

  // Parent
  static const String parentChildren = 'parent_children';
  static const String parentSelectedChild = 'parent_selected_child';
  static const String parentLeaveRequests = 'parent_leave_requests';
  static const String parentMessages = 'parent_messages';
  static const String parentFeePayments = 'parent_fee_payments';
  static const String parentNoticesRead = 'parent_notices_read';
}
