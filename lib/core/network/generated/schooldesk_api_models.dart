import 'package:freezed_annotation/freezed_annotation.dart';

part 'schooldesk_api_models.freezed.dart';
part 'schooldesk_api_models.g.dart';

@freezed
abstract class ApiEnvelope with _$ApiEnvelope {
  const factory ApiEnvelope({
    @Default(false) bool success,
    String? code,
    String? message,
    dynamic data,
    String? error,
    dynamic details,
    @JsonKey(name: 'request_id') String? requestId,
  }) = _ApiEnvelope;

  factory ApiEnvelope.fromJson(Map<String, dynamic> json) =>
      _$ApiEnvelopeFromJson(json);
}

@freezed
abstract class PaginatedEnvelope with _$PaginatedEnvelope {
  const factory PaginatedEnvelope({
    @Default(false) bool success,
    @Default(<dynamic>[]) List<dynamic> data,
    @Default(1) int page,
    @JsonKey(name: 'page_size') @Default(20) int pageSize,
    @Default(0) int total,
    @JsonKey(name: 'total_pages') @Default(0) int totalPages,
  }) = _PaginatedEnvelope;

  factory PaginatedEnvelope.fromJson(Map<String, dynamic> json) =>
      _$PaginatedEnvelopeFromJson(json);
}

@freezed
abstract class LoginRequestDto with _$LoginRequestDto {
  const factory LoginRequestDto({
    String? username,
    String? email,
    required String password,
  }) = _LoginRequestDto;

  factory LoginRequestDto.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestDtoFromJson(json);
}

@freezed
abstract class UserDto with _$UserDto {
  const factory UserDto({
    String? id,
    String? username,
    String? name,
    String? email,
    String? phone,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'role_id') String? roleId,
    @JsonKey(name: 'role_name') String? roleName,
    @JsonKey(name: 'linked_type') String? linkedType,
    @JsonKey(name: 'linked_id') String? linkedId,
    @JsonKey(name: 'is_active') bool? isActive,
    @JsonKey(name: 'is_verified') bool? isVerified,
  }) = _UserDto;

  factory UserDto.fromJson(Map<String, dynamic> json) =>
      _$UserDtoFromJson(json);
}

@freezed
abstract class LoginPayloadDto with _$LoginPayloadDto {
  const factory LoginPayloadDto({
    String? token,
    @JsonKey(name: 'refresh_token') String? refreshToken,
    @JsonKey(name: 'expires_at') int? expiresAt,
    UserDto? user,
  }) = _LoginPayloadDto;

  factory LoginPayloadDto.fromJson(Map<String, dynamic> json) =>
      _$LoginPayloadDtoFromJson(json);
}

@freezed
abstract class TablesMdClassDto with _$TablesMdClassDto {
  const factory TablesMdClassDto({
    String? id,
    @JsonKey(name: 'class_id') String? classId,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'academic_year_id') String? academicYearId,
    @JsonKey(name: 'class_name') String? className,
    @JsonKey(name: 'class_code') String? classCode,
    @JsonKey(name: 'section_id') String? sectionId,
    @JsonKey(name: 'class_teacher_id') String? classTeacherId,
    @JsonKey(name: 'room_id') String? roomId,
    String? medium,
    @JsonKey(name: 'sort_order') int? sortOrder,
    @JsonKey(name: 'is_active') bool? isActive,
  }) = _TablesMdClassDto;

  factory TablesMdClassDto.fromJson(Map<String, dynamic> json) =>
      _$TablesMdClassDtoFromJson(json);
}

@freezed
abstract class TablesMdAttendanceDto with _$TablesMdAttendanceDto {
  const factory TablesMdAttendanceDto({
    String? id,
    @JsonKey(name: 'attendance_id') String? attendanceId,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'academic_year_id') String? academicYearId,
    @JsonKey(name: 'attendance_type') String? attendanceType,
    @JsonKey(name: 'student_id') String? studentId,
    @JsonKey(name: 'staff_id') String? staffId,
    @JsonKey(name: 'class_id') String? classId,
    @JsonKey(name: 'section_id') String? sectionId,
    @JsonKey(name: 'attendance_date') dynamic attendanceDate,
    String? status,
    @JsonKey(name: 'marked_by') String? markedBy,
    String? remarks,
  }) = _TablesMdAttendanceDto;

  factory TablesMdAttendanceDto.fromJson(Map<String, dynamic> json) =>
      _$TablesMdAttendanceDtoFromJson(json);
}

