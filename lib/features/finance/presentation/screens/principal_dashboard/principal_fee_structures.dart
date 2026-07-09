import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';

class PrincipalFeeStructures extends StatefulWidget {
  const PrincipalFeeStructures({super.key});

  @override
  State<PrincipalFeeStructures> createState() => _PrincipalFeeStructuresState();
}

class _PrincipalFeeStructuresState extends State<PrincipalFeeStructures> {
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
    setState(() { _loading = true; _error = null; });
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
        _structures = (results[0] as List).cast<Map<String, dynamic>>().map(normalizeFeeStructure).toList();
        _academicYears = years;
        _grades = results[2] as List<GradeModel>;
        _sections = results[3] as List<SectionModel>;
        _feeCategories = (results[4] as List).cast<Map<String, dynamic>>();
        _selectedAcademicYearId = _selectedAcademicYearId.isEmpty
            ? (years.firstWhereOrNull((y) => y.isCurrent)?.id ?? (years.isEmpty ? '' : years.first.id))
            : _selectedAcademicYearId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final list = _selectedAcademicYearId.isEmpty
        ? _structures
        : _structures.where((s) => textValue(s['academic_year_id']) == _selectedAcademicYearId).toList();
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list.where((s) {
      final haystack = '${s['class']} ${s['section']} ${s['category']}'.toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.surface,
      appBar: AppBar(
        title: const Text('Fee Structures', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: context.appTheme.onSurface,
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Error: $_error'),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_academicYears.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          value: _selectedAcademicYearId.isEmpty ? null : _selectedAcademicYearId,
                          isExpanded: true,
                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), labelText: 'Academic Year'),
                          items: _academicYears.map((y) => DropdownMenuItem(value: y.id, child: Text(y.yearLabel))).toList(),
                          onChanged: (v) { setState(() => _selectedAcademicYearId = v ?? ''); },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search structures...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      const SizedBox(height: 16),
                      if (_filtered.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Text(
                              'No structures found.',
                              style: TextStyle(color: context.appTheme.muted),
                            ),
                          ),
                        ),
                      for (final s in _filtered)
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: context.appTheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s['category'] ?? 'Fee',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${s['class']} - ${s['section']}',
                                            style: TextStyle(fontSize: 12, color: context.appTheme.muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      money(numValue(s['amount'])),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Frequency: ${textValue(s['frequency'], fallback: 'term')}',
                                      style: TextStyle(fontSize: 12, color: context.appTheme.muted),
                                    ),
                                    Text(
                                      'Due Day: ${s['due_day'] ?? 10}',
                                      style: TextStyle(fontSize: 12, color: context.appTheme.muted),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                      color: context.appTheme.error,
                                      onPressed: () => _deleteStructure(s),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Future<void> _openCreateForm() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.principalFeeStructureForm,
      arguments: AdminFeeStructureFormArgs(
        academicYears: _academicYears,
        grades: _grades,
        sections: _sections,
        feeCategories: _feeCategories,
        ownerRole: 'principal',
      ),
    );
    if (!mounted || result is! AdminFeeStructureFormResult) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    await _loadData();
  }

  Future<void> _deleteStructure(Map<String, dynamic> s) async {
    final id = textValue(s['id']);
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete fee structure?'),
        content: const Text('This will remove the fee component and clear unpaid student invoices.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.delete_outline_rounded), label: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await BackendApiClient.instance.deleteFeeStructure(id, removePending: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fee structure deleted.')));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: context.appTheme.error));
    }
  }
}
