/// API contract definitions for the school-desk REST backend.
///
/// These DTOs mirror the request/response payloads used by BackendApiClient.
/// LoginResponse and UserResponse are defined in backend_models.dart (the
/// single source of truth); do not redeclare them here.
library;

// Authentication -------------------------------------------------------------

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

  // If the caller typed an email address as their username, include it in the
  // 'email' field too so backends that accept either field work correctly.
  // No shorthand credential remapping — that logic belongs in dev/test tooling.
  static String _fallbackEmail(String value) {
    final identity = value.trim();
    if (_looksLikeEmail(identity)) return identity;
    return '';
  }

  static bool _looksLikeEmail(String value) {
    return value.contains('@') && value.contains('.');
  }
}

// LoginResponse and UserResponse are defined in backend_models.dart.
// Import that file (via BackendApiClient or directly) instead of declaring
// them here to avoid diverging fromJson implementations.

// Pagination -----------------------------------------------------------------

class PaginatedResponse<T> {
  final List<T> data;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PaginatedResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  bool get hasMore => page * pageSize < total;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return PaginatedResponse(
      data: _listMap(json['data']).map(fromJson).toList(),
      total: _int(json['total']),
      page: _int(json['page']),
      pageSize: _int(json['page_size']),
      totalPages: _int(json['total_pages']),
    );
  }
}

// Error responses ------------------------------------------------------------

class ApiErrorResponse {
  final String message;
  final String? code;
  final Map<String, List<String>>? fieldErrors;

  const ApiErrorResponse({required this.message, this.code, this.fieldErrors});

  factory ApiErrorResponse.fromJson(Map<String, dynamic> json) =>
      ApiErrorResponse(
        message: _firstText([
          json['error'],
          json['message'],
          'An error occurred.',
        ]),
        code: _nullableText(json['code']),
        fieldErrors: _fieldErrors(json['details'] ?? json['errors']),
      );
}

// Student API contracts ------------------------------------------------------

class CreateStudentRequest {
  final String firstName;
  final String lastName;
  final String dateOfBirth;
  final String gender;
  final String admissionNumber;
  final String studentCode;
  final String currentSectionId;
  final String admissionDate;
  final String status;

  const CreateStudentRequest({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    this.admissionNumber = '',
    this.studentCode = '',
    this.currentSectionId = '',
    this.admissionDate = '2026-01-01',
    this.status = 'active',
  });

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'last_name': lastName,
    'date_of_birth': dateOfBirth,
    'gender': gender,
    'admission_number': admissionNumber,
    'student_id_number': studentCode,
    'current_section_id': currentSectionId,
    'admission_date': admissionDate,
    'status': status,
  };
}

// Attendance API contracts ---------------------------------------------------

class MarkAttendanceRequest {
  final String sessionId;
  final List<AttendanceEntryRequest> attendances;

  const MarkAttendanceRequest({
    required this.sessionId,
    required this.attendances,
  });

  Map<String, dynamic> toJson() => {
    'attendances': attendances.map((entry) => entry.toJson()).toList(),
  };
}

class AttendanceEntryRequest {
  final String studentId;
  final String enrollmentId;
  final String status;
  final String reason;

  const AttendanceEntryRequest({
    required this.studentId,
    required this.enrollmentId,
    required this.status,
    this.reason = '',
  });

  Map<String, dynamic> toJson() => {
    'student_id': studentId,
    'enrollment_id': enrollmentId,
    'status': status,
    if (reason.trim().isNotEmpty) 'reason': reason.trim(),
  };
}

// Fee API contracts ----------------------------------------------------------

class RecordPaymentRequest {
  final String invoiceId;
  final String receiptNumber;
  final double amountPaid;
  final String paymentDate;
  final String paymentMode;
  final String? transactionId;

  const RecordPaymentRequest({
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
    if (_text(transactionId).isNotEmpty) 'transaction_id': transactionId,
  };
}

// Leave API contracts --------------------------------------------------------

class SubmitLeaveRequest {
  final String staffId;
  final String leaveTypeId;
  final String fromDate;
  final String toDate;
  final bool halfDay;
  final String? reason;

  const SubmitLeaveRequest({
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
    'start_date': fromDate,
    'end_date': toDate,
    if (_text(reason).isNotEmpty) 'reason': reason,
  };
}

class ReviewLeaveRequest {
  final String status;
  final String reason;

  const ReviewLeaveRequest({required this.status, this.reason = ''});

  Map<String, dynamic> toJson() => {'status': status, 'reason': reason};
}

String _text(Object? value) => value?.toString().trim() ?? '';

String? _nullableText(Object? value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}

String _firstText(Iterable<Object?> values) {
  for (final value in values) {
    final text = _text(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_text(value)) ?? 0;
}

List<Map<String, dynamic>> _listMap(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, List<String>>? _fieldErrors(Object? value) {
  if (value is! Map) return null;
  final errors = <String, List<String>>{};
  for (final entry in value.entries) {
    final key = _text(entry.key);
    if (key.isEmpty) continue;
    final raw = entry.value;
    if (raw is List) {
      errors[key] = raw.map(_text).where((item) => item.isNotEmpty).toList();
    } else {
      final message = _text(raw);
      if (message.isNotEmpty) errors[key] = [message];
    }
  }
  return errors.isEmpty ? null : errors;
}
