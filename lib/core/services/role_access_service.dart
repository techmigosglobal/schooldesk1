import 'package:schooldesk1/core/network/backend_api_client.dart';

/// Runtime role scope sourced from backend-synced data.
class RoleAccessService {
  RoleAccessService._();

  static bool _initialized = false;
  static bool _signedOut = false;
  static List<Map<String, dynamic>> _students = [];
  static List<Map<String, dynamic>> _teachers = [];
  static List<Map<String, dynamic>> _parentChildren = [];
  static List<Map<String, dynamic>> _todayTimetable = [];
  static List<Map<String, dynamic>> _teacherTimetable = [];
  static List<Map<String, dynamic>> _invoices = [];
  static Map<String, dynamic> _activeTeacher = const {};
  static Map<String, dynamic> _teacherDashboard = const {};
  static List<Map<String, dynamic>> _teacherAssignedClasses = [];

  static Future<void> initialize() async {
    if (_signedOut) return;
    final api = BackendApiClient.instance;
    if (!api.isAuthenticated) {
      _setEmptyScope(initialized: true);
      return;
    }

    final profile = await _try(() => api.getProfile());
    final profileRole = profile?.roleName.trim().toLowerCase();
    api.setCurrentRole(profile?.roleName);
    final teacherDashboard = profileRole == 'teacher'
        ? await _try(() => api.getDashboard('teacher'))
        : null;
    _teacherDashboard = teacherDashboard ?? const {};
    _teacherAssignedClasses = _listMap(_teacherDashboard['assigned_classes'])
        .map(_normalizeTeacherAssignedClass)
        .where((row) {
          return _sectionId(row).isNotEmpty;
        })
        .toList();

    final teacherStaffId = _text(_teacherDashboard['staff_id']);
    final classTeacherRow = _teacherAssignedClasses.firstWhere(
      (row) => _isTrue(row['is_class_teacher']),
      orElse: () => _teacherAssignedClasses.isNotEmpty
          ? _teacherAssignedClasses.first
          : const {},
    );
    final teacherSectionId = _sectionId(classTeacherRow);

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
    var timetable = await _try(
      () => api.getTimetableSlots(
        staffId: teacherStaffId.isEmpty ? null : teacherStaffId,
      ),
    );
    // If no staff-scoped timetable found, try section-scoped timetable as a
    // fallback (some backends store timetables by section rather than staff).
    if ((timetable == null || timetable.isEmpty) && teacherSectionId.isNotEmpty) {
      timetable = await _try(() => api.getTimetableSlots(sectionId: teacherSectionId));
    }
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
    final assignedSubject = _subjectFromTimetable(timetableRows).isNotEmpty
        ? _subjectFromTimetable(timetableRows)
        : _subjectFromAssignments(_teacherAssignedClasses);
    _parentChildren = parentChildren ?? [];
    _teacherTimetable = timetableRows;
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
    _signedOut = true;
    _setEmptyScope(initialized: false);
  }

