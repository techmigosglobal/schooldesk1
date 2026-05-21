class SchoolDeskGlossary {
  SchoolDeskGlossary._();

  static const principal = 'Principal';
  static const admin = 'Admin';
  static const teacher = 'Teacher';
  static const parent = 'Parent';

  static const dashboard = 'Dashboard';
  static const home = 'Home';
  static const notifications = 'Notifications';
  static const profile = 'Profile';
  static const settings = 'Settings';
  static const search = 'Search';
  static const globalSearch = 'Global Search';
  static const signOut = 'Sign Out';

  static const schoolProfile = 'School Profile';
  static const accessPermissions = 'Access & Permissions';
  static const students = 'Students';
  static const studentOversight = 'Student Oversight';
  static const staff = 'Staff';
  static const staffOversight = 'Staff Oversight';
  static const attendance = 'Attendance';
  static const approvalCenter = 'Approval Center';
  static const fees = 'Fees';
  static const feeMonitoring = 'Fee Monitoring';
  static const timetable = 'Timetable';
  static const timetableRecords = 'Timetable Records';
  static const syllabus = 'Syllabus';
  static const syllabusRecords = 'Syllabus Records';
  static const exams = 'Exams';
  static const examRecords = 'Exam Records';
  static const academics = 'Academics';
  static const academicInfo = 'Academic Info';
  static const academicManagement = 'Academic Management';
  static const academicRecords = 'Academic Records';
  static const communication = 'Communication';
  static const communicationCenter = 'Communication Center';
  static const complaints = 'Complaints';
  static const helpdesk = 'Helpdesk';
  static const calendar = 'Calendar';
  static const reports = 'Reports';
  static const analytics = 'Analytics';
  static const documents = 'Documents';
  static const access = 'Access';
  static const idCards = 'ID Cards';

  static String roleLabel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'principal':
      case 'principle':
        return principal;
      case 'admin':
        return admin;
      case 'teacher':
        return teacher;
      case 'parent':
        return parent;
      default:
        return role.trim().isEmpty ? 'SchoolDesk' : role.trim();
    }
  }

  static String portalLabel(String role) {
    final label = roleLabel(role);
    return label == 'SchoolDesk' ? label : '$label Portal';
  }
}
