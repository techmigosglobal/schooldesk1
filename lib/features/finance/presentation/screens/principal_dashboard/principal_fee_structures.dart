import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';
import 'package:schooldesk1/modules/finance/data/api_admin_fees_repository.dart';
import 'package:schooldesk1/modules/finance/domain/admin_fees_repository.dart';

// Fee-type color/icon metadata used for badges on each structure card.
import 'package:schooldesk1/core/navigation/schooldesk_navigation.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';

const _feeCategoryColors = {
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

({Color color, Color bg, IconData icon}) _categoryMeta(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('tuition') || lower.contains('monthly')) {
    return _feeCategoryColors['tuition']!;
  }
  if (lower.contains('book')) return _feeCategoryColors['books']!;
  if (lower.contains('kit') || lower.contains('uniform')) {
    return _feeCategoryColors['kit']!;
  }
  return (
    color: const Color(0xFF7C3AED),
    bg: const Color(0xFFF5F3FF),
    icon: Icons.receipt_outlined,
  );
}

class PrincipalFeeStructures extends StatefulWidget {
  final AdminFeesRepository? repository;

  const PrincipalFeeStructures({super.key, this.repository});

  @override
  State<PrincipalFeeStructures> createState() => _PrincipalFeeStructuresState();
}

class _PrincipalFeeStructuresState extends State<PrincipalFeeStructures> {
  AdminFeesRepository get _repository =>
      widget.repository ?? ApiAdminFeesRepository.legacyDefault;

