import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/core/widgets/operations_workspace.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/widgets/desktop_screen_wrapper.dart';
import 'package:schooldesk1/modules/finance/data/api_admin_fees_repository.dart';
import 'package:schooldesk1/modules/finance/domain/admin_fees_repository.dart';

@immutable
class AdminFeeStructureFormArgs {
  final List<AcademicYearModel> academicYears;
  final List<GradeModel> grades;
  final List<SectionModel> sections;
  final List<Map<String, dynamic>> feeCategories;
  final Map<String, dynamic>? feeStructure;
  final String ownerRole;

  const AdminFeeStructureFormArgs({
    required this.academicYears,
    required this.grades,
    required this.sections,
    required this.feeCategories,
    this.feeStructure,
    this.ownerRole = 'admin',
  });

  /// A non-null structure can also be a create-form seed (for example, the
  /// selected academic year and class). Only a persisted backend record has an
  /// identifier and may use the update workflow.
  bool get isEditing {
    final structure = feeStructure;
    if (structure == null) return false;
    final id =
        structure['id'] ??
        structure['structure_id'] ??
        structure['fee_structure_id'];
    return id?.toString().trim().isNotEmpty ?? false;
  }
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
  final String ownerRole;

  const AdminInvoiceGenerationFormArgs({
    required this.academicYears,
    required this.grades,
    required this.sections,
    required this.students,
    required this.feeStructures,
    this.seedStructure,
    this.ownerRole = 'admin',
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

typedef _FeeFrequencyOption = ({String value, String label});

const List<_FeeFrequencyOption> _feeFrequencyOptions = [
  (value: 'one_time', label: 'One Time'),
  (value: 'yearly', label: 'Yearly'),
  (value: 'monthly', label: 'Monthly'),
  (value: 'term', label: 'Term'),
];

@immutable
class AdminPaymentRecordFormArgs {
  final List<Map<String, dynamic>> pendingDues;
  final Map<String, dynamic>? initialInvoice;
  final String ownerRole;

  const AdminPaymentRecordFormArgs({
    required this.pendingDues,
    this.initialInvoice,
    this.ownerRole = 'admin',
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
  final AdminFeesRepository? repository;

  const AdminFeeStructureFormScreen({
    super.key,
    required this.args,
    this.repository,
  });

  @override
  State<AdminFeeStructureFormScreen> createState() =>
      _AdminFeeStructureFormScreenState();
}

class _AdminFeeStructureFormScreenState
    extends State<AdminFeeStructureFormScreen> {
  late final AdminFeesRepository _repository;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _dueDayController;
  late final TextEditingController _lateFineController;
  late String _selectedYearId;
  late String _selectedGradeId;
  late String _selectedSectionId;
  late String _selectedCategoryId;
  late String _selectedFrequency;
  bool _replaceExisting = false;
  bool _saving = false;

  bool get _hasReferenceData =>
      widget.args.academicYears.isNotEmpty &&
      widget.args.grades.isNotEmpty &&
      widget.args.feeCategories.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiAdminFeesRepository.legacyDefault;
    final fee = widget.args.feeStructure ?? const <String, dynamic>{};
    _selectedYearId = _initialId(
      '${fee['academic_year_id'] ?? ''}',
      widget.args.academicYears.map((year) => year.id),
    );
    _selectedGradeId = _initialId(
      '${fee['grade_id'] ?? ''}',
      _gradeOptions.map((grade) => grade.id),
    );
    _selectedSectionId = _initialId('${fee['section_id'] ?? ''}', [
      '',
      ..._structureSectionOptions.map((section) => section.id),
    ]);
    _selectedCategoryId = _initialId(
      '${fee['fee_category_id'] ?? fee['category_id'] ?? ''}',
      widget.args.feeCategories.map((category) => '${category['id']}'),
    );
    _selectedFrequency = _initialFrequency(fee);
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
    final isDesktop = DesktopBreakpoints.isDesktopWidth(
      MediaQuery.sizeOf(context).width,
    );

    if (isDesktop) {
      return DesktopScreenWrapper(
        breadcrumbs: const ['Finance', 'Fees', 'Form'],
        title: widget.args.isEditing
            ? 'Edit Fee Structure'
            : 'Create Fee Structure',
        subtitle: 'Class and section-wise fee setup owned by Principal finance',
        actions: const [],
        maxWidth: 600,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: context.appTheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_hasReferenceData)
                    const SchoolDeskStatusPanel.empty(
                      title: 'Setup data missing',
                      message:
                          'Academic years, classes, and fee categories are required before fee structure requests can be prepared.',
                    )
                  else ...[
                    _buildSummary(),
                    const SizedBox(height: 14),
                    _buildSelectors(),
                    const SizedBox(height: 14),
                    _buildAmountFields(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(_saving ? 'Saving...' : 'Save Structure'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SchoolDeskModuleScaffold(
      title: widget.args.isEditing
          ? 'Edit Fee Structure'
          : 'Create Fee Structure',
      subtitle: 'Class and section-wise fee setup owned by Principal finance',
      drawer: _financeDrawer(widget.args.ownerRole),
      floatingActionButton: DashboardFabWidget(
        role: _dashboardRole(widget.args.ownerRole),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: SchoolDeskRepositoryStateView<Object>(
        state: const RepositoryState<Object>(
          data: Object(),
          source: RepositorySource.remote,
        ),
        onRetry: () {},
        data: (_) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_hasReferenceData)
                const SchoolDeskStatusPanel.empty(
                  title: 'Setup data missing',
                  message:
                      'Academic years, classes, and fee categories are required before fee structure requests can be prepared.',
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
                  label: Text(_saving ? 'Saving...' : 'Save Structure'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final fee = widget.args.feeStructure;
    final grade = widget.args.grades
        .where((g) => g.id == _selectedGradeId)
        .firstOrNull;
    final section = _structureSectionOptions
        .where((s) => s.id == _selectedSectionId)
        .firstOrNull;
    final titleLabel = widget.args.isEditing
        ? _textValue(fee?['class'], fallback: 'Fee structure')
        : grade != null
        ? 'Fee Structure for ${grade.gradeName}${section != null ? ' - ${section.sectionName}' : ' (All Sections)'}'
        : 'Create backend fee structure';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.appTheme.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.playlist_add_check_rounded,
              color: context.appTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleLabel,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Review the class, section, fee category, due day, and amount.',
                  style: GoogleFonts.dmSans(
                    color: context.appTheme.muted,
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
          value: _selectedYearId,
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
              : (value) => setState(() {
                  _selectedYearId = value ?? '';
                  _selectedGradeId = _initialId(
                    '',
                    _gradeOptions.map((grade) => grade.id),
                  );
                  _selectedSectionId = '';
                }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedGradeId,
          decoration: const InputDecoration(labelText: 'Class'),
          items: _gradeOptions
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
              : (value) => setState(() {
                  _selectedGradeId = value ?? '';
                  if (!_structureSectionOptions.any(
                    (section) => section.id == _selectedSectionId,
                  )) {
                    _selectedSectionId = '';
                  }
                }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedSectionId,
          decoration: const InputDecoration(labelText: 'Section scope'),
          items: [
            const DropdownMenuItem(value: '', child: Text('All sections')),
            for (final section in _structureSectionOptions)
              DropdownMenuItem(
                value: section.id,
                child: Text(section.sectionName),
              ),
          ],
          onChanged: _saving
              ? null
              : (value) => setState(() => _selectedSectionId = value ?? ''),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedCategoryId,
          decoration: const InputDecoration(labelText: 'Fee category'),
          items: widget.args.feeCategories
              .map(
                (category) => DropdownMenuItem(
                  value: '${category['id']}',
                  child: Text(
                    _textValue(
                      category['category_name'] ?? category['name'],
                      fallback: 'Fee',
                    ),
                  ),
                ),
              )
              .toList(),
          validator: (value) => _required(value, 'Select fee category.'),
          onChanged: _saving
              ? null
              : (value) => setState(() {
                  _selectedCategoryId = value ?? '';
                  _selectedFrequency = _defaultFrequencyForCategory(
                    _selectedCategoryName,
                    fallback: _selectedFrequency,
                  );
                }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedFrequency,
          decoration: const InputDecoration(labelText: 'Frequency'),
          items: _feeFrequencyOptions
              .map(
                (option) => DropdownMenuItem(
                  value: option.value,
                  child: Text(option.label),
                ),
              )
              .toList(),
          validator: (value) => _required(value, 'Select frequency.'),
          onChanged: _saving
              ? null
              : (value) => setState(() => _selectedFrequency = value ?? 'term'),
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
          onChanged: (_) => setState(() {}),
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
          onChanged: (_) => setState(() {}),
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
        const SizedBox(height: 12),
        _feePreview(),
        if (!widget.args.isEditing) ...[
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _replaceExisting,
            onChanged: _saving
                ? null
                : (value) => setState(() => _replaceExisting = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('Replace existing class/year fee structure'),
            subtitle: const Text(
              'Deletes all existing fee components for the selected class and academic year, then saves this new setup.',
            ),
          ),
        ],
      ],
    );
  }

  Widget _feePreview() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final dueDay = int.tryParse(_dueDayController.text) ?? 10;
    final frequencyLabel = _feeFrequencyLabel(_selectedFrequency);
    final parentBehavior = switch (_selectedFrequency) {
      'one_time' => 'Parents pay this once. It is not split.',
      'yearly' =>
        'One annual tuition invoice is created; parents can pay only the next continuous unpaid months.',
      'monthly' => 'Parents pay this as monthly dues.',
      'term' =>
        'Use monthly tuition for the parent workflow; term plans are not used in this flow.',
      _ => 'Parents pay according to the saved frequency.',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appTheme.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live payment preview',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: context.appTheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'INR ${amount.toStringAsFixed(0)} | $frequencyLabel | due day $dueDay',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.appTheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            parentBehavior,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appTheme.muted,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_replaceExisting && !await _confirmReplaceExisting()) return;
    setState(() => _saving = true);
    try {
      final id = _feeStructureId;
      if (widget.args.isEditing) {
        if (id.isEmpty) throw Exception('Backend fee structure ID is missing');
        await _repository.updateFeeStructure(
          id,
          academicYearId: _selectedYearId,
          gradeId: _selectedGradeId,
          sectionId: _selectedSectionId,
          feeCategoryId: _selectedCategoryId,
          amount: double.parse(_amountController.text),
          frequency: _selectedFrequency,
          dueDay: int.parse(_dueDayController.text),
          lateFinePerDay: double.tryParse(_lateFineController.text) ?? 0,
        );
        await _repository.applyFeeInvoiceSync(
          id,
          includePartiallyPaid: true,
        );
      } else {
        final created = await _repository.createFeeStructure(
          academicYearId: _selectedYearId,
          gradeId: _selectedGradeId,
          sectionId: _selectedSectionId,
          feeCategoryId: _selectedCategoryId,
          amount: double.parse(_amountController.text),
          frequency: _selectedFrequency,
          dueDay: int.parse(_dueDayController.text),
          lateFinePerDay: double.tryParse(_lateFineController.text) ?? 0,
          replaceExisting: _replaceExisting,
        );
        final createdId = _textValue(created['id']);
        if (createdId.isNotEmpty) {
          await _repository.applyFeeInvoiceSync(
            createdId,
            includePartiallyPaid: true,
          );
        }
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        AdminFeeStructureFormResult(
          widget.args.isEditing
              ? 'Fee structure updated and dues refreshed'
              : _replaceExisting
              ? 'Existing class fee structure replaced with the new setup'
              : 'Fee structure created',
        ),
      );
    } on Object catch (error) {
      _showErrorSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _feeStructureId {
    final fee = widget.args.feeStructure ?? const <String, dynamic>{};
    return _textValue(
      fee['id'] ?? fee['structure_id'] ?? fee['fee_structure_id'],
    );
  }

  Future<bool> _confirmReplaceExisting() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace class fee structure?'),
        content: const Text(
          'This will delete all existing fee components for the selected class and academic year before saving this new setup. Existing generated invoices and payment records are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_sweep_rounded),
            label: const Text('Replace'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  List<GradeModel> get _gradeOptions {
    final gradeIds = widget.args.sections
        .where((section) => section.academicYearId == _selectedYearId)
        .map((section) => section.gradeId)
        .where((id) => id.isNotEmpty)
        .toSet();
    return widget.args.grades
        .where((grade) => gradeIds.contains(grade.id))
        .toList();
  }

  List<SectionModel> get _structureSectionOptions =>
      widget.args.sections.where((section) {
        return section.gradeId == _selectedGradeId &&
            section.academicYearId == _selectedYearId;
      }).toList()..sort((a, b) => a.sectionName.compareTo(b.sectionName));

  String get _selectedCategoryName {
    for (final category in widget.args.feeCategories) {
      if ('${category['id']}' == _selectedCategoryId) {
        return _textValue(
          category['category_name'] ?? category['name'],
          fallback: 'Fee',
        );
      }
    }
    return 'Fee';
  }

  String _initialFrequency(Map<String, dynamic> fee) {
    if (_selectedCategoryName.toLowerCase().contains('tuition')) {
      return 'monthly';
    }
    final raw = _textValue(fee['frequency'] ?? fee['billing_mode']);
    if (raw.isNotEmpty) return _feeFrequencyPayload(raw);
    return _defaultFrequencyForCategory(_selectedCategoryName);
  }
}

class AdminInvoiceGenerationFormScreen extends StatefulWidget {
  final AdminInvoiceGenerationFormArgs args;
  final AdminFeesRepository? repository;

  const AdminInvoiceGenerationFormScreen({
    super.key,
    required this.args,
    this.repository,
  });

  @override
  State<AdminInvoiceGenerationFormScreen> createState() =>
      _AdminInvoiceGenerationFormScreenState();
}

class _AdminInvoiceGenerationFormScreenState
    extends State<AdminInvoiceGenerationFormScreen> {
  late final AdminFeesRepository _repository;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _dueDateController;
  late String _scope;
  late String _selectedYearId;
  late String _selectedGradeId;
  String _selectedTermId = '';
  String _selectedSectionId = '';
  String _selectedStudentId = '';
  List<Map<String, dynamic>> _terms = [];
  bool _loadingTerms = false;
  bool _includeOneTime = false;
  bool _includeYearly = false;
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
      .fold<double>(0, (sum, fee) {
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

  List<SectionModel> get _sectionOptions =>
      widget.args.sections.where((section) {
        return section.gradeId == _selectedGradeId &&
            section.academicYearId == _selectedYearId;
      }).toList()..sort((a, b) => a.sectionName.compareTo(b.sectionName));

  List<GradeModel> get _gradeOptions {
    final gradeIds = widget.args.sections
        .where((section) => section.academicYearId == _selectedYearId)
        .map((section) => section.gradeId)
        .where((id) => id.isNotEmpty)
        .toSet();
    return widget.args.grades
        .where((grade) => gradeIds.contains(grade.id))
        .toList();
  }

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
    _repository = widget.repository ?? ApiAdminFeesRepository.legacyDefault;
    final seed = widget.args.seedStructure ?? const <String, dynamic>{};
    _scope = 'class';
    _selectedYearId = _initialId(
      '${seed['academic_year_id'] ?? ''}',
      widget.args.academicYears.map((year) => year.id),
    );
    _selectedGradeId = _initialId(
      '${seed['grade_id'] ?? ''}',
      _gradeOptions.map((grade) => grade.id),
    );
    _labelController = TextEditingController(text: _defaultInvoiceLabel());
    _dueDateController = TextEditingController(
      text: _defaultDueDate(dueDay: (seed['due_day'] as num?)?.toInt()),
    );
    _loadTermsForYear(_selectedYearId);
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
      title: 'Generate Invoices',
      subtitle:
          'Prepare class, section, or student invoices for the fees workflow',
      drawer: _financeDrawer(widget.args.ownerRole),
      floatingActionButton: DashboardFabWidget(
        role: _dashboardRole(widget.args.ownerRole),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: SchoolDeskRepositoryStateView<Object>(
        state: const RepositoryState<Object>(
          data: Object(),
          source: RepositorySource.remote,
        ),
        onRetry: () {},
        data: (_) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_hasReferenceData)
                const SchoolDeskStatusPanel.empty(
                  title: 'Invoice setup data missing',
                  message:
                      'Academic year, class, and student data must be loaded before invoice requests can be submitted.',
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
                    _generating ? 'Generating...' : 'Generate Invoices',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceScope() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedYearId,
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
              : (value) => _loadTermsForYear(value ?? ''),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('invoice-term-$_selectedYearId-$_selectedTermId'),
          value: _selectedTermId.isEmpty ? null : _selectedTermId,
          decoration: const InputDecoration(labelText: 'Term'),
          items: _terms
              .map(
                (term) => DropdownMenuItem(
                  value: _textValue(term['id']),
                  child: Text(_termLabel(term)),
                ),
              )
              .toList(),
          validator: (value) => _required(value, 'Select term.'),
          onChanged: _generating || _loadingTerms
              ? null
              : (value) {
                  setState(() {
                    _selectedTermId = value ?? '';
                    _labelController.text = _selectedTermLabel;
                  });
                },
        ),
        if (_loadingTerms)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedGradeId,
          decoration: const InputDecoration(labelText: 'Class'),
          items: _gradeOptions
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
        OpsModeSelector<String>(
          selected: _scope,
          enabled: !_generating,
          options: const [
            OpsModeOption(
              value: 'class',
              icon: Icons.groups_rounded,
              label: 'Class',
            ),
            OpsModeOption(
              value: 'section',
              icon: Icons.group_work_rounded,
              label: 'Section',
            ),
            OpsModeOption(
              value: 'student',
              icon: Icons.person_rounded,
              label: 'Student',
            ),
          ],
          onSelected: (value) => setState(() {
            _scope = value;
            _selectedSectionId = '';
            _selectedStudentId = '';
          }),
        ),
        if (_scope == 'section' || _scope == 'student') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedSectionId.isEmpty ? null : _selectedSectionId,
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
            value: _selectedStudentId.isEmpty ? null : _selectedStudentId,
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
          decoration: const InputDecoration(labelText: 'Invoice label'),
          validator: (value) => _required(value, 'Enter invoice label.'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _dueDateController,
          enabled: !_generating,
          decoration: const InputDecoration(labelText: 'Due date'),
          keyboardType: TextInputType.datetime,
          validator: _dateValidator,
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          value: _includeOneTime,
          onChanged: _generating
              ? null
              : (value) => setState(() => _includeOneTime = value),
          contentPadding: EdgeInsets.zero,
          title: const Text('Include one-time components'),
        ),
        SwitchListTile.adaptive(
          value: _includeYearly,
          onChanged: _generating
              ? null
              : (value) => setState(() => _includeYearly = value),
          contentPadding: EdgeInsets.zero,
          title: const Text('Include yearly components'),
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
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate_rounded, color: context.appTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Estimated invoice is INR ${_estimatedTotal.toStringAsFixed(0)} per student for $_selectedTermLabel and the $scopeLabel.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: context.appTheme.muted,
              ),
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
      final result = await _repository.createRaw('/fees/invoices/generate', {
        'academic_year_id': _selectedYearId,
        'grade_id': _selectedGradeId,
        if (_scope == 'section') 'section_id': _selectedSectionId,
        if (_scope == 'student') 'student_id': _selectedStudentId,
        'term_id': _selectedTermId,
        'include_one_time': _includeOneTime,
        'include_yearly': _includeYearly,
        'invoice_label': _labelController.text.trim(),
        'due_date': _dueDateController.text.trim(),
      });
      if (!mounted) return;
      final createdCount = (result['created'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      Navigator.pop(
        context,
        AdminInvoiceGenerationFormResult(
          created: createdCount,
          skipped: (result['skipped'] as num?)?.toInt() ?? 0,
        ),
      );
    } on Object catch (error) {
      _showErrorSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _defaultInvoiceLabel() {
    final now = DateTime.now();
    if (_selectedTermId.isNotEmpty) return _selectedTermLabel;
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

  Future<void> _loadTermsForYear(String yearId) async {
    setState(() {
      _selectedYearId = yearId;
      _selectedGradeId = _initialId('', _gradeOptions.map((grade) => grade.id));
      _selectedSectionId = '';
      _selectedStudentId = '';
      _selectedTermId = '';
      _terms = [];
      _loadingTerms = true;
    });
    if (yearId.isEmpty) {
      if (mounted) setState(() => _loadingTerms = false);
      return;
    }
    try {
      final terms = await _repository.loadTerms(yearId);
      if (!mounted) return;
      setState(() {
        _terms = terms;
        _selectedTermId = _initialId(
          '',
          terms.map((term) => _textValue(term['id'])),
        );
        if (_selectedTermId.isNotEmpty) {
          _labelController.text = _selectedTermLabel;
        }
        _loadingTerms = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadingTerms = false);
      _showErrorSnack(context, 'Unable to load terms: $error');
    }
  }

  String get _selectedTermLabel {
    for (final term in _terms) {
      if (_textValue(term['id']) == _selectedTermId) return _termLabel(term);
    }
    return 'Term';
  }
}

class AdminPaymentRecordFormScreen extends StatefulWidget {
  final AdminPaymentRecordFormArgs args;
  final AdminFeesRepository? repository;

  const AdminPaymentRecordFormScreen({
    super.key,
    required this.args,
    this.repository,
  });

  @override
  State<AdminPaymentRecordFormScreen> createState() =>
      _AdminPaymentRecordFormScreenState();
}

class _AdminPaymentRecordFormScreenState
    extends State<AdminPaymentRecordFormScreen> {
  late final AdminFeesRepository _repository;
  final _formKey = GlobalKey<FormState>();
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
    _repository = widget.repository ?? ApiAdminFeesRepository.legacyDefault;
    final initialId = '${widget.args.initialInvoice?['id'] ?? ''}'.trim();
    _selectedInvoiceId = _initialId(
      initialId,
      _pendingDues.map((due) => '${due['id']}'),
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
    _amountController.dispose();
    _paymentDateController.dispose();
    _transactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Record Payment',
      subtitle: 'Record a verified payment against an outstanding invoice',
      drawer: _financeDrawer(widget.args.ownerRole),
      floatingActionButton: DashboardFabWidget(
        role: _dashboardRole(widget.args.ownerRole),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: SchoolDeskRepositoryStateView<Object>(
        state: const RepositoryState<Object>(
          data: Object(),
          source: RepositorySource.remote,
        ),
        onRetry: () {},
        data: (_) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_pendingDues.isEmpty)
                const SchoolDeskStatusPanel.empty(
                  title: 'No outstanding invoices',
                  message:
                      'Payment requests can be submitted after outstanding invoices are available.',
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
                  label: Text(_saving ? 'Saving...' : 'Record Payment'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedInvoiceId,
      decoration: const InputDecoration(labelText: 'Outstanding invoice'),
      items: _pendingDues
          .map(
            (due) => DropdownMenuItem(
              value: '${due['id']}',
              child: Text(
                '${_textValue(due['name'], fallback: 'Student')} - INR ${_numValue(due['balance'] ?? due['amount']).toStringAsFixed(0)}',
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
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.receipt_long_outlined),
          title: Text('Receipt number generated automatically'),
          subtitle: Text(
            'A finalized payment receives its official AV receipt number.',
          ),
        ),
        const SizedBox(height: 8),
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
          value: _paymentMode,
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
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
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
            _textValue(
              invoice['due_date'] ?? invoice['date'],
              fallback: 'Not recorded',
            ),
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
            style: GoogleFonts.dmSans(
              color: context.appTheme.muted,
              fontSize: 12,
            ),
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
      await _repository.recordPayment(
        PaymentRequest(
          invoiceId: _selectedInvoiceId,
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
    } on Object catch (error) {
      _showErrorSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

Widget _financeDrawer(String ownerRole) {
  if (_isPrincipalOwner(ownerRole)) {
    return PrincipalDrawer(
      selectedIndex: PrincipalNav.fees,
      onDestinationSelected: (_) {},
    );
  }
  return PrincipalDrawer(
    selectedIndex: PrincipalNav.fees,
    onDestinationSelected: (_) {},
  );
}

DashboardRole _dashboardRole(String ownerRole) {
  return _isPrincipalOwner(ownerRole)
      ? DashboardRole.principal
      : DashboardRole.principal;
}

bool _isPrincipalOwner(String ownerRole) =>
    ownerRole.trim().toLowerCase() == 'principal';

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

String _termLabel(Map<String, dynamic> term) {
  final name = _textValue(term['term_name'] ?? term['name'] ?? term['label']);
  if (name.isNotEmpty) return name;
  final number = _textValue(term['term_number']);
  return number.isEmpty ? 'Term' : 'Term $number';
}

String _defaultFrequencyForCategory(String categoryName, {String? fallback}) {
  final text = categoryName.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    ' ',
  );
  if (text.contains('tuition')) return 'monthly';
  if (text.contains('book') || text.contains('kit')) return 'one_time';
  return _feeFrequencyPayload(fallback ?? 'term');
}

String _feeFrequencyPayload(String frequency) {
  final raw = frequency.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  if (raw.contains('one')) return 'one_time';
  if (raw.contains('year')) return 'yearly';
  if (raw.contains('month')) return 'monthly';
  if (raw.contains('term')) return 'term';
  return raw.isEmpty ? 'term' : raw;
}

String _feeFrequencyLabel(String frequency) {
  return switch (_feeFrequencyPayload(frequency)) {
    'one_time' => 'One Time',
    'yearly' => 'Yearly',
    'monthly' => 'Monthly',
    'term' => 'Term',
    _ => frequency,
  };
}

String _feeFrequency(Map<String, dynamic> fee) {
  final category = fee['fee_category'] is Map
      ? Map<String, dynamic>.from(fee['fee_category'] as Map)
      : const <String, dynamic>{};
  final raw = _textValue(
    fee['frequency'] ?? category['frequency'],
    fallback: 'term',
  );
  return _feeFrequencyPayload(raw);
}

String _studentLabel(StudentModel student) {
  final roll = student.admissionNumber.isNotEmpty
      ? student.admissionNumber
      : student.studentCode;
  return roll.isEmpty ? student.fullName : '${student.fullName} - $roll';
}

void _showErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: context.appTheme.error),
  );
}