  /// Reset the signed-out guard so the next login can initialize fresh.
  static void resetSignOutGuard() {
    _signedOut = false;
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

  static List<Map<String, dynamic>> get teacherClassTeacherClasses {
    _ensureInitialized();
    return _teacherAssignedClasses
        .where((row) => _isTrue(row['is_class_teacher']))
        .map((row) => {...row, 'label': _classLabel(row)})
        .toList();
  }

  static List<Map<String, dynamic>> get assignedTeacherClasses =>
      teacherAssignedClasses;

  static Map<String, dynamic> get primaryTeacherClass {
    _ensureInitialized();
    if (_teacherAssignedClasses.isEmpty) return const {};
    return {
      ..._teacherAssignedClasses.first,
      'label': _classLabel(_teacherAssignedClasses.first),
    };
  }

  static List<String> get teacherSectionIds {
    _ensureInitialized();
    return _teacherAssignedClasses
        .map(_sectionId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }

  static List<String> get teacherSubjectIds {
    _ensureInitialized();
    final ids = <String>{};
    for (final row in _teacherAssignedClasses) {
      final subjectId = _text(row['subject_id']);
      if (subjectId.isNotEmpty) ids.add(subjectId);
      final subject = row['subject'];
      if (subject is Map) {
        final id = _text(subject['id'] ?? subject['subject_id']);
        if (id.isNotEmpty) ids.add(id);
      }
      final subjects = row['subjects'];
      if (subjects is List) {
        for (final subject in subjects) {
          if (subject is Map) {
            final id = _text(subject['id'] ?? subject['subject_id']);
            if (id.isNotEmpty) ids.add(id);
          } else {
            final id = _text(subject);
            if (id.isNotEmpty) ids.add(id);
          }
        }
      }
    }
    for (final slot in _teacherTimetable) {
      final id = _text(slot['subject_id']);
      if (id.isNotEmpty) ids.add(id);
    }
    return ids.toList();
  }

  static bool get hasTeacherStaffLink {
    _ensureInitialized();
    return teacherStaffId.isNotEmpty;
  }

  static bool get hasAssignedClasses {
    _ensureInitialized();
    return _teacherAssignedClasses.isNotEmpty;
  }

  static String get teacherScopeStatus {
    _ensureInitialized();
    if (!hasTeacherStaffLink) {
      return 'Your teacher account is not linked to a staff profile. Please contact Admin/Principal.';
    }
    if (!hasAssignedClasses) return 'No classes assigned yet.';
    return '';
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

  static List<Map<String, dynamic>> get teacherTimetable {
    _ensureInitialized();
    return _teacherTimetable.map((e) => Map<String, dynamic>.from(e)).toList();
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
      throw RangeError.index(index, _parentChildren, 'index');
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
    _setEmptyScope(initialized: true);
  }

  static void _setEmptyScope({required bool initialized}) {
    // Best effort defaults before async initialize() runs or after sign-out.
    _initialized = initialized;
    _students = [];
    _teachers = [];
    _parentChildren = [];
    _todayTimetable = [];
    _teacherTimetable = [];
    _invoices = [];
    _activeTeacher = const {};
    _teacherDashboard = const {};
    _teacherAssignedClasses = [];
  }

  static List<Map<String, dynamic>> _filterTodayTimetable(
    List<Map<String, dynamic>> timetable,
  ) {
    final today = DateTime.now().weekday;
    final rows = timetable
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
    rows.sort(
      (a, b) => _timeMinutes(a['time']).compareTo(_timeMinutes(b['time'])),
    );
    return rows;
  }

  static int _timeMinutes(dynamic value) {
    final text = _text(value);
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(text);
    if (match == null) return 24 * 60;
    final hour = int.tryParse(match.group(1) ?? '') ?? 24;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    return hour * 60 + minute;
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

  static String _subjectFromAssignments(List<Map<String, dynamic>> classes) {
    for (final row in classes) {
      final subject = row['subject'];
      if (subject is Map) {
        final label = _text(subject['subject_name']);
        if (label.isNotEmpty) return label;
      }
      final label = _text(row['subject_name'] ?? row['subject']);
      if (label.isNotEmpty &&
          label.toLowerCase() != 'class teacher' &&
          label.toLowerCase() != 'co-teacher') {
        return label;
      }
      final subjects = row['subjects'];
      if (subjects is List) {
        for (final item in subjects) {
          if (item is Map) {
            final nested = _text(item['subject_name']);
            if (nested.isNotEmpty) return nested;
          }
        }
      }
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
      (row) => _sectionId(row) == sectionId,
    );
    if (match.isNotEmpty) return _classLabel(match.first);
    return sectionId;
  }

  static String _sectionLabelForSection(String sectionId) {
    if (sectionId.isEmpty) return '';
    final match = _teacherAssignedClasses.where(
      (row) => _sectionId(row) == sectionId,
    );
    if (match.isNotEmpty) return _text(match.first['section_name']);
    return '';
  }

  static String _classLabelForTimetableSlot(Map<String, dynamic> slot) {
    final section = slot['section'];
    if (section is Map) {
      final grade = _text(section['grade_name']);
      final sectionName = _text(section['section_name']);
      final label = _joinGradeSectionLabel(grade, sectionName);
      if (label.isNotEmpty) return label;
    }
    return _classLabelForSection(_text(slot['section_id']));
  }

  static String _classLabel(Map<String, dynamic> row) {
    final sectionRow = row['section'];
    final gradeRow = row['grade'];
    final nestedGrade = sectionRow is Map ? sectionRow['grade'] : null;
    final grade = _text(
      row['grade_name'] ??
          (nestedGrade is Map ? nestedGrade['grade_name'] : null) ??
          (gradeRow is Map ? gradeRow['grade_name'] : null),
    );
    final section = _text(
      row['section_name'] ??
          (sectionRow is Map ? sectionRow['section_name'] : null),
    );
    final label = _joinGradeSectionLabel(grade, section);
    return label.isNotEmpty ? label : _sectionId(row);
  }

  static Map<String, dynamic> _normalizeTeacherAssignedClass(
    Map<String, dynamic> row,
  ) {
    final section = row['section'];
    final grade = row['grade'];
    final subject = row['subject'];
    final sectionMap = section is Map<String, dynamic>
        ? section
        : section is Map
        ? Map<String, dynamic>.from(section)
        : const <String, dynamic>{};
    final gradeMap = grade is Map<String, dynamic>
        ? grade
        : grade is Map
        ? Map<String, dynamic>.from(grade)
        : const <String, dynamic>{};
    final subjectMap = subject is Map<String, dynamic>
        ? subject
        : subject is Map
        ? Map<String, dynamic>.from(subject)
        : const <String, dynamic>{};
    final nestedGrade = sectionMap['grade'];
    final nestedGradeMap = nestedGrade is Map<String, dynamic>
        ? nestedGrade
        : nestedGrade is Map
        ? Map<String, dynamic>.from(nestedGrade)
        : const <String, dynamic>{};
    final sectionId = _text(row['section_id'] ?? sectionMap['id'] ?? row['id']);
    final assignmentId = _text(row['assignment_id']).isNotEmpty
        ? _text(row['assignment_id'])
        : (_text(row['section_id']).isNotEmpty && _text(row['id']) != sectionId
              ? _text(row['id'])
              : '');
    final subjectId = _text(
      row['subject_id'] ?? subjectMap['id'] ?? subjectMap['subject_id'],
    );
    final subjectName = _text(
      row['subject_name'] ?? subjectMap['subject_name'] ?? row['subject'],
    );
    final rawSubjects = row['subjects'];
    final subjects = rawSubjects is List
        ? rawSubjects.map((entry) {
            if (entry is Map<String, dynamic>) return entry;
            if (entry is Map) return Map<String, dynamic>.from(entry);
            return {'id': _text(entry), 'subject_id': _text(entry)};
          }).toList()
        : <Map<String, dynamic>>[
            if (subjectId.isNotEmpty || subjectName.isNotEmpty)
              {
                if (subjectId.isNotEmpty) 'id': subjectId,
                if (subjectId.isNotEmpty) 'subject_id': subjectId,
                if (subjectName.isNotEmpty) 'subject_name': subjectName,
              },
          ];
    return {
      ...row,
      'id': sectionId,
      'section_id': sectionId,
      if (assignmentId.isNotEmpty) 'assignment_id': assignmentId,
      'grade_name': _text(
        row['grade_name'] ??
            nestedGradeMap['grade_name'] ??
            gradeMap['grade_name'],
      ),
      'section_name': _text(row['section_name'] ?? sectionMap['section_name']),
      'subject_id': subjectId,
      'subject_name': subjectName,
      'subject': subjectMap.isEmpty ? row['subject'] : subjectMap,
      'grade': gradeMap.isEmpty ? row['grade'] : gradeMap,
      'section': sectionMap.isEmpty ? row['section'] : sectionMap,
      'subjects': subjects,
      'is_class_teacher': _isTrue(row['is_class_teacher']),
      'is_co_teacher': _isTrue(row['is_co_teacher']),
    };
  }

  static String _sectionId(Map<String, dynamic> row) {
    return _text(row['section_id'] ?? row['id']);
  }

  static String _joinGradeSectionLabel(String grade, String section) {
    if (grade.isEmpty) return section;
    if (section.isEmpty) return grade;
    final normalizedGrade = grade.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final normalizedSection = section.toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '',
    );
    if (normalizedGrade.endsWith('-$normalizedSection') ||
        normalizedGrade.endsWith(normalizedSection)) {
      return grade;
    }
    return '$grade $section';
  }

  static Future<T?> _try<T>(Future<T> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return null;
    }
  }

  static bool _isTrue(dynamic value) {
    if (value is bool) return value;
    return value?.toString().trim().toLowerCase() == 'true';
  }
}
