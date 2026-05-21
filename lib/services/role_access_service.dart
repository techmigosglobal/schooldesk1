import 'backend_api_client.dart';

/// Runtime role scope sourced from backend-synced data.
class RoleAccessService {
  RoleAccessService._();

  static bool _initialized = false;
  static List<Map<String, dynamic>> _students = [];
  static List<Map<String, dynamic>> _teachers = [];
  static List<Map<String, dynamic>> _parentChildren = [];
  static List<Map<String, dynamic>> _todayTimetable = [];
  static List<Map<String, dynamic>> _invoices = [];
  static Map<String, dynamic> _activeTeacher = const {};
  static Map<String, dynamic> _teacherDashboard = const {};
  static List<Map<String, dynamic>> _teacherAssignedClasses = [];

  static Future<void> initialize() async {
    final api = BackendApiClient.instance;
    final profile = await _try(() => api.getProfile());
    final profileRole = profile?.roleName.trim().toLowerCase();
    api.setCurrentRole(profile?.roleName);
    final teacherDashboard = profileRole == 'teacher'
        ? await _try(() => api.getDashboard('teacher'))
        : null;
    _teacherDashboard = teacherDashboard ?? const {};
    _teacherAssignedClasses = _listMap(_teacherDashboard['assigned_classes']);

    final teacherStaffId = _text(_teacherDashboard['staff_id']);
    final teacherSectionId = _teacherAssignedClasses.isNotEmpty
        ? _text(_teacherAssignedClasses.first['id'])
        : '';

    final students = await _try(
      () => api.getStudents(
        sectionId: teacherSectionId.isEmpty ? null : teacherSectionId,
        page: 1,
        pageSize: 100,
      ),
    );
    final staff = profileRole == 'teacher'
        ? null
        : await _try(() => api.getStaff(page: 1, pageSize: 100));
    final parentChildren = profileRole == 'parent'
        ? await _try(() => api.getMyStudents())
        : <Map<String, dynamic>>[];
    final timetable = await _try(
      () => api.getTimetableSlots(
        staffId: teacherStaffId.isEmpty ? null : teacherStaffId,
      ),
    );
    final invoices = profileRole == 'teacher'
        ? <Map<String, dynamic>>[]
        : await _try(() => api.getInvoices());

    _students = (students?.data ?? [])
        .map(
          (s) => {
            'id': s.id,
            'name': s.fullName,
            'class_id': s.currentSectionId ?? '',
            'class': _classLabelForSection(s.currentSectionId ?? ''),
            'section': _sectionLabelForSection(s.currentSectionId ?? ''),
            'roll': s.admissionNumber.isNotEmpty
                ? s.admissionNumber
                : s.studentCode,
            'admission_number': s.admissionNumber,
            'student_code': s.studentCode,
            'attendance': 'Not marked',
            'grade': 'N/A',
            'status': s.status,
          },
        )
        .toList();
    _teachers = (staff?.data ?? [])
        .map(
          (s) => {
            'id': s.id,
            'name': '${s.firstName} ${s.lastName}',
            'subject': s.designation ?? 'General',
            'class': '',
            'assignedClass': '',
            'email': s.email ?? '',
            'phone': s.phone ?? '',
            'status': s.status,
          },
        )
        .toList();
    final timetableRows = timetable ?? [];
    final assignedSubject = _subjectFromTimetable(timetableRows);
    _parentChildren = parentChildren ?? [];
    _todayTimetable = _filterTodayTimetable(timetableRows);
    _invoices = invoices ?? [];

    if (profileRole == 'teacher') {
      final profileEmail = profile?.email.trim().toLowerCase() ?? '';
      final matches = _teachers.where(
        (teacher) =>
            profileEmail.isNotEmpty &&
            teacher['email']?.toString().trim().toLowerCase() == profileEmail,
      );
      _activeTeacher = {
        if (matches.isNotEmpty) ...matches.first,
        'id': teacherStaffId.isNotEmpty ? teacherStaffId : profile?.id ?? '',
        'user_id': profile?.id ?? '',
        'name': _displayName(profile),
        'subject': assignedSubject.isNotEmpty ? assignedSubject : 'General',
        'class_id': teacherSectionId,
        'class': _classLabelForSection(teacherSectionId),
        'assignedClass': _classLabelForSection(teacherSectionId),
        'email': profile?.email ?? '',
        'phone': profile?.phone ?? '',
        'status': profile?.isActive == false ? 'inactive' : 'active',
      };
    } else if (_teachers.isNotEmpty) {
      _activeTeacher = _teachers.first;
    } else {
      _activeTeacher = const {};
    }
    _initialized = true;
  }

  static void clear() {
    _initialized = false;
    _students = [];
    _teachers = [];
    _parentChildren = [];
    _todayTimetable = [];
    _invoices = [];
    _activeTeacher = const {};
    _teacherDashboard = const {};
    _teacherAssignedClasses = [];
  }