@freezed
abstract class TablesMdFeeDto with _$TablesMdFeeDto {
  const factory TablesMdFeeDto({
    String? id,
    @JsonKey(name: 'fee_id') String? feeId,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'academic_year_id') String? academicYearId,
    @JsonKey(name: 'student_id') String? studentId,
    @JsonKey(name: 'class_id') String? classId,
    @JsonKey(name: 'section_id') String? sectionId,
    @JsonKey(name: 'fee_type_id') String? feeTypeId,
    @JsonKey(name: 'invoice_no') String? invoiceNo,
    @JsonKey(name: 'receipt_no') String? receiptNo,
    @JsonKey(name: 'due_date') dynamic dueDate,
    num? amount,
    @JsonKey(name: 'discount_amount') num? discountAmount,
    @JsonKey(name: 'fine_amount') num? fineAmount,
    @JsonKey(name: 'paid_amount') num? paidAmount,
    @JsonKey(name: 'balance_amount') num? balanceAmount,
    @JsonKey(name: 'payment_mode') String? paymentMode,
    @JsonKey(name: 'payment_status') String? paymentStatus,
    @JsonKey(name: 'transaction_id') String? transactionId,
    String? remarks,
  }) = _TablesMdFeeDto;

  factory TablesMdFeeDto.fromJson(Map<String, dynamic> json) =>
      _$TablesMdFeeDtoFromJson(json);
}

@freezed
abstract class ExamDto with _$ExamDto {
  const factory ExamDto({
    String? id,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'academic_year_id') String? academicYearId,
    @JsonKey(name: 'term_id') String? termId,
    @JsonKey(name: 'exam_type_id') String? examTypeId,
    @JsonKey(name: 'exam_name') String? examName,
    @JsonKey(name: 'start_date') dynamic startDate,
    @JsonKey(name: 'end_date') dynamic endDate,
    @JsonKey(name: 'is_published') bool? isPublished,
    @Default(<ExamScheduleDto>[]) List<ExamScheduleDto> schedules,
  }) = _ExamDto;

  factory ExamDto.fromJson(Map<String, dynamic> json) =>
      _$ExamDtoFromJson(json);
}

@freezed
abstract class ExamScheduleDto with _$ExamScheduleDto {
  const factory ExamScheduleDto({
    String? id,
    @JsonKey(name: 'exam_id') String? examId,
    @JsonKey(name: 'grade_id') String? gradeId,
    @JsonKey(name: 'section_id') String? sectionId,
    @JsonKey(name: 'subject_id') String? subjectId,
    @JsonKey(name: 'exam_date') dynamic examDate,
    @JsonKey(name: 'start_time') String? startTime,
    @JsonKey(name: 'end_time') String? endTime,
    @JsonKey(name: 'max_marks') int? maxMarks,
    @JsonKey(name: 'pass_marks') int? passMarks,
    @JsonKey(name: 'room_id') String? roomId,
  }) = _ExamScheduleDto;

  factory ExamScheduleDto.fromJson(Map<String, dynamic> json) =>
      _$ExamScheduleDtoFromJson(json);
}

@freezed
abstract class StudentMarkDto with _$StudentMarkDto {
  const factory StudentMarkDto({
    String? id,
    @JsonKey(name: 'exam_schedule_id') String? examScheduleId,
    @JsonKey(name: 'student_id') String? studentId,
    @JsonKey(name: 'enrollment_id') String? enrollmentId,
    @JsonKey(name: 'marks_obtained') num? marksObtained,
    @JsonKey(name: 'grade_label') String? gradeLabel,
    @JsonKey(name: 'is_absent') bool? isAbsent,
    @JsonKey(name: 'is_exempted') bool? isExempted,
  }) = _StudentMarkDto;

  factory StudentMarkDto.fromJson(Map<String, dynamic> json) =>
      _$StudentMarkDtoFromJson(json);
}

