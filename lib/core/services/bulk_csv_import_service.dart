import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/routes/app_routes.dart';

enum BulkCsvImportTarget { students, staff, parents, classes, classTimetables }

class BulkCsvImportService {
  const BulkCsvImportService._();

  static Future<bool> importCsv(
    BuildContext context,
    BulkCsvImportTarget target,
  ) async {
    final proceed = await _showFormatDialog(context, target);
    if (proceed != true || !context.mounted) return false;

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return false;

    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (context.mounted) {
        _snack(
          context,
          'Unable to read the selected CSV file.',
          AppTheme.error,
        );
      }
      return false;
    }

    if (target == BulkCsvImportTarget.classes) {
      return _importClassHubCsvWithPreview(context, bytes);
    }

    final progress = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text('Importing ${_schema(target).label}...')),
          ],
        ),
      ),
    );

    final result = await _importBytes(target, bytes);
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    await progress;
    if (!context.mounted) {
      return result.created > 0 || result.timetableSlotsCreated > 0;
    }

    await _showResultDialog(context, target, result);
    return result.created > 0 || result.timetableSlotsCreated > 0;
  }

  static Future<void> copyTemplate(
    BuildContext context,
    BulkCsvImportTarget target,
  ) async {
    final schema = _schema(target);
    await Clipboard.setData(ClipboardData(text: schema.template));
    if (context.mounted) {
      _snack(context, '${schema.label} CSV template copied.', AppTheme.success);
    }
  }

  static Future<bool> _importClassHubCsvWithPreview(
    BuildContext context,
    Uint8List bytes,
  ) async {
    final csvText = utf8.decode(bytes, allowMalformed: true);
    final api = BackendApiClient.instance;
    final dryRunProgress = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Validating Class Hub CSV...')),
          ],
        ),
      ),
    );

    Map<String, dynamic> dryRun;
    try {
      dryRun = await api.dryRunPrincipalClassCsvImport(csvText: csvText);
    } catch (error) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      await dryRunProgress;
      if (context.mounted) {
        await _showResultDialog(
          context,
          BulkCsvImportTarget.classes,
          _BulkImportResult(failures: ['Class Hub CSV dry-run failed: $error']),
        );
      }
      return false;
    }
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    await dryRunProgress;
    if (!context.mounted) return false;

    final proceed = await _showClassHubDryRunDialog(context, dryRun);
    if (proceed != true || !context.mounted) return false;

    final importProgress = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Importing Class Hub setup...')),
          ],
        ),
      ),
    );

    Map<String, dynamic> imported;
    try {
      imported = await api.importPrincipalClassCsv(csvText: csvText);
    } catch (error) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      await importProgress;
      if (context.mounted) {
        await _showResultDialog(
          context,
          BulkCsvImportTarget.classes,
          _BulkImportResult(failures: ['Class Hub CSV import failed: $error']),
        );
      }
      return false;
    }
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    await importProgress;
    if (!context.mounted) {
      return _intValue(_map(imported['summary'])['valid_rows']) > 0;
    }

    final result = _classHubImportResultFrom(imported);
    await _showResultDialog(context, BulkCsvImportTarget.classes, result);
    return result.created > 0;
  }

  static Future<bool?> _showClassHubDryRunDialog(
    BuildContext context,
    Map<String, dynamic> dryRun,
  ) {
    final canImport = dryRun['can_import'] == true;
    final summary = _map(dryRun['summary']);
    final rows = _listMap(dryRun['rows']);
    final errors = _issueLines(dryRun['errors']);
    final warnings = _issueLines(dryRun['warnings']);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Review Class Hub CSV'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_intValue(summary['valid_rows'])} valid row${_intValue(summary['valid_rows']) == 1 ? '' : 's'}, '
                  '${_intValue(summary['invalid_rows'])} invalid, '
                  '${_intValue(summary['classes_to_create'])} create, '
                  '${_intValue(summary['classes_to_update'])} update.',
                ),
                const SizedBox(height: 12),
                for (final row in rows.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Row ${_intValue(row['row_number'])} - '
                      '${_text(row['mode']).toUpperCase()} - '
                      '${_text(row['grade_name'])} ${_text(row['section_name'])} - '
                      '${_intValue(row['subject_count'])} subject${_intValue(row['subject_count']) == 1 ? '' : 's'}, '
                      '${_intValue(row['fee_item_count'])} fee${_intValue(row['fee_item_count']) == 1 ? '' : 's'}',
                    ),
                  ),
                if (rows.length > 8) Text('+${rows.length - 8} more rows'),
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Warnings:'),
                  const SizedBox(height: 8),
                  for (final warning in warnings.take(8))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(warning),
                    ),
                ],
                if (errors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Errors:'),
                  const SizedBox(height: 8),
                  for (final error in errors.take(10))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(error),
                    ),
                  if (errors.length > 10) Text('+${errors.length - 10} more'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(canImport ? 'Cancel' : 'Done'),
          ),
          if (canImport)
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.fact_check_rounded, size: 18),
              label: const Text('Import validated rows'),
            ),
        ],
      ),
    );
  }

  static Future<_BulkImportResult> _importBytes(
    BulkCsvImportTarget target,
    Uint8List bytes,
  ) async {
    final text = utf8.decode(bytes, allowMalformed: true);
    final parsed = _parseCsv(text);
    if (parsed.length < 2) {
      return _BulkImportResult(
        failures: const ['CSV must include headers and at least one data row.'],
      );
    }

    final schema = _schema(target);
    final headers = parsed.first.map(_normalizeHeader).toList();
    final missing = schema.required.where((key) {
      final accepted = schema.aliases[key] ?? [key];
      return !accepted.map(_normalizeHeader).any(headers.contains);
    }).toList();
    if (missing.isNotEmpty) {
      return _BulkImportResult(
        failures: [
          'Missing required header${missing.length == 1 ? '' : 's'}: ${missing.join(', ')}',
        ],
      );
    }

    final api = BackendApiClient.instance;
    final helpers = await _ImportLookup.load(api);
    final failures = <String>[];
    final warnings = <String>[];
    final suggestions = <String>[];
    var created = 0;
    var timetableSlotsCreated = 0;

    for (var index = 1; index < parsed.length; index++) {
      final rowNumber = index + 1;
      final values = parsed[index];
      if (values.every((cell) => cell.trim().isEmpty)) continue;
      final row = _CsvRow(headers, values, schema.aliases);
      try {
        switch (target) {
          case BulkCsvImportTarget.students:
            await _importStudent(api, helpers, row);
          case BulkCsvImportTarget.staff:
            await _importStaff(api, row);
          case BulkCsvImportTarget.parents:
            await _importParent(api, helpers, row);
          case BulkCsvImportTarget.classes:
            await _importClass(api, helpers, row);
          case BulkCsvImportTarget.classTimetables:
            final outcome = await _importClassTimetable(api, helpers, row);
            timetableSlotsCreated += outcome.slotsCreated;
            warnings.addAll(
              outcome.warnings.map((warning) => 'Row $rowNumber: $warning'),
            );
            suggestions.addAll(outcome.suggestions);
        }
        created++;
      } catch (error) {
        failures.add('Row $rowNumber: $error');
      }
    }

    if (target == BulkCsvImportTarget.classes && created > 0) {
      warnings.add(
        'Class, subject, and fee data was imported. Timetable slots are not generated from the Principal class import because timetable writes are Admin-owned.',
      );
      suggestions.add(
        'Ask an Admin to open Timetable Builder and upload this same all-features class CSV with Generate from class CSV.',
      );
    }

    final actions = <_BulkImportAction>[
      if (target == BulkCsvImportTarget.classTimetables && created > 0)
        const _BulkImportAction(
          label: 'Open timetable grid',
          route: AppRoutes.adminTimetable,
          icon: Icons.calendar_view_week_rounded,
        )
      else if (target == BulkCsvImportTarget.classes && created > 0)
        const _BulkImportAction(
          label: 'Review timetables',
          route: AppRoutes.principalTimetable,
          icon: Icons.fact_check_outlined,
        ),
    ];

    return _BulkImportResult(
      created: created,
      timetableSlotsCreated: timetableSlotsCreated,
      failures: failures,
      warnings: _unique(warnings),
      suggestions: _unique(suggestions),
      actions: actions,
    );
  }

  static Future<void> _importStudent(
    BackendApiClient api,
    _ImportLookup lookup,
    _CsvRow row,
  ) async {
    final firstName = row.required('first_name');
    final lastName = row.value('last_name');
    final sectionId = row.value('current_section_id').isNotEmpty
        ? row.value('current_section_id')
        : lookup.sectionIdFor(
            gradeName: row.value('class'),
            sectionName: row.value('section'),
          );
    final student = await api.createStudent(
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: _date(row.value('date_of_birth'), '2010-01-01'),
      gender: row.value('gender', fallback: 'unspecified'),
      admissionNumber: row.value('admission_number'),
      studentCode: row.value('student_code'),
      currentSectionId: sectionId,
      admissionDate: _date(row.value('admission_date'), '2026-01-01'),
      status: row.value('status', fallback: 'active'),
    );
    final parentId = row.value('parent_user_id').isNotEmpty
        ? row.value('parent_user_id')
        : lookup.parentIdFor(
            email: row.value('parent_email'),
            username: row.value('parent_username'),
          );
    if (parentId.isNotEmpty) {
      await api.setStudentParent(studentId: student.id, parentUserId: parentId);
    }
  }

  static Future<void> _importStaff(BackendApiClient api, _CsvRow row) async {
    await api.createStaff(
      firstName: row.required('first_name'),
      lastName: row.value('last_name'),
      staffCode: row.value('staff_code'),
      username: row.value('username'),
      email: row.value('email'),
      phone: row.value('phone'),
      designation: row.value('designation', fallback: 'Teacher'),
      password: row.value('password'),
      accountRole: row.value('account_role', fallback: 'Teacher'),
      gender: row.value('gender', fallback: 'unspecified'),
      employmentType: row.value('employment_type', fallback: 'full_time'),
      joinDate: _date(row.value('join_date'), '2026-01-01'),
      dateOfBirth: _date(row.value('date_of_birth'), '1990-01-01'),
      basicSalary: double.tryParse(row.value('basic_salary')) ?? 0,
    );
  }

  static Future<void> _importParent(
    BackendApiClient api,
    _ImportLookup lookup,
    _CsvRow row,
  ) async {
    final parent = await api.createUser(
      username: row.required('username'),
      password: row.required('password'),
      role: 'Parent',
      fullName: row.required('full_name'),
      email: row.value('email'),
      phone: row.value('phone'),
      isActive: _bool(row.value('is_active'), fallback: true),
    );
    final admissions = _splitList(row.value('admission_numbers'));
    final studentIds = [
      ..._splitList(row.value('student_ids')),
      for (final admission in admissions) lookup.studentIdFor(admission),
    ].where((id) => id.isNotEmpty).toSet().toList();
    if (admissions.isNotEmpty || studentIds.isNotEmpty) {
      await api.assignParentStudents(
        parentUserId: parent.id,
        admissionNumbers: admissions,
        studentIds: studentIds,
      );
    }
    final relationship = row.value('relationship', fallback: 'Parent/Guardian');
    for (final studentId in studentIds) {
      await api.createRaw('/guardians', {
        'student_id': studentId,
        'full_name': row.required('full_name'),
        'relationship': relationship,
        'phone': row.value('phone'),
        'email': row.value('email'),
        'occupation': row.value('occupation'),
        'annual_income': double.tryParse(row.value('annual_income')) ?? 0,
        'is_primary': _bool(row.value('is_primary')),
        'can_pickup': _bool(row.value('can_pickup')),
      });
    }
  }

  static Future<void> _importClass(
    BackendApiClient api,
    _ImportLookup lookup,
    _CsvRow row,
  ) async {
    final academicYearId = row.value('academic_year_id').isNotEmpty
        ? row.value('academic_year_id')
        : lookup.academicYearIdFor(row.value('year_label'));
    if (academicYearId.isEmpty) {
      throw 'academic_year_id or a matching year_label is required';
    }
    await api.createPrincipalClass(
      academicYearId: academicYearId,
      sectionName: row.required('section_name'),
      capacity: int.tryParse(row.value('capacity')) ?? 40,
      gradeName: row.required('grade_name'),
      gradeNumber:
          int.tryParse(row.value('grade_number')) ??
          _gradeNumberFrom(row.required('grade_name')),
      classTeacherId: lookup.staffIdFor(
        id: row.value('class_teacher_id'),
        staffCode: row.value('class_teacher_staff_code'),
        email: row.value('class_teacher_email'),
      ),
      subjectMappings: _classSubjectMappings(row, lookup),
      feeItems: _classFeeItems(row),
    );
  }

  static Future<_TimetableImportOutcome> _importClassTimetable(
    BackendApiClient api,
    _ImportLookup lookup,
    _CsvRow row,
  ) async {
    final academicYearId = row.value('academic_year_id').isNotEmpty
        ? row.value('academic_year_id')
        : lookup.academicYearIdFor(row.value('year_label'));
    if (academicYearId.isEmpty) {
      throw 'academic_year_id or a matching year_label is required before timetable generation';
    }

    final sectionId = row.value('section_id').isNotEmpty
        ? row.value('section_id')
        : lookup.sectionIdFor(
            gradeName: row.required('grade_name'),
            sectionName: row.required('section_name'),
            academicYearId: academicYearId,
          );
    if (sectionId.isEmpty) {
      throw 'class ${row.required('grade_name')} - ${row.required('section_name')} was not found. Import or create this class before generating its timetable';
    }

    final termId = lookup.termIdFor(
      academicYearId: academicYearId,
      termId: row.value('term_id'),
      termName: row.value('term_name'),
    );
    if (termId.isEmpty) {
      throw 'term_id or a term for ${row.value('year_label', fallback: academicYearId)} is required before timetable generation';
    }

    final days = _workingDays(row.value('working_days'));
    final periodsPerDay = _periodsPerDay(row, days.length);
    final response = await api.generateSmartTimetable(
      sectionId: sectionId,
      academicYearId: academicYearId,
      termId: termId,
      days: days,
      periodsPerDay: periodsPerDay,
      startTime: row.value('start_time', fallback: '09:00'),
      periodDurationMinutes:
          int.tryParse(row.value('period_duration_minutes')) ?? 40,
      gapMinutes: int.tryParse(row.value('gap_minutes')) ?? 5,
      breaks: _breakRowsFor(row, days, periodsPerDay),
      regenerateScope: _bool(row.value('regenerate_scope'), fallback: true),
    );

    final slotsCreated = _createdSlotsFrom(response);
    final issues = _timetableIssuesFrom(response, slotsCreated);
    final suggestions = _timetableSuggestionsFrom(response, slotsCreated);
    return _TimetableImportOutcome(
      slotsCreated: slotsCreated,
      warnings: issues,
      suggestions: suggestions,
    );
  }

  static List<Map<String, dynamic>> _classSubjectMappings(
    _CsvRow row,
    _ImportLookup lookup,
  ) {
    final names = _splitList(row.value('subject_names'));
    final codes = _splitList(row.value('subject_codes'));
    final types = _splitList(row.value('subject_types'));
    final departments = _splitList(row.value('subject_departments'));
    final teacherCodes = _splitList(row.value('subject_teacher_staff_codes'));
    final teacherEmails = _splitList(row.value('subject_teacher_emails'));
    final periods = _splitList(row.value('periods_per_week'));
    final maxMarks = _splitList(row.value('max_marks'));
    final passMarks = _splitList(row.value('pass_marks'));

    return [
      for (var index = 0; index < names.length; index++)
        {
          'subject_name': names[index],
          'subject_code': _at(codes, index),
          'subject_type': _at(types, index, fallback: 'core'),
          'department_name': _at(departments, index, fallback: 'Academics'),
          'teacher_id': lookup.staffIdFor(
            staffCode: _at(teacherCodes, index),
            email: _at(teacherEmails, index),
          ),
          'periods_per_week': int.tryParse(_at(periods, index)) ?? 5,
          'max_marks': int.tryParse(_at(maxMarks, index)) ?? 100,
          'pass_marks': int.tryParse(_at(passMarks, index)) ?? 35,
          'is_mandatory': true,
          'is_primary': true,
        },
    ];
  }

  static List<Map<String, dynamic>> _classFeeItems(_CsvRow row) {
    final categories = _splitList(row.value('fee_categories'));
    final amounts = _splitList(row.value('fee_amounts'));
    final frequencies = _splitList(row.value('fee_frequencies'));
    final dueDays = _splitList(row.value('fee_due_days'));
    final lateFines = _splitList(row.value('fee_late_fines'));

    return [
      for (var index = 0; index < categories.length; index++)
        {
          'category_name': categories[index],
          'frequency': _at(frequencies, index, fallback: 'term'),
          'amount': double.tryParse(_at(amounts, index)) ?? 0,
          'due_day': int.tryParse(_at(dueDays, index)) ?? 10,
          'late_fine_per_day': double.tryParse(_at(lateFines, index)) ?? 0,
        },
    ];
  }

  static Future<bool?> _showFormatDialog(
    BuildContext context,
    BulkCsvImportTarget target,
  ) {
    final schema = _schema(target);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Upload ${schema.label} CSV'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Required headers: ${schema.required.join(', ')}'),
                const SizedBox(height: 10),
                Text('Accepted headers: ${schema.displayHeaders.join(', ')}'),
                const SizedBox(height: 14),
                SelectableText(schema.template),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              copyTemplate(dialogContext, target);
            },
            child: const Text('Copy template'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Choose CSV'),
          ),
        ],
      ),
    );
  }

  static Future<void> _showResultDialog(
    BuildContext context,
    BulkCsvImportTarget target,
    _BulkImportResult result,
  ) {
    final color = result.failures.isEmpty && result.warnings.isEmpty
        ? AppTheme.success
        : AppTheme.warning;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_schema(target).label} import complete'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${result.created} row${result.created == 1 ? '' : 's'} imported.',
                ),
                if (result.timetableSlotsCreated > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${result.timetableSlotsCreated} timetable slot${result.timetableSlotsCreated == 1 ? '' : 's'} generated for class and teacher views.',
                  ),
                ],
                if (result.warnings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${result.warnings.length} gap${result.warnings.length == 1 ? '' : 's'} or warning${result.warnings.length == 1 ? '' : 's'} found.',
                  ),
                  const SizedBox(height: 8),
                  for (final warning in result.warnings.take(10))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(warning),
                    ),
                  if (result.warnings.length > 10)
                    Text('+${result.warnings.length - 10} more'),
                ],
                if (result.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Suggested next steps:'),
                  const SizedBox(height: 8),
                  for (final suggestion in result.suggestions.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('- $suggestion'),
                    ),
                ],
                if (result.failures.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${result.failures.length} row${result.failures.length == 1 ? '' : 's'} need attention.',
                  ),
                  const SizedBox(height: 8),
                  for (final failure in result.failures.take(12))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(failure),
                    ),
                  if (result.failures.length > 12)
                    Text('+${result.failures.length - 12} more'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          for (final action in result.actions.take(2))
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.of(context).pushNamed(action.route);
              },
              icon: Icon(action.icon, size: 18),
              label: Text(action.label),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  static List<List<String>> _parseCsv(String source) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (char == '"') {
        if (quoted && i + 1 < source.length && source[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        row.add(cell.toString().trim());
        cell.clear();
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') {
          i++;
        }
        row.add(cell.toString().trim());
        cell.clear();
        if (row.any((value) => value.isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        cell.write(char);
      }
    }
    row.add(cell.toString().trim());
    if (row.any((value) => value.isNotEmpty)) rows.add(row);
    return rows;
  }

  static _CsvSchema _schema(BulkCsvImportTarget target) {
    switch (target) {
      case BulkCsvImportTarget.students:
        return _CsvSchema(
          label: 'students',
          required: const ['first_name'],
          displayHeaders: const [
            'first_name',
            'last_name',
            'date_of_birth',
            'gender',
            'admission_number',
            'student_code',
            'class',
            'section',
            'parent_email',
          ],
          aliases: _baseAliases,
          template:
              'first_name,last_name,date_of_birth,gender,admission_number,student_code,class,section,parent_email\nAsha,Rao,2012-04-12,female,ADM-101,STU-101,5,A,parent@example.com',
        );
      case BulkCsvImportTarget.staff:
        return _CsvSchema(
          label: 'staff',
          required: const ['first_name'],
          displayHeaders: const [
            'first_name',
            'last_name',
            'staff_code',
            'username',
            'email',
            'phone',
            'designation',
            'password',
            'account_role',
          ],
          aliases: _baseAliases,
          template:
              'first_name,last_name,staff_code,username,email,phone,designation,password,account_role\nMeera,Nair,T-101,meera.nair,meera@example.com,9876543210,Teacher,Welcome@123,Teacher',
        );
      case BulkCsvImportTarget.parents:
        return _CsvSchema(
          label: 'parents and guardians',
          required: const ['full_name', 'username', 'password'],
          displayHeaders: const [
            'full_name',
            'username',
            'password',
            'email',
            'phone',
            'admission_numbers',
            'relationship',
            'is_primary',
            'can_pickup',
          ],
          aliases: _baseAliases,
          template:
              'full_name,username,password,email,phone,admission_numbers,relationship,is_primary,can_pickup\nRaj Rao,raj.rao,Welcome@123,raj@example.com,9876500011,ADM-101,Father,true,true',
        );
      case BulkCsvImportTarget.classes:
        return _CsvSchema(
          label: 'classes',
          required: const ['grade_name', 'section_name'],
          displayHeaders: const [
            'grade_name',
            'grade_number',
            'section_name',
            'capacity',
            'room_number',
            'room_type',
            'room_capacity',
            'year_label',
            'academic_year_id',
            'term_id',
            'term_name',
            'class_teacher_id',
            'class_teacher_staff_code',
            'class_teacher_email',
            'subject_names',
            'subject_codes',
            'subject_types',
            'subject_departments',
            'subject_teacher_staff_codes',
            'subject_teacher_emails',
            'periods_per_week',
            'max_marks',
            'pass_marks',
            'fee_categories',
            'fee_amounts',
            'fee_frequencies',
            'fee_due_days',
            'fee_late_fines',
            'working_days',
            'periods_per_day',
            'start_time',
            'period_duration_minutes',
            'gap_minutes',
            'short_break_period',
            'short_break_label',
            'short_break_start_time',
            'short_break_end_time',
            'long_break_period',
            'long_break_label',
            'long_break_start_time',
            'long_break_end_time',
            'regenerate_scope',
          ],
          aliases: _baseAliases,
          template:
              'grade_name,grade_number,section_name,capacity,room_number,room_type,room_capacity,year_label,academic_year_id,term_id,term_name,class_teacher_id,class_teacher_staff_code,class_teacher_email,subject_names,subject_codes,subject_types,subject_departments,subject_teacher_staff_codes,subject_teacher_emails,periods_per_week,max_marks,pass_marks,fee_categories,fee_amounts,fee_frequencies,fee_due_days,fee_late_fines,working_days,periods_per_day,start_time,period_duration_minutes,gap_minutes,short_break_period,short_break_label,short_break_start_time,short_break_end_time,long_break_period,long_break_label,long_break_start_time,long_break_end_time,regenerate_scope\n5,5,A,40,5-A,classroom,40,2026-2027,,,Term 1,,T-101,,Mathematics;English,MATH;ENG,core;core,Academics;Languages,T-101;T-102,,6;5,100;100,35;35,Tuition;Transport,25000;8000,term;monthly,10;5,0;0,Mon;Tue;Wed;Thu;Fri,6,09:00,40,5,3,Interval,10:45,11:00,5,Lunch Break,12:20,12:50,true',
        );
      case BulkCsvImportTarget.classTimetables:
        return _CsvSchema(
          label: 'class timetables',
          required: const ['grade_name', 'section_name'],
          displayHeaders: const [
            'grade_name',
            'grade_number',
            'section_name',
            'year_label',
            'academic_year_id',
            'term_id',
            'term_name',
            'subject_names',
            'subject_teacher_staff_codes',
            'periods_per_week',
            'working_days',
            'periods_per_day',
            'start_time',
            'period_duration_minutes',
            'gap_minutes',
            'short_break_period',
            'short_break_label',
            'short_break_start_time',
            'short_break_end_time',
            'long_break_period',
            'long_break_label',
            'long_break_start_time',
            'long_break_end_time',
            'regenerate_scope',
          ],
          aliases: _baseAliases,
          template:
              'grade_name,grade_number,section_name,year_label,term_name,subject_names,subject_codes,subject_teacher_staff_codes,periods_per_week,working_days,periods_per_day,start_time,period_duration_minutes,gap_minutes,short_break_period,short_break_label,short_break_start_time,short_break_end_time,long_break_period,long_break_label,long_break_start_time,long_break_end_time,regenerate_scope\n5,5,A,2026-2027,Term 1,Mathematics;English,MATH;ENG,T-101;T-102,6;5,Mon;Tue;Wed;Thu;Fri,6,09:00,40,5,3,Interval,10:45,11:00,5,Lunch Break,12:20,12:50,true',
        );
    }
  }

  static const Map<String, List<String>> _baseAliases = {
    'first_name': ['first_name', 'firstname', 'first name', 'given_name'],
    'last_name': ['last_name', 'lastname', 'last name', 'surname'],
    'full_name': ['full_name', 'name', 'parent_name', 'guardian_name'],
    'date_of_birth': ['date_of_birth', 'dob', 'birth_date'],
    'admission_number': ['admission_number', 'admission_no', 'admission'],
    'admission_numbers': [
      'admission_numbers',
      'admission_number',
      'admissions',
      'student_admissions',
    ],
    'student_code': ['student_code', 'student_id', 'roll_no'],
    'current_section_id': ['current_section_id', 'section_id'],
    'section_id': ['section_id', 'current_section_id'],
    'parent_user_id': ['parent_user_id', 'parent_id'],
    'parent_email': ['parent_email', 'guardian_email'],
    'parent_username': ['parent_username'],
    'staff_code': ['staff_code', 'employee_id', 'employee_code'],
    'account_role': ['account_role', 'role'],
    'section_name': ['section_name', 'section'],
    'grade_name': ['grade_name', 'class', 'class_name', 'grade'],
    'year_label': ['year_label', 'academic_year', 'year'],
    'term_id': ['term_id'],
    'term_name': ['term_name', 'term'],
    'room_number': ['room_number', 'room_name', 'classroom', 'class_room'],
    'room_type': ['room_type', 'classroom_type'],
    'room_capacity': ['room_capacity', 'classroom_capacity'],
    'class_teacher_staff_code': ['class_teacher_staff_code', 'teacher_code'],
    'class_teacher_email': ['class_teacher_email', 'teacher_email'],
    'subject_names': ['subject_names', 'subjects', 'subject_name'],
    'subject_codes': ['subject_codes', 'subject_code'],
    'subject_types': ['subject_types', 'subject_type'],
    'subject_departments': ['subject_departments', 'department_names'],
    'subject_teacher_staff_codes': [
      'subject_teacher_staff_codes',
      'subject_teacher_codes',
      'teacher_staff_codes',
    ],
    'subject_teacher_emails': ['subject_teacher_emails', 'teacher_emails'],
    'periods_per_week': ['periods_per_week', 'periods'],
    'working_days': ['working_days', 'days', 'timetable_days'],
    'periods_per_day': ['periods_per_day', 'period_count'],
    'start_time': ['start_time', 'school_start_time'],
    'period_duration_minutes': [
      'period_duration_minutes',
      'period_duration',
      'duration_minutes',
    ],
    'gap_minutes': ['gap_minutes', 'period_gap_minutes'],
    'short_break_period': ['short_break_period', 'interval_period'],
    'short_break_label': ['short_break_label', 'interval_label'],
    'short_break_start_time': ['short_break_start_time', 'interval_start_time'],
    'short_break_end_time': ['short_break_end_time', 'interval_end_time'],
    'long_break_period': ['long_break_period', 'lunch_period'],
    'long_break_label': ['long_break_label', 'lunch_label'],
    'long_break_start_time': ['long_break_start_time', 'lunch_start_time'],
    'long_break_end_time': ['long_break_end_time', 'lunch_end_time'],
    'regenerate_scope': ['regenerate_scope', 'replace_existing_timetable'],
    'max_marks': ['max_marks'],
    'pass_marks': ['pass_marks'],
    'fee_categories': ['fee_categories', 'fee_category_names', 'fees'],
    'fee_amounts': ['fee_amounts', 'amounts'],
    'fee_frequencies': ['fee_frequencies', 'fee_frequency'],
    'fee_due_days': ['fee_due_days', 'due_days'],
    'fee_late_fines': ['fee_late_fines', 'late_fines'],
  };

  static String _normalizeHeader(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');

  static String _date(String value, String fallback) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return parsed.toIso8601String().substring(0, 10);
    return trimmed;
  }

  static List<String> _splitList(String value) => value
      .split(RegExp(r'[;|]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  static String _at(List<String> values, int index, {String fallback = ''}) {
    if (index < 0 || index >= values.length) return fallback;
    final value = values[index].trim();
    return value.isEmpty ? fallback : value;
  }

  static bool _bool(String value, {bool fallback = false}) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return fallback;
    return const {'true', 'yes', 'y', '1', 'active'}.contains(normalized);
  }

  static int _periodsPerDay(_CsvRow row, int workingDayCount) {
    final explicit = int.tryParse(row.value('periods_per_day')) ?? 0;
    if (explicit > 0) return explicit.clamp(1, 12).toInt();

    final weeklyPeriods = _splitList(row.value('periods_per_week'))
        .map((value) => int.tryParse(value) ?? 0)
        .where((value) => value > 0)
        .fold<int>(0, (total, value) => total + value);
    if (weeklyPeriods <= 0 || workingDayCount <= 0) return 8;
    final calculated = (weeklyPeriods / workingDayCount).ceil();
    return calculated.clamp(1, 12).toInt();
  }

  static List<int> _workingDays(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [1, 2, 3, 4, 5];
    final lower = trimmed.toLowerCase().replaceAll(' ', '');
    if (lower == 'mon-fri' || lower == 'monday-friday') {
      return const [1, 2, 3, 4, 5];
    }
    if (lower == 'mon-sat' || lower == 'monday-saturday') {
      return const [1, 2, 3, 4, 5, 6];
    }
    final days = <int>[];
    for (final part in trimmed.split(RegExp(r'[;|/]'))) {
      final normalized = part.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      final asNumber = int.tryParse(normalized);
      final day = asNumber ?? _weekdayNumbers[normalized];
      if (day == null || day < 1 || day > 7 || days.contains(day)) continue;
      days.add(day);
    }
    return days.isEmpty ? const [1, 2, 3, 4, 5] : days;
  }

  static List<Map<String, dynamic>> _breakRowsFor(
    _CsvRow row,
    List<int> days,
    int periodsPerDay,
  ) {
    final rows = <Map<String, dynamic>>[];
    final usedPeriods = <int>{};

    void addBreak(
      String periodKey,
      String labelKey,
      String startKey,
      String endKey,
      String fallbackLabel,
      String type,
    ) {
      final periodText = row.value(periodKey);
      final start = row.value(startKey).trim();
      final end = row.value(endKey).trim();
      final hasCustomTiming = start.isNotEmpty || end.isNotEmpty;
      if (periodText.trim().isEmpty) {
        if (hasCustomTiming) {
          throw '$periodKey is required when custom break timing is entered';
        }
        return;
      }
      final period = int.tryParse(periodText.trim()) ?? 0;
      if (period <= 0) {
        throw '$periodKey must be a positive period number';
      }
      if (period > periodsPerDay) {
        throw '$periodKey must be within periods_per_day';
      }
      if (!usedPeriods.add(period)) {
        throw 'short_break_period and long_break_period cannot use the same period';
      }
      final label = row.value(labelKey, fallback: fallbackLabel).trim();
      if (hasCustomTiming) {
        _validateBreakTiming(startKey, start, endKey, end);
      }
      final breakRow = <String, dynamic>{
        'label': label.isEmpty ? fallbackLabel : label,
        'type': type,
        'days': days,
        'periods': [period],
      };
      if (hasCustomTiming) {
        breakRow['start_time'] = start;
        breakRow['end_time'] = end;
      }
      rows.add(breakRow);
    }

    addBreak(
      'short_break_period',
      'short_break_label',
      'short_break_start_time',
      'short_break_end_time',
      'Interval',
      'short_break',
    );
    addBreak(
      'long_break_period',
      'long_break_label',
      'long_break_start_time',
      'long_break_end_time',
      'Lunch Break',
      'long_break',
    );
    return rows;
  }

  static void _validateBreakTiming(
    String startKey,
    String start,
    String endKey,
    String end,
  ) {
    if (start.isEmpty || end.isEmpty) {
      throw '$startKey and $endKey must both be supplied for custom break timing';
    }
    if (!_validCsvTime(start) || !_validCsvTime(end)) {
      throw '$startKey and $endKey must use HH:MM format';
    }
    if (_csvTimeMinutes(end) <= _csvTimeMinutes(start)) {
      throw '$endKey must be after $startKey';
    }
  }

  static bool _validCsvTime(String value) {
    return RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').hasMatch(value.trim());
  }

  static int _csvTimeMinutes(String value) {
    final parts = value.trim().split(':');
    return (int.tryParse(parts.first) ?? 0) * 60 +
        (int.tryParse(parts.last) ?? 0);
  }

  static const Map<String, int> _weekdayNumbers = {
    'mon': 1,
    'monday': 1,
    'tue': 2,
    'tues': 2,
    'tuesday': 2,
    'wed': 3,
    'wednesday': 3,
    'thu': 4,
    'thur': 4,
    'thurs': 4,
    'thursday': 4,
    'fri': 5,
    'friday': 5,
    'sat': 6,
    'saturday': 6,
    'sun': 7,
    'sunday': 7,
  };

  static int _createdSlotsFrom(Map<String, dynamic> response) {
    final created = response['created'];
    final createdCount = created is List ? created.length : 0;
    final summaryCount = _intValue(_map(response['summary'])['created_slots']);
    return summaryCount > createdCount ? summaryCount : createdCount;
  }

  static List<String> _timetableIssuesFrom(
    Map<String, dynamic> response,
    int slotsCreated,
  ) {
    final issues = <String>[];
    for (final conflict in _listMap(response['conflicts'])) {
      final message = _text(conflict['message']);
      if (message.isNotEmpty) issues.add(message);
    }
    for (final log in _listMap(response['logs'])) {
      final severity = _text(log['severity']).toLowerCase();
      if (severity != 'warning' && severity != 'error') continue;
      final message = _text(log['message']);
      if (message.isNotEmpty) issues.add(message);
    }
    final summary = _map(response['summary']);
    final requested = _intValue(summary['requested_slots']);
    final blocked = _intValue(summary['blocked_slots']);
    if (blocked > 0) {
      issues.add(
        '$blocked timetable slot${blocked == 1 ? '' : 's'} could not be placed because of blocking constraints.',
      );
    }
    if (slotsCreated == 0 && requested > 0) {
      issues.add(
        'No timetable slots were generated for a requested $requested-period plan.',
      );
    }
    return _unique(issues);
  }

  static List<String> _timetableSuggestionsFrom(
    Map<String, dynamic> response,
    int slotsCreated,
  ) {
    final suggestions = <String>[];
    final summary = _map(response['summary']);
    if (_intValue(summary['conflict_count']) > 0) {
      suggestions.add(
        'Open the Admin timetable grid and edit the duplicate teacher/class periods flagged by the backend.',
      );
    }
    if (_intValue(summary['blocked_slots']) > 0 || slotsCreated == 0) {
      suggestions.add(
        'Check subject mappings and teacher staff codes in the class CSV, then regenerate this class timetable.',
      );
    }
    if (slotsCreated > 0) {
      suggestions.add(
        'Review both class timetable and teacher timetable views; they now use the same generated backend slots.',
      );
    }
    return _unique(suggestions);
  }

  static _BulkImportResult _classHubImportResultFrom(
    Map<String, dynamic> response,
  ) {
    final summary = _map(response['summary']);
    final createdClasses = _intValue(summary['created_classes']);
    final updatedClasses = _intValue(summary['updated_classes']);
    final importedRows = createdClasses + updatedClasses;
    final failures = _issueLines(response['errors']);
    final warnings = _issueLines(response['warnings']);
    final suggestions = <String>[
      if (failures.isNotEmpty)
        'Fix the highlighted CSV rows and run the Class Hub dry-run again.',
      if (importedRows > 0)
        'Review Class Hub, Subjects, and Fees; all three now read the imported backend setup.',
      if (importedRows > 0)
        'Timetable generation remains on the Admin timetable path because timetable writes are Admin-owned.',
    ];
    return _BulkImportResult(
      created: importedRows,
      failures: failures,
      warnings: _unique(warnings),
      suggestions: _unique(suggestions),
      actions: importedRows > 0
          ? const [
              _BulkImportAction(
                label: 'Review timetables',
                route: AppRoutes.principalTimetable,
                icon: Icons.fact_check_outlined,
              ),
            ]
          : const [],
    );
  }

  static List<String> _issueLines(Object? value) {
    final issues = <String>[];
    for (final item in _listMap(value)) {
      final row = _intValue(item['row']);
      final field = _text(item['field']);
      final message = _text(item['message']);
      if (message.isEmpty) continue;
      final prefix = [
        if (row > 0) 'Row $row',
        if (field.isNotEmpty) field,
      ].join(' ');
      issues.add(prefix.isEmpty ? message : '$prefix: $message');
    }
    return _unique(issues);
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _listMap(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static int _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  static String _text(Object? value) => '${value ?? ''}'.trim();

  static List<String> _unique(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final text = value.trim();
      if (text.isEmpty || seen.contains(text)) continue;
      seen.add(text);
      result.add(text);
    }
    return result;
  }

  static int _gradeNumberFrom(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return int.tryParse(match?.group(0) ?? '') ?? 1;
  }

  static void _snack(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}

class _CsvRow {
  _CsvRow(this.headers, this.values, this.aliases);

  final List<String> headers;
  final List<String> values;
  final Map<String, List<String>> aliases;

  String required(String key) {
    final result = value(key);
    if (result.isEmpty) throw '$key is required';
    return result;
  }

  String value(String key, {String fallback = ''}) {
    final accepted = (aliases[key] ?? [key]).map(
      BulkCsvImportService._normalizeHeader,
    );
    for (final candidate in accepted) {
      final index = headers.indexOf(candidate);
      if (index < 0 || index >= values.length) continue;
      final value = values[index].trim();
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }
}

class _CsvSchema {
  const _CsvSchema({
    required this.label,
    required this.required,
    required this.displayHeaders,
    required this.aliases,
    required this.template,
  });

  final String label;
  final List<String> required;
  final List<String> displayHeaders;
  final Map<String, List<String>> aliases;
  final String template;
}

class _BulkImportResult {
  const _BulkImportResult({
    this.created = 0,
    this.timetableSlotsCreated = 0,
    this.failures = const [],
    this.warnings = const [],
    this.suggestions = const [],
    this.actions = const [],
  });

  final int created;
  final int timetableSlotsCreated;
  final List<String> failures;
  final List<String> warnings;
  final List<String> suggestions;
  final List<_BulkImportAction> actions;
}

class _BulkImportAction {
  const _BulkImportAction({
    required this.label,
    required this.route,
    required this.icon,
  });

  final String label;
  final String route;
  final IconData icon;
}

class _TimetableImportOutcome {
  const _TimetableImportOutcome({
    required this.slotsCreated,
    this.warnings = const [],
    this.suggestions = const [],
  });

  final int slotsCreated;
  final List<String> warnings;
  final List<String> suggestions;
}

class _ImportLookup {
  const _ImportLookup({
    required this.academicYears,
    required this.grades,
    required this.sections,
    required this.staff,
    required this.students,
    required this.parents,
    required this.termsByYear,
  });

  final List<AcademicYearModel> academicYears;
  final List<GradeModel> grades;
  final List<SectionModel> sections;
  final List<StaffModel> staff;
  final List<StudentModel> students;
  final List<UserAccountModel> parents;
  final Map<String, List<Map<String, dynamic>>> termsByYear;

  static Future<_ImportLookup> load(BackendApiClient api) async {
    final years = await _safe(() => api.getAcademicYears());
    final termLists = await Future.wait(
      years.map((year) => _safe(() => api.getTerms(year.id))),
    );
    final termsByYear = <String, List<Map<String, dynamic>>>{
      for (var index = 0; index < years.length; index++)
        years[index].id: termLists[index],
    };
    final grades = await _safe(() => api.getGrades());
    final sections = await _safe(() => api.getSections());
    final staff = await _safePaginated(
      () => api.getStaff(page: 1, pageSize: 500),
    );
    final students = await _safePaginated(
      () => api.getStudents(page: 1, pageSize: 500),
    );
    final parents = await _safePaginated(
      () => api.getUsers(role: 'Parent', page: 1, pageSize: 500),
    );
    return _ImportLookup(
      academicYears: years,
      grades: grades,
      sections: sections,
      staff: staff,
      students: students,
      parents: parents,
      termsByYear: termsByYear,
    );
  }

  static Future<List<T>> _safe<T>(Future<List<T>> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<T>> _safePaginated<T>(
    Future<PaginatedList<T>> Function() load,
  ) async {
    try {
      return (await load()).data;
    } catch (_) {
      return const [];
    }
  }

  String academicYearIdFor(String yearLabel) {
    final wanted = yearLabel.trim().toLowerCase();
    for (final year in academicYears) {
      if (wanted.isNotEmpty && year.yearLabel.toLowerCase() == wanted) {
        return year.id;
      }
    }
    for (final year in academicYears) {
      if (year.isCurrent) return year.id;
    }
    return academicYears.isEmpty ? '' : academicYears.first.id;
  }

  String sectionIdFor({
    required String gradeName,
    required String sectionName,
    String academicYearId = '',
  }) {
    final gradeId = _gradeIdFor(gradeName);
    final wantedSection = sectionName.trim().toLowerCase();
    for (final section in sections) {
      if (gradeId.isNotEmpty && section.gradeId != gradeId) continue;
      if (academicYearId.trim().isNotEmpty &&
          section.academicYearId != academicYearId.trim()) {
        continue;
      }
      if (wantedSection.isNotEmpty &&
          section.sectionName.trim().toLowerCase() != wantedSection) {
        continue;
      }
      return section.id;
    }
    return '';
  }

  String termIdFor({
    required String academicYearId,
    String termId = '',
    String termName = '',
  }) {
    if (termId.trim().isNotEmpty) return termId.trim();
    final terms = termsByYear[academicYearId.trim()] ?? const [];
    final wanted = termName.trim().toLowerCase();
    if (wanted.isNotEmpty) {
      for (final term in terms) {
        final id = BulkCsvImportService._text(term['id']);
        final name = BulkCsvImportService._text(
          term['term_name'] ?? term['name'] ?? term['label'],
        ).toLowerCase();
        if (id.toLowerCase() == wanted || name == wanted) return id;
      }
    }
    for (final term in terms) {
      final isCurrent = term['is_current'] == true;
      final status = BulkCsvImportService._text(term['status']).toLowerCase();
      if (isCurrent || status == 'current' || status == 'active') {
        return BulkCsvImportService._text(term['id']);
      }
    }
    if (terms.isEmpty) return '';
    return BulkCsvImportService._text(terms.first['id']);
  }

  String staffIdFor({
    String id = '',
    String staffCode = '',
    String email = '',
  }) {
    if (id.trim().isNotEmpty) return id.trim();
    final code = staffCode.trim().toLowerCase();
    final mail = email.trim().toLowerCase();
    for (final member in staff) {
      if (code.isNotEmpty && member.staffCode.trim().toLowerCase() == code) {
        return member.id;
      }
      if (mail.isNotEmpty &&
          (member.email ?? '').trim().toLowerCase() == mail) {
        return member.id;
      }
    }
    return '';
  }

  String parentIdFor({String email = '', String username = ''}) {
    final mail = email.trim().toLowerCase();
    final user = username.trim().toLowerCase();
    for (final parent in parents) {
      if (mail.isNotEmpty && parent.email.trim().toLowerCase() == mail) {
        return parent.id;
      }
      if (user.isNotEmpty && parent.username.trim().toLowerCase() == user) {
        return parent.id;
      }
    }
    return '';
  }

  String studentIdFor(String admissionOrCode) {
    final key = admissionOrCode.trim().toLowerCase();
    if (key.isEmpty) return '';
    for (final student in students) {
      if (student.id.toLowerCase() == key ||
          student.admissionNumber.toLowerCase() == key ||
          student.studentCode.toLowerCase() == key) {
        return student.id;
      }
    }
    return '';
  }

  String _gradeIdFor(String gradeName) {
    final wanted = gradeName.trim().toLowerCase();
    if (wanted.isEmpty) return '';
    for (final grade in grades) {
      if (grade.id.toLowerCase() == wanted ||
          grade.gradeName.trim().toLowerCase() == wanted ||
          'class ${grade.gradeName}'.toLowerCase() == wanted) {
        return grade.id;
      }
    }
    return '';
  }
}
