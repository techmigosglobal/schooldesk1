// API models exported by BackendApiClient's facade.
// ─── Request/Response Models ──────────────────────────────────────────────────

class LoginRequest {
  final String username;
  final String password;

  const LoginRequest({required this.username, required this.password});

  Map<String, dynamic> toJson() {
    final identity = username.trim();
    final fallbackEmail = _fallbackEmail(identity);
    return {
      'username': identity,
      if (fallbackEmail.isNotEmpty) 'email': fallbackEmail,
      'password': password,
    };
  }

  static String _fallbackEmail(String value) {
    final identity = value.trim();
    final lower = identity.toLowerCase();
    if (lower == 'princ' || lower == 'principal') {
      return 'principal@schooldesk.local';
    }
    if (lower == 'principal@schooldesk.com') {
      return 'principal@schooldesk.local';
    }
    if (_looksLikeEmail(identity)) {
      return identity;
    }
    return '';
  }

  static bool _looksLikeEmail(String value) {
    return value.contains('@') && value.contains('.');
  }
}

class SchoolSetupRequest {
  final String schoolName;
  final String schoolType;
  final String affiliationBoard;
  final String email;
  final String phone;
  final String city;
  final String state;
  final String adminName;
  final String adminUsername;
  final String adminEmail;
  final String adminPhone;
  final String adminPassword;
  final String adminRole;

  const SchoolSetupRequest({
    required this.schoolName,
    required this.schoolType,
    required this.affiliationBoard,
    required this.email,
    required this.phone,
    required this.city,
    required this.state,
    required this.adminName,
    required this.adminUsername,
    required this.adminEmail,
    required this.adminPhone,
    required this.adminPassword,
    required this.adminRole,
  });

  Map<String, dynamic> toJson() => {
    'school_name': schoolName.trim(),
    'school_type': schoolType.trim().isEmpty ? 'school' : schoolType.trim(),
    if (affiliationBoard.trim().isNotEmpty)
      'affiliation_board': affiliationBoard.trim(),
    if (email.trim().isNotEmpty) 'email': email.trim(),
    if (phone.trim().isNotEmpty) 'phone': phone.trim(),
    if (city.trim().isNotEmpty) 'city': city.trim(),
    if (state.trim().isNotEmpty) 'state': state.trim(),
    'admin_name': adminName.trim(),
    if (adminUsername.trim().isNotEmpty) 'admin_username': adminUsername.trim(),
    'admin_email': adminEmail.trim(),
    if (adminPhone.trim().isNotEmpty) 'admin_phone': adminPhone.trim(),
    'admin_password': adminPassword,
    'admin_role': adminRole,
  };
}

class LoginResponse {
  final String token;
  final String refreshToken;
  final int expiresAt;
  final UserResponse user;

  const LoginResponse({
    required this.token,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    token: json['token'] as String,
    refreshToken: json['refresh_token'] as String? ?? '',
    expiresAt: json['expires_at'] as int,
    user: UserResponse.fromJson(json['user'] as Map<String, dynamic>),
  );
}

class UserResponse {
  final String id;
  final String username;
  final String name;
  final String email;
  final String phone;
  final String avatar;
  final String schoolId;
  final String roleId;
  final String roleName;
  final String linkedType;
  final String linkedId;
  final bool isActive;
  final bool isVerified;

  const UserResponse({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.phone,
    required this.avatar,
    required this.schoolId,
    required this.roleId,
    required this.roleName,
    required this.linkedType,
    required this.linkedId,
    required this.isActive,
    required this.isVerified,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) => UserResponse(
    id: json['id'] as String,
    username: json['username'] as String? ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String,
    phone: json['phone'] as String? ?? '',
    avatar: json['avatar'] as String? ?? '',
    schoolId: json['school_id'] as String,
    roleId: json['role_id'] as String,
    roleName: json['role_name'] as String,
    linkedType: json['linked_type'] as String? ?? '',
    linkedId: json['linked_id'] as String? ?? '',
    isActive: json['is_active'] as bool? ?? true,
    isVerified: json['is_verified'] as bool? ?? false,
  );
}

class UserAccountModel {
  final String id;
  final String name;
  final String username;
  final String email;
  final String phone;
  final String avatar;
  final String schoolId;
  final String roleId;
  final String roleName;
  final String linkedType;
  final String linkedId;
  final bool isActive;
  final bool isVerified;
  final DateTime? lastLogin;
  final DateTime? createdAt;

