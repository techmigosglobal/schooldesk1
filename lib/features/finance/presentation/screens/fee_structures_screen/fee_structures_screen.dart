/// Fee Structures — manage fee components per class/section.
library;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_widgets.dart';
import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/widgets/desktop_screen_wrapper.dart';

class FeeStructuresScreen extends StatefulWidget {
  const FeeStructuresScreen({super.key});
  @override
  State<FeeStructuresScreen> createState() => _FeeStructuresScreenState();
}

class _FeeStructuresScreenState extends State<FeeStructuresScreen> {
  bool _loading = true;
  String? _error;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait<Object>([
        api.getFeeStructures(),
        api.getAcademicYears(),
        api.getGrades(),
        api.getSections(),
        api.getFeeCategories(),
      ]);
      if (!mounted) return;
      final years = results[1] as List<AcademicYearModel>;
      setState(() {
        _structures = (results[0] as List)
            .cast<Map<String, dynamic>>()
            .map(normalizeFeeStructure)
            .toList();
        _academicYears = years;
        _grades = results[2] as List<GradeModel>;
        _sections = results[3] as List<SectionModel>;
        _feeCategories = (results[4] as List).cast<Map<String, dynamic>>();
        _selectedAcademicYearId = _selectedAcademicYearId.isEmpty
            ? (years.firstWhereOrNull((y) => y.isCurrent)?.id ??
                  (years.isEmpty ? '' : years.first.id))
            : _selectedAcademicYearId;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
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


  final isDesktop = DesktopBreakpoints.isDesktopWidth(


        MediaQuery.sizeOf(context).width,


      );


      if (isDesktop) {


        return DesktopScreenWrapper(


          breadcrumbs: ['Finance', 'Structures'],


          title: 'Fee Structures',


          actions: const [],


          child: Card(


            elevation: 0,


            child: Padding(


              padding: const EdgeInsets.all(32),


              child: Center(


                child: Column(


                  mainAxisSize: MainAxisSize.min,


                  children: [


                    Icon(Icons.desktop_windows_rounded, size: 48, color: Theme.of(context).colorScheme.primary),


                    const SizedBox(height: 16),


                    Text('Fee Structures', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),


                    const SizedBox(height: 8),


                    Text('Desktop view coming soon', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5))),


                  ],


                ),


              ),


            ),


          ),


        );


      }

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? FeeEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Error',
              message: _error!,
              actionLabel: 'Retry',
              onAction: _loadData,
            )
          : RefreshIndicator(
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
                      message:
                          'Create fee structures to start collecting fees.',
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
    );
  }

  Future<void> _openCreateForm({Map<String, dynamic>? existing}) async {
    final result = await Navigator.pushNamed(
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
      await BackendApiClient.instance.deleteFeeStructure(
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
