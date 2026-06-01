import 'package:schooldesk1/core/network/backend_api_client.dart';

class BackendDataService {
  BackendDataService._();

  static final BackendDataService instance = BackendDataService._();
  static Future<BackendDataService> getInstance() async => instance;

  static const String kStudents = 'principal_students';
  static const String kFeeStructures = 'principal_fee_structures';
  static const String kStudentFees = 'principal_student_fees';
  static const String kConcessionRequests = 'principal_concession_requests';
  static const String kTimetable = 'principal_timetable';
  static const String kSubstituteRequests = 'principal_substitute_requests';
  static const String kSyllabusData = 'principal_syllabus_data';
  static const String kExamSchedule = 'principal_exam_schedule';
  static const String kExamResults = 'principal_exam_results';
  static const String kComplaints = 'principal_complaints';
  static const String kCirculars = 'principal_circulars';
  static const String kNotices = 'principal_notices';
  static const String kEvents = 'principal_events';
  static const String kHolidays = 'principal_holidays';
  static const String kAcademicYears = 'academic_years';
  static const String kAcademicSubjects = 'academic_subjects';
  static const String kAcademicClasses = 'academic_classes';
  static const String kAcademicCurriculum = 'academic_curriculum';
  static const String kActiveAcademicYear = 'active_academic_year';
  static const String kSharedCurriculum = 'shared_curriculum';
  static const String kAdminStudents = 'admin_students';
  static const String kAdminTeachers = 'admin_teachers';
  static const String kAdminLeaveRequests = 'admin_leave_requests';
  static const String kAdminAttendanceRecords = 'admin_attendance_records';
  static const String kAdminAttendanceExceptions =
      'admin_attendance_exceptions';
  static const String kAdminFeeStructures = 'admin_fee_structures';
  static const String kAdminPendingDues = 'admin_pending_dues';
  static const String kAdminRecentPayments = 'admin_recent_payments';
  static const String kAdminExams = 'admin_exams';
  static const String kAdminSeatings = 'admin_seatings';
  static const String kTeacherAttendance = 'teacher_attendance';
  static const String kTeacherHomework = 'teacher_homework';
  static const String kTeacherSyllabus = 'teacher_syllabus';
  static const String kTeacherWeeklyPlan = 'teacher_weekly_plan';
  static const String kTeacherNotes = 'teacher_notes';
  static const String kParentChildren = 'parent_children';
  static const String kParentFeeStructure = 'parent_fee_structure';
  static const String kParentPaymentHistory = 'parent_payment_history';
  static const String kParentAttendanceHistory = 'parent_attendance_history';
  static const String kParentLeaveRequests = 'parent_leave_requests';
  static const String kParentHomework = 'parent_homework';
  static const String kSharedLeaveRequests = 'shared_leave_requests';
  static const String kSharedDisciplineIncidents =
      'shared_discipline_incidents';
  static const String kSharedHelpdeskTickets = 'shared_helpdesk_tickets';
  static const String kSharedSchoolNotices = 'shared_school_notices';
  static const String kSharedPtmMeetings = 'shared_ptm_meetings';
  static const String kSharedParentLeaveRequests =
      'shared_parent_leave_requests';
  static const String kRuntimeNotifications = 'app_notifications';

  final BackendApiClient _api = BackendApiClient.instance;
  static const int _defaultDirectoryPageSize = 200;
  static const int _maxDirectoryPageSize = 500;