@freezed
abstract class HomeworkDto with _$HomeworkDto {
  const factory HomeworkDto({
    String? id,
    @JsonKey(name: 'homework_id') String? homeworkId,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'academic_year_id') String? academicYearId,
    @JsonKey(name: 'class_id') String? classId,
    @JsonKey(name: 'section_id') String? sectionId,
    @JsonKey(name: 'subject_id') String? subjectId,
    @JsonKey(name: 'staff_id') String? staffId,
    @JsonKey(name: 'student_id') String? studentId,
    String? title,
    String? description,
    @JsonKey(name: 'assigned_date') dynamic assignedDate,
    @JsonKey(name: 'submission_date') dynamic submissionDate,
    @JsonKey(name: 'attachment_url') String? attachmentUrl,
    @JsonKey(name: 'submission_mode') String? submissionMode,
    String? status,
  }) = _HomeworkDto;

  factory HomeworkDto.fromJson(Map<String, dynamic> json) =>
      _$HomeworkDtoFromJson(json);
}

@freezed
abstract class LeaveDto with _$LeaveDto {
  const factory LeaveDto({
    String? id,
    @JsonKey(name: 'leave_id') String? leaveId,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'user_type') String? userType,
    @JsonKey(name: 'student_id') String? studentId,
    @JsonKey(name: 'staff_id') String? staffId,
    @JsonKey(name: 'leave_type_id') String? leaveTypeId,
    @JsonKey(name: 'from_date') dynamic fromDate,
    @JsonKey(name: 'to_date') dynamic toDate,
    @JsonKey(name: 'total_days') num? totalDays,
    String? reason,
    @JsonKey(name: 'approval_status') String? approvalStatus,
    @JsonKey(name: 'approved_by') String? approvedBy,
    @JsonKey(name: 'approved_at') dynamic approvedAt,
    String? remarks,
  }) = _LeaveDto;

  factory LeaveDto.fromJson(Map<String, dynamic> json) =>
      _$LeaveDtoFromJson(json);
}

@freezed
abstract class NotificationDto with _$NotificationDto {
  const factory NotificationDto({
    String? id,
    @JsonKey(name: 'notification_id') String? notificationId,
    @JsonKey(name: 'notification_log_id') String? notificationLogId,
    @JsonKey(name: 'school_id') String? schoolId,
    String? title,
    String? message,
    String? body,
    @JsonKey(name: 'notification_type') String? notificationType,
    String? type,
    @JsonKey(name: 'target_role') String? targetRole,
    @JsonKey(name: 'target_user_id') String? targetUserId,
    String? priority,
    String? route,
    @JsonKey(name: 'reference_type') String? referenceType,
    @JsonKey(name: 'reference_id') String? referenceId,
    @JsonKey(name: 'is_read') bool? isRead,
    @JsonKey(name: 'read_at') dynamic readAt,
    @JsonKey(name: 'sent_at') dynamic sentAt,
  }) = _NotificationDto;

  factory NotificationDto.fromJson(Map<String, dynamic> json) =>
      _$NotificationDtoFromJson(json);
}

@freezed
abstract class HolidayDto with _$HolidayDto {
  const factory HolidayDto({
    String? id,
    @JsonKey(name: 'holiday_id') String? holidayId,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'holiday_name') String? holidayName,
    @JsonKey(name: 'holiday_type') String? holidayType,
    @JsonKey(name: 'start_date') dynamic startDate,
    @JsonKey(name: 'end_date') dynamic endDate,
    String? description,
    @JsonKey(name: 'is_optional') bool? isOptional,
    @JsonKey(name: 'applicable_for') String? applicableFor,
    String? status,
  }) = _HolidayDto;

  factory HolidayDto.fromJson(Map<String, dynamic> json) =>
      _$HolidayDtoFromJson(json);
}

@freezed
abstract class EventDto with _$EventDto {
  const factory EventDto({
    String? id,
    @JsonKey(name: 'event_id') String? eventId,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'event_name') String? eventName,
    @JsonKey(name: 'event_type') String? eventType,
    String? description,
    @JsonKey(name: 'start_date') dynamic startDate,
    @JsonKey(name: 'end_date') dynamic endDate,
    @JsonKey(name: 'start_time') String? startTime,
    @JsonKey(name: 'end_time') String? endTime,
    String? venue,
    @JsonKey(name: 'organizer_id') String? organizerId,
    @JsonKey(name: 'audience_type') String? audienceType,
    @JsonKey(name: 'attachment_url') String? attachmentUrl,
    String? status,
    @JsonKey(name: 'is_holiday') bool? isHoliday,
    @JsonKey(name: 'academic_year_id') String? academicYearId,
  }) = _EventDto;

  factory EventDto.fromJson(Map<String, dynamic> json) =>
      _$EventDtoFromJson(json);
}