  RepositoryState<Object> _state = const RepositoryState.loading();
  String _query = '';
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _structures = const [];
  List<AcademicYearModel> _academicYears = const [];
  List<GradeModel> _grades = const [];
  List<SectionModel> _sections = const [];
  List<Map<String, dynamic>> _feeCategories = const [];
  String _selectedAcademicYearId = '';
  String _selectedGradeId = ''; // NEW — class filter

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final previous = _state.data;
    setState(() {
      _state = RepositoryState.loading(
        data: previous,
        source: previous == null
            ? RepositorySource.empty
            : RepositorySource.cache,
        isStale: previous != null,
        isRefreshing: previous != null,
      );
    });
    try {
      final results = await Future.wait<Object>([
        _repository.loadFeeStructures(),
        _repository.loadAcademicYears(),
        _repository.loadGrades(),
        _repository.loadSections(),
        _repository.loadFeeCategories(),
      ]);
      if (!mounted) return;
      final years = results[1] as List<AcademicYearModel>;
      setState(() {
        _structures = (results[0] as List)
            .cast<Map<String, dynamic>>()
            .map(normalizeFeeStructure)
            .where((row) => !isDaycareFeeStructure(row))
            .toList();
        _academicYears = years;
        _grades = results[2] as List<GradeModel>;
        _sections = results[3] as List<SectionModel>;
        _feeCategories = (results[4] as List).cast<Map<String, dynamic>>();
        _selectedAcademicYearId = _selectedAcademicYearId.isEmpty
            ? (years.firstWhereOrNull((y) => y.isCurrent)?.id ??
                  (years.isEmpty ? '' : years.first.id))
            : _selectedAcademicYearId;
        _state = const RepositoryState(
          data: Object(),
          source: RepositorySource.remote,
        );
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _state = previous == null
            ? RepositoryState.error(error: e)
            : RepositoryState(
                data: previous,
                source: RepositorySource.cache,
                isStale: true,
                error: e,
              );
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _selectedAcademicYearId.isEmpty
        ? _structures
        : _structures
              .where(
                (s) =>
                    textValue(s['academic_year_id']) == _selectedAcademicYearId,
              )
              .toList();
    if (_selectedGradeId.isNotEmpty) {
      list = list
          .where((s) => textValue(s['grade_id']) == _selectedGradeId)
          .toList();
    }
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list.where((s) {
      final haystack = '${s['class']} ${s['section']} ${s['category']}'
          .toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  /// Grades are school-wide records. Only show grades which still have a
  /// section in the selected academic year so deleted class rows cannot leak
  /// into the fee setup selector.
  List<GradeModel> get _gradeOptions {
    final gradeIds = _sections
        .where(
          (section) =>
              _selectedAcademicYearId.isEmpty ||
              section.academicYearId == _selectedAcademicYearId,
        )
        .map((section) => section.gradeId)
        .where((id) => id.isNotEmpty)
        .toSet();
    return _grades.where((grade) => gradeIds.contains(grade.id)).toList();
  }

  // Group filtered structures by category for organised display
  Map<String, List<Map<String, dynamic>>> get _groupedByCategory {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in _filtered) {
      final cat = textValue(s['category'], fallback: 'Fee');
      grouped.putIfAbsent(cat, () => []).add(s);
    }
    return grouped;
  }

  int get _eligibleAssignments => _filtered.fold(
    0,
    (sum, row) => sum + (row['eligible_student_count'] as num? ?? 0).toInt(),
  );

  int get _completedAssignments => _filtered.fold(
    0,
    (sum, row) => sum + (row['invoiced_student_count'] as num? ?? 0).toInt(),
  );

  int get _missingAssignments => _filtered.fold(
    0,
    (sum, row) => sum + (row['missing_invoice_count'] as num? ?? 0).toInt(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Fee Structures',
          style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // + button: enabled only when a class is selected
          Tooltip(
            message: _selectedGradeId.isEmpty
                ? 'Select a class first'
                : 'Create Fee Structure',
            child: IconButton(
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: _selectedGradeId.isEmpty ? Colors.white38 : Colors.white,
              ),
              onPressed: _selectedGradeId.isEmpty ? null : _openCreateForm,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SchoolDeskRepositoryStateView<Object>(
        state: _state,
        onRetry: _loadData,
        data: (_) => RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Filters section
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Structures',
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: context.appTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_academicYears.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedAcademicYearId.isEmpty
                            ? null
                            : _selectedAcademicYearId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          labelText: 'Academic Year',
                          prefixIcon: Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                          ),
                        ),
                        items: _academicYears
                            .map(
                              (y) => DropdownMenuItem(
                                value: y.id,
                                child: Text(y.yearLabel),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          final yearId = v ?? '';
                          final availableGradeIds = _sections
                              .where(
                                (section) => section.academicYearId == yearId,
                              )
                              .map((section) => section.gradeId)
                              .toSet();
                          setState(() {
                            _selectedAcademicYearId = yearId;
                            if (!availableGradeIds.contains(
                              _selectedGradeId,
                            )) {
                              _selectedGradeId = '';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Class / Grade dropdown (NEW)
                    if (_gradeOptions.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: _selectedGradeId.isEmpty
                            ? null
                            : _selectedGradeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          labelText: 'Class / Grade',
                          prefixIcon: Icon(Icons.class_rounded, size: 18),
                        ),
                        hint: const Text('Select a class to enable add'),
                        items: _gradeOptions
                            .map(
                              (g) => DropdownMenuItem(
                                value: g.id,
                                child: Text(g.gradeName),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() => _selectedGradeId = v ?? '');
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Search
              TextFormField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search fee structures...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF2563EB),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),

              const SizedBox(height: 16),

              if (_filtered.isNotEmpty) ...[
                _buildAssignmentSummary(),
                const SizedBox(height: 14),
              ],

              // Hint when no class selected
              if (_selectedGradeId.isEmpty && _gradeOptions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF2563EB),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select a class above to enable the + add button and view class-specific structures.',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            color: const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Grouped structures
              if (_filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.schema_rounded,
                          size: 48,
                          color: context.appTheme.muted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No structures found.',
                          style: GoogleFonts.ibmPlexSans(
                            color: context.appTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final entry in _groupedByCategory.entries) ...[
                  _categoryHeader(entry.key),
                  const SizedBox(height: 8),
                  for (final s in entry.value) _buildStructureCard(s),
                  const SizedBox(height: 16),
                ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Category Section Header ───────────────────────────────────────────────

  Widget _buildAssignmentSummary() {
    final isSynced = _missingAssignments == 0;
    final accent = isSynced ? const Color(0xFF15803D) : const Color(0xFFD97706);
    final surface = isSynced
        ? const Color(0xFFECFDF3)
        : const Color(0xFFFFF7ED);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withAlpha(48)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSynced ? Icons.sync_rounded : Icons.sync_problem_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSynced
                      ? 'All student fees are synced'
                      : '$_missingAssignments fee assignment${_missingAssignments == 1 ? '' : 's'} pending',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_completedAssignments of $_eligibleAssignments assignments across ${_filtered.length} structure${_filtered.length == 1 ? '' : 's'}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh assignment status',
            onPressed: _loadData,
            icon: Icon(Icons.refresh_rounded, color: accent, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _categoryHeader(String categoryName) {
    final meta = _categoryMeta(categoryName);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: meta.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(meta.icon, size: 14, color: meta.color),
        ),
        const SizedBox(width: 8),
        Text(
          categoryName,
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: meta.color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: meta.color.withOpacity(0.2))),
      ],
    );
  }

  // ── Structure Card ────────────────────────────────────────────────────────

  Widget _buildStructureCard(Map<String, dynamic> s) {
    final meta = _categoryMeta(textValue(s['category'], fallback: 'Fee'));
    final frequencyLabel = textValue(
      s['frequency'],
      fallback: 'term',
    ).replaceAll('_', ' ');
    final eligible = (s['eligible_student_count'] as num? ?? 0).toInt();
    final assigned = (s['invoiced_student_count'] as num? ?? 0).toInt();
    final missing = (s['missing_invoice_count'] as num? ?? 0).toInt();
    final isSynced = missing == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: meta.color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: meta.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(meta.icon, size: 16, color: meta.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['category'] ?? 'Fee',
                        style: GoogleFonts.ibmPlexSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: meta.color,
                        ),
                      ),
                      Text(
                        '${s['class']} — ${s['section']}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 12,
                          color: context.appTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Amount badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: meta.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    money(numValue(s['amount'])),
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: meta.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: isSynced
                    ? const Color(0xFFECFDF3)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSynced
                        ? Icons.check_circle_rounded
                        : Icons.sync_problem_rounded,
                    size: 14,
                    color: isSynced
                        ? const Color(0xFF15803D)
                        : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isSynced
                        ? '$assigned/$eligible students synced'
                        : '$missing student${missing == 1 ? '' : 's'} pending',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSynced
                          ? const Color(0xFF15803D)
                          : const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                _infoChip(
                  Icons.repeat_rounded,
                  frequencyLabel,
                  context.appTheme.muted,
                ),
                const SizedBox(width: 10),
                _infoChip(
                  Icons.calendar_today_rounded,
                  'Due day: ${s['due_day'] ?? 10}',
                  context.appTheme.muted,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Edit structure',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: meta.color,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _openEditForm(s),
                ),
                const SizedBox(width: 14),
                IconButton(
                  tooltip: 'Delete structure',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: context.appTheme.error,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _deleteStructure(s),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: color)),
      ],
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _openCreateForm() async {
    // Pre-seed the grade from the currently selected class dropdown
    final seedStructure = _selectedGradeId.isNotEmpty
        ? <String, dynamic>{
            'grade_id': _selectedGradeId,
            if (_selectedAcademicYearId.isNotEmpty)
              'academic_year_id': _selectedAcademicYearId,
          }
        : null;

    final result = await SchoolDeskNavigation.push(
      context,
      AppRoutes.principalFeeStructureForm,
      arguments: AdminFeeStructureFormArgs(
        academicYears: _academicYears,
        grades: _grades,
        sections: _sections,
        feeCategories: _feeCategories,
        ownerRole: 'principal',
        feeStructure: seedStructure,
      ),
    );
    if (!mounted || result is! AdminFeeStructureFormResult) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
    await _loadData();
  }

  Future<void> _openEditForm(Map<String, dynamic> structure) async {
    final result = await SchoolDeskNavigation.push(
      context,
      AppRoutes.principalFeeStructureForm,
      arguments: AdminFeeStructureFormArgs(
        academicYears: _academicYears,
        grades: _grades,
        sections: _sections,
        feeCategories: _feeCategories,
        ownerRole: 'principal',
        feeStructure: structure,
      ),
    );
    if (!mounted || result is! AdminFeeStructureFormResult) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
    await _loadData();
  }

  Future<void> _deleteStructure(Map<String, dynamic> s) async {
    final id = textValue(s['id']);
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete fee structure?'),
        content: const Text(
          'This will remove the fee component and clear unpaid student invoices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteFeeStructure(
        id,
        removePending: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fee structure deleted.')));
      await _loadData();
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: context.appTheme.error,
        ),
      );
    }
  }
}