  Future<List<Map<String, dynamic>>> getList(String key) async {
    switch (key) {
      case kStudents:
      case kAdminStudents:
      case kParentChildren:
        return (await _fetchAll(
          (page, pageSize) => _api.getStudents(page: page, pageSize: pageSize),
        )).map(_studentDirectoryMap).toList();
      case kAdminTeachers:
        return (await _fetchAll(
              (page, pageSize) => _api.getStaff(page: page, pageSize: pageSize),
            ))
            .map(
              (s) => {
                'id': s.id,
                'name': s.fullName,
                'employeeId': s.staffCode,
                'designation': s.designation,
                'email': s.email,
                'phone': s.phone,
                'status': s.status,
              },
            )
            .toList();
      case kAdminAttendanceRecords:
        final students = await _fetchAll(
          (page, pageSize) => _api.getStudents(page: page, pageSize: pageSize),
        );
        final rows = <Map<String, dynamic>>[];
        for (final student in students) {
          final summary = await _api.getStudentAttendanceSummary(
            studentId: student.id,
          );
          rows.add({
            'class': (student.currentSectionId ?? '').isEmpty
                ? 'Unassigned'
                : student.currentSectionId,
            'student_id': student.id,
            'student_name': student.fullName,
            'present': summary['present_days'] ?? 0,
            'total': summary['total_days'] ?? 0,
            'percent': summary['percentage'] ?? 0,
          });
        }
        return rows;
      case kAcademicYears:
        return (await _api.getAcademicYears())
            .map(
              (y) => {
                'id': y.id,
                'school_id': y.schoolId,
                'year_label': y.yearLabel,
                'name': y.yearLabel,
                'start': _dateLabel(y.startDate),
                'end': _dateLabel(y.endDate),
                'start_date': y.startDate,
                'end_date': y.endDate,
                'is_current': y.isCurrent,
                'status': y.isCurrent ? 'active' : y.status,
              },
            )
            .toList();
      case kAcademicSubjects:
        return (await _api.getRawList('/subjects'))
            .map(
              (s) => {
                ...s,
                'name': s['subject_name'] ?? s['name'] ?? '',
                'code': s['subject_code'] ?? s['code'] ?? '',
                'type': s['subject_type'] ?? s['type'] ?? 'Core',
                'periodsPerWeek': s['periods_per_week'] ?? 5,
              },
            )
            .toList();
      case kAcademicClasses:
        final grades = await _api.getGrades();
        final sections = await _api.getSections();
        return grades.map((g) {
          final gradeSections = sections
              .where((s) => s.gradeId == g.id)
              .toList();
          final classTeacherIds = gradeSections
              .map((s) => s.classTeacherId)
              .where((id) => id.isNotEmpty)
              .toSet();
          final classTeacherNames = gradeSections
              .map((s) => s.classTeacherName)
              .where((name) => name.isNotEmpty)
              .toSet();
          final sectionIds = {
            for (final section in gradeSections)
              section.sectionName: section.id,
          };
          final sectionTeacherIds = {
            for (final section in gradeSections)
              section.sectionName: section.classTeacherId,
          };
          return {
            'id': g.id,
            'grade_id': g.id,
            'grade_number': g.gradeNumber,
            'name': g.gradeName,
            'sections': gradeSections.map((s) => s.sectionName).toList(),
            'sectionIds': sectionIds,
            'sectionTeacherIds': sectionTeacherIds,
            'strength': gradeSections.isEmpty
                ? 40
                : gradeSections.first.capacity,
            'academic_year_id': gradeSections.isEmpty
                ? ''
                : gradeSections.first.academicYearId,
            'classTeacher': classTeacherNames.length == 1
                ? classTeacherNames.first
                : classTeacherNames.length > 1
                ? 'Multiple class teachers'
                : '',
            'classTeacherId': classTeacherIds.length == 1
                ? classTeacherIds.first
                : '',
            'classTeacherIds': classTeacherIds.toList(),
          };
        }).toList();
      case kAcademicCurriculum:
      case kSharedCurriculum:
        return await _api.getRawList('/curriculum');
      case kFeeStructures:
      case kAdminFeeStructures:
      case kParentFeeStructure:
        return await _api.getFeeStructures();
      case kStudentFees:
      case kAdminPendingDues:
      case kAdminRecentPayments:
      case kParentPaymentHistory:
        return await _fetchAll(
          (page, pageSize) =>
              _api.getInvoicesPage(page: page, pageSize: pageSize),
        );
      case kRuntimeNotifications:
        return await _api.getNotifications();
      case kSharedSchoolNotices:
      case kNotices:
      case kCirculars:
        return (await _api.getAnnouncements())
            .map(
              (a) => {
                'id': a.id,
                'title': a.title,
                'body': a.content,
                'content': a.content,
                'target_audience': a.targetAudience,
                'urgent': a.isUrgent,
                'is_urgent': a.isUrgent,
                'status': 'Published',
                'date': a.publishedAt,
                'created_by': a.createdBy,
              },
            )
            .toList();
      case kEvents:
      case kHolidays:
        return await _api.getEvents();
      case kTimetable:
        return await _api.getTimetableSlots();
      case kSubstituteRequests:
        return await _api.getSubstitutions();
      case kSyllabusData:
        return await _api.getRawList('/syllabus');
      case kExamSchedule:
        return (await _api.getRawList(
          '/exams/schedules',
        )).map(_principalExamSchedule).toList();
      case kExamResults:
        return (await _api.getRawList(
          '/exams/report-cards',
        )).map(_principalExamResult).toList();
      case kAdminExams:
        return (await _api.getExams())
            .map(
              (e) => {
                'id': e.id,
                'school_id': e.schoolId,
                'academic_year_id': e.academicYearId,
                'term_id': e.termId,
                'exam_type_id': e.examTypeId,
                'exam_name': e.examName,
                'name': e.examName,
                'start_date': e.startDate,
                'end_date': e.endDate,
                'is_published': e.isPublished,
              },
            )
            .toList();
      case kTeacherHomework:
      case kParentHomework:
        return await _api.getRawList('/homework');
      case kTeacherNotes:
      case kTeacherWeeklyPlan:
        return await _api.getRawList('/diary-entries');
      case kSharedPtmMeetings:
        return await _api.getRawList('/parent-teacher-meetings');
      case kSharedLeaveRequests:
      case kSharedParentLeaveRequests:
      case kParentLeaveRequests:
      case kAdminLeaveRequests:
        return (await _api.getLeaveApplications())
            .map(
              (l) => {
                'id': l.id,
                'staff_id': l.staffId,
                'leave_type_id': l.leaveTypeId,
                'from_date': l.fromDate,
                'to_date': l.toDate,
                'half_day': l.halfDay,
                'total_days': l.totalDays,
                'reason': l.reason,
                'status': l.status,
                'rejection_reason': l.rejectionReason,
              },
            )
            .toList();
      case kComplaints:
        return await _api.getRawList('/complaints');
      case kSharedDisciplineIncidents:
        return await _api.getRawList('/discipline-incidents');
      case kSharedHelpdeskTickets:
        return await _api.getRawList('/helpdesk-tickets');
      default:
        return <Map<String, dynamic>>[];
    }
  }

