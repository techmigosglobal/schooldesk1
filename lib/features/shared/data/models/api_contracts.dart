/// API contract definitions — request/response models for backend integration.
/// These define the exact JSON structure expected from/sent to the REST API.
library;

// ─── Authentication ──────────────────────────────────────────────────────────

class LoginRequest {
  final String email;
  final String password;
  final String role;

  const LoginRequest({
    required this.email,
    required this.password,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'role': role,
  };
}

class LoginResponse {
  final String token;
  final String refreshToken;
  final String userId;
  final String role;
  final String name;
  final String email;
  final DateTime expiresAt;

  const LoginResponse({
    required this.token,
    required this.refreshToken,
    required this.userId,
    required this.role,
    required this.name,
    required this.email,
    required this.expiresAt,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    token: json['token'] as String,
    refreshToken: json['refresh_token'] as String,
    userId: json['user_id'] as String,
    role: json['role'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
  );
}

// ─── Pagination ──────────────────────────────────────────────────────────────

class PaginatedResponse<T> {
  final List<T> data;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;

  const PaginatedResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return PaginatedResponse(
      data: (json['data'] as List)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      hasMore: json['has_more'] as bool,
    );
  }
}

// ─── API Error Response ──────────────────────────────────────────────────────

class ApiErrorResponse {
  final String message;
  final String? code;
  final Map<String, List<String>>? fieldErrors;

  const ApiErrorResponse({required this.message, this.code, this.fieldErrors});

  factory ApiErrorResponse.fromJson(Map<String, dynamic> json) =>
      ApiErrorResponse(
        message: json['message'] as String? ?? 'An error occurred.',
        code: json['code'] as String?,
        fieldErrors: json['errors'] != null
            ? Map<String, List<String>>.from(
                (json['errors'] as Map).map(
                  (k, v) => MapEntry(k as String, List<String>.from(v as List)),
                ),
              )
            : null,
      );
}

// ─── Student API Contracts ───────────────────────────────────────────────────

class CreateStudentRequest {
  final String name;
  final String admissionNumber;
  final String rollNumber;
  final String className;
  final String section;
  final String parentName;
  final String parentPhone;
  final String? parentEmail;
  final String? dateOfBirth;
  final String? address;

  const CreateStudentRequest({
    required this.name,
    required this.admissionNumber,
    required this.rollNumber,
    required this.className,
    required this.section,
    required this.parentName,
    required this.parentPhone,
    this.parentEmail,
    this.dateOfBirth,
    this.address,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'admission_number': admissionNumber,
    'roll_number': rollNumber,
    'class_name': className,
    'section': section,
    'parent_name': parentName,
    'parent_phone': parentPhone,
    if (parentEmail != null) 'parent_email': parentEmail,
    if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
    if (address != null) 'address': address,
  };
}

// ─── Attendance API Contracts ────────────────────────────────────────────────

class MarkAttendanceRequest {
  final String className;
  final String section;
  final String date; // ISO 8601
  final List<AttendanceEntryRequest> entries;

  const MarkAttendanceRequest({
    required this.className,
    required this.section,
    required this.date,
    required this.entries,
  });

  Map<String, dynamic> toJson() => {
    'class_name': className,
    'section': section,
    'date': date,
    'entries': entries.map((e) => e.toJson()).toList(),
  };
}

class AttendanceEntryRequest {
  final String studentId;
  final String status;
  final String? remarks;

  const AttendanceEntryRequest({
    required this.studentId,
    required this.status,
    this.remarks,
  });

  Map<String, dynamic> toJson() => {
    'student_id': studentId,
    'status': status,
    if (remarks != null) 'remarks': remarks,
  };
}

// ─── Fee API Contracts ───────────────────────────────────────────────────────

class RecordPaymentRequest {
  final String feeRecordId;
  final double amount;
  final String paymentMode;
  final String? remarks;

  const RecordPaymentRequest({
    required this.feeRecordId,
    required this.amount,
    required this.paymentMode,
    this.remarks,
  });

  Map<String, dynamic> toJson() => {
    'fee_record_id': feeRecordId,
    'amount': amount,
    'payment_mode': paymentMode,
    if (remarks != null) 'remarks': remarks,
  };
}

// ─── Leave API Contracts ─────────────────────────────────────────────────────

class SubmitLeaveRequest {
  final String leaveType;
  final String fromDate;
  final String toDate;
  final String reason;
  final String? substituteTeacher;
  final String? studentId;

  const SubmitLeaveRequest({
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.substituteTeacher,
    this.studentId,
  });

  Map<String, dynamic> toJson() => {
    'leave_type': leaveType,
    'from_date': fromDate,
    'to_date': toDate,
    'reason': reason,
    if (substituteTeacher != null) 'substitute_teacher': substituteTeacher,
    if (studentId != null) 'student_id': studentId,
  };
}

class ReviewLeaveRequest {
  final String action; // 'approve' or 'reject'
  final String? remark;

  const ReviewLeaveRequest({required this.action, this.remark});

  Map<String, dynamic> toJson() => {
    'action': action,
    if (remark != null) 'remark': remark,
  };
}
