/// Fee Structures — manage fee components per class/section.
library;

import 'package:schooldesk1/core/navigation/schooldesk_navigation.dart';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_widgets.dart';
import 'package:schooldesk1/modules/finance/data/api_admin_fees_repository.dart';
import 'package:schooldesk1/modules/finance/domain/admin_fees_repository.dart';

final class _FeeStructuresSnapshot {
  const _FeeStructuresSnapshot({
    required this.structures,
    required this.academicYears,
    required this.grades,
    required this.sections,
    required this.feeCategories,
  });

  final List<Map<String, dynamic>> structures;
  final List<AcademicYearModel> academicYears;
  final List<GradeModel> grades;
  final List<SectionModel> sections;
  final List<Map<String, dynamic>> feeCategories;
}

class FeeStructuresScreen extends StatefulWidget {
  final AdminFeesRepository? repository;

  const FeeStructuresScreen({super.key, this.repository});
  @override
  State<FeeStructuresScreen> createState() => _FeeStructuresScreenState();
}

class _FeeStructuresScreenState extends State<FeeStructuresScreen> {
  AdminFeesRepository get _repository =>
      widget.repository ?? ApiAdminFeesRepository.legacyDefault;

  RepositoryState<_FeeStructuresSnapshot> _repositoryState =
      const RepositoryState.loading();
  String _query = '';
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _structures = const [];
  List<AcademicYearModel> _academicYears = const [];
  List<GradeModel> _grades = const [];
  List<SectionModel> _sections = const [];
  List<Map<String, dynamic>> _feeCategories = const [];
  String _selectedAcademicYearId = '';

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
    final previous = _repositoryState;
    setState(() {
      _repositoryState = RepositoryState.loading(
        data: previous.data,
        source: previous.source,
        isStale: previous.isStale,
        isRefreshing: previous.hasData,
        lastUpdated: previous.lastUpdated,
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
      final structures = (results[0] as List)
          .cast<Map<String, dynamic>>()
          .map(normalizeFeeStructure)
          .toList();
      final grades = results[2] as List<GradeModel>;
      final sections = results[3] as List<SectionModel>;
      final feeCategories = (results[4] as List).cast<Map<String, dynamic>>();
      setState(() {
        _structures = structures;
        _academicYears = years;
        _grades = grades;
        _sections = sections;
        _feeCategories = feeCategories;
        _selectedAcademicYearId = _selectedAcademicYearId.isEmpty
            ? (years.firstWhereOrNull((y) => y.isCurrent)?.id ??
                  (years.isEmpty ? '' : years.first.id))
            : _selectedAcademicYearId;
        _repositoryState = RepositoryState(
          data: _FeeStructuresSnapshot(
            structures: List.unmodifiable(structures),
            academicYears: List.unmodifiable(years),
            grades: List.unmodifiable(grades),
            sections: List.unmodifiable(sections),
            feeCategories: List.unmodifiable(feeCategories),
          ),
          source: RepositorySource.remote,
          lastUpdated: DateTime.now().toUtc(),
        );
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _repositoryState = previous.hasData
            ? RepositoryState(
                data: previous.data,
                source: RepositorySource.cache,
                isStale: true,
                error: e,
                lastUpdated: previous.lastUpdated,
              )
            : RepositoryState.error(error: e);
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final list = _selectedAcademicYearId.isEmpty
        ? _structures
        : _structures
              .where(
                (s) =>
                    textValue(s['academic_year_id']) == _selectedAcademicYearId,
              )
              .toList();
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list.where((s) {
      final haystack = '${s['class']} ${s['section']} ${s['category']}'
          .toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Fee Structures',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFFF7FAFF),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Create Fee Structure',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _openCreateForm,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SchoolDeskRepositoryStateView<_FeeStructuresSnapshot>(
        state: _repositoryState,
        onRetry: _loadData,
        emptyTitle: 'No fee structures',
        emptyMessage: 'Create fee structures to start collecting fees.',
        errorTitle: 'Fee structures unavailable',
        data: (_) => RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
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
                    setState(() => _selectedAcademicYearId = v ?? '');
                  },
                ),
                const SizedBox(height: 12),
              ],
              FeeSearchBox(
                controller: _searchCtrl..text = _query,
                hint: 'Search structures',
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              if (_filtered.isEmpty)
                const FeeEmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No fee structures',
                  message: 'Create fee structures to start collecting fees.',
                ),
              for (final s in _filtered)
                FeeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const FeeIconBadge(
                            icon: Icons.price_change_outlined,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['category'] ?? 'Fee',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${s['class']} - ${s['section']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.appTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FeeStatusPill(
                            label: money(numValue(s['amount'])),
                            color: const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          FeeInfoTile(
                            label: 'Amount',
                            value: money(numValue(s['amount'])),
                          ),
                          const SizedBox(width: 16),
                          FeeInfoTile(
                            label: 'Frequency',
                            value: textValue(
                              s['frequency'],
                              fallback: 'term',
                            ),
                          ),
                          const SizedBox(width: 16),
                          FeeInfoTile(
                            label: 'Due Day',
                            value: '${s['due_day'] ?? 10}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                          ),
                          color: context.appTheme.error,
                          onPressed: () => _deleteStructure(s),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateForm({Map<String, dynamic>? existing}) async {
    final result = await SchoolDeskNavigation.push(
      context,
      AppRoutes.principalFeeStructureForm,
      arguments: AdminFeeStructureFormArgs(
        academicYears: _academicYears,
        grades: _grades,
        sections: _sections,
        feeCategories: _feeCategories,
        feeStructure: existing,
        ownerRole: 'principal',
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
