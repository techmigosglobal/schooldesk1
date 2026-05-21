import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_components.dart';
import '../../widgets/erp_module_scaffold.dart';

@immutable
class AdminFeeStructureFormArgs {
  final List<AcademicYearModel> academicYears;
  final List<GradeModel> grades;
  final List<Map<String, dynamic>> feeCategories;
  final Map<String, dynamic>? feeStructure;

  const AdminFeeStructureFormArgs({
    required this.academicYears,
    required this.grades,
    required this.feeCategories,
    this.feeStructure,
  });

  bool get isEditing => feeStructure != null;
}

@immutable
class AdminFeeStructureFormResult {
  final String message;

  const AdminFeeStructureFormResult(this.message);
}

@immutable
class AdminInvoiceGenerationFormArgs {
  final List<AcademicYearModel> academicYears;
  final List<GradeModel> grades;
  final List<SectionModel> sections;
  final List<StudentModel> students;
  final List<Map<String, dynamic>> feeStructures;
  final Map<String, dynamic>? seedStructure;

  const AdminInvoiceGenerationFormArgs({
    required this.academicYears,
    required this.grades,
    required this.sections,
    required this.students,
    required this.feeStructures,
    this.seedStructure,
  });
}

@immutable
class AdminInvoiceGenerationFormResult {
  final int created;
  final int skipped;

  const AdminInvoiceGenerationFormResult({
    required this.created,
    required this.skipped,
  });
}

@immutable
class AdminPaymentRecordFormArgs {
  final List<Map<String, dynamic>> pendingDues;
  final Map<String, dynamic>? initialInvoice;

  const AdminPaymentRecordFormArgs({
    required this.pendingDues,
    this.initialInvoice,
  });
}

@immutable
class AdminPaymentRecordFormResult {
  final String studentName;
  final double amount;

  const AdminPaymentRecordFormResult({
    required this.studentName,
    required this.amount,
  });
}

class AdminFeeStructureFormScreen extends StatefulWidget {
  final AdminFeeStructureFormArgs args;

  const AdminFeeStructureFormScreen({super.key, required this.args});

  @override
  State<AdminFeeStructureFormScreen> createState() =>
      _AdminFeeStructureFormScreenState();
}

