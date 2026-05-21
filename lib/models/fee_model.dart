class FeeModel {
  const FeeModel({
    required this.id,
    required this.studentId,
    required this.amount,
    required this.status,
    this.feeType,
    this.dueDate,
    this.paidDate,
  });

  final String id;
  final String studentId;
  final double amount;
  final String status;
  final String? feeType;
  final String? dueDate;
  final String? paidDate;

  factory FeeModel.fromJson(Map<String, dynamic> json) {
    return FeeModel(
      id: (json['id'] ?? '').toString(),
      studentId: (json['student_id'] ?? '').toString(),
      amount: ((json['amount'] ?? json['net_amount'] ?? 0) as num).toDouble(),
      status: (json['status'] ?? '').toString(),
      feeType: (json['fee_type'] ?? json['invoice_number'])?.toString(),
      dueDate: json['due_date']?.toString(),
      paidDate: json['paid_date']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': studentId,
    'amount': amount,
    'status': status,
    if (feeType != null) 'fee_type': feeType,
    if (dueDate != null) 'due_date': dueDate,
    if (paidDate != null) 'paid_date': paidDate,
  };
}