  static Map<String, dynamic> get loggedInTeacher {
    _ensureInitialized();
    return _activeTeacher;
  }

  static List<Map<String, dynamic>> get loggedInParentChildren {
    _ensureInitialized();
    return List.unmodifiable(_parentChildren);
  }

  static Map<String, dynamic> get teacherAssignedClass {
    _ensureInitialized();
    final className = teacherClassName;
    final match = adminAllClasses.where((c) => c['name'] == className);
    if (match.isNotEmpty) {
      return Map<String, dynamic>.from(match.first);
    }
    return {
      'name': className,
      'subjects': teacherClassSubjects,
      'sections': ['A'],
    };
  }

  static String get teacherClassName {
    _ensureInitialized();
    final className =
        (_activeTeacher['assignedClass'] ?? _activeTeacher['class'])
            ?.toString()
            .trim();
    return (className == null || className.isEmpty)
        ? 'Not assigned'
        : className;
  }

  static String get teacherClassId {
    _ensureInitialized();
    return _text(_activeTeacher['class_id']);
  }

  static String get teacherStaffId {
    _ensureInitialized();
    return _text(_activeTeacher['id']);
  }

  static String get teacherUserId {
    _ensureInitialized();
    return _text(_activeTeacher['user_id']);
  }

  static String get teacherSubject {
    _ensureInitialized();
    final subject = _activeTeacher['subject']?.toString().trim();
    return (subject == null || subject.isEmpty) ? 'General' : subject;
  }

  static String get teacherName {
    _ensureInitialized();
    final name = _activeTeacher['name']?.toString().trim();
    return (name == null || name.isEmpty) ? 'Teacher' : name;
  }