@freezed
abstract class ApprovalRequestDto with _$ApprovalRequestDto {
  const factory ApprovalRequestDto({
    String? id,
    @JsonKey(name: 'approval_id') String? approvalId,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'request_type') String? requestType,
    @JsonKey(name: 'module_name') String? moduleName,
    @JsonKey(name: 'reference_table') String? referenceTable,
    @JsonKey(name: 'reference_id') String? referenceId,
    String? title,
    String? description,
    String? priority,
    @JsonKey(name: 'approval_status') String? approvalStatus,
    @JsonKey(name: 'approved_by') String? approvedBy,
    @JsonKey(name: 'approved_at') dynamic approvedAt,
  }) = _ApprovalRequestDto;

  factory ApprovalRequestDto.fromJson(Map<String, dynamic> json) =>
      _$ApprovalRequestDtoFromJson(json);
}

@freezed
abstract class CommunicationDto with _$CommunicationDto {
  const factory CommunicationDto({
    String? id,
    @JsonKey(name: 'message_id') String? messageId,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'sender_id') String? senderId,
    @JsonKey(name: 'sender_role') String? senderRole,
    @JsonKey(name: 'receiver_id') String? receiverId,
    @JsonKey(name: 'receiver_role') String? receiverRole,
    @JsonKey(name: 'student_id') String? studentId,
    @JsonKey(name: 'message_type') String? messageType,
    @JsonKey(name: 'message_content') String? messageContent,
    @JsonKey(name: 'attachment_url') String? attachmentUrl,
    @JsonKey(name: 'is_read') bool? isRead,
    @JsonKey(name: 'sent_at') dynamic sentAt,
  }) = _CommunicationDto;

  factory CommunicationDto.fromJson(Map<String, dynamic> json) =>
      _$CommunicationDtoFromJson(json);
}

@freezed
abstract class PrincipalReportDto with _$PrincipalReportDto {
  const factory PrincipalReportDto({
    String? id,
    @JsonKey(name: 'report_id') String? reportId,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'report_name') String? reportName,
    @JsonKey(name: 'report_type') String? reportType,
    @JsonKey(name: 'module_name') String? moduleName,
    @JsonKey(name: 'generated_by') String? generatedBy,
    @JsonKey(name: 'generated_role') String? generatedRole,
    @JsonKey(name: 'report_status') String? reportStatus,
    @JsonKey(name: 'report_file_url') String? reportFileUrl,
    @JsonKey(name: 'total_records') int? totalRecords,
  }) = _PrincipalReportDto;

  factory PrincipalReportDto.fromJson(Map<String, dynamic> json) =>
      _$PrincipalReportDtoFromJson(json);
}

@freezed
abstract class DashboardDto with _$DashboardDto {
  const factory DashboardDto({
    String? role,
    @Default(<String, dynamic>{}) Map<String, dynamic> metrics,
    @Default(<String, dynamic>{}) Map<String, dynamic> fees,
    @JsonKey(name: 'today_attendance')
    @Default(<String, dynamic>{})
    Map<String, dynamic> todayAttendance,
    @Default(<dynamic>[]) List<dynamic> children,
    @JsonKey(name: 'assigned_classes')
    @Default(<dynamic>[])
    List<dynamic> assignedClasses,
    @JsonKey(name: 'staff_id') String? staffId,
  }) = _DashboardDto;

  factory DashboardDto.fromJson(Map<String, dynamic> json) =>
      _$DashboardDtoFromJson(json);
}

@freezed
abstract class StudentDto with _$StudentDto {
  const factory StudentDto({
    String? id,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'student_code') String? studentCode,
    @JsonKey(name: 'admission_number') String? admissionNumber,
    @JsonKey(name: 'first_name') String? firstName,
    @JsonKey(name: 'last_name') String? lastName,
    @JsonKey(name: 'current_section_id') String? currentSectionId,
    String? status,
  }) = _StudentDto;

  factory StudentDto.fromJson(Map<String, dynamic> json) =>
      _$StudentDtoFromJson(json);
}

