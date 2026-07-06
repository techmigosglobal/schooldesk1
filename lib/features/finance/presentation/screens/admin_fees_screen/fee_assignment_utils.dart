Map<String, dynamic> buildFeeAssignmentPayload({
  required String academicYearId,
  required String gradeId,
  String sectionId = '',
  required String dueDate,
  String invoiceLabel = '',
  String termId = '',
  bool includeOneTime = false,
  bool includeYearly = false,
  int installmentCount = 0,
}) {
  return {
    'academic_year_id': academicYearId.trim(),
    'grade_id': gradeId.trim(),
    if (sectionId.trim().isNotEmpty) 'section_id': sectionId.trim(),
    'due_date': dueDate.trim(),
    if (invoiceLabel.trim().isNotEmpty) 'invoice_label': invoiceLabel.trim(),
    if (termId.trim().isNotEmpty) 'term_id': termId.trim(),
    'include_one_time': includeOneTime,
    'include_yearly': includeYearly,
    if (installmentCount > 0) 'installment_count': installmentCount,
  };
}

String defaultAssignmentDueDate({DateTime? referenceDate}) {
  final baseDate = referenceDate ?? DateTime.now();
  final dueDate = baseDate.add(const Duration(days: 30));
  return '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
}