class _AdminFeeStructureFormScreenState
    extends State<AdminFeeStructureFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _dueDayController;
  late final TextEditingController _lateFineController;
  late String _selectedYearId;
  late String _selectedGradeId;
  late String _selectedCategoryId;
  bool _saving = false;

  bool get _hasReferenceData =>
      widget.args.academicYears.isNotEmpty &&
      widget.args.grades.isNotEmpty &&
      widget.args.feeCategories.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final fee = widget.args.feeStructure ?? const <String, dynamic>{};
    _selectedYearId = _initialId(
      '${fee['academic_year_id'] ?? ''}',
      widget.args.academicYears.map((year) => year.id),
    );
    _selectedGradeId = _initialId(
      '${fee['grade_id'] ?? ''}',
      widget.args.grades.map((grade) => grade.id),
    );
    _selectedCategoryId = _initialId(
      '${fee['fee_category_id'] ?? ''}',
      widget.args.feeCategories.map((category) => '${category['id']}'),
    );
    _amountController = TextEditingController(
      text: _controllerNumber(fee['amount'] ?? fee['total'] ?? fee['tuition']),
    );
    _dueDayController = TextEditingController(
      text: _controllerInt(fee['due_day'], fallback: '10'),
    );
    _lateFineController = TextEditingController(
      text: _controllerNumber(fee['late_fine_per_day'], fallback: '0'),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dueDayController.dispose();
    _lateFineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: widget.args.isEditing ? 'Edit Fee Structure' : 'New Fee Structure',
      subtitle: 'Class-wise fee setup connected to backend fee structures',
      drawer: AdminDrawer(selectedIndex: 4, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_hasReferenceData)
              const SchoolDeskStatusPanel.empty(
                title: 'Setup data missing',
                message:
                    'Create academic years, classes, and fee categories before adding fee structures.',
              )
            else ...[
              _buildSummary(),
              const SizedBox(height: 14),
              _buildSelectors(),
              const SizedBox(height: 14),
              _buildAmountFields(),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_saving ? 'Saving...' : 'Save structure'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final fee = widget.args.feeStructure;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.playlist_add_check_rounded,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.args.isEditing
                      ? _textValue(fee?['class'], fallback: 'Fee structure')
                      : 'Create backend fee structure',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Select class, category, due day, and amount. This saves directly to /fees/structures.',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectors() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedYearId,
          decoration: const InputDecoration(labelText: 'Academic year'),
          items: widget.args.academicYears
              .map(
                (year) => DropdownMenuItem(
                  value: year.id,
                  child: Text(year.yearLabel),
                ),
              )
              .toList(),
          validator: (value) => _required(value, 'Select academic year.'),
          onChanged: _saving
              ? null
              : (value) => setState(() => _selectedYearId = value ?? ''),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedGradeId,
          decoration: const InputDecoration(labelText: 'Class'),
          items: widget.args.grades
              .map(
                (grade) => DropdownMenuItem(
                  value: grade.id,
                  child: Text(grade.gradeName),
                ),
              )
              .toList(),
          validator: (value) => _required(value, 'Select class.'),
          onChanged: _saving
              ? null
              : (value) => setState(() => _selectedGradeId = value ?? ''),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedCategoryId,
          decoration: const InputDecoration(labelText: 'Fee category'),
          items: widget.args.feeCategories
              .map(
                (category) => DropdownMenuItem(
                  value: '${category['id']}',
                  child: Text(
                    _textValue(category['category_name'], fallback: 'Fee'),
                  ),
                ),
              )
              .toList(),
          validator: (value) => _required(value, 'Select fee category.'),
          onChanged: _saving
              ? null
              : (value) => setState(() => _selectedCategoryId = value ?? ''),
        ),
      ],
    );
  }

  Widget _buildAmountFields() {
    return Column(
      children: [
        TextFormField(
          controller: _amountController,
          enabled: !_saving,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: 'INR ',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_decimalFormatter],
          validator: (value) {
            final amount = double.tryParse(value ?? '') ?? 0;
            return amount <= 0 ? 'Enter a valid amount.' : null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _dueDayController,
          enabled: !_saving,
          decoration: const InputDecoration(labelText: 'Due day'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            final dueDay = int.tryParse(value ?? '') ?? 0;
            return dueDay < 1 || dueDay > 31
                ? 'Enter a due day from 1 to 31.'
                : null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _lateFineController,
          enabled: !_saving,
          decoration: const InputDecoration(
            labelText: 'Late fine per day',
            prefixText: 'INR ',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_decimalFormatter],
          validator: (value) {
            final fine = double.tryParse(value ?? '') ?? 0;
            return fine < 0 ? 'Late fine cannot be negative.' : null;
          },
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'academic_year_id': _selectedYearId,
        'grade_id': _selectedGradeId,
        'fee_category_id': _selectedCategoryId,
        'amount': double.parse(_amountController.text),
        'due_day': int.parse(_dueDayController.text),
        'late_fine_per_day': double.tryParse(_lateFineController.text) ?? 0,
      };
      final id = '${widget.args.feeStructure?['id'] ?? ''}'.trim();
      if (widget.args.isEditing) {
        if (id.isEmpty) throw Exception('Backend fee structure ID is missing');
        await BackendApiClient.instance.updateRaw(
          '/fees/structures/$id',
          payload,
        );
      } else {
        await BackendApiClient.instance.createRaw('/fees/structures', payload);
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        AdminFeeStructureFormResult(
          widget.args.isEditing
              ? 'Fee structure updated from backend'
              : 'Fee structure created',
        ),
      );
    } catch (error) {
      _showErrorSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class AdminInvoiceGenerationFormScreen extends StatefulWidget {
  final AdminInvoiceGenerationFormArgs args;

  const AdminInvoiceGenerationFormScreen({super.key, required this.args});

  @override
  State<AdminInvoiceGenerationFormScreen> createState() =>
      _AdminInvoiceGenerationFormScreenState();
}

class _AdminInvoiceGenerationFormScreenState
    extends State<AdminInvoiceGenerationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _dueDateController;
  late String _scope;
  late String _selectedYearId;
  late String _selectedGradeId;
  String _selectedSectionId = '';
  String _selectedStudentId = '';
  bool _generating = false;

  bool get _hasReferenceData =>
      widget.args.academicYears.isNotEmpty &&
      widget.args.grades.isNotEmpty &&
      widget.args.students.isNotEmpty;

  double get _estimatedTotal => widget.args.feeStructures
      .where(
        (fee) =>
            '${fee['academic_year_id']}' == _selectedYearId &&
            '${fee['grade_id']}' == _selectedGradeId,
      )
      .fold<double>(0, (sum, fee) => sum + _numValue(fee['amount']));

  List<SectionModel> get _sectionOptions =>
      widget.args.sections.where((section) {
        return section.gradeId == _selectedGradeId;
      }).toList()..sort((a, b) => a.sectionName.compareTo(b.sectionName));

  List<StudentModel> get _studentOptions {
    final sectionIds = _sectionOptions.map((section) => section.id).toSet();
    return widget.args.students.where((student) {
      final studentSection = student.currentSectionId ?? '';
      if (_selectedSectionId.isNotEmpty) {
        return studentSection == _selectedSectionId;
      }
      return sectionIds.contains(studentSection);
    }).toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  @override
  void initState() {
    super.initState();
    final seed = widget.args.seedStructure ?? const <String, dynamic>{};
    _scope = 'class';
    _selectedYearId = _initialId(
      '${seed['academic_year_id'] ?? ''}',
      widget.args.academicYears.map((year) => year.id),
    );
    _selectedGradeId = _initialId(
      '${seed['grade_id'] ?? ''}',
      widget.args.grades.map((grade) => grade.id),
    );
    _labelController = TextEditingController(text: _defaultInvoiceLabel());
    _dueDateController = TextEditingController(
      text: _defaultDueDate(dueDay: (seed['due_day'] as num?)?.toInt()),
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Generate Fee Invoices',
      subtitle: 'Create backend invoices for a class, section, or student',
      drawer: AdminDrawer(selectedIndex: 4, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_hasReferenceData)
              const SchoolDeskStatusPanel.empty(
                title: 'Invoice setup data missing',
                message:
                    'Academic year, class, and student data must be loaded before generating invoices.',
              )
            else ...[
              _buildInvoiceScope(),
              const SizedBox(height: 14),
              _buildInvoiceFields(),
              const SizedBox(height: 14),
              _buildEstimate(),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _generating ? null : _generate,
                icon: _generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long_rounded, size: 18),
                label: Text(
                  _generating ? 'Generating...' : 'Generate invoices',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceScope() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedYearId,
          decoration: const InputDecoration(labelText: 'Academic year'),
          items: widget.args.academicYears
              .map(
                (year) => DropdownMenuItem(
                  value: year.id,
                  child: Text(year.yearLabel),
                ),
              )
              .toList(),
          validator: (value) => _required(value, 'Select academic year.'),
          onChanged: _generating
              ? null
              : (value) => setState(() => _selectedYearId = value ?? ''),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedGradeId,
          decoration: const InputDecoration(labelText: 'Class'),
          items: widget.args.grades
              .map(
                (grade) => DropdownMenuItem(
                  value: grade.id,
                  child: Text(grade.gradeName),
                ),
              )
              .toList(),
          validator: (value) => _required(value, 'Select class.'),
          onChanged: _generating
              ? null
              : (value) => setState(() {
                  _selectedGradeId = value ?? '';
                  _selectedSectionId = '';
                  _selectedStudentId = '';
                }),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'class',
              icon: Icon(Icons.groups_rounded),
              label: Text('Class'),
            ),
            ButtonSegment(
              value: 'section',
              icon: Icon(Icons.group_work_rounded),
              label: Text('Section'),
            ),
            ButtonSegment(
              value: 'student',
              icon: Icon(Icons.person_rounded),
              label: Text('Student'),
            ),
          ],
          selected: {_scope},
          onSelectionChanged: _generating
              ? null
              : (values) => setState(() {
                  _scope = values.first;
                  _selectedSectionId = '';
                  _selectedStudentId = '';
                }),
        ),
        if (_scope == 'section' || _scope == 'student') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedSectionId.isEmpty
                ? null
                : _selectedSectionId,
            decoration: InputDecoration(
              labelText: _scope == 'section' ? 'Section' : 'Filter by section',
            ),
            items: _sectionOptions
                .map(
                  (section) => DropdownMenuItem(
                    value: section.id,
                    child: Text(section.sectionName),
                  ),
                )
                .toList(),
            validator: (value) {
              if (_scope == 'section') {
                return _required(value, 'Select section.');
              }
              return null;
            },
            onChanged: _generating
                ? null
                : (value) => setState(() {
                    _selectedSectionId = value ?? '';
                    _selectedStudentId = '';
                  }),
          ),
        ],
        if (_scope == 'student') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedStudentId.isEmpty
                ? null
                : _selectedStudentId,
            decoration: const InputDecoration(labelText: 'Student'),
            items: _studentOptions
                .map(
                  (student) => DropdownMenuItem(
                    value: student.id,
                    child: Text(_studentLabel(student)),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select student.'),
            onChanged: _generating
                ? null
                : (value) => setState(() => _selectedStudentId = value ?? ''),
          ),
        ],
      ],
    );
  }

  Widget _buildInvoiceFields() {
    return Column(
      children: [
        TextFormField(
          controller: _labelController,
          enabled: !_generating,
          decoration: const InputDecoration(
            labelText: 'Invoice label',
            helperText: 'Example: Term 1, May 2026, Annual 2026',
          ),
          validator: (value) => _required(value, 'Enter invoice label.'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _dueDateController,
          enabled: !_generating,
          decoration: const InputDecoration(
            labelText: 'Due date',
            helperText: 'YYYY-MM-DD',
          ),
          keyboardType: TextInputType.datetime,
          validator: _dateValidator,
        ),
      ],
    );
  }

  Widget _buildEstimate() {
    final scopeLabel = switch (_scope) {
      'section' => 'selected section',
      'student' => 'selected student',
      _ => 'selected class',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.calculate_rounded, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Estimated invoice is INR ${_estimatedTotal.toStringAsFixed(0)} per student for the $scopeLabel.',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_estimatedTotal <= 0) {
      _showErrorSnack(context, 'No fee structures found for this class/year.');
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
            'invoice_label': _labelController.text.trim(),
            'due_date': _dueDateController.text.trim(),
          });
      if (!mounted) return;
      Navigator.pop(
        context,
        AdminInvoiceGenerationFormResult(
          created: (result['created'] as num?)?.toInt() ?? 0,
          skipped: (result['skipped'] as num?)?.toInt() ?? 0,
        ),
      );
    } catch (error) {
      _showErrorSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _defaultInvoiceLabel() {
    final now = DateTime.now();
    final current = widget.args.academicYears
        .where((year) => year.isCurrent)
        .firstOrNull;
    final year = current?.yearLabel ?? '${now.year}';
    return '${_monthName(now.month)} $year';
  }

  String _defaultDueDate({int? dueDay}) {
    final now = DateTime.now();
    final day = (dueDay == null || dueDay <= 0)
        ? 10
        : dueDay.clamp(1, 28).toInt();
    var candidate = DateTime(now.year, now.month, day);
    final today = DateTime(now.year, now.month, now.day);
    if (candidate.isBefore(today)) {
      candidate = DateTime(now.year, now.month + 1, day);
    }
    return _dateInput(candidate);
  }
}