@freezed
abstract class StaffDto with _$StaffDto {
  const factory StaffDto({
    String? id,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'staff_code') String? staffCode,
    @JsonKey(name: 'first_name') String? firstName,
    @JsonKey(name: 'last_name') String? lastName,
    String? email,
    String? phone,
    String? designation,
    String? status,
  }) = _StaffDto;

  factory StaffDto.fromJson(Map<String, dynamic> json) =>
      _$StaffDtoFromJson(json);
}

@freezed
abstract class AttendanceSessionDto with _$AttendanceSessionDto {
  const factory AttendanceSessionDto({
    String? id,
    @JsonKey(name: 'section_id') String? sectionId,
    @JsonKey(name: 'subject_id') String? subjectId,
    @JsonKey(name: 'staff_id') String? staffId,
    dynamic date,
    @JsonKey(name: 'period_number') int? periodNumber,
    @JsonKey(name: 'total_students') int? totalStudents,
    @JsonKey(name: 'present_count') int? presentCount,
    @JsonKey(name: 'is_finalized') bool? isFinalized,
  }) = _AttendanceSessionDto;

  factory AttendanceSessionDto.fromJson(Map<String, dynamic> json) =>
      _$AttendanceSessionDtoFromJson(json);
}

@freezed
abstract class FeeInvoiceDto with _$FeeInvoiceDto {
  const factory FeeInvoiceDto({
    String? id,
    @JsonKey(name: 'student_id') String? studentId,
    @JsonKey(name: 'academic_year_id') String? academicYearId,
    @JsonKey(name: 'invoice_number') String? invoiceNumber,
    @JsonKey(name: 'due_date') dynamic dueDate,
    @JsonKey(name: 'total_amount') num? totalAmount,
    @JsonKey(name: 'paid_amount') num? paidAmount,
    num? balance,
    String? status,
  }) = _FeeInvoiceDto;

  factory FeeInvoiceDto.fromJson(Map<String, dynamic> json) =>
      _$FeeInvoiceDtoFromJson(json);
}

@freezed
abstract class PaymentDto with _$PaymentDto {
  const factory PaymentDto({
    String? id,
    @JsonKey(name: 'invoice_id') String? invoiceId,
    @JsonKey(name: 'student_id') String? studentId,
    num? amount,
    @JsonKey(name: 'payment_mode') String? paymentMode,
    @JsonKey(name: 'transaction_id') String? transactionId,
    @JsonKey(name: 'paid_at') dynamic paidAt,
  }) = _PaymentDto;

  factory PaymentDto.fromJson(Map<String, dynamic> json) =>
      _$PaymentDtoFromJson(json);
}

@freezed
abstract class ParentPaymentRequestDto with _$ParentPaymentRequestDto {
  const factory ParentPaymentRequestDto({
    String? id,
    @JsonKey(name: 'invoice_id') String? invoiceId,
    @JsonKey(name: 'student_id') String? studentId,
    @JsonKey(name: 'parent_user_id') String? parentUserId,
    num? amount,
    String? status,
    String? remarks,
  }) = _ParentPaymentRequestDto;

  factory ParentPaymentRequestDto.fromJson(Map<String, dynamic> json) =>
      _$ParentPaymentRequestDtoFromJson(json);
}

@freezed
abstract class MessageConversationDto with _$MessageConversationDto {
  const factory MessageConversationDto({
    String? id,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'teacher_id') String? teacherId,
    @JsonKey(name: 'parent_id') String? parentId,
    @JsonKey(name: 'student_id') String? studentId,
    String? title,
    @JsonKey(name: 'last_message') String? lastMessage,
    @JsonKey(name: 'last_message_time') dynamic lastMessageTime,
  }) = _MessageConversationDto;

  factory MessageConversationDto.fromJson(Map<String, dynamic> json) =>
      _$MessageConversationDtoFromJson(json);
}

@freezed
abstract class MessageDto with _$MessageDto {
  const factory MessageDto({
    String? id,
    @JsonKey(name: 'conversation_id') String? conversationId,
    @JsonKey(name: 'sender_id') String? senderId,
    @JsonKey(name: 'sender_role') String? senderRole,
    @JsonKey(name: 'sender_name') String? senderName,
    String? body,
    @JsonKey(name: 'is_read') bool? isRead,
    @JsonKey(name: 'sent_at') dynamic sentAt,
  }) = _MessageDto;

  factory MessageDto.fromJson(Map<String, dynamic> json) =>
      _$MessageDtoFromJson(json);
}