  const UserAccountModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.avatar,
    required this.schoolId,
    required this.roleId,
    required this.roleName,
    required this.linkedType,
    required this.linkedId,
    required this.isActive,
    required this.isVerified,
    this.lastLogin,
    this.createdAt,
  });

  factory UserAccountModel.fromJson(Map<String, dynamic> json) =>
      UserAccountModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        avatar: json['avatar'] as String? ?? '',
        schoolId: json['school_id'] as String? ?? '',
        roleId: json['role_id'] as String? ?? '',
        roleName: json['role_name'] as String? ?? '',
        linkedType: json['linked_type'] as String? ?? '',
        linkedId: json['linked_id'] == null ? '' : json['linked_id'].toString(),
        isActive: json['is_active'] as bool? ?? true,
        isVerified: json['is_verified'] as bool? ?? false,
        lastLogin: json['last_login'] == null
            ? null
            : DateTime.tryParse(json['last_login'].toString()),
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'].toString()),
      );
}

class PaginatedList<T> {
  final List<T> data;
  final int total;
  final int page;
  final int pageSize;

  const PaginatedList({
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  bool get hasMore => page * pageSize < total;
}

// ─── School Models ─────────────────────────────────────────────────────────────

class SchoolModel {
  final String id;
  final String name;
  final String schoolType;
  final String? affiliationBoard;
  final String? email;
  final String? phone;
  final String? city;
  final String? state;

  const SchoolModel({
    required this.id,
    required this.name,
    required this.schoolType,
    this.affiliationBoard,
    this.email,
    this.phone,
    this.city,
    this.state,
  });

  factory SchoolModel.fromJson(Map<String, dynamic> json) => SchoolModel(
    id: json['id'] as String,
    name: json['name'] as String,
    schoolType: json['school_type'] as String,
    affiliationBoard: json['affiliation_board'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    city: json['city'] as String?,
    state: json['state'] as String?,
  );
}

class AcademicYearModel {
  final String id;
  final String schoolId;
  final String yearLabel;
  final String startDate;
  final String endDate;
  final bool isCurrent;
  final String status;

  const AcademicYearModel({
    required this.id,
    required this.schoolId,
    required this.yearLabel,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.status,
  });

  factory AcademicYearModel.fromJson(Map<String, dynamic> json) =>
      AcademicYearModel(
        id: json['id'] as String,
        schoolId: json['school_id'] as String,
        yearLabel: json['year_label'] as String,
        startDate: json['start_date'] as String,
        endDate: json['end_date'] as String,
        isCurrent: json['is_current'] as bool? ?? false,
        status: json['status'] as String? ?? 'upcoming',
      );
}

class GradeModel {
  final String id;
  final String schoolId;
  final int gradeNumber;
  final String gradeName;

  const GradeModel({
    required this.id,
    required this.schoolId,
    required this.gradeNumber,
    required this.gradeName,
  });

  factory GradeModel.fromJson(Map<String, dynamic> json) => GradeModel(
    id: json['id'] as String,
    schoolId: json['school_id'] as String,
    gradeNumber: json['grade_number'] as int,
    gradeName: json['grade_name'] as String,
  );
}

class SubjectModel {
  final String id;
  final String schoolId;
  final String departmentId;
  final String subjectName;
  final String subjectCode;
  final String subjectType;
  final String subjectColor;

  const SubjectModel({
    required this.id,
    required this.schoolId,
    required this.departmentId,
    required this.subjectName,
    required this.subjectCode,
    required this.subjectType,
    required this.subjectColor,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) => SubjectModel(
    id: _stringValue(json['id']),
    schoolId: _stringValue(json['school_id']),
    departmentId: _stringValue(json['department_id']),
    subjectName: _stringValue(json['subject_name'] ?? json['name']),
    subjectCode: _stringValue(json['subject_code']),
    subjectType: _stringValue(json['subject_type']),
    subjectColor: _stringValue(json['subject_color']),
  );

  static String _stringValue(Object? value) => value?.toString() ?? '';
}

class SectionModel {
  final String id;
  final String gradeId;
  final String gradeName;
  final String academicYearId;
  final String sectionName;
  final String classTeacherId;
  final String classTeacherName;
  final String roomId;
  final String roomNumber;
  final String roomType;
  final int capacity;

  const SectionModel({
    required this.id,
    required this.gradeId,
    required this.gradeName,
    required this.academicYearId,
    required this.sectionName,
    required this.classTeacherId,
    required this.classTeacherName,
    required this.roomId,
    required this.roomNumber,
    required this.roomType,
    required this.capacity,
  });

  factory SectionModel.fromJson(Map<String, dynamic> json) => SectionModel(
    id: _stringValue(json['id']),
    gradeId: _stringValue(json['grade_id']),
    gradeName: _gradeName(json['grade']),
    academicYearId: _stringValue(json['academic_year_id']),
    sectionName: _stringValue(json['section_name']),
    classTeacherId: _stringValue(json['class_teacher_id']),
    classTeacherName: _staffName(json['class_teacher']),
    roomId: _stringValue(json['room_id']),
    roomNumber: _roomNumber(json),
    roomType: _roomType(json),
    capacity: (json['capacity'] as num?)?.toInt() ?? 0,
  );

  static String _stringValue(Object? value) => value?.toString() ?? '';

  static String _gradeName(Object? value) {
    if (value is! Map) return '';
    return _stringValue(value['grade_name'] ?? value['name'] ?? value['id']);
  }

  static String _staffName(Object? value) {
    if (value is! Map) return '';
    final direct = _stringValue(value['name']).trim();
    if (direct.isNotEmpty) return direct;
    final first = _stringValue(value['first_name']).trim();
    final last = _stringValue(value['last_name']).trim();
    final fullName = '$first $last'.trim();
    if (fullName.isNotEmpty) return fullName;
    return _stringValue(value['email'] ?? value['id']);
  }

  static String _roomNumber(Map<String, dynamic> json) {
    final direct = _stringValue(
      json['room_number'] ?? json['room_name'],
    ).trim();
    if (direct.isNotEmpty) return direct;
    final room = json['room'];
    if (room is! Map) return '';
    return _stringValue(room['room_number'] ?? room['name'] ?? room['id']);
  }

  static String _roomType(Map<String, dynamic> json) {
    final direct = _stringValue(json['room_type']).trim();
    if (direct.isNotEmpty) return direct;
    final room = json['room'];
    if (room is! Map) return '';
    return _stringValue(room['room_type'] ?? room['type']);
  }
}

// ─── Staff Models ─────────────────────────────────────────────────────────────

class StaffModel {
  final String id;
  final String schoolId;
  final String staffCode;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? designation;
  final String? employmentType;
  final String? departmentId;
  final String? departmentName;
  final String status;
  final String? dateOfBirth;
  final String? gender;
  final String? joinDate;
  final String photoUrl;
  final List<Map<String, dynamic>> documents;
  final int documentCount;

  const StaffModel({
    required this.id,
    required this.schoolId,
    required this.staffCode,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.designation,
    this.employmentType,
    this.departmentId,
    this.departmentName,
    required this.status,
    this.dateOfBirth,
    this.gender,
    this.joinDate,
    required this.photoUrl,
    this.documents = const [],
    this.documentCount = 0,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    final documents = _listMapValue(json['documents']);
    return StaffModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String,
      staffCode: json['staff_code'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      gender: json['gender'] as String?,
      designation: json['designation'] as String?,
      employmentType: json['employment_type'] as String?,
      departmentId: json['department_id'] as String?,
      departmentName:
          json['department_name'] as String? ??
          (json['department'] as Map<String, dynamic>?)?['department_name']
              as String?,
      joinDate: json['join_date'] as String?,
      status: json['status'] as String? ?? 'active',
      photoUrl: _photoUrlFromJson(json),
      documents: documents,
      documentCount: documents.length,
    );
  }

  static List<Map<String, dynamic>> _listMapValue(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static String _photoUrlFromJson(Map<String, dynamic> json) {
    final direct = (json['photo_url'] ?? json['photo'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final documents = json['documents'];
    if (documents is List) {
      for (final item in documents) {
        if (item is! Map) continue;
        final type = (item['doc_type'] ?? item['type'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        if (type != 'profile_photo' && type != 'staff_photo') continue;
        final url = (item['file_url'] ?? item['url'] ?? '').toString().trim();
        if (url.isNotEmpty) return url;
      }
    }
    return '';
  }
}

// ─── Student Models ───────────────────────────────────────────────────────────

class StudentModel {
  final String id;
  final String schoolId;
  final String studentCode;
  final String admissionNumber;
  final String firstName;
  final String lastName;
  final String? dateOfBirth;
  final String? admissionDate;
  final String? gender;
  final String? currentSectionId;
  final String status;
  final String photoUrl;
  final List<Map<String, dynamic>> guardians;
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> parentAccounts;
  final Map<String, dynamic> primaryGuardian;
  final Map<String, dynamic> medicalRecord;
  final Map<String, dynamic> currentSection;
  final Map<String, dynamic> attendanceSummary;
  final Map<String, dynamic> feeSummary;
  final Map<String, dynamic> performanceSummary;

  const StudentModel({
    required this.id,
    required this.schoolId,
    required this.studentCode,
    required this.admissionNumber,
    required this.firstName,
    required this.lastName,
    this.dateOfBirth,
    this.admissionDate,
    this.gender,
    this.currentSectionId,
    required this.status,
    required this.photoUrl,
    this.guardians = const [],
    this.documents = const [],
    this.parentAccounts = const [],
    this.primaryGuardian = const {},
    this.medicalRecord = const {},
    this.currentSection = const {},
    this.attendanceSummary = const {},
    this.feeSummary = const {},
    this.performanceSummary = const {},
  });

  String get fullName => '$firstName $lastName'.trim();
  double get attendancePercent => _doubleFromJson(
    attendanceSummary['percent'] ?? attendanceSummary['attendance_percent'],
  );
  String get attendanceStatusLabel =>
      (attendanceSummary['status_label'] ?? '').toString().trim();
  String get feeStatus => (feeSummary['status'] ?? 'clear').toString().trim();
  double get feeBalance => _doubleFromJson(feeSummary['balance']);
  int get pendingInvoices => _intFromJson(feeSummary['pending_invoices']);
  double get performanceScore =>
      _doubleFromJson(performanceSummary['average_percent']);
  String get performanceGrade =>
      (performanceSummary['grade'] ?? 'N/A').toString().trim();
  int get documentCount => documents.length;
  String get primaryGuardianName {
    final name = (primaryGuardian['full_name'] ?? primaryGuardian['name'] ?? '')
        .toString()
        .trim();
    if (name.isNotEmpty) return name;
    if (parentAccounts.isNotEmpty) {
      final parent = parentAccounts.first;
      final parentName = (parent['name'] ?? parent['username'] ?? '')
          .toString()
          .trim();
      if (parentName.isNotEmpty) return parentName;
    }
    return '';
  }

  String get primaryGuardianPhone {
    final phone = (primaryGuardian['phone'] ?? '').toString().trim();
    if (phone.isNotEmpty) return phone;
    if (parentAccounts.isNotEmpty) {
      return (parentAccounts.first['phone'] ?? '').toString().trim();
    }
    return '';
  }

  factory StudentModel.fromJson(Map<String, dynamic> json) => StudentModel(
    id: json['id'] as String,
    schoolId: json['school_id'] as String? ?? '',
    studentCode: json['student_code'] as String? ?? '',
    admissionNumber: json['admission_number'] as String? ?? '',
    firstName: json['first_name'] as String? ?? '',
    lastName: json['last_name'] as String? ?? '',
    dateOfBirth: json['date_of_birth'] as String?,
    admissionDate: json['admission_date'] as String?,
    gender: json['gender'] as String?,
    currentSectionId: json['current_section_id'] as String?,
    status: json['status'] as String? ?? 'active',
    photoUrl: _photoUrlFromJson(json),
    guardians: _asListMap(json['guardians']),
    documents: _asListMap(json['documents']),
    parentAccounts: _asListMap(json['parent_accounts']),
    primaryGuardian: _asMap(json['primary_guardian']),
    medicalRecord: _asMap(json['medical_record']),
    currentSection: _asMap(json['current_section']),
    attendanceSummary: _asMap(json['attendance_summary']),
    feeSummary: _asMap(json['fee_summary']),
    performanceSummary: _asMap(json['performance_summary']),
  );

  static List<Map<String, dynamic>> _asListMap(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static double _doubleFromJson(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  static int _intFromJson(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  static String _photoUrlFromJson(Map<String, dynamic> json) {
    final direct = (json['photo_url'] ?? json['photo'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final documents = json['documents'];
    if (documents is List) {
      for (final item in documents) {
        if (item is! Map) continue;
        final type = (item['doc_type'] ?? item['type'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        if (type != 'profile_photo' && type != 'student_photo') continue;
        final url = (item['file_url'] ?? item['url'] ?? '').toString().trim();
        if (url.isNotEmpty) return url;
      }
    }
    return '';
  }
}

// ─── Attendance Models ────────────────────────────────────────────────────────

class AttendanceSessionModel {
  final String id;
  final String sectionId;
  final String timetableSlotId;
  final String subjectId;
  final String staffId;
  final String date;
  final int periodNumber;
  final int totalStudents;
  final int presentCount;

  const AttendanceSessionModel({
    required this.id,
    required this.sectionId,
    required this.timetableSlotId,
    required this.subjectId,
    required this.staffId,
    required this.date,
    required this.periodNumber,
    required this.totalStudents,
    required this.presentCount,
  });

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> json) =>
      AttendanceSessionModel(
        id: json['id'] as String,
        sectionId: json['section_id'] as String,
        timetableSlotId: json['timetable_slot_id'] as String? ?? '',
        subjectId: json['subject_id'] as String,
        staffId: json['staff_id'] as String,
        date: json['date'] as String,
        periodNumber: json['period_number'] as int? ?? 0,
        totalStudents: json['total_students'] as int? ?? 0,
        presentCount: json['present_count'] as int? ?? 0,
      );
}

class StaffQrTokenModel {
  final String token;
  final String schoolDate;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final DateTime? serverTime;
  final int refreshAfterSeconds;

  const StaffQrTokenModel({
    required this.token,
    required this.schoolDate,
    required this.issuedAt,
    required this.expiresAt,
    required this.serverTime,
    required this.refreshAfterSeconds,
  });

  bool get isExpired =>
      expiresAt != null && !DateTime.now().toUtc().isBefore(expiresAt!);

  int get secondsRemaining {
    final expiry = expiresAt;
    if (expiry == null) return refreshAfterSeconds;
    final remaining = expiry.difference(DateTime.now().toUtc()).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  factory StaffQrTokenModel.fromJson(Map<String, dynamic> json) =>
      StaffQrTokenModel(
        token: '${json['token'] ?? ''}',
        schoolDate: '${json['school_date'] ?? ''}',
        issuedAt: _parseDateTime(json['issued_at']),
        expiresAt: _parseDateTime(json['expires_at']),
        serverTime: _parseDateTime(json['server_time']),
        refreshAfterSeconds: _intValue(json['refresh_after_seconds'], 60),
      );

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  static int _intValue(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }
}

class StaffAttendanceModel {
  final String id;
  final String staffId;
  final DateTime? date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status;
  final String source;
  final String biometricId;
  final String markedBy;
  final StaffModel? staff;

  const StaffAttendanceModel({
    required this.id,
    required this.staffId,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.status,
    required this.source,
    required this.biometricId,
    required this.markedBy,
    required this.staff,
  });

  bool get checkedIn => checkIn != null;

  String get staffName {
    final name = staff?.fullName.trim() ?? '';
    if (name.isNotEmpty) return name;
    return staffId;
  }

  String get checkInTimeLabel => _clockLabel(checkIn);

  String get checkOutTimeLabel => _clockLabel(checkOut);

  factory StaffAttendanceModel.fromJson(Map<String, dynamic> json) {
    final staffJson = json['staff'];
    return StaffAttendanceModel(
      id: '${json['id'] ?? ''}',
      staffId: '${json['staff_id'] ?? ''}',
      date: _parseDateTime(json['date']),
      checkIn: _parseDateTime(json['check_in']),
      checkOut: _parseDateTime(json['check_out']),
      status: '${json['status'] ?? ''}',
      source: '${json['source'] ?? 'manual'}',
      biometricId: '${json['biometric_id'] ?? ''}',
      markedBy: '${json['marked_by'] ?? ''}',
      staff: staffJson is Map
          ? StaffModel.fromJson(Map<String, dynamic>.from(staffJson))
          : null,
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static String _clockLabel(DateTime? value) {
    if (value == null) return '--:--';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class TimetableSuggestionModel {
  final String sectionId;
  final String academicYearId;
  final String termId;
  final int dayOfWeek;
  final int periodNumber;
  final String subjectId;
  final String subjectName;
  final String staffId;
  final String staffName;
  final String roomId;
  final String roomName;
  final String startTime;
  final String endTime;
  final int confidence;
  final List<String> warnings;
  final bool blocking;

  const TimetableSuggestionModel({
    required this.sectionId,
    required this.academicYearId,
    required this.termId,
    required this.dayOfWeek,
    required this.periodNumber,
    required this.subjectId,
    required this.subjectName,
    required this.staffId,
    required this.staffName,
    required this.roomId,
    required this.roomName,
    required this.startTime,
    required this.endTime,
    required this.confidence,
    required this.warnings,
    required this.blocking,
  });

  factory TimetableSuggestionModel.fromJson(Map<String, dynamic> json) {
    final warnings = json['warnings'] is List
        ? (json['warnings'] as List).map((value) => '$value').toList()
        : <String>[];
    return TimetableSuggestionModel(
      sectionId: '${json['section_id'] ?? ''}',
      academicYearId: '${json['academic_year_id'] ?? ''}',
      termId: '${json['term_id'] ?? ''}',
      dayOfWeek: _intFromJson(json['day_of_week']),
      periodNumber: _intFromJson(json['period_number']),
      subjectId: '${json['subject_id'] ?? ''}',
      subjectName: '${json['subject_name'] ?? json['subject_id'] ?? ''}',
      staffId: '${json['staff_id'] ?? ''}',
      staffName: '${json['staff_name'] ?? json['staff_id'] ?? ''}',
      roomId: '${json['room_id'] ?? ''}',
      roomName: '${json['room_name'] ?? json['room_id'] ?? ''}',
      startTime: '${json['start_time'] ?? ''}',
      endTime: '${json['end_time'] ?? ''}',
      confidence: _intFromJson(json['confidence']),
      warnings: warnings,
      blocking: json['blocking'] == true,
    );
  }

  Map<String, dynamic> toSlotPayload() => {
    'section_id': sectionId,
    'academic_year_id': academicYearId,
    'term_id': termId,
    'day_of_week': dayOfWeek,
    'period_number': periodNumber,
    'subject_id': subjectId,
    'staff_id': staffId,
    'room_id': roomId,
    'start_time': startTime,
    'end_time': endTime,
  };

  static int _intFromJson(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

class TimetableSuggestionResult {
  final String sectionId;
  final String academicYearId;
  final String termId;
  final int dayOfWeek;
  final List<TimetableSuggestionModel> suggestions;
  final int requestedPeriods;
  final int suggestedPeriods;
  final int creatablePeriods;
  final int blockedPeriods;

  const TimetableSuggestionResult({
    required this.sectionId,
    required this.academicYearId,
    required this.termId,
    required this.dayOfWeek,
    required this.suggestions,
    required this.requestedPeriods,
    required this.suggestedPeriods,
    required this.creatablePeriods,
    required this.blockedPeriods,
  });

  factory TimetableSuggestionResult.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : <String, dynamic>{};
    final suggestions = json['suggestions'] is List
        ? (json['suggestions'] as List)
              .whereType<Map>()
              .map(
                (row) => TimetableSuggestionModel.fromJson(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList()
        : <TimetableSuggestionModel>[];
    return TimetableSuggestionResult(
      sectionId: '${json['section_id'] ?? ''}',
      academicYearId: '${json['academic_year_id'] ?? ''}',
      termId: '${json['term_id'] ?? ''}',
      dayOfWeek: TimetableSuggestionModel._intFromJson(json['day_of_week']),
      suggestions: suggestions,
      requestedPeriods: TimetableSuggestionModel._intFromJson(
        summary['requested_periods'],
      ),
      suggestedPeriods: TimetableSuggestionModel._intFromJson(
        summary['suggested_periods'],
      ),
      creatablePeriods: TimetableSuggestionModel._intFromJson(
        summary['creatable_periods'],
      ),
      blockedPeriods: TimetableSuggestionModel._intFromJson(
        summary['blocked_periods'],
      ),
    );
  }

  Map<String, dynamic> toSummaryPayload() => {
    'requested_periods': requestedPeriods,
    'suggested_periods': suggestedPeriods,
    'creatable_periods': creatablePeriods,
    'blocked_periods': blockedPeriods,
  };
}

class TimetableGenerationResult {
  final int created;
  final int skipped;
  final List<TimetableSuggestionModel> skippedSuggestions;

  const TimetableGenerationResult({
    required this.created,
    required this.skipped,
    required this.skippedSuggestions,
  });

  factory TimetableGenerationResult.fromJson(Map<String, dynamic> json) {
    final skippedSuggestions = json['skipped_suggestions'] is List
        ? (json['skipped_suggestions'] as List)
              .whereType<Map>()
              .map(
                (row) => TimetableSuggestionModel.fromJson(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList()
        : <TimetableSuggestionModel>[];
    return TimetableGenerationResult(
      created: TimetableSuggestionModel._intFromJson(json['created']),
      skipped: TimetableSuggestionModel._intFromJson(json['skipped']),
      skippedSuggestions: skippedSuggestions,
    );
  }
}

// ─── Exam Models ──────────────────────────────────────────────────────────────

class ExamModel {
  final String id;
  final String schoolId;
  final String academicYearId;
  final String termId;
  final String examTypeId;
  final String examName;
  final String startDate;
  final String endDate;
  final bool isPublished;

  const ExamModel({
    required this.id,
    required this.schoolId,
    required this.academicYearId,
    required this.termId,
    required this.examTypeId,
    required this.examName,
    required this.startDate,
    required this.endDate,
    required this.isPublished,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) => ExamModel(
    id: '${json['id'] ?? json['exam_id'] ?? ''}',
    schoolId: '${json['school_id'] ?? ''}',
    academicYearId: '${json['academic_year_id'] ?? ''}',
    termId: '${json['term_id'] ?? ''}',
    examTypeId: '${json['exam_type_id'] ?? json['exam_type'] ?? ''}',
    examName: '${json['exam_name'] ?? ''}',
    startDate: '${json['start_date'] ?? json['exam_date'] ?? ''}',
    endDate: '${json['end_date'] ?? json['exam_date'] ?? ''}',
    isPublished:
        json['is_published'] as bool? ??
        '${json['status'] ?? ''}'.toLowerCase() == 'published',
  );
}

// ─── Fee Models ───────────────────────────────────────────────────────────────

class FeeInvoiceModel {
  final String id;
  final String studentId;
  final String invoiceNumber;
  final String invoiceDate;
  final String dueDate;
  final double totalAmount;
  final double discountAmount;
  final double netAmount;
  final double paidAmount;
  final double balance;
  final String status;

  const FeeInvoiceModel({
    required this.id,
    required this.studentId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.dueDate,
    required this.totalAmount,
    required this.discountAmount,
    required this.netAmount,
    required this.paidAmount,
    required this.balance,
    required this.status,
  });

  factory FeeInvoiceModel.fromJson(Map<String, dynamic> json) =>
      FeeInvoiceModel(
        id: json['id'] as String,
        studentId: json['student_id'] as String,
        invoiceNumber: json['invoice_number'] as String,
        invoiceDate: json['invoice_date'] as String,
        dueDate: json['due_date'] as String,
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
        discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
        netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0,
        paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'pending',
      );
}

class PaymentRequest {
  final String invoiceId;
  final String receiptNumber;
  final double amountPaid;
  final String paymentDate;
  final String paymentMode;
  final String? transactionId;

  const PaymentRequest({
    required this.invoiceId,
    required this.receiptNumber,
    required this.amountPaid,
    required this.paymentDate,
    required this.paymentMode,
    this.transactionId,
  });

  Map<String, dynamic> toJson() => {
    'invoice_id': invoiceId,
    'receipt_number': receiptNumber,
    'amount_paid': amountPaid,
    'payment_date': paymentDate,
    'payment_mode': paymentMode,
    if (transactionId != null) 'transaction_id': transactionId,
  };

  Map<String, dynamic> toParentPaymentRequestJson() => {
    'invoice_id': invoiceId,
    'request_reference': receiptNumber,
    'amount': amountPaid,
    'payment_date': paymentDate,
    'payment_mode': paymentMode,
    if (transactionId != null) 'transaction_id': transactionId,
  };
}

// ─── Leave Models ─────────────────────────────────────────────────────────────

class LeaveApplicationModel {
  final String id;
  final String staffId;
  final String leaveTypeId;
  final String fromDate;
  final String toDate;
  final bool halfDay;
  final double totalDays;
  final String? reason;
  final String status;
  final String? rejectionReason;

  const LeaveApplicationModel({
    required this.id,
    required this.staffId,
    required this.leaveTypeId,
    required this.fromDate,
    required this.toDate,
    required this.halfDay,
    required this.totalDays,
    this.reason,
    required this.status,
    this.rejectionReason,
  });

  factory LeaveApplicationModel.fromJson(Map<String, dynamic> json) =>
      LeaveApplicationModel(
        id: json['id'] as String,
        staffId: json['staff_id'] as String,
        leaveTypeId: json['leave_type_id'] as String,
        fromDate: json['from_date'] as String,
        toDate: json['to_date'] as String,
        halfDay: json['half_day'] as bool? ?? false,
        totalDays: (json['total_days'] as num?)?.toDouble() ?? 0,
        reason: json['reason'] as String?,
        status: json['status'] as String? ?? 'pending',
        rejectionReason: json['rejection_reason'] as String?,
      );
}

class LeaveApplicationRequest {
  final String staffId;
  final String leaveTypeId;
  final String fromDate;
  final String toDate;
  final bool halfDay;
  final String? reason;

  const LeaveApplicationRequest({
    required this.staffId,
    required this.leaveTypeId,
    required this.fromDate,
    required this.toDate,
    this.halfDay = false,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
    'staff_id': staffId,
    'leave_type_id': leaveTypeId,
    'from_date': fromDate,
    'to_date': toDate,
    'half_day': halfDay,
    if (reason != null) 'reason': reason,
  };
}

// ─── Announcement Models ──────────────────────────────────────────────────────

class AnnouncementModel {
  final String id;
  final String schoolId;
  final String title;
  final String content;
  final String targetAudience;
  final bool isUrgent;
  final String createdBy;
  final String publishedAt;
  final String? attachmentUrl;

  const AnnouncementModel({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.content,
    required this.targetAudience,
    required this.isUrgent,
    required this.createdBy,
    required this.publishedAt,
    this.attachmentUrl,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) =>
      AnnouncementModel(
        id: json['id'] as String,
        schoolId: json['school_id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        targetAudience: json['target_audience'] as String? ?? 'all',
        isUrgent: json['is_urgent'] as bool? ?? false,
        createdBy: json['created_by'] as String,
        publishedAt: json['published_at'] as String,
        attachmentUrl: json['attachment_url'] as String?,
      );
}
