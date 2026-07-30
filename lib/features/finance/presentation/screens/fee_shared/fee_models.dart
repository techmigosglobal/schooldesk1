/// Shared data models and helpers for the principal fee module.
///
/// Extracted from the former monolithic FeeMonitoringScreen to allow
/// focused, single-responsibility screens to share the same data layer.
library;

// ── Data Models ──────────────────────────────────────────────────────────────

class FeeStructureBundle {
  final String id;
  final String gradeId;
  final String sectionId;
  final String academicYearId;
  final String title;
  final String classLabel;
  final String sectionLabel;
  final String academicYearLabel;
  final List<FeeComponent> components;
  final bool isActive;

  FeeStructureBundle({
    required this.id,
    required this.gradeId,
    required this.sectionId,
    required this.academicYearId,
    required this.title,
    required this.classLabel,
    required this.sectionLabel,
    required this.academicYearLabel,
    required this.components,
    this.isActive = true,
  });

  String get statusLabel => isActive ? 'Active' : 'Draft';
  double get total => components.fold(0, (sum, c) => sum + c.amount);
  double get oneTimeTotal => components
      .where((c) => c.frequency.toLowerCase().contains('one'))
      .fold(0, (sum, c) => sum + c.amount);
  double get yearlyTotal => total - oneTimeTotal;
}

class FeeComponent {
  final String name;
  final String frequency;
  final double amount;
  final String status;
  final String source;

  FeeComponent({
    required this.name,
    required this.frequency,
    required this.amount,
    this.status = '',
    this.source = '',
  });

  factory FeeComponent.fromRow(Map<String, dynamic> row) {
    return FeeComponent(
      name: _textValue(
        row['fee_item_name'] ?? row['category_name'] ?? row['name'],
      ),
      frequency: _textValue(
        row['frequency'] ?? row['billing_mode'],
        fallback: 'monthly',
      ),
      amount: _numValue(row['amount']),
      status: _textValue(row['status']),
      source: _textValue(row['source']),
    );
  }
}

class FeeStudentAccount {
  final String studentId;
  final String name;
  final String rollNumber;
  final String classLabel;
  final String academicYearLabel;
  final String structureTitle;
  final String gradeId;
  final String sectionId;
  final String academicYearId;
  final String photoUrl;
  final double total;
  final double paid;
  final double balance;
  final List<Map<String, dynamic>> invoices;
  final List<Map<String, dynamic>> payments;

  FeeStudentAccount({
    required this.studentId,
    required this.name,
    required this.rollNumber,
    required this.classLabel,
    required this.academicYearLabel,
    required this.structureTitle,
    required this.gradeId,
    required this.sectionId,
    required this.academicYearId,
    this.photoUrl = '',
    required this.total,
    required this.paid,
    required this.balance,
    required this.invoices,
    required this.payments,
  });

  String get status {
    if (balance <= 0) return 'Paid';
    if (paid > 0) return 'Partial';
    return 'Unpaid';
  }
}

class FeePaymentResult {
  final String studentName;
  final String classLabel;
  final String rollNumber;
  final double amount;
  final String paymentMode;
  final String transactionId;
  final String receiptNumber;
  final DateTime paymentDate;
  final double balanceAfterPayment;

  FeePaymentResult({
    required this.studentName,
    required this.classLabel,
    required this.rollNumber,
    required this.amount,
    required this.paymentMode,
    required this.transactionId,
    required this.receiptNumber,
    required this.paymentDate,
    required this.balanceAfterPayment,
  });
}

class FeeReportDefinition {
  final String title;
  final String subtitle;
  final String reportType;
  final String icon;
  final String color;

  const FeeReportDefinition({
    required this.title,
    required this.subtitle,
    required this.reportType,
    this.icon = '',
    this.color = '',
  });
}

// ── Normalization Helpers ────────────────────────────────────────────────────

Map<String, dynamic> normalizeFeeStructure(Map<String, dynamic> row) {
  final category = _mapValue(row['fee_category'] ?? row['category']);
  final grade = _mapValue(row['grade']);
  final section = _mapValue(row['section']);
  final gradeName = _textValue(
    grade['grade_name'],
    fallback: _textValue(row['grade_id']),
  );
  final sectionName = _textValue(
    section['section_name'],
    fallback: _textValue(row['section_id']).isEmpty
        ? 'All sections'
        : _textValue(row['section_id']),
  );
  final categoryName = _textValue(
    category['category_name'] ?? category['name'],
    fallback: 'Fee',
  );

  return {
    ...row,
    'id': _textValue(row['id']),
    'grade_id': _textValue(row['grade_id']),
    'section_id': _textValue(row['section_id']),
    'academic_year_id': _textValue(row['academic_year_id']),
    'category_id': _textValue(row['fee_category_id'] ?? row['category_id']),
    'class': gradeName,
    'section': sectionName,
    'category': categoryName,
    'amount': _numValue(row['amount']),
    'frequency': _textValue(row['frequency'], fallback: 'term'),
    'fee_type': _textValue(row['fee_type']),
    'fee_item_name': _textValue(row['fee_item_name']),
    'billing_mode': _textValue(row['billing_mode']),
    'due_day': row['due_day'] ?? 10,
    'due_date': row['due_date'],
    'late_fine_per_day': _numValue(row['late_fine_per_day']),
    'is_mandatory': row['is_mandatory'] ?? true,
  };
}

