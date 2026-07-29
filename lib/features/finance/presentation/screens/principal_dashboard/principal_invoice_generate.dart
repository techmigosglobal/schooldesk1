import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';

class PrincipalInvoiceGenerate extends StatefulWidget {
  final AdminInvoiceGenerationFormArgs args;

  const PrincipalInvoiceGenerate({super.key, required this.args});

  @override
  State<PrincipalInvoiceGenerate> createState() =>
      _PrincipalInvoiceGenerateState();
}

class _PrincipalInvoiceGenerateState extends State<PrincipalInvoiceGenerate> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _dueDateController;

  String _scope = 'class';
  late String _selectedYearId;
  late String _selectedGradeId;
  String _selectedSectionId = '';
  String _selectedStudentId = '';

  bool _includeOneTime = true;
  bool _includeYearly = false;
  bool _generating = false;

  bool get _hasReferenceData =>
      widget.args.academicYears.isNotEmpty && widget.args.grades.isNotEmpty;

  double get _estimatedTotal {
    return widget.args.feeStructures
        .where(
          (fee) =>
              '${fee['academic_year_id']}' == _selectedYearId &&
              '${fee['grade_id']}' == _selectedGradeId,
        )
        .fold<double>(0.0, (sum, fee) {
          final amount = _numValue(fee['amount']);
          final frequency = _feeFrequency(fee);
          if (frequency == 'one_time') {
            return _includeOneTime ? sum + amount : sum;
          }
          if (frequency == 'yearly') {
            return _includeYearly ? sum + amount : sum;
          }
          return sum + amount;
        });
  }

  List<SectionModel> get _sectionOptions =>
      widget.args.sections.where((s) => s.gradeId == _selectedGradeId).toList()
        ..sort((a, b) => a.sectionName.compareTo(b.sectionName));

  List<StudentModel> get _studentOptions {
    final sectionIds = _sectionOptions.map((s) => s.id).toSet();
    return widget.args.students.where((student) {
      final sectionId = student.currentSectionId ?? '';
      if (_selectedSectionId.isNotEmpty) {
        return sectionId == _selectedSectionId;
      }
      return sectionIds.contains(sectionId);
    }).toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  @override
  void initState() {
    super.initState();
    final seed = widget.args.seedStructure ?? const <String, dynamic>{};
    _selectedYearId = _initialId(
      '${seed['academic_year_id'] ?? ''}',
      widget.args.academicYears.map((year) => year.id),
    );
    _selectedGradeId = _initialId(
      '${seed['grade_id'] ?? ''}',
      widget.args.grades.map((grade) => grade.id),
    );

    _labelController = TextEditingController();
    _dueDateController = TextEditingController(
      text: _defaultDueDate(dueDay: seed['due_day'] as int?),
    );

    _labelController.text = _defaultInvoiceLabel();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  String _initialId(String seedValue, Iterable<String> options) {
    if (options.contains(seedValue)) return seedValue;
    final currentOption = widget.args.academicYears
        .firstWhereOrNull((y) => y.isCurrent)
        ?.id;
    if (currentOption != null && options.contains(currentOption)) {
      return currentOption;
    }
    return options.isEmpty ? '' : options.first;
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_estimatedTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fee structures found for this class/year.'),
        ),
      );
      return;
    }
    setState(() => _generating = true);
    try {
      final result = await BackendApiClient.instance
          .createRaw('/fees/invoices/generate', {
            'academic_year_id': _selectedYearId,
            'grade_id': _selectedGradeId,
            if (_scope == 'section') 'section_id': _selectedSectionId,
            if (_scope == 'student') 'student_id': _selectedStudentId,
            'include_one_time': _includeOneTime,
            'include_yearly': _includeYearly,
            'invoice_label': _labelController.text.trim(),
            'due_date': _dueDateController.text.trim(),
          });
      if (!mounted) return;
      final createdCount = (result['created'] as num?)?.toInt() ?? 0;
      final skippedCount = (result['skipped'] as num?)?.toInt() ?? 0;
      final existingPaid =
          (result['existing_paid_count'] as num?)?.toInt() ?? 0;
      final existingUnpaid =
          (result['existing_unpaid_count'] as num?)?.toInt() ?? 0;
      if (createdCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              skippedCount > 0
                  ? 'No duplicate invoices were created. $existingPaid paid and $existingUnpaid unpaid existing invoice(s) were kept.'
                  : 'No eligible fee components or students were found for this selection.',
            ),
          ),
        );
        return;
      }
      if (createdCount > 0) {
        try {
          final gradeLabel =
              widget.args.grades
                  .firstWhereOrNull((g) => g.id == _selectedGradeId)
                  ?.gradeName ??
              'Class';
          final notifService = await NotificationService.getInstance();
          await notifService.triggerInvoiceGeneratedAlert(
            invoiceCount: createdCount,
            classLabel: gradeLabel,
            termLabel: _labelController.text.trim(),
          );
        } on Object catch (_) {}
      }
      Navigator.pop(
        context,
        AdminInvoiceGenerationFormResult(
          created: createdCount,
          skipped: skippedCount,
        ),
      );
    } on Object catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: context.appTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _defaultInvoiceLabel() {
    final now = DateTime.now();
    final current = widget.args.academicYears.firstWhereOrNull(
      (year) => year.isCurrent,
    );
    return '${_monthName(now.month)} ${current?.yearLabel ?? '${now.year}'}';
  }

  String _feeComponentName(Map<String, dynamic> fee) {
    final direct = textValue(fee['category_name'] ?? fee['fee_item_name']);
    if (direct.isNotEmpty) return direct;
    final category = fee['fee_category'] ?? fee['category'];
    if (category is Map) {
      final nested = textValue(category['category_name'] ?? category['name']);
      if (nested.isNotEmpty) return nested;
    } else {
      final value = textValue(category);
      if (value.isNotEmpty && !RegExp(r'^[0-9a-f-]{36}$').hasMatch(value)) {
        return value;
      }
    }
    return 'Fee';
  }

  String _defaultDueDate({int? dueDay}) {
    final now = DateTime.now();
    final day = (dueDay == null || dueDay <= 0) ? 10 : dueDay.clamp(1, 28);
    var candidate = DateTime(now.year, now.month, day);
    if (candidate.isBefore(DateTime(now.year, now.month, now.day))) {
      candidate = DateTime(now.year, now.month + 1, day);
    }
    return candidate.toIso8601String().split('T').first;
  }

  String _monthName(int month) {
    const list = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return (month >= 1 && month <= 12) ? list[month - 1] : '';
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasReferenceData) {
      return Scaffold(
        appBar: AppBar(title: const Text('Generate Invoices')),
        body: const Center(
          child: Text('Reference metadata is incomplete. Please wait...'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.appTheme.surface,
      appBar: AppBar(
        title: const Text(
          'Generate Invoices',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: context.appTheme.onSurface,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Step 1: Scope',
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: context.appTheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedYearId,
                      decoration: const InputDecoration(
                        labelText: 'Academic Year',
                      ),
                      items: widget.args.academicYears
                          .map(
                            (y) => DropdownMenuItem(
                              value: y.id,
                              child: Text(y.yearLabel),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedYearId = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedGradeId,
                      decoration: const InputDecoration(
                        labelText: 'Class / Grade',
                      ),
                      items: widget.args.grades
                          .map(
                            (g) => DropdownMenuItem(
                              value: g.id,
                              child: Text(g.gradeName),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _selectedGradeId = v;
                          _selectedSectionId = '';
                          _selectedStudentId = '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _scope,
                      decoration: const InputDecoration(labelText: 'Scope'),
                      items: const [
                        DropdownMenuItem(
                          value: 'class',
                          child: Text('Entire Class'),
                        ),
                        DropdownMenuItem(
                          value: 'section',
                          child: Text('Specific Section'),
                        ),
                        DropdownMenuItem(
                          value: 'student',
                          child: Text('Single Student'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _scope = v;
                          _selectedSectionId = '';
                          _selectedStudentId = '';
                        });
                      },
                    ),
                    if (_scope != 'class') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedSectionId.isEmpty
                            ? null
                            : _selectedSectionId,
                        decoration: const InputDecoration(labelText: 'Section'),
                        items: _sectionOptions
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.sectionName),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedSectionId = v ?? '';
                            _selectedStudentId = '';
                          });
                        },
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Please select a section'
                            : null,
                      ),
                    ],
                    if (_scope == 'student') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedStudentId.isEmpty
                            ? null
                            : _selectedStudentId,
                        decoration: const InputDecoration(labelText: 'Student'),
                        items: _studentOptions
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.fullName),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() => _selectedStudentId = v ?? '');
                        },
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Please select a student'
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Step 2: Settings',
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: context.appTheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _labelController,
                      decoration: const InputDecoration(
                        labelText: 'Invoice Description Label',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Label is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dueDateController,
                      decoration: const InputDecoration(
                        labelText: 'Due Date (YYYY-MM-DD)',
                        prefixIcon: Icon(Icons.calendar_month_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Due date is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text(
                        'Include One-Time Fees',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: _includeOneTime,
                      onChanged: (val) =>
                          setState(() => _includeOneTime = val ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text(
                        'Include Yearly Fees',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: _includeYearly,
                      onChanged: (val) =>
                          setState(() => _includeYearly = val ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Step 3: Invoice Preview',
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            _buildFeeBreakdownPreview(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _generating ? null : _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A6B4A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: _generating
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Generate Invoices',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ── Fee Breakdown Preview ─────────────────────────────────────────────────

  Widget _buildFeeBreakdownPreview() {
    final matchingFees = widget.args.feeStructures
        .where(
          (fee) =>
              '${fee['academic_year_id']}' == _selectedYearId &&
              '${fee['grade_id']}' == _selectedGradeId,
        )
        .toList();

    if (matchingFees.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appTheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'No fee structures found for this class and academic year. '
          'Please set up fee structures first.',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            color: context.appTheme.onSurface,
          ),
        ),
      );
    }

    // Categorise each fee entry
    const catColors = {
      'tuition': (
        color: Color(0xFF1A6B4A),
        bg: Color(0xFFDCFCE7),
        icon: Icons.school_rounded,
      ),
      'books': (
        color: Color(0xFF1D4ED8),
        bg: Color(0xFFDBEAFE),
        icon: Icons.menu_book_rounded,
      ),
      'kit': (
        color: Color(0xFF92400E),
        bg: Color(0xFFFEF3C7),
        icon: Icons.backpack_rounded,
      ),
    };

    ({Color color, Color bg, IconData icon}) feeColor(String name) {
      final n = name.toLowerCase();
      if (n.contains('tuition') || n.contains('monthly')) {
        return catColors['tuition']!;
      }
      if (n.contains('book')) return catColors['books']!;
      if (n.contains('kit') || n.contains('uniform')) return catColors['kit']!;
      return (
        color: const Color(0xFF7C3AED),
        bg: const Color(0xFFF5F3FF),
        icon: Icons.receipt_outlined,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  size: 16,
                  color: Color(0xFF1A6B4A),
                ),
                const SizedBox(width: 8),
                Text(
                  'Fee Components for Selected Class',
                  style: GoogleFonts.ibmPlexSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: const Color(0xFF1A6B4A),
                  ),
                ),
              ],
            ),
          ),
          // Fee rows
          for (final fee in matchingFees) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  () {
                    final meta = feeColor(_feeComponentName(fee));
                    return Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: meta.bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(meta.icon, size: 12, color: meta.color),
                    );
                  }(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _feeComponentName(fee),
                          style: GoogleFonts.ibmPlexSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _feeFrequency(fee).replaceAll('_', ' '),
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11,
                            color: context.appTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${_numValue(fee['amount']).toStringAsFixed(0)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: const Color(0xFF1A6B4A),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Total row
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estimated Total per Student',
                  style: GoogleFonts.ibmPlexSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: const Color(0xFF1A6B4A),
                  ),
                ),
                Text(
                  '₹${_estimatedTotal.toStringAsFixed(0)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A6B4A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _numValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0.0;
  }

  String _feeFrequency(Map<String, dynamic> fee) {
    return '${fee['frequency'] ?? fee['billing_mode'] ?? 'term'}'.toLowerCase();
  }
}