class AdminPaymentRecordFormScreen extends StatefulWidget {
  final AdminPaymentRecordFormArgs args;

  const AdminPaymentRecordFormScreen({super.key, required this.args});

  @override
  State<AdminPaymentRecordFormScreen> createState() =>
      _AdminPaymentRecordFormScreenState();
}

class _AdminPaymentRecordFormScreenState
    extends State<AdminPaymentRecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _receiptController;
  late final TextEditingController _amountController;
  late final TextEditingController _paymentDateController;
  final _transactionController = TextEditingController();
  String _selectedInvoiceId = '';
  String _paymentMode = 'cash';
  bool _saving = false;

  List<Map<String, dynamic>> get _pendingDues => widget.args.pendingDues
      .where((due) => '${due['id'] ?? ''}'.trim().isNotEmpty)
      .map((due) => Map<String, dynamic>.from(due))
      .toList();

  Map<String, dynamic> get _selectedInvoice {
    if (_selectedInvoiceId.isEmpty) return const <String, dynamic>{};
    return _pendingDues.firstWhere(
      (due) => '${due['id']}' == _selectedInvoiceId,
      orElse: () => const <String, dynamic>{},
    );
  }

  double get _selectedBalance =>
      _numValue(_selectedInvoice['balance'] ?? _selectedInvoice['amount']);

  @override
  void initState() {
    super.initState();
    final initialId = '${widget.args.initialInvoice?['id'] ?? ''}'.trim();
    _selectedInvoiceId = _initialId(
      initialId,
      _pendingDues.map((due) => '${due['id']}'),
    );
    _receiptController = TextEditingController(
      text: 'RCP${DateTime.now().millisecondsSinceEpoch}',
    );
    _amountController = TextEditingController(
      text: _selectedBalance > 0 ? _selectedBalance.toStringAsFixed(0) : '',
    );
    _paymentDateController = TextEditingController(
      text: _dateInput(DateTime.now()),
    );
  }

  @override
  void dispose() {
    _receiptController.dispose();
    _amountController.dispose();
    _paymentDateController.dispose();
    _transactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Record Payment',
      subtitle: 'Apply a verified payment to an outstanding backend invoice',
      drawer: AdminDrawer(selectedIndex: 4, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_pendingDues.isEmpty)
              const SchoolDeskStatusPanel.empty(
                title: 'No outstanding invoices',
                message:
                    'Payments can be recorded after invoices are generated.',
              )
            else ...[
              _buildInvoiceSelector(),
              const SizedBox(height: 14),
              _buildPaymentFields(),
              const SizedBox(height: 14),
              _buildInvoiceSummary(),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _record,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.payments_rounded, size: 18),
                label: Text(_saving ? 'Recording...' : 'Record payment'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceSelector() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedInvoiceId,
      decoration: const InputDecoration(labelText: 'Outstanding invoice'),
      items: _pendingDues
          .map(
            (due) => DropdownMenuItem(
              value: '${due['id']}',
              child: Text(
                '${_textValue(due['name'], fallback: 'Student')} - INR ${_numValue(due['amount']).toStringAsFixed(0)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      validator: (value) => _required(value, 'Select backend invoice.'),
      onChanged: _saving
          ? null
          : (value) => setState(() {
              _selectedInvoiceId = value ?? '';
              final balance = _selectedBalance;
              _amountController.text = balance > 0
                  ? balance.toStringAsFixed(0)
                  : '';
            }),
    );
  }

  Widget _buildPaymentFields() {
    return Column(
      children: [
        TextFormField(
          controller: _receiptController,
          enabled: !_saving,
          decoration: const InputDecoration(labelText: 'Receipt number'),
          validator: (value) => _required(value, 'Enter receipt number.'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _amountController,
          enabled: !_saving,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: 'INR ',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_decimalFormatter],
          validator: (value) {
            final amount = double.tryParse(value ?? '') ?? 0;
            if (amount <= 0) return 'Enter a valid amount.';
            if (amount > _selectedBalance) {
              return 'Amount exceeds outstanding balance.';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _paymentDateController,
          enabled: !_saving,
          decoration: const InputDecoration(
            labelText: 'Payment date',
            helperText: 'YYYY-MM-DD',
          ),
          keyboardType: TextInputType.datetime,
          validator: _dateValidator,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _paymentMode,
          decoration: const InputDecoration(labelText: 'Payment mode'),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'online', child: Text('Online')),
            DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
            DropdownMenuItem(value: 'dd', child: Text('DD')),
          ],
          onChanged: _saving
              ? null
              : (value) => setState(() => _paymentMode = value ?? 'cash'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _transactionController,
          enabled: !_saving,
          decoration: const InputDecoration(
            labelText: 'Transaction ID',
            hintText: 'Optional for cash payments',
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceSummary() {
    final invoice = _selectedInvoice;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _textValue(invoice['name'], fallback: 'Selected student'),
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _summaryRow('Class', _textValue(invoice['class'], fallback: '-')),
          _summaryRow(
            'Invoice',
            _textValue(
              invoice['invoice_number'],
              fallback: '${invoice['id'] ?? '-'}',
            ),
          ),
          _summaryRow(
            'Outstanding',
            'INR ${_selectedBalance.toStringAsFixed(0)}',
          ),
          _summaryRow(
            'Due date',
            _textValue(invoice['date'], fallback: 'Not recorded'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(color: AppTheme.muted, fontSize: 12),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _record() async {
    if (!_formKey.currentState!.validate()) return;
    final invoice = _selectedInvoice;
    final amount = double.parse(_amountController.text);
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.recordPayment(
        PaymentRequest(
          invoiceId: _selectedInvoiceId,
          receiptNumber: _receiptController.text.trim(),
          amountPaid: amount,
          paymentDate: _paymentDateController.text.trim(),
          paymentMode: _paymentMode,
          transactionId: _transactionController.text.trim().isEmpty
              ? null
              : _transactionController.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        AdminPaymentRecordFormResult(
          studentName: _textValue(invoice['name'], fallback: 'student'),
          amount: amount,
        ),
      );
    } catch (error) {
      _showErrorSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

final _decimalFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'^\d*\.?\d{0,2}'),
);

String _initialId(String preferred, Iterable<String> options) {
  final values = options.where((value) => value.trim().isNotEmpty).toList();
  if (preferred.trim().isNotEmpty && values.contains(preferred)) {
    return preferred;
  }
  return values.isEmpty ? '' : values.first;
}

String? _required(String? value, String message) {
  if (value == null || value.trim().isEmpty) return message;
  return null;
}

String? _dateValidator(String? value) {
  final text = (value ?? '').trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    return 'Use YYYY-MM-DD.';
  }
  return DateTime.tryParse(text) == null ? 'Enter a valid date.' : null;
}

String _controllerNumber(Object? value, {String fallback = ''}) {
  final number = _numValue(value);
  if (number == 0) return fallback;
  return number.toStringAsFixed(number.truncateToDouble() == number ? 0 : 2);
}

String _controllerInt(Object? value, {String fallback = ''}) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  return parsed == null || parsed == 0 ? fallback : '$parsed';
}

double _numValue(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

String _textValue(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? fallback : text;
}

String _dateInput(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

String _two(int value) => value.toString().padLeft(2, '0');

String _monthName(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[(month - 1).clamp(0, 11).toInt()];
}

String _studentLabel(StudentModel student) {
  final roll = student.admissionNumber.isNotEmpty
      ? student.admissionNumber
      : student.studentCode;
  return roll.isEmpty ? student.fullName : '${student.fullName} - $roll';
}

void _showErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppTheme.error),
  );
}