  Future<List<T>> _fetchAll<T>(
    Future<PaginatedList<T>> Function(int page, int pageSize) fetchPage, {
    int pageSize = _defaultDirectoryPageSize,
  }) async {
    final effectivePageSize = pageSize.clamp(1, _maxDirectoryPageSize).toInt();
    final rows = <T>[];
    var page = 1;

    while (true) {
      final result = await fetchPage(page, effectivePageSize);
      rows.addAll(result.data);
      if (!result.hasMore || result.data.isEmpty) break;
      page += 1;
    }

    return rows;
  }

  Future<Map<String, dynamic>?> getMap(String key) async {
    if (key == kActiveAcademicYear) {
      final years = await _api.getAcademicYears();
      final current = years.where((y) => y.isCurrent).toList();
      if (current.isEmpty) return null;
      final y = current.first;
      return {
        'id': y.id,
        'school_id': y.schoolId,
        'year_label': y.yearLabel,
        'name': y.yearLabel,
        'start_date': y.startDate,
        'end_date': y.endDate,
        'is_current': y.isCurrent,
        'status': y.status,
      };
    }
    final rows = await getList(key);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> ensureAcademicManagementLoaded() async {}

  Future<void> saveAcademicYearRecord(Map<String, dynamic> row) async {
    await _saveAcademicYear(row);
  }

  Future<void> deleteAcademicYearRecord(String id) async {
    final value = id.trim();
    if (value.isEmpty) return;
    await _api.deleteRaw('/academic-years/$value');
  }

  Future<void> saveAcademicSubjectRecord(Map<String, dynamic> row) async {
    await _saveSubject(row);
  }

  Future<void> deleteAcademicSubjectRecord(String id) async {
    final value = id.trim();
    if (value.isEmpty) return;
    await _api.deleteRaw('/subjects/$value');
  }

  Future<void> saveAcademicClassRecord(Map<String, dynamic> row) async {
    await _saveClass(row);
  }

  Future<void> deleteAcademicClassRecord(Map<String, dynamic> row) async {
    final gradeId = '${row['grade_id'] ?? row['id'] ?? ''}'.trim();
    if (gradeId.isEmpty || gradeId.startsWith('cls')) return;
    final yearId = '${row['academic_year_id'] ?? ''}'.trim();
    final allSections = await _api.getSections(gradeId: gradeId);
    final sections = yearId.isEmpty
        ? allSections
        : allSections.where((s) => s.academicYearId == yearId).toList();
    for (final section in sections) {
      await _api.deleteRaw('/sections/${section.id}');
    }
    final remainingSections = await _api.getSections(gradeId: gradeId);
    if (remainingSections.isEmpty) {
      await _api.deleteRaw('/grades/$gradeId');
    }
  }

  Future<void> saveAcademicCurriculumRecord(Map<String, dynamic> row) async {
    await _saveFrontendRecord('/curriculum', row);
  }

  Future<void> deleteAcademicCurriculumRecord(String id) async {
    final value = id.trim();
    if (value.isEmpty) return;
    await _api.deleteRaw('/curriculum/$value');
  }

  Future<void> saveList(String key, List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return;
    final latest = data.last;
    switch (key) {
      case kAcademicYears:
        await saveAcademicYearRecord(latest);
        return;
      case kAcademicSubjects:
        await saveAcademicSubjectRecord(latest);
        return;
      case kAcademicClasses:
        await saveAcademicClassRecord(latest);
        return;
      case kAcademicCurriculum:
      case kSharedCurriculum:
        await saveAcademicCurriculumRecord(latest);
        return;
      case kSyllabusData:
        await _saveFrontendRecord('/syllabus', latest);
        return;
      case kSharedSchoolNotices:
      case kNotices:
        await _api.createAnnouncement(
          title: '${latest['title'] ?? 'Notice'}',
          content: '${latest['body'] ?? latest['content'] ?? ''}',
          targetAudience: '${latest['target_audience'] ?? 'all'}',
          isUrgent: latest['urgent'] == true || latest['is_urgent'] == true,
        );
        return;
      case kSharedPtmMeetings:
        await _api.createRaw('/parent-teacher-meetings', latest);
        return;
      case kTeacherNotes:
      case kTeacherWeeklyPlan:
        await _api.createRaw('/diary-entries', latest);
        return;
      case kSharedLeaveRequests:
      case kSharedParentLeaveRequests:
      case kParentLeaveRequests:
      case kAdminLeaveRequests:
        await _api.createRaw('/leave/applications', latest);
        return;
      case kComplaints:
        await _saveMutableFrontendRecord('/complaints', latest);
        return;
      case kSharedDisciplineIncidents:
        await _saveMutableFrontendRecord('/discipline-incidents', latest);
        return;
      case kSharedHelpdeskTickets:
        await _saveMutableFrontendRecord('/helpdesk-tickets', latest);
        return;
      default:
        return;
    }
  }

  Future<void> saveMap(String key, Map<String, dynamic> data) async {
    if (key == kActiveAcademicYear) {
      await _saveAcademicYear({
        ...data,
        'status': 'active',
        'is_current': true,
      });
    }
  }

  Future<void> _saveAcademicYear(Map<String, dynamic> row) async {
    final payload = {
      'year_label': '${row['name'] ?? row['year_label'] ?? row['year'] ?? ''}',
      'start_date': _dateValue(row['start_date'] ?? row['start'], start: true),
      'end_date': _dateValue(row['end_date'] ?? row['end'], start: false),
      'is_current':
          row['is_current'] == true || '${row['status'] ?? ''}' == 'active',
    };
    final id = '${row['id'] ?? ''}';
    if (id.startsWith('ay') || id.isEmpty) {
      await _api.createRaw('/academic-years', payload);
    } else {
      await _api.updateRaw('/academic-years/$id', payload);
    }
  }

  Future<void> _saveSubject(Map<String, dynamic> row) async {
    final payload = {
      'subject_name': '${row['name'] ?? row['subject_name'] ?? ''}',
      'subject_code': '${row['code'] ?? row['subject_code'] ?? ''}',
      'subject_type': '${row['type'] ?? row['subject_type'] ?? 'Core'}',
      'department_name': '${row['department_name'] ?? 'Academics'}',
      'credit_hours': 0,
    };
    final id = '${row['id'] ?? ''}';
    if (id.startsWith('sub') || id.isEmpty) {
      await _api.createRaw('/subjects', payload);
    } else {
      await _api.updateRaw('/subjects/$id', payload);
    }
  }

  Future<void> _saveClass(Map<String, dynamic> row) async {
    final id = '${row['id'] ?? ''}';
    if (!id.startsWith('cls') && id.isNotEmpty) {
      await _updateClass(row);
      return;
    }
    final name = '${row['name'] ?? ''}'.trim();
    final sections = (row['sections'] as List? ?? const ['A'])
        .map((e) => '$e'.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final effectiveSections = sections.isEmpty ? const ['A'] : sections;
    final strength = row['strength'] ?? 40;
    final classTeacherId =
        '${row['classTeacherId'] ?? row['class_teacher_id'] ?? ''}'.trim();
    if (row['request_principal_approval'] == true) {
      await _api.createRaw('/class-approvals', {
        'class_name': name,
        'sections': effectiveSections,
        'capacity': strength,
        'strength': strength,
        'class_teacher_id': classTeacherId,
        'academic_year_id': '${row['academic_year_id'] ?? ''}',
        'details':
            'Admin requested creation from Academic Management. Principal approval required before the class becomes active.',
      });
      return;
    }
    final gradeNumber =
        int.tryParse(RegExp(r'\d+').firstMatch(name)?.group(0) ?? '') ?? 1;
    final grade = await _api.createRaw('/grades', {
      'grade_number': gradeNumber,
      'grade_name': name.isEmpty ? 'Class $gradeNumber' : name,
    });
    final gradeId = '${grade['id'] ?? ''}';
    if (gradeId.isEmpty) return;
    final year = await getMap(kActiveAcademicYear);
    final yearId = '${year?['id'] ?? ''}';
    if (yearId.isEmpty) return;
    for (final section in effectiveSections) {
      await _api.createRaw('/sections', {
        'grade_id': gradeId,
        'academic_year_id': yearId,
        'section_name': section,
        if (classTeacherId.isNotEmpty) 'class_teacher_id': classTeacherId,
        'capacity': strength,
      });
    }
  }

  Future<void> _updateClass(Map<String, dynamic> row) async {
    final gradeId = '${row['grade_id'] ?? row['id'] ?? ''}'.trim();
    if (gradeId.isEmpty) return;
    final name = '${row['name'] ?? ''}'.trim();
    final gradeNumber =
        int.tryParse(RegExp(r'\d+').firstMatch(name)?.group(0) ?? '') ??
        (row['grade_number'] is int ? row['grade_number'] as int : 1);
    final sections = (row['sections'] as List? ?? const ['A'])
        .map((e) => '$e'.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final effectiveSections = sections.isEmpty ? const ['A'] : sections;
    final strength = row['strength'] ?? 40;
    final classTeacherId =
        '${row['classTeacherId'] ?? row['class_teacher_id'] ?? ''}'.trim();
    await _api.updateRaw('/grades/$gradeId', {
      'grade_number': gradeNumber,
      'grade_name': name.isEmpty ? 'Class $gradeNumber' : name,
    });

    final currentYear = await getMap(kActiveAcademicYear);
    final yearId = '${row['academic_year_id'] ?? currentYear?['id'] ?? ''}'
        .trim();
    final existing = await _api.getSections(gradeId: gradeId);
    final scopedExisting = yearId.isEmpty
        ? existing
        : existing.where((s) => s.academicYearId == yearId).toList();
    final touched = <String>{};

    for (var index = 0; index < effectiveSections.length; index++) {
      final sectionName = effectiveSections[index];
      SectionModel? target;
      final sameName = scopedExisting.where(
        (s) => s.sectionName.toLowerCase() == sectionName.toLowerCase(),
      );
      if (sameName.isNotEmpty) {
        target = sameName.first;
      } else if (index < scopedExisting.length) {
        target = scopedExisting[index];
      }

      final targetYearId = target?.academicYearId ?? yearId;
      if (target == null) {
        if (targetYearId.isEmpty) continue;
        final created = await _api.createRaw('/sections', {
          'grade_id': gradeId,
          'academic_year_id': targetYearId,
          'section_name': sectionName,
          'class_teacher_id': classTeacherId,
          'capacity': strength,
        });
        final createdId = '${created['id'] ?? ''}';
        if (createdId.isNotEmpty) touched.add(createdId);
      } else {
        await _api.updateRaw('/sections/${target.id}', {
          'grade_id': gradeId,
          'academic_year_id': targetYearId,
          'section_name': sectionName,
          'class_teacher_id': classTeacherId,
          'capacity': strength,
        });
        touched.add(target.id);
      }
    }

    for (final section in scopedExisting) {
      if (!touched.contains(section.id)) {
        await _api.deleteRaw('/sections/${section.id}');
      }
    }
  }

  Future<void> _saveFrontendRecord(
    String path,
    Map<String, dynamic> row,
  ) async {
    final id = '${row['id'] ?? ''}';
    final persisted =
        row.containsKey('resource') || row.containsKey('created_at');
    if (id.isEmpty || (!persisted && id.startsWith('cur'))) {
      await _api.createRaw(path, row);
    } else {
      await _api.updateRaw('$path/$id', row);
    }
  }

  Future<void> _saveMutableFrontendRecord(
    String path,
    Map<String, dynamic> row,
  ) async {
    final id = '${row['id'] ?? ''}';
    final persisted =
        row.containsKey('resource') || row.containsKey('created_at');
    if (id.isEmpty ||
        (!persisted &&
            (id.startsWith('cp') ||
                id.startsWith('disc_') ||
                id.startsWith('ticket_') ||
                id.startsWith('hd_')))) {
      await _api.createRaw(path, row);
    } else {
      await _api.updateRaw('$path/$id', row);
    }
  }

  Map<String, dynamic> _principalExamSchedule(Map<String, dynamic> row) {
    final subject = _asMap(row['subject']);
    final grade = _asMap(row['grade']);
    final section = _asMap(row['section']);
    final room = _asMap(row['room']);
    final examDate = _dateDayMonth(row['exam_date'] ?? row['date']);
    final start = '${row['start_time'] ?? row['time'] ?? ''}'.trim();
    final end = '${row['end_time'] ?? ''}'.trim();
    return {
      ...row,
      'date': examDate,
      'subject':
          subject['subject_name'] ??
          subject['name'] ??
          row['subject_name'] ??
          row['subject_id'] ??
          'Subject pending',
      'class': [
        grade['grade_name'] ?? row['grade_name'],
        section['section_name'] ?? row['section_name'],
      ].where((part) => '${part ?? ''}'.trim().isNotEmpty).join(' '),
      'time': end.isEmpty || start.isEmpty ? start : '$start - $end',
      'duration': '${row['max_marks'] ?? 0} marks',
      'room':
          room['room_number'] ??
          room['room_name'] ??
          row['room_name'] ??
          row['room_id'] ??
          'Not assigned',
      'status': row['status'] ?? 'scheduled',
    };
  }

  Map<String, dynamic> _principalExamResult(Map<String, dynamic> row) {
    final student = _asMap(row['student']);
    final enrollment = _asMap(row['enrollment']);
    final percentage = _numValue(row['percentage'] ?? row['percent']);
    final totalObtained = _numValue(row['total_obtained']);
    return {
      ...row,
      'name': [
        student['first_name'],
        student['last_name'],
      ].where((part) => '${part ?? ''}'.trim().isNotEmpty).join(' ').trim(),
      'class': enrollment['section_id'] ?? row['section_id'] ?? '',
      'roll': enrollment['roll_number'] ?? row['roll_number'] ?? '',
      'rank': row['class_rank'] ?? row['rank'] ?? 0,
      'percent': percentage,
      'grade': row['overall_grade'] ?? row['grade'] ?? '',
      'math': totalObtained,
      'science': 0,
      'english': 0,
      'hindi': 0,
      'social': 0,
    };
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  num _numValue(Object? value) {
    if (value is num) return value;
    return num.tryParse('${value ?? ''}') ?? 0;
  }

  String _dateDayMonth(Object? value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) {
      final raw = '${value ?? ''}'.trim();
      return raw.isEmpty ? 'TBD Date' : raw;
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${parsed.day} ${months[parsed.month - 1]}';
  }

  String _dateValue(Object? value, {required bool start}) {
    final raw = '${value ?? ''}'.trim();
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.toIso8601String().split('T').first;
    final yearMatch = RegExp(r'(20\d{2})').firstMatch(raw);
    final year = int.tryParse(yearMatch?.group(1) ?? '') ?? DateTime.now().year;
    if (raw.toLowerCase().contains('mar')) {
      return '$year-03-31';
    }
    if (raw.toLowerCase().contains('apr')) {
      return '$year-04-01';
    }
    return start ? '$year-04-01' : '${year + 1}-03-31';
  }

  String _dateLabel(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.year}';
  }
}

Map<String, dynamic> _studentDirectoryMap(StudentModel student) {
  final section = student.currentSection;
  final gradeName = _nestedText(section, 'grade', 'grade_name');
  final sectionName = _text(section['section_name']);
  final classTeacherName = _personName(section['class_teacher']);

  return {
    'id': student.id,
    'name': student.fullName,
    'student_code': student.studentCode,
    'admission_number': student.admissionNumber,
    'admissionNo': student.admissionNumber,
    'rollNo': student.admissionNumber.isNotEmpty
        ? student.admissionNumber
        : student.studentCode,
    'current_section_id': student.currentSectionId,
    'status': student.status,
    'photo': student.photoUrl,
    'photo_url': student.photoUrl,
    'class': gradeName,
    'grade_name': gradeName,
    'section': sectionName,
    'section_name': sectionName,
    'classTeacher': classTeacherName,
    'class_teacher_name': classTeacherName,
    'attendance': student.attendancePercent,
    'attendance_percentage': student.attendancePercent,
    'attendance_status': student.attendanceStatusLabel,
    'feesDue': student.feeBalance,
    'pending_fee_balance': student.feeBalance,
    'pending_invoices': student.pendingInvoices,
    'feeStatus': student.feeStatus,
    'primaryGuardian': student.primaryGuardianName,
    'primary_guardian_name': student.primaryGuardianName,
  };
}

String _text(Object? value) => value?.toString().trim() ?? '';

String _nestedText(Map<String, dynamic> source, String key, String nestedKey) {
  final nested = source[key];
  if (nested is Map) {
    return _text(nested[nestedKey]);
  }
  return '';
}

String _personName(Object? value) {
  if (value is! Map) return '';
  final direct = _text(value['full_name'] ?? value['name']);
  if (direct.isNotEmpty) return direct;
  return [
    _text(value['first_name']),
    _text(value['last_name']),
  ].where((part) => part.isNotEmpty).join(' ');
}