Map<String, dynamic> normalizeInvoice(Map<String, dynamic> row) {
  final student = _mapValue(row['student']);
  final section = _mapValue(student['current_section'] ?? row['section']);
  final grade = _mapValue(section['grade']);
  final classLabel = [
    _textValue(grade['grade_name'] ?? row['grade_name']),
    _textValue(section['section_name'] ?? row['section_name']),
  ].where((p) => p.isNotEmpty).join(' - ');

  return {
    ...row,
    'id': _textValue(row['id']),
    'student_id': _textValue(row['student_id']),
    'name': _studentName(student, fallback: _textValue(row['student_name'])),
    'class': classLabel.isEmpty
        ? _textValue(row['class'], fallback: 'Class pending')
        : classLabel,
    'grade_id': _textValue(grade['id'] ?? row['grade_id']),
    'section_id': _textValue(
      section['id'] ?? student['current_section_id'] ?? row['section_id'],
    ),
    'total': _numValue(row['net_amount'] ?? row['total_amount']),
    'discount': _numValue(row['discount_amount']),
    'paid': _numValue(row['paid_amount']),
    'balance': _numValue(row['balance']),
    'due_date': row['due_date'],
    'status': _textValue(row['status'], fallback: 'pending'),
    'invoice_number': _textValue(row['invoice_number']),
    'fee_item_name': _textValue(
      row['fee_item_name'] ??
          (_listValue(row['fee_invoice_items']).isNotEmpty
              ? _mapValue(
                  _listValue(row['fee_invoice_items']).first,
                )['category_name']
              : null),
      fallback: 'Fee',
    ),
    'fee_type': _textValue(row['fee_type']),
  };
}

List<Map<String, dynamic>> normalizePayments(Map<String, dynamic> invoice) {
  final normalized = normalizeInvoice(invoice);
  final payments = invoice['payments'];
  if (payments is! List) return const [];
  return payments.whereType<Map>().map((payment) {
    final row = Map<String, dynamic>.from(payment);
    final receipt = _mapValue(row['receipt']);
    final receiptSnapshot = _mapValue(row['receipt_snapshot']);
    return {
      ...row,
      'name': normalized['name'],
      'class': normalized['class'],
      'student_id': normalized['student_id'],
      'invoice_id': normalized['id'],
      'amount': _numValue(row['amount_paid'] ?? row['amount']),
      'mode': _textValue(
        row['payment_method'] ?? row['payment_mode'] ?? row['mode'],
      ),
      'date': row['payment_date'] ?? row['paid_at'] ?? row['created_at'],
      'receipt': _textValue(
        receipt['receipt_number'] ?? row['receipt_number'] ?? row['receipt'],
      ),
      'receipt_snapshot': receiptSnapshot,
      'status': _textValue(row['status'], fallback: 'completed'),
      'transaction_id': _textValue(row['transaction_id'], fallback: 'N/A'),
    };
  }).toList();
}

// ── Common type-safe helpers ─────────────────────────────────────────────────

Map<String, dynamic> _mapValue(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<dynamic> _listValue(Object? value) => value is List ? value : const [];

double _numValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

String _textValue(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? fallback : text;
}

String _studentName(Map<String, dynamic> student, {String fallback = ''}) {
  final direct = _textValue(student['name']);
  if (direct.isNotEmpty) return direct;
  final fullName =
      '${_textValue(student['first_name'])} ${_textValue(student['last_name'])}'
          .trim();
  return fullName.isEmpty ? fallback : fullName;
}

/// Re-export the safe text helpers for screens that import this file.
String textValue(Object? value, {String fallback = ''}) =>
    _textValue(value, fallback: fallback);

double numValue(Object? value) => _numValue(value);

String money(double amount) => '₹${amount.toStringAsFixed(0)}';

String displayDate(Object? value) {
  final date = DateTime.tryParse('${value ?? ''}');
  return date == null ? '-' : date.toIso8601String().split('T').first;
}

String studentFullName(Map<String, dynamic> student) =>
    _studentName(student, fallback: 'Student');

/// A stable student-facing identifier for documents. Invoice numbers are
/// transaction identifiers, never student roll/admission numbers.
String studentIdentifier(
  Map<String, dynamic> student, {
  String fallback = '—',
}) {
  return _textValue(
    student['student_id_number'] ?? student['admission_number'],
    fallback: fallback,
  );
}
