/// Fee record entity.
class FeeRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String className;
  final String feeType;
  final double amount;
  final double paidAmount;
  final DateTime dueDate;
  final DateTime? paidDate;
  final String status; // 'Paid', 'Pending', 'Overdue', 'Partial'
  final String? receiptNumber;
  final String? paymentMode; // 'Cash', 'Online', 'Cheque', 'DD'
  final String? remarks;

  const FeeRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.feeType,
    required this.amount,
    this.paidAmount = 0,
    required this.dueDate,
    this.paidDate,
    required this.status,
    this.receiptNumber,
    this.paymentMode,
    this.remarks,
  });

  double get pendingAmount => amount - paidAmount;
  bool get isOverdue =>
      status == 'Overdue' ||
      (status == 'Pending' && dueDate.isBefore(DateTime.now()));

  FeeRecord copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? className,
    String? feeType,
    double? amount,
    double? paidAmount,
    DateTime? dueDate,
    DateTime? paidDate,
    String? status,
    String? receiptNumber,
    String? paymentMode,
    String? remarks,
  }) {
    return FeeRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      className: className ?? this.className,
      feeType: feeType ?? this.feeType,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      status: status ?? this.status,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      paymentMode: paymentMode ?? this.paymentMode,
      remarks: remarks ?? this.remarks,
    );
  }

  @override
  bool operator ==(Object other) => other is FeeRecord && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
