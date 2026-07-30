// Route matching remains intentionally compact and declarative.
// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';

/// Fictional, relational data used by the offline SchoolDesk demonstration.
///
/// The store deliberately mirrors the Edge API envelope and keeps every write
/// in memory until [reset]. Its exported snapshot is encrypted by
/// [DemoSandboxService]; no record contains a production identifier or URL.
class DemoFixtureStore {
  DemoFixtureStore._(this._data);

  factory DemoFixtureStore.pristine() => DemoFixtureStore._(_seed());

  factory DemoFixtureStore.fromSnapshot(Map<String, dynamic> snapshot) {
    final data = snapshot['fixture_store'];
    if (data is Map) {
      return DemoFixtureStore._(Map<String, dynamic>.from(data));
    }
    return DemoFixtureStore.pristine();
  }

  Map<String, dynamic> _data;

  Map<String, dynamic> toSnapshot() => {
    'fixture_store': jsonDecode(jsonEncode(_data)) as Map<String, dynamic>,
  };

  Map<String, dynamic> respond({
    required String path,
    required String method,
    required String role,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) {
    final clean = path.toLowerCase();
    final verb = method.toUpperCase();
    if (verb != 'GET') return _write(clean, verb, body ?? const {});

    if (clean == '/auth/profile') return _ok({'profile': _profile(role)});
    if (clean.startsWith('/dashboard/')) return _ok(_dashboard(role));
    if (clean == '/schools/current') return _ok(_school);
    if (clean == '/schools') return _ok([_school]);
    if (clean == '/me/students') return _ok(_list('students'));
    if (clean == '/students') return _paged(_list('students'));
    if (clean.startsWith('/students/') && clean.endsWith('/attendance')) {
      return _ok(_list('attendance'));
    }
    if (clean.startsWith('/students/') && clean.endsWith('/fees')) {
      return _ok(_list('invoices'));
    }
    if (clean.startsWith('/students/') && clean.endsWith('/guardians')) {
      return _ok(_list('guardians'));
    }
    if (clean.startsWith('/students/') && clean.endsWith('/documents')) {
      return _ok(_list('documents'));
    }
    if (clean.startsWith('/students/')) return _ok(_byId('students', clean));
    if (clean == '/staff') return _paged(_list('staff'));
    if (clean.startsWith('/staff/') && clean.endsWith('/documents')) {
      return _ok(_list('documents'));
    }
    if (clean.startsWith('/staff/')) return _ok(_byId('staff', clean));
    if (clean == '/users') return _paged(_list('users'));
    if (clean == '/grades') return _ok(_list('grades'));
    if (clean == '/sections') return _ok(_list('sections'));
    if (clean == '/subjects') return _ok(_list('subjects'));
    if (clean == '/academic-years') return _ok(_list('academic_years'));
    if (clean.startsWith('/academic-years/')) {
      final year = _byId('academic_years', clean);
      return _ok({...year, 'holidays': const <Map<String, dynamic>>[]});
    }
    if (clean.startsWith('/timetable')) return _ok(_list('timetable'));
    if (clean.startsWith('/principal/timetable'))
      return _ok(_list('timetable'));
    if (clean.startsWith('/principal/classes')) return _ok(_list('sections'));
    if (clean.startsWith('/principal/subjects')) return _ok(_list('subjects'));
    if (clean.startsWith('/attendance/staff/me/today'))
      return _ok(_staffAttendance);
    if (clean.startsWith('/attendance/staff'))
      return _ok(_list('staff_attendance'));
    if (clean.startsWith('/attendance/summary')) return _ok(_attendanceSummary);
    if (clean.startsWith('/attendance/')) return _ok(_list('attendance'));
    if (clean.startsWith('/fees/invoices')) return _paged(_list('invoices'));
    if (clean.startsWith('/fees/payments')) return _paged(_list('payments'));
    if (clean.startsWith('/fees/payment-requests'))
      return _paged(_list('payment_requests'));
    if (clean.startsWith('/fees/reminders')) return _ok(const []);
    if (clean == '/fees/daycare-eligible-students') {
      return _ok(_list('daycare_students'));
    }
    if (clean.startsWith('/fees/daycare-plans')) {
      return _ok(_list('daycare_plans'));
    }
    if (clean.startsWith('/fees/payment-config')) {
      return _ok({'upi_id': 'demo@upi', 'payee_name': 'Arish Ville Demo'});
    }
    if (clean.startsWith('/fees/')) return _ok(_list('fee_structures'));
    if (clean.startsWith('/parent/students/') && clean.endsWith('/fees'))
      return _ok(_list('invoices'));
    if (clean.startsWith('/students/') && clean.endsWith('/fees'))
      return _ok(_list('invoices'));
    if (clean == '/announcements') return _ok(_list('announcements'));
    if (clean.startsWith('/event-posts/home-feed') ||
        clean.startsWith('/event-posts/gallery') ||
        clean.startsWith('/event-posts'))
      return _ok(_list('event_posts'));
    if (clean == '/events') return _ok(_list('events'));
    if (clean.startsWith('/holidays')) return _ok(const []);
    if (clean.startsWith('/homework')) return _paged(_list('homework'));
    if (clean.startsWith('/lesson-planners'))
      return _ok(_list('lesson_planners'));
    if (clean.startsWith('/leave/')) return _ok(_list('leave'));
    if (clean.startsWith('/student-leave/')) return _ok(_list('student_leave'));
    if (clean.startsWith('/health-reminders'))
      return _ok(_list('health_reminders'));
    if (clean.startsWith('/approvals')) return _ok(_list('approvals'));
    if (clean.startsWith('/issues')) return _paged(_list('issues'));
    if (clean.startsWith('/notifications')) return _ok(_list('notifications'));
    if (clean.startsWith('/documents') || clean.endsWith('/documents'))
      return _ok(_list('documents'));
    if (clean.startsWith('/parent-teacher-meetings') ||
        clean.startsWith('/teacher/ptm'))
      return _ok(_list('ptm'));
    if (clean.startsWith('/chat/contacts')) return _ok(_contacts(role));
    if (clean.startsWith('/chat/conversations/') && clean.endsWith('/messages'))
      return _ok(_list('messages'));
    if (clean.startsWith('/chat/conversations') ||
        clean == '/message-conversations')
      return _ok(_list('conversations'));
    if (clean.startsWith('/messages')) return _ok(_list('messages'));
    if (clean.startsWith('/monitoring/')) return _ok(_monitoring);
    if (clean == '/help' || clean.startsWith('/help/'))
      return _ok(_list('help'));
    if (clean.startsWith('/rooms')) return _ok(_list('rooms'));
    if (clean.startsWith('/branches')) return _ok([_school]);
    if (clean.startsWith('/access/')) return _ok({'permissions': const []});

    // A non-empty local result is safer than a network fallback for legacy
    // screens with read-only supplementary endpoints.
    return _ok(<String, dynamic>{'items': const [], 'demo': true});
  }

  Map<String, dynamic> _write(
    String path,
    String method,
    Map<String, dynamic> body,
  ) {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = 'demo-local-${DateTime.now().microsecondsSinceEpoch}';
    final record = <String, dynamic>{
      'id': id,
      ...body,
      'updated_at': now,
      'created_at': now,
      'demo_local': true,
    };
    final bucket = _bucketFor(path);
    if (bucket != null) {
      final rows = _mutableList(bucket);
      if (method == 'DELETE') {
        rows.removeWhere((row) => '${row['id']}' == _pathId(path));
      } else if (method == 'PATCH' || method == 'PUT') {
        final existing = rows.indexWhere(
          (row) => '${row['id']}' == _pathId(path),
        );
        if (existing >= 0)
          rows[existing] = {
            ...rows[existing],
            ...record,
            'id': rows[existing]['id'],
          };
        else
          rows.insert(0, record);
      } else {
        rows.insert(0, record);
      }
    }
    _mutableList('notifications').insert(0, {
      'id': 'notice-$id',
      'title': 'Demo action completed',
      'body': 'This ${_labelFor(path)} update is stored only on this device.',
      'role': 'all',
      'category': 'general',
      'priority': 'normal',
      'is_read': false,
      'created_at': now,
    });
    if (path.contains('/payments')) {
      record['receipt_number'] =
          'DEMO-RCPT-${DateTime.now().millisecondsSinceEpoch}';
      record['status'] = 'simulated_paid';
      record['is_simulated'] = true;
    }
    return _ok(record);
  }

  String? _bucketFor(String path) {
    if (path.contains('homework')) return 'homework';
    if (path.contains('lesson-planner')) return 'lesson_planners';
    if (path.contains('leave')) return 'leave';
    if (path.contains('attendance')) return 'attendance';
    if (path.contains('event-post')) return 'event_posts';
    if (path.contains('announcement')) return 'announcements';
    if (path.contains('issue') || path.contains('complaint')) return 'issues';
    if (path.contains('payment')) return 'payments';
    if (path.contains('daycare-plans')) return 'daycare_plans';
    if (path.contains('invoice')) return 'invoices';
    if (path.contains('message') || path.contains('/chat/')) return 'messages';
    if (path.contains('notification')) return 'notifications';
    if (path.contains('document')) return 'documents';
    return null;
  }

  Map<String, dynamic> _ok(dynamic data) => {'success': true, 'data': data};
  Map<String, dynamic> _paged(List<Map<String, dynamic>> data) => {
    'success': true,
    'data': data,
    'total': data.length,
    'page': 1,
    'page_size': data.length,
  };
  List<Map<String, dynamic>> _list(String key) =>
      List<Map<String, dynamic>>.from(
        (_data[key] as List? ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
  List<Map<String, dynamic>> _mutableList(String key) {
    final raw = _data.putIfAbsent(key, () => <Map<String, dynamic>>[]) as List;
    final normalized = raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    _data[key] = normalized;
    return normalized;
  }

  Map<String, dynamic> _byId(String key, String path) => _list(key).firstWhere(
    (row) => '${row['id']}' == _pathId(path),
    orElse: () => _list(key).first,
  );
  String _pathId(String path) => path.split('/').last;
  String _labelFor(String path) => path
      .split('/')
      .where((part) => part.isNotEmpty)
      .last
      .replaceAll('-', ' ');

  Map<String, dynamic> _profile(String role) =>
      Map<String, dynamic>.from((_data['profiles'] as Map)[role] as Map);
  Map<String, dynamic> get _school =>
      Map<String, dynamic>.from((_data['school'] as Map));
  Map<String, dynamic> get _staffAttendance => Map<String, dynamic>.from(
    (_data['staff_attendance'] as List).first as Map,
  );
  Map<String, dynamic> get _attendanceSummary =>
      Map<String, dynamic>.from((_data['attendance_summary'] as Map));
  Map<String, dynamic> get _monitoring => {
    'total_events': 0,
    'open_events': 0,
    'resolved_events': 0,
    'cleanup_eligible': 0,
    'storage_bytes': 0,
    'settings': {
      'max_raw_events': 10000,
      'warning_keep_days': 14,
      'resolved_keep_days': 30,
      'resolved_fatal_keep_days': 90,
    },
  };

  Map<String, dynamic> _dashboard(String role) {
    final common = <String, dynamic>{
      'school_name': _school['name'],
      'students': _list('students').length,
      'staff': _list('staff').length,
      'classes': _list('sections').length,
      'pending_approvals': _list('approvals').length,
      'assigned_classes': [
        {
          'section_id': _list('sections').first['id'],
          'section_name': _list('sections').first['section_name'],
          'grade_name': 'Nursery',
          'is_class_teacher': true,
          'subject_name': 'Early Learning',
        },
      ],
      'staff_id': _list('staff').first['id'],
      'children': _list('students'),
      'attendance_percent': 94.7,
      'fee_balance': 0,
      'demo_offline': true,
    };
    return {
      ...common,
      'title': role == 'parent'
          ? "Aarav's learning day"
          : role == 'teacher'
          ? 'Sunshine Nursery'
          : 'SchoolDesk Demo Preschool',
    };
  }

  List<Map<String, dynamic>> _contacts(String role) {
    final contacts = <Map<String, dynamic>>[
      {
        'id': 'user-teacher-1',
        'name': 'Meera Sharma',
        'role': 'teacher',
        'contact_role': 'class_teacher',
        'student_id': 'student-1',
        'student_name': 'Aarav Demo',
        'subtitle': 'Sunshine Nursery',
      },
      {
        'id': 'user-principal-1',
        'name': 'Ananya Rao',
        'role': 'principal',
        'contact_role': 'principal',
        'subtitle': 'Principal',
      },
      {
        'id': 'user-parent-1',
        'name': 'Kavya Demo',
        'role': 'parent',
        'contact_role': 'student_parent',
        'student_id': 'student-1',
        'student_name': 'Aarav Demo',
        'subtitle': 'Aarav’s parent',
      },
    ];
    return role == 'parent'
        ? contacts.where((c) => c['role'] != 'parent').toList()
        : role == 'teacher'
        ? contacts.where((c) => c['role'] != 'teacher').toList()
        : contacts;
  }

  static Map<String, dynamic> _seed() {
    const schoolId = '00000000-0000-4000-8000-000000000001';
    const sectionId = '00000000-0000-4000-8000-000000000060';
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'school': {
        'id': schoolId,
        'name': 'SchoolDesk Demo Preschool',
        'school_name': 'SchoolDesk Demo Preschool',
        'city': 'Demo City',
        'phone': '+91 90000 00000',
        'email': 'demo@schooldesk.local',
      },
      'profiles': {
        'principal': {
          'id': 'user-principal-1',
          'username': 'demo-principal',
          'name': 'Ananya Rao',
          'email': 'principal@demo.schooldesk.local',
          'school_id': schoolId,
          'role_name': 'principal',
          'role_id': 'demo-principal',
          'is_active': true,
          'is_verified': true,
        },
        'teacher': {
          'id': 'user-teacher-1',
          'username': 'demo-teacher',
          'name': 'Meera Sharma',
          'email': 'teacher@demo.schooldesk.local',
          'school_id': schoolId,
          'role_name': 'teacher',
          'role_id': 'demo-teacher',
          'linked_type': 'staff',
          'linked_id': 'staff-1',
          'is_active': true,
          'is_verified': true,
        },
        'parent': {
          'id': 'user-parent-1',
          'username': 'demo-parent',
          'name': 'Kavya Demo',
          'email': 'parent@demo.schooldesk.local',
          'school_id': schoolId,
          'role_name': 'parent',
          'role_id': 'demo-parent',
          'linked_type': 'guardian',
          'linked_id': 'guardian-1',
          'is_active': true,
          'is_verified': true,
        },
      },
      'academic_years': [
        {
          'id': 'year-1',
          'school_id': schoolId,
          'year_label': '2026–27',
          'start_date': '2026-06-01',
          'end_date': '2027-03-31',
          'is_current': true,
          'status': 'active',
        },
      ],
      'grades': [
        {
          'id': 'grade-1',
          'school_id': schoolId,
          'grade_number': 1,
          'grade_name': 'Nursery',
        },
      ],
      'sections': [
        {
          'id': sectionId,
          'school_id': schoolId,
          'grade_id': 'grade-1',
          'section_name': 'Sunshine Nursery',
          'name': 'Sunshine Nursery',
          'capacity': 30,
          'class_teacher_id': 'staff-1',
        },
      ],
      'subjects': [
        {
          'id': 'subject-1',
          'school_id': schoolId,
          'subject_name': 'Early Learning',
          'subject_code': 'EL',
          'subject_type': 'core',
          'subject_color': '#2E7D32',
        },
      ],
      'students': [
        {
          'id': 'student-1',
          'school_id': schoolId,
          'student_code': 'DEMO-001',
          'admission_number': 'LV-2026-001',
          'first_name': 'Aarav',
          'last_name': 'Demo',
          'full_name': 'Aarav Demo',
          'status': 'active',
          'current_section_id': sectionId,
          'active_enrollment_id': 'enrollment-1',
          'current_section': {
            'id': sectionId,
            'section_name': 'Sunshine Nursery',
          },
          'attendance_summary': {'percent': 94.7, 'status_label': 'Excellent'},
          'fee_summary': {
            'balance': 0,
            'status': 'clear',
            'pending_invoices': 0,
          },
        },
      ],
      'daycare_students': [
        {
          'id': 'student-daycare-1',
          'school_id': schoolId,
          'admission_number': 'LV-2026-DC01',
          'first_name': 'Maya',
          'last_name': 'Demo',
          'status': 'active',
          'current_section': {
            'id': 'section-daycare-a',
            'section_name': 'A',
            'grade': {'id': 'grade-daycare', 'grade_name': 'Day Care'},
          },
        },
      ],
      'daycare_plans': <Map<String, dynamic>>[],
      'staff': [
        {
          'id': 'staff-1',
          'school_id': schoolId,
          'staff_code': 'DEMO-T01',
          'first_name': 'Meera',
          'last_name': 'Sharma',
          'designation': 'Class Teacher',
          'email': 'teacher@demo.schooldesk.local',
          'phone': '+91 90000 00001',
          'status': 'active',
        },
      ],
      'users': [
        {
          'id': 'user-principal-1',
          'name': 'Ananya Rao',
          'role_name': 'principal',
        },
        {
          'id': 'user-teacher-1',
          'name': 'Meera Sharma',
          'role_name': 'teacher',
        },
        {'id': 'user-parent-1', 'name': 'Kavya Demo', 'role_name': 'parent'},
      ],
      'guardians': [
        {
          'id': 'guardian-1',
          'student_id': 'student-1',
          'name': 'Kavya Demo',
          'relationship': 'Mother',
          'phone': '+91 90000 00002',
          'email': 'parent@demo.schooldesk.local',
          'is_primary': true,
        },
      ],
      'timetable': [
        {
          'id': 'slot-1',
          'section_id': sectionId,
          'staff_id': 'staff-1',
          'subject_id': 'subject-1',
          'day_of_week': DateTime.now().weekday,
          'period_number': 1,
          'start_time': '09:00',
          'end_time': '09:40',
          'subject_name': 'Early Learning',
          'section_name': 'Sunshine Nursery',
        },
      ],
      'attendance': [
        {
          'id': 'attendance-1',
          'student_id': 'student-1',
          'section_id': sectionId,
          'attendance_date': DateTime.now().toIso8601String().substring(0, 10),
          'status': 'present',
          'marked_by': 'staff-1',
        },
      ],
      'attendance_summary': {
        'student_id': 'student-1',
        'present_days': 18,
        'absent_days': 1,
        'total_days': 19,
        'attendance_pct': 94.7,
      },
      'staff_attendance': [
        {
          'id': 'staff-attendance-1',
          'staff_id': 'staff-1',
          'attendance_date': DateTime.now().toIso8601String().substring(0, 10),
          'status': 'present',
          'check_in_time': '08:45',
        },
      ],
      'fee_structures': [
        {
          'id': 'fee-structure-1',
          'name': 'Nursery Annual Plan',
          'school_id': schoolId,
          'is_active': true,
        },
      ],
      'invoices': [
        {
          'id': 'invoice-1',
          'student_id': 'student-1',
          'invoice_number': 'DEMO-INV-001',
          'net_amount': 12000,
          'paid_amount': 12000,
          'balance': 0,
          'status': 'paid',
          'due_date': '2026-07-10',
        },
      ],
      'payments': [
        {
          'id': 'payment-1',
          'student_id': 'student-1',
          'invoice_id': 'invoice-1',
          'amount': 12000,
          'status': 'simulated_paid',
          'receipt_number': 'DEMO-RCPT-001',
          'is_simulated': true,
        },
      ],
      'payment_requests': [
        {
          'id': 'payment-request-1',
          'student_id': 'student-1',
          'amount': 12000,
          'status': 'approved',
          'is_simulated': true,
        },
      ],
      'announcements': [
        {
          'id': 'announcement-1',
          'title': 'Welcome to our offline demo',
          'body':
              'Every record shown here is fictional and stored only on this device.',
          'priority': 'normal',
          'published_at': now,
          'created_at': now,
        },
      ],
      'event_posts': [
        {
          'id': 'post-1',
          'title': 'Little artists at work',
          'description': 'A joyful morning of colour and creativity.',
          'category': 'Classroom',
          'author': 'Meera Sharma',
          'event_date': '2026-07-20',
          'created_at': now,
          'media_urls': ['assets/images/demo/painting-play.png'],
        },
        {
          'id': 'post-2',
          'title': 'Garden discovery day',
          'description': 'Our young gardeners planted their first seedlings.',
          'category': 'Nature',
          'author': 'Meera Sharma',
          'event_date': '2026-07-18',
          'created_at': now,
          'media_urls': ['assets/images/demo/garden-discovery.png'],
        },
        {
          'id': 'post-3',
          'title': 'Stories that spark imagination',
          'description': 'A warm story circle filled with wonder.',
          'category': 'Literacy',
          'author': 'Meera Sharma',
          'event_date': '2026-07-15',
          'created_at': now,
          'media_urls': ['assets/images/demo/story-circle.png'],
        },
        {
          'id': 'post-4',
          'title': 'Building big ideas',
          'description': 'Teamwork took shape in our block city.',
          'category': 'Play',
          'author': 'Meera Sharma',
          'event_date': '2026-07-12',
          'created_at': now,
          'media_urls': ['assets/images/demo/block-builders.png'],
        },
        {
          'id': 'post-5',
          'title': 'Music and movement',
          'description': 'Rhythm, scarves, and happy little steps.',
          'category': 'Enrichment',
          'author': 'Meera Sharma',
          'event_date': '2026-07-10',
          'created_at': now,
          'media_urls': ['assets/images/demo/music-movement.png'],
        },
      ],
      'events': [
        {
          'id': 'event-1',
          'title': 'Family story morning',
          'event_date': '2026-07-30',
          'start_time': '10:00',
          'end_time': '11:00',
          'description': 'A fictional family engagement event.',
        },
      ],
      'homework': [
        {
          'id': 'homework-1',
          'section_id': sectionId,
          'student_id': 'student-1',
          'title': 'My favourite colour',
          'description': 'Draw and tell us about one favourite colour.',
          'due_date': '2026-07-28',
          'status': 'assigned',
          'submission_status': 'submitted',
        },
      ],
      'lesson_planners': [
        {
          'id': 'lesson-1',
          'section_id': sectionId,
          'subject_id': 'subject-1',
          'title': 'Colours in nature',
          'objective': 'Notice colours outdoors',
          'status': 'uploaded',
          'week_start_date': '2026-07-20',
          'week_end_date': '2026-07-24',
          'note': 'Colours, shapes, and outdoor observation activities.',
        },
      ],
      'leave': [
        {
          'id': 'leave-1',
          'applicant_name': 'Meera Sharma',
          'leave_type': 'Casual Leave',
          'start_date': '2026-08-04',
          'end_date': '2026-08-04',
          'status': 'approved',
          'reason': 'Personal appointment',
        },
      ],
      'student_leave': [
        {
          'id': 'student-leave-1',
          'student_id': 'student-1',
          'start_date': '2026-08-05',
          'end_date': '2026-08-05',
          'status': 'approved',
          'reason': 'Family occasion',
        },
      ],
      'health_reminders': [
        {
          'id': 'health-1',
          'student_id': 'student-1',
          'title': 'Water bottle reminder',
          'notes': 'Please offer water after outdoor play.',
          'is_active': true,
          'created_at': now,
        },
      ],
      'approvals': [
        {
          'id': 'approval-1',
          'title': 'Garden discovery post',
          'status': 'pending',
          'requested_by': 'Meera Sharma',
          'created_at': now,
        },
      ],
      'issues': [
        {
          'id': 'issue-1',
          'title': 'Playground shade suggestion',
          'description': 'Fictional parent feedback record.',
          'status': 'open',
          'created_at': now,
        },
      ],
      'ptm': [
        {
          'id': 'ptm-1',
          'student_id': 'student-1',
          'teacher_id': 'staff-1',
          'starts_at': '2026-07-31T10:00:00Z',
          'status': 'booked',
        },
      ],
      'documents': [
        {
          'id': 'document-1',
          'title': 'Nursery welcome guide',
          'file_name': 'demo-welcome-guide.pdf',
          'document_type': 'guide',
          'created_at': now,
          'is_demo': true,
        },
      ],
      'notifications': [
        {
          'id': 'notification-1',
          'title': 'New classroom memory',
          'body': 'Garden discovery day is ready to view.',
          'role': 'parent',
          'category': 'general',
          'priority': 'normal',
          'is_read': false,
          'created_at': now,
        },
      ],
      'conversations': [
        {
          'id': 'conversation-1',
          'conversation_type': 'parent_teacher',
          'title': 'Meera Sharma',
          'last_message': 'Aarav loved the garden activity today!',
          'updated_at': now,
          'student_id': 'student-1',
        },
      ],
      'messages': [
        {
          'id': 'message-1',
          'conversation_id': 'conversation-1',
          'sender_id': 'user-teacher-1',
          'body': 'Aarav loved the garden activity today!',
          'content': 'Aarav loved the garden activity today!',
          'sent_at': now,
          'created_at': now,
        },
      ],
      'rooms': [
        {'id': 'room-1', 'name': 'Sunshine Room', 'capacity': 30},
      ],
      'help': [
        {
          'id': 'help-1',
          'title': 'How to show the demo',
          'content':
              'Choose a role, open a classroom memory, then try a local action.',
        },
      ],
    };
  }
}