  static int get teacherLeaveBalance {
    _ensureInitialized();
    final raw = _activeTeacher['leaveBalance'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static List<Map<String, dynamic>> get teacherClassStudents {
    _ensureInitialized();
    final classId = teacherClassId;
    final className = teacherClassName;
    return _students
        .where(
          (s) => classId.isNotEmpty
              ? (s['class_id']?.toString() ?? '') == classId
              : (s['class']?.toString() ?? '') == className,
        )
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static List<Map<String, dynamic>> get teacherAssignedClasses {
    _ensureInitialized();
    return _teacherAssignedClasses
        .map((row) => {...row, 'label': _classLabel(row)})
        .toList();
  }

  static Map<String, dynamic> get teacherDashboardMetrics {
    _ensureInitialized();
    final metrics = _teacherDashboard['metrics'];
    return metrics is Map ? Map<String, dynamic>.from(metrics) : const {};
  }

  static int get teacherHomeworkDue {
    _ensureInitialized();
    return _intValue(teacherDashboardMetrics['homework_due']);
  }

  static int get teacherUnreadMessages {
    _ensureInitialized();
    return _intValue(teacherDashboardMetrics['unread_messages']);
  }

  static List<String> get teacherClassSubjects {
    _ensureInitialized();
    final classData = teacherAssignedClass;
    final subjects = classData['subjects'];
    if (subjects is List) {
      return subjects.map((e) => e.toString()).toList();
    }
    return [teacherSubject];
  }

  static List<Map<String, dynamic>> get teacherTimetableToday {
    _ensureInitialized();
    return _todayTimetable.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static List<Map<String, dynamic>> get parentChildren {
    _ensureInitialized();
    return List.unmodifiable(_parentChildren);
  }

  static Map<String, dynamic> childAt(int index) {
    _ensureInitialized();
    if (_parentChildren.isEmpty) {
      return const {};
    }
    if (index < 0 || index >= _parentChildren.length) {
      return _parentChildren.first;
    }
    return _parentChildren[index];
  }

  static List<String> get parentChildNames {
    _ensureInitialized();
    return _parentChildren
        .map((c) => '${c['name'] ?? 'Student'} (${c['class'] ?? '-'})')
        .toList();
  }

  static List<Map<String, dynamic>> get adminAllClasses {
    _ensureInitialized();
    final classes = <String, Map<String, dynamic>>{};
    for (final s in _students) {
      final name = (s['class'] ?? '').toString();
      if (name.isEmpty) continue;
      classes.putIfAbsent(
        name,
        () => {
          'name': name,
          'sections': [(s['section'] ?? 'A').toString()],
          'subjects': <String>[],
          'strength': 0,
        },
      );
      classes[name]!['strength'] = (classes[name]!['strength'] as int) + 1;
    }
    return classes.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static List<Map<String, dynamic>> get adminAllTeachers {
    _ensureInitialized();
    return _teachers.map((t) => Map<String, dynamic>.from(t)).toList();
  }

  static List<Map<String, dynamic>> get principalAllClasses => adminAllClasses;

  static List<Map<String, dynamic>> get principalAllTeachers =>
      adminAllTeachers;

  static int get principalTotalStudents {
    _ensureInitialized();
    return _students.length;
  }

  static List<Map<String, dynamic>> get allInvoices {
    _ensureInitialized();
    return _invoices.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Map<String, double> get feeKPIs {
    _ensureInitialized();
    final invoices = allInvoices;
    double totalBilled = 0;
    double totalCollected = 0;
    for (final inv in invoices) {
      final billed =
          (inv['total_amount'] as num?)?.toDouble() ??
          (inv['net_amount'] as num?)?.toDouble() ??
          (inv['amount'] as num?)?.toDouble() ??
          0;
      final paid =
          (inv['paid_amount'] as num?)?.toDouble() ??
          (billed - ((inv['balance'] as num?)?.toDouble() ?? 0)).clamp(
            0,
            billed,
          );
      totalBilled += billed;
      totalCollected += paid;
    }
    return {
      'totalBilled': totalBilled,
      'totalCollected': totalCollected,
      'pending': totalBilled - totalCollected,
      'collectionRate': totalBilled > 0
          ? (totalCollected / totalBilled) * 100
          : 0.0,
    };
  }

  static void _ensureInitialized() {
    if (_initialized) return;
    // Best effort defaults before async initialize() runs.
    _students = [];
    _teachers = [];
    _parentChildren = [];
    _todayTimetable = [];
    _invoices = [];
    _activeTeacher = const {};
    _teacherDashboard = const {};
    _teacherAssignedClasses = [];
    _initialized = true;
  }

  static List<Map<String, dynamic>> _filterTodayTimetable(
    List<Map<String, dynamic>> timetable,
  ) {
    final today = DateTime.now().weekday;
    return timetable
        .where((slot) => slot['day_of_week'] == today)
        .map(
          (slot) => {
            'period': slot['period_number']?.toString() ?? '-',
            'subject':
                slot['subject']?['subject_name'] ?? slot['subject_id'] ?? '',
            'class': _classLabelForTimetableSlot(slot),
            'section_id': slot['section_id'] ?? '',
            'subject_id': slot['subject_id'] ?? '',
            'time':
                '${slot['start_time'] ?? ''}${slot['end_time'] == null ? '' : ' - ${slot['end_time']}'}',
            'room': slot['room'] ?? slot['room_number'] ?? '',
            'done': false,
          },
        )
        .toList();
  }

  static String _subjectFromTimetable(List<Map<String, dynamic>> timetable) {
    for (final slot in timetable) {
      final subject = slot['subject'];
      if (subject is Map) {
        final label = _text(subject['subject_name']);
        if (label.isNotEmpty) return label;
      }
      final label = _text(slot['subject_name']);
      if (label.isNotEmpty) return label;
      final rawSubject = _text(slot['subject']);
      if (rawSubject.isNotEmpty) return rawSubject;
    }
    return '';
  }

  static String _displayName(UserResponse? profile) {
    final name = profile?.name.trim() ?? '';
    if (name.isNotEmpty) return name;
    final username = profile?.username.trim() ?? '';
    if (username.isNotEmpty) return username;
    final email = profile?.email.trim() ?? '';
    return email.isNotEmpty ? email : 'Teacher';
  }

  static List<Map<String, dynamic>> _listMap(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _classLabelForSection(String sectionId) {
    if (sectionId.isEmpty) return '';
    final match = _teacherAssignedClasses.where(
      (row) => _text(row['id']) == sectionId,
    );
    if (match.isNotEmpty) return _classLabel(match.first);
    return sectionId;
  }

  static String _sectionLabelForSection(String sectionId) {
    if (sectionId.isEmpty) return '';
    final match = _teacherAssignedClasses.where(
      (row) => _text(row['id']) == sectionId,
    );
    if (match.isNotEmpty) return _text(match.first['section_name']);
    return '';
  }

  static String _classLabelForTimetableSlot(Map<String, dynamic> slot) {
    final section = slot['section'];
    if (section is Map) {
      final grade = _text(section['grade_name']);
      final sectionName = _text(section['section_name']);
      final label = [
        grade,
        sectionName,
      ].where((part) => part.isNotEmpty).join(' ');
      if (label.isNotEmpty) return label;
    }
    return _classLabelForSection(_text(slot['section_id']));
  }

  static String _classLabel(Map<String, dynamic> row) {
    final grade = _text(row['grade_name']);
    final section = _text(row['section_name']);
    final label = [grade, section].where((part) => part.isNotEmpty).join(' ');
    return label.isNotEmpty ? label : _text(row['id']);
  }

  static Future<T?> _try<T>(Future<T> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return null;
    }
  }
}
