/// Server-authoritative school calendar and permitted attendance dates.
class TeacherAttendanceContext {
  const TeacherAttendanceContext({
    required this.sectionId,
    required this.schoolDate,
    required this.configurationStatus,
    this.academicYearId,
    this.academicYearStart,
    this.academicYearEnd,
    this.minDate,
    this.maxDate,
    this.message,
  });

  final String sectionId;
  final String? academicYearId;
  final DateTime schoolDate;
  final DateTime? academicYearStart;
  final DateTime? academicYearEnd;
  final DateTime? minDate;
  final DateTime? maxDate;
  final String configurationStatus;
  final String? message;

  factory TeacherAttendanceContext.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) {
      final value = json[key]?.toString();
      if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        return null;
      }
      final parsed = DateTime.tryParse(value);
      if (parsed == null ||
          parsed.toIso8601String().split('T').first != value) {
        return null;
      }
      return parsed;
    }

    final today = date('school_date');
    if (today == null) {
      throw const FormatException(
        'School date is unavailable. Refresh to retry.',
      );
    }
    return TeacherAttendanceContext(
      sectionId: json['section_id']?.toString() ?? '',
      academicYearId: json['academic_year_id']?.toString(),
      schoolDate: today,
      academicYearStart: date('academic_year_start'),
      academicYearEnd: date('academic_year_end'),
      minDate: date('min_date'),
      maxDate: date('max_date'),
      configurationStatus:
          json['configuration_status']?.toString() ?? 'invalid_year',
      message: json['message']?.toString(),
    );
  }

  bool get hasSelectableDates =>
      (configurationStatus == 'ready' || configurationStatus == 'ended') &&
      academicYearId?.isNotEmpty == true &&
      minDate != null &&
      maxDate != null &&
      !maxDate!.isBefore(minDate!);

  bool contains(DateTime date) =>
      hasSelectableDates && !date.isBefore(minDate!) && !date.isAfter(maxDate!);

  DateTime get initialDate => !hasSelectableDates
      ? schoolDate
      : schoolDate.isAfter(maxDate!)
      ? maxDate!
      : schoolDate.isBefore(minDate!)
      ? minDate!
      : schoolDate;

  String get guidance =>
      message ??
      switch (configurationStatus) {
        'not_started' =>
          'The academic year has not started. Attendance dates will be available when it starts.',
        'ended' =>
          'The academic year has ended. Choose a date within the academic year.',
        _ =>
          'Ask school leadership to configure the current academic year, then refresh.',
      };
}
