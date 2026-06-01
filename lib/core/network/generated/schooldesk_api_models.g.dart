// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schooldesk_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ApiEnvelope _$ApiEnvelopeFromJson(Map<String, dynamic> json) => _ApiEnvelope(
  success: json['success'] as bool? ?? false,
  code: json['code'] as String?,
  message: json['message'] as String?,
  data: json['data'],
  error: json['error'] as String?,
  details: json['details'],
  requestId: json['request_id'] as String?,
);

Map<String, dynamic> _$ApiEnvelopeToJson(_ApiEnvelope instance) =>
    <String, dynamic>{
      'success': instance.success,
      'code': instance.code,
      'message': instance.message,
      'data': instance.data,
      'error': instance.error,
      'details': instance.details,
      'request_id': instance.requestId,
    };

_PaginatedEnvelope _$PaginatedEnvelopeFromJson(Map<String, dynamic> json) =>
    _PaginatedEnvelope(
      success: json['success'] as bool? ?? false,
      data: json['data'] as List<dynamic>? ?? const <dynamic>[],
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PaginatedEnvelopeToJson(_PaginatedEnvelope instance) =>
    <String, dynamic>{
      'success': instance.success,
      'data': instance.data,
      'page': instance.page,
      'page_size': instance.pageSize,
      'total': instance.total,
      'total_pages': instance.totalPages,
    };

_LoginRequestDto _$LoginRequestDtoFromJson(Map<String, dynamic> json) =>
    _LoginRequestDto(
      username: json['username'] as String?,
      email: json['email'] as String?,
      password: json['password'] as String,
    );

Map<String, dynamic> _$LoginRequestDtoToJson(_LoginRequestDto instance) =>
    <String, dynamic>{
      'username': instance.username,
      'email': instance.email,
      'password': instance.password,
    };

_UserDto _$UserDtoFromJson(Map<String, dynamic> json) => _UserDto(
  id: json['id'] as String?,
  username: json['username'] as String?,
  name: json['name'] as String?,
  email: json['email'] as String?,
  phone: json['phone'] as String?,
  schoolId: json['school_id'] as String?,
  roleId: json['role_id'] as String?,
  roleName: json['role_name'] as String?,
  linkedType: json['linked_type'] as String?,
  linkedId: json['linked_id'] as String?,
  isActive: json['is_active'] as bool?,
  isVerified: json['is_verified'] as bool?,
);

Map<String, dynamic> _$UserDtoToJson(_UserDto instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'name': instance.name,
  'email': instance.email,
  'phone': instance.phone,
  'school_id': instance.schoolId,
  'role_id': instance.roleId,
  'role_name': instance.roleName,
  'linked_type': instance.linkedType,
  'linked_id': instance.linkedId,
  'is_active': instance.isActive,
  'is_verified': instance.isVerified,
};

_LoginPayloadDto _$LoginPayloadDtoFromJson(Map<String, dynamic> json) =>
    _LoginPayloadDto(
      token: json['token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      expiresAt: (json['expires_at'] as num?)?.toInt(),
      user: json['user'] == null
          ? null
          : UserDto.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LoginPayloadDtoToJson(_LoginPayloadDto instance) =>
    <String, dynamic>{
      'token': instance.token,
      'refresh_token': instance.refreshToken,
      'expires_at': instance.expiresAt,
      'user': instance.user,
    };

_TablesMdClassDto _$TablesMdClassDtoFromJson(Map<String, dynamic> json) =>
    _TablesMdClassDto(
      id: json['id'] as String?,
      classId: json['class_id'] as String?,
      schoolId: json['school_id'] as String?,
      academicYearId: json['academic_year_id'] as String?,
      className: json['class_name'] as String?,
      classCode: json['class_code'] as String?,
      sectionId: json['section_id'] as String?,
      classTeacherId: json['class_teacher_id'] as String?,
      roomId: json['room_id'] as String?,
      medium: json['medium'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      isActive: json['is_active'] as bool?,
    );

Map<String, dynamic> _$TablesMdClassDtoToJson(_TablesMdClassDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'class_id': instance.classId,
      'school_id': instance.schoolId,
      'academic_year_id': instance.academicYearId,
      'class_name': instance.className,
      'class_code': instance.classCode,
      'section_id': instance.sectionId,
      'class_teacher_id': instance.classTeacherId,
      'room_id': instance.roomId,
      'medium': instance.medium,
      'sort_order': instance.sortOrder,
      'is_active': instance.isActive,
    };

_TablesMdAttendanceDto _$TablesMdAttendanceDtoFromJson(
  Map<String, dynamic> json,
) => _TablesMdAttendanceDto(
  id: json['id'] as String?,
  attendanceId: json['attendance_id'] as String?,
  schoolId: json['school_id'] as String?,
  academicYearId: json['academic_year_id'] as String?,
  attendanceType: json['attendance_type'] as String?,
  studentId: json['student_id'] as String?,
  staffId: json['staff_id'] as String?,
  classId: json['class_id'] as String?,
  sectionId: json['section_id'] as String?,
  attendanceDate: json['attendance_date'],
  status: json['status'] as String?,
  markedBy: json['marked_by'] as String?,
  remarks: json['remarks'] as String?,
);

Map<String, dynamic> _$TablesMdAttendanceDtoToJson(
  _TablesMdAttendanceDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'attendance_id': instance.attendanceId,
  'school_id': instance.schoolId,
  'academic_year_id': instance.academicYearId,
  'attendance_type': instance.attendanceType,
  'student_id': instance.studentId,
  'staff_id': instance.staffId,
  'class_id': instance.classId,
  'section_id': instance.sectionId,
  'attendance_date': instance.attendanceDate,
  'status': instance.status,
  'marked_by': instance.markedBy,
  'remarks': instance.remarks,
};

_TablesMdFeeDto _$TablesMdFeeDtoFromJson(Map<String, dynamic> json) =>
    _TablesMdFeeDto(
      id: json['id'] as String?,
      feeId: json['fee_id'] as String?,
      schoolId: json['school_id'] as String?,
      academicYearId: json['academic_year_id'] as String?,
      studentId: json['student_id'] as String?,
      classId: json['class_id'] as String?,
      sectionId: json['section_id'] as String?,
      feeTypeId: json['fee_type_id'] as String?,
      invoiceNo: json['invoice_no'] as String?,
      receiptNo: json['receipt_no'] as String?,
      dueDate: json['due_date'],
      amount: json['amount'] as num?,
      discountAmount: json['discount_amount'] as num?,
      fineAmount: json['fine_amount'] as num?,
      paidAmount: json['paid_amount'] as num?,
      balanceAmount: json['balance_amount'] as num?,
      paymentMode: json['payment_mode'] as String?,
      paymentStatus: json['payment_status'] as String?,
      transactionId: json['transaction_id'] as String?,
      remarks: json['remarks'] as String?,
    );

Map<String, dynamic> _$TablesMdFeeDtoToJson(_TablesMdFeeDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fee_id': instance.feeId,
      'school_id': instance.schoolId,
      'academic_year_id': instance.academicYearId,
      'student_id': instance.studentId,
      'class_id': instance.classId,
      'section_id': instance.sectionId,
      'fee_type_id': instance.feeTypeId,
      'invoice_no': instance.invoiceNo,
      'receipt_no': instance.receiptNo,
      'due_date': instance.dueDate,
      'amount': instance.amount,
      'discount_amount': instance.discountAmount,
      'fine_amount': instance.fineAmount,
      'paid_amount': instance.paidAmount,
      'balance_amount': instance.balanceAmount,
      'payment_mode': instance.paymentMode,
      'payment_status': instance.paymentStatus,
      'transaction_id': instance.transactionId,
      'remarks': instance.remarks,
    };

_ExamDto _$ExamDtoFromJson(Map<String, dynamic> json) => _ExamDto(
  id: json['id'] as String?,
  schoolId: json['school_id'] as String?,
  academicYearId: json['academic_year_id'] as String?,
  termId: json['term_id'] as String?,
  examTypeId: json['exam_type_id'] as String?,
  examName: json['exam_name'] as String?,
  startDate: json['start_date'],
  endDate: json['end_date'],
  isPublished: json['is_published'] as bool?,
  schedules:
      (json['schedules'] as List<dynamic>?)
          ?.map((e) => ExamScheduleDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ExamScheduleDto>[],
);

Map<String, dynamic> _$ExamDtoToJson(_ExamDto instance) => <String, dynamic>{
  'id': instance.id,
  'school_id': instance.schoolId,
  'academic_year_id': instance.academicYearId,
  'term_id': instance.termId,
  'exam_type_id': instance.examTypeId,
  'exam_name': instance.examName,
  'start_date': instance.startDate,
  'end_date': instance.endDate,
  'is_published': instance.isPublished,
  'schedules': instance.schedules,
};

_ExamScheduleDto _$ExamScheduleDtoFromJson(Map<String, dynamic> json) =>
    _ExamScheduleDto(
      id: json['id'] as String?,
      examId: json['exam_id'] as String?,
      gradeId: json['grade_id'] as String?,
      sectionId: json['section_id'] as String?,
      subjectId: json['subject_id'] as String?,
      examDate: json['exam_date'],
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      maxMarks: (json['max_marks'] as num?)?.toInt(),
      passMarks: (json['pass_marks'] as num?)?.toInt(),
      roomId: json['room_id'] as String?,
    );

Map<String, dynamic> _$ExamScheduleDtoToJson(_ExamScheduleDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'exam_id': instance.examId,
      'grade_id': instance.gradeId,
      'section_id': instance.sectionId,
      'subject_id': instance.subjectId,
      'exam_date': instance.examDate,
      'start_time': instance.startTime,
      'end_time': instance.endTime,
      'max_marks': instance.maxMarks,
      'pass_marks': instance.passMarks,
      'room_id': instance.roomId,
    };

_StudentMarkDto _$StudentMarkDtoFromJson(Map<String, dynamic> json) =>
    _StudentMarkDto(
      id: json['id'] as String?,
      examScheduleId: json['exam_schedule_id'] as String?,
      studentId: json['student_id'] as String?,
      enrollmentId: json['enrollment_id'] as String?,
      marksObtained: json['marks_obtained'] as num?,
      gradeLabel: json['grade_label'] as String?,
      isAbsent: json['is_absent'] as bool?,
      isExempted: json['is_exempted'] as bool?,
    );

Map<String, dynamic> _$StudentMarkDtoToJson(_StudentMarkDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'exam_schedule_id': instance.examScheduleId,
      'student_id': instance.studentId,
      'enrollment_id': instance.enrollmentId,
      'marks_obtained': instance.marksObtained,
      'grade_label': instance.gradeLabel,
      'is_absent': instance.isAbsent,
      'is_exempted': instance.isExempted,
    };

_HomeworkDto _$HomeworkDtoFromJson(Map<String, dynamic> json) => _HomeworkDto(
  id: json['id'] as String?,
  homeworkId: json['homework_id'] as String?,
  schoolId: json['school_id'] as String?,
  academicYearId: json['academic_year_id'] as String?,
  classId: json['class_id'] as String?,
  sectionId: json['section_id'] as String?,
  subjectId: json['subject_id'] as String?,
  staffId: json['staff_id'] as String?,
  studentId: json['student_id'] as String?,
  title: json['title'] as String?,
  description: json['description'] as String?,
  assignedDate: json['assigned_date'],
  submissionDate: json['submission_date'],
  attachmentUrl: json['attachment_url'] as String?,
  submissionMode: json['submission_mode'] as String?,
  status: json['status'] as String?,
);

Map<String, dynamic> _$HomeworkDtoToJson(_HomeworkDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'homework_id': instance.homeworkId,
      'school_id': instance.schoolId,
      'academic_year_id': instance.academicYearId,
      'class_id': instance.classId,
      'section_id': instance.sectionId,
      'subject_id': instance.subjectId,
      'staff_id': instance.staffId,
      'student_id': instance.studentId,
      'title': instance.title,
      'description': instance.description,
      'assigned_date': instance.assignedDate,
      'submission_date': instance.submissionDate,
      'attachment_url': instance.attachmentUrl,
      'submission_mode': instance.submissionMode,
      'status': instance.status,
    };

_LeaveDto _$LeaveDtoFromJson(Map<String, dynamic> json) => _LeaveDto(
  id: json['id'] as String?,
  leaveId: json['leave_id'] as String?,
  schoolId: json['school_id'] as String?,
  userType: json['user_type'] as String?,
  studentId: json['student_id'] as String?,
  staffId: json['staff_id'] as String?,
  leaveTypeId: json['leave_type_id'] as String?,
  fromDate: json['from_date'],
  toDate: json['to_date'],
  totalDays: json['total_days'] as num?,
  reason: json['reason'] as String?,
  approvalStatus: json['approval_status'] as String?,
  approvedBy: json['approved_by'] as String?,
  approvedAt: json['approved_at'],
  remarks: json['remarks'] as String?,
);

Map<String, dynamic> _$LeaveDtoToJson(_LeaveDto instance) => <String, dynamic>{
  'id': instance.id,
  'leave_id': instance.leaveId,
  'school_id': instance.schoolId,
  'user_type': instance.userType,
  'student_id': instance.studentId,
  'staff_id': instance.staffId,
  'leave_type_id': instance.leaveTypeId,
  'from_date': instance.fromDate,
  'to_date': instance.toDate,
  'total_days': instance.totalDays,
  'reason': instance.reason,
  'approval_status': instance.approvalStatus,
  'approved_by': instance.approvedBy,
  'approved_at': instance.approvedAt,
  'remarks': instance.remarks,
};

_NotificationDto _$NotificationDtoFromJson(Map<String, dynamic> json) =>
    _NotificationDto(
      id: json['id'] as String?,
      notificationId: json['notification_id'] as String?,
      notificationLogId: json['notification_log_id'] as String?,
      schoolId: json['school_id'] as String?,
      title: json['title'] as String?,
      message: json['message'] as String?,
      body: json['body'] as String?,
      notificationType: json['notification_type'] as String?,
      type: json['type'] as String?,
      targetRole: json['target_role'] as String?,
      targetUserId: json['target_user_id'] as String?,
      priority: json['priority'] as String?,
      route: json['route'] as String?,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      isRead: json['is_read'] as bool?,
      readAt: json['read_at'],
      sentAt: json['sent_at'],
    );

Map<String, dynamic> _$NotificationDtoToJson(_NotificationDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'notification_id': instance.notificationId,
      'notification_log_id': instance.notificationLogId,
      'school_id': instance.schoolId,
      'title': instance.title,
      'message': instance.message,
      'body': instance.body,
      'notification_type': instance.notificationType,
      'type': instance.type,
      'target_role': instance.targetRole,
      'target_user_id': instance.targetUserId,
      'priority': instance.priority,
      'route': instance.route,
      'reference_type': instance.referenceType,
      'reference_id': instance.referenceId,
      'is_read': instance.isRead,
      'read_at': instance.readAt,
      'sent_at': instance.sentAt,
    };

_HolidayDto _$HolidayDtoFromJson(Map<String, dynamic> json) => _HolidayDto(
  id: json['id'] as String?,
  holidayId: json['holiday_id'] as String?,
  schoolId: json['school_id'] as String?,
  holidayName: json['holiday_name'] as String?,
  holidayType: json['holiday_type'] as String?,
  startDate: json['start_date'],
  endDate: json['end_date'],
  description: json['description'] as String?,
  isOptional: json['is_optional'] as bool?,
  applicableFor: json['applicable_for'] as String?,
  status: json['status'] as String?,
);

Map<String, dynamic> _$HolidayDtoToJson(_HolidayDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'holiday_id': instance.holidayId,
      'school_id': instance.schoolId,
      'holiday_name': instance.holidayName,
      'holiday_type': instance.holidayType,
      'start_date': instance.startDate,
      'end_date': instance.endDate,
      'description': instance.description,
      'is_optional': instance.isOptional,
      'applicable_for': instance.applicableFor,
      'status': instance.status,
    };

_EventDto _$EventDtoFromJson(Map<String, dynamic> json) => _EventDto(
  id: json['id'] as String?,
  eventId: json['event_id'] as String?,
  schoolId: json['school_id'] as String?,
  eventName: json['event_name'] as String?,
  eventType: json['event_type'] as String?,
  description: json['description'] as String?,
  startDate: json['start_date'],
  endDate: json['end_date'],
  startTime: json['start_time'] as String?,
  endTime: json['end_time'] as String?,
  venue: json['venue'] as String?,
  organizerId: json['organizer_id'] as String?,
  audienceType: json['audience_type'] as String?,
  attachmentUrl: json['attachment_url'] as String?,
  status: json['status'] as String?,
  isHoliday: json['is_holiday'] as bool?,
  academicYearId: json['academic_year_id'] as String?,
);

Map<String, dynamic> _$EventDtoToJson(_EventDto instance) => <String, dynamic>{
  'id': instance.id,
  'event_id': instance.eventId,
  'school_id': instance.schoolId,
  'event_name': instance.eventName,
  'event_type': instance.eventType,
  'description': instance.description,
  'start_date': instance.startDate,
  'end_date': instance.endDate,
  'start_time': instance.startTime,
  'end_time': instance.endTime,
  'venue': instance.venue,
  'organizer_id': instance.organizerId,
  'audience_type': instance.audienceType,
  'attachment_url': instance.attachmentUrl,
  'status': instance.status,
  'is_holiday': instance.isHoliday,
  'academic_year_id': instance.academicYearId,
};

_ApprovalRequestDto _$ApprovalRequestDtoFromJson(Map<String, dynamic> json) =>
    _ApprovalRequestDto(
      id: json['id'] as String?,
      approvalId: json['approval_id'] as String?,
      schoolId: json['school_id'] as String?,
      requestType: json['request_type'] as String?,
      moduleName: json['module_name'] as String?,
      referenceTable: json['reference_table'] as String?,
      referenceId: json['reference_id'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      priority: json['priority'] as String?,
      approvalStatus: json['approval_status'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'],
    );

Map<String, dynamic> _$ApprovalRequestDtoToJson(_ApprovalRequestDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'approval_id': instance.approvalId,
      'school_id': instance.schoolId,
      'request_type': instance.requestType,
      'module_name': instance.moduleName,
      'reference_table': instance.referenceTable,
      'reference_id': instance.referenceId,
      'title': instance.title,
      'description': instance.description,
      'priority': instance.priority,
      'approval_status': instance.approvalStatus,
      'approved_by': instance.approvedBy,
      'approved_at': instance.approvedAt,
    };

_CommunicationDto _$CommunicationDtoFromJson(Map<String, dynamic> json) =>
    _CommunicationDto(
      id: json['id'] as String?,
      messageId: json['message_id'] as String?,
      schoolId: json['school_id'] as String?,
      senderId: json['sender_id'] as String?,
      senderRole: json['sender_role'] as String?,
      receiverId: json['receiver_id'] as String?,
      receiverRole: json['receiver_role'] as String?,
      studentId: json['student_id'] as String?,
      messageType: json['message_type'] as String?,
      messageContent: json['message_content'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      isRead: json['is_read'] as bool?,
      sentAt: json['sent_at'],
    );

Map<String, dynamic> _$CommunicationDtoToJson(_CommunicationDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'message_id': instance.messageId,
      'school_id': instance.schoolId,
      'sender_id': instance.senderId,
      'sender_role': instance.senderRole,
      'receiver_id': instance.receiverId,
      'receiver_role': instance.receiverRole,
      'student_id': instance.studentId,
      'message_type': instance.messageType,
      'message_content': instance.messageContent,
      'attachment_url': instance.attachmentUrl,
      'is_read': instance.isRead,
      'sent_at': instance.sentAt,
    };

_PrincipalReportDto _$PrincipalReportDtoFromJson(Map<String, dynamic> json) =>
    _PrincipalReportDto(
      id: json['id'] as String?,
      reportId: json['report_id'] as String?,
      schoolId: json['school_id'] as String?,
      reportName: json['report_name'] as String?,
      reportType: json['report_type'] as String?,
      moduleName: json['module_name'] as String?,
      generatedBy: json['generated_by'] as String?,
      generatedRole: json['generated_role'] as String?,
      reportStatus: json['report_status'] as String?,
      reportFileUrl: json['report_file_url'] as String?,
      totalRecords: (json['total_records'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PrincipalReportDtoToJson(_PrincipalReportDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'report_id': instance.reportId,
      'school_id': instance.schoolId,
      'report_name': instance.reportName,
      'report_type': instance.reportType,
      'module_name': instance.moduleName,
      'generated_by': instance.generatedBy,
      'generated_role': instance.generatedRole,
      'report_status': instance.reportStatus,
      'report_file_url': instance.reportFileUrl,
      'total_records': instance.totalRecords,
    };

_DashboardDto _$DashboardDtoFromJson(Map<String, dynamic> json) =>
    _DashboardDto(
      role: json['role'] as String?,
      metrics:
          json['metrics'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      fees: json['fees'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      todayAttendance:
          json['today_attendance'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
      children: json['children'] as List<dynamic>? ?? const <dynamic>[],
      assignedClasses:
          json['assigned_classes'] as List<dynamic>? ?? const <dynamic>[],
      staffId: json['staff_id'] as String?,
    );

Map<String, dynamic> _$DashboardDtoToJson(_DashboardDto instance) =>
    <String, dynamic>{
      'role': instance.role,
      'metrics': instance.metrics,
      'fees': instance.fees,
      'today_attendance': instance.todayAttendance,
      'children': instance.children,
      'assigned_classes': instance.assignedClasses,
      'staff_id': instance.staffId,
    };

_StudentDto _$StudentDtoFromJson(Map<String, dynamic> json) => _StudentDto(
  id: json['id'] as String?,
  schoolId: json['school_id'] as String?,
  studentCode: json['student_code'] as String?,
  admissionNumber: json['admission_number'] as String?,
  firstName: json['first_name'] as String?,
  lastName: json['last_name'] as String?,
  currentSectionId: json['current_section_id'] as String?,
  status: json['status'] as String?,
);

Map<String, dynamic> _$StudentDtoToJson(_StudentDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'school_id': instance.schoolId,
      'student_code': instance.studentCode,
      'admission_number': instance.admissionNumber,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'current_section_id': instance.currentSectionId,
      'status': instance.status,
    };

_StaffDto _$StaffDtoFromJson(Map<String, dynamic> json) => _StaffDto(
  id: json['id'] as String?,
  schoolId: json['school_id'] as String?,
  staffCode: json['staff_code'] as String?,
  firstName: json['first_name'] as String?,
  lastName: json['last_name'] as String?,
  email: json['email'] as String?,
  phone: json['phone'] as String?,
  designation: json['designation'] as String?,
  status: json['status'] as String?,
);

Map<String, dynamic> _$StaffDtoToJson(_StaffDto instance) => <String, dynamic>{
  'id': instance.id,
  'school_id': instance.schoolId,
  'staff_code': instance.staffCode,
  'first_name': instance.firstName,
  'last_name': instance.lastName,
  'email': instance.email,
  'phone': instance.phone,
  'designation': instance.designation,
  'status': instance.status,
};

_AttendanceSessionDto _$AttendanceSessionDtoFromJson(
  Map<String, dynamic> json,
) => _AttendanceSessionDto(
  id: json['id'] as String?,
  sectionId: json['section_id'] as String?,
  subjectId: json['subject_id'] as String?,
  staffId: json['staff_id'] as String?,
  date: json['date'],
  periodNumber: (json['period_number'] as num?)?.toInt(),
  totalStudents: (json['total_students'] as num?)?.toInt(),
  presentCount: (json['present_count'] as num?)?.toInt(),
  isFinalized: json['is_finalized'] as bool?,
);

Map<String, dynamic> _$AttendanceSessionDtoToJson(
  _AttendanceSessionDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'section_id': instance.sectionId,
  'subject_id': instance.subjectId,
  'staff_id': instance.staffId,
  'date': instance.date,
  'period_number': instance.periodNumber,
  'total_students': instance.totalStudents,
  'present_count': instance.presentCount,
  'is_finalized': instance.isFinalized,
};

_FeeInvoiceDto _$FeeInvoiceDtoFromJson(Map<String, dynamic> json) =>
    _FeeInvoiceDto(
      id: json['id'] as String?,
      studentId: json['student_id'] as String?,
      academicYearId: json['academic_year_id'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      dueDate: json['due_date'],
      totalAmount: json['total_amount'] as num?,
      paidAmount: json['paid_amount'] as num?,
      balance: json['balance'] as num?,
      status: json['status'] as String?,
    );

Map<String, dynamic> _$FeeInvoiceDtoToJson(_FeeInvoiceDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'student_id': instance.studentId,
      'academic_year_id': instance.academicYearId,
      'invoice_number': instance.invoiceNumber,
      'due_date': instance.dueDate,
      'total_amount': instance.totalAmount,
      'paid_amount': instance.paidAmount,
      'balance': instance.balance,
      'status': instance.status,
    };

_PaymentDto _$PaymentDtoFromJson(Map<String, dynamic> json) => _PaymentDto(
  id: json['id'] as String?,
  invoiceId: json['invoice_id'] as String?,
  studentId: json['student_id'] as String?,
  amount: json['amount'] as num?,
  paymentMode: json['payment_mode'] as String?,
  transactionId: json['transaction_id'] as String?,
  paidAt: json['paid_at'],
);

Map<String, dynamic> _$PaymentDtoToJson(_PaymentDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'invoice_id': instance.invoiceId,
      'student_id': instance.studentId,
      'amount': instance.amount,
      'payment_mode': instance.paymentMode,
      'transaction_id': instance.transactionId,
      'paid_at': instance.paidAt,
    };

_ParentPaymentRequestDto _$ParentPaymentRequestDtoFromJson(
  Map<String, dynamic> json,
) => _ParentPaymentRequestDto(
  id: json['id'] as String?,
  invoiceId: json['invoice_id'] as String?,
  studentId: json['student_id'] as String?,
  parentUserId: json['parent_user_id'] as String?,
  amount: json['amount'] as num?,
  status: json['status'] as String?,
  remarks: json['remarks'] as String?,
);

Map<String, dynamic> _$ParentPaymentRequestDtoToJson(
  _ParentPaymentRequestDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'invoice_id': instance.invoiceId,
  'student_id': instance.studentId,
  'parent_user_id': instance.parentUserId,
  'amount': instance.amount,
  'status': instance.status,
  'remarks': instance.remarks,
};

_MessageConversationDto _$MessageConversationDtoFromJson(
  Map<String, dynamic> json,
) => _MessageConversationDto(
  id: json['id'] as String?,
  schoolId: json['school_id'] as String?,
  teacherId: json['teacher_id'] as String?,
  parentId: json['parent_id'] as String?,
  studentId: json['student_id'] as String?,
  title: json['title'] as String?,
  lastMessage: json['last_message'] as String?,
  lastMessageTime: json['last_message_time'],
);

Map<String, dynamic> _$MessageConversationDtoToJson(
  _MessageConversationDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'school_id': instance.schoolId,
  'teacher_id': instance.teacherId,
  'parent_id': instance.parentId,
  'student_id': instance.studentId,
  'title': instance.title,
  'last_message': instance.lastMessage,
  'last_message_time': instance.lastMessageTime,
};

_MessageDto _$MessageDtoFromJson(Map<String, dynamic> json) => _MessageDto(
  id: json['id'] as String?,
  conversationId: json['conversation_id'] as String?,
  senderId: json['sender_id'] as String?,
  senderRole: json['sender_role'] as String?,
  senderName: json['sender_name'] as String?,
  body: json['body'] as String?,
  isRead: json['is_read'] as bool?,
  sentAt: json['sent_at'],
);

Map<String, dynamic> _$MessageDtoToJson(_MessageDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'conversation_id': instance.conversationId,
      'sender_id': instance.senderId,
      'sender_role': instance.senderRole,
      'sender_name': instance.senderName,
      'body': instance.body,
      'is_read': instance.isRead,
      'sent_at': instance.sentAt,
    };
