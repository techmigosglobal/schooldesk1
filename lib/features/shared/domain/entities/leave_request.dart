/// Leave request entity.
class LeaveRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String requesterRole; // 'teacher', 'parent'
  final String leaveType; // 'Sick', 'Casual', 'Emergency', 'Other'
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String status; // 'Pending', 'Approved', 'Rejected'
  final String? approvedBy;
  final String? rejectionRemark;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  // For teacher leaves
  final String? substituteTeacher;
  // For parent leaves (student leave)
  final String? studentId;
  final String? studentName;

  const LeaveRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.requesterRole,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.status = 'Pending',
    this.approvedBy,
    this.rejectionRemark,
    required this.submittedAt,
    this.reviewedAt,
    this.substituteTeacher,
    this.studentId,
    this.studentName,
  });

  int get durationDays => toDate.difference(fromDate).inDays + 1;

  LeaveRequest copyWith({
    String? id,
    String? requesterId,
    String? requesterName,
    String? requesterRole,
    String? leaveType,
    DateTime? fromDate,
    DateTime? toDate,
    String? reason,
    String? status,
    String? approvedBy,
    String? rejectionRemark,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? substituteTeacher,
    String? studentId,
    String? studentName,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      requesterRole: requesterRole ?? this.requesterRole,
      leaveType: leaveType ?? this.leaveType,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionRemark: rejectionRemark ?? this.rejectionRemark,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      substituteTeacher: substituteTeacher ?? this.substituteTeacher,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
    );
  }

  @override
  bool operator ==(Object other) => other is LeaveRequest && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
