import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/modules/documents/data/api_id_card_repository.dart';
import 'package:schooldesk1/modules/documents/domain/id_card_repository.dart';

final class _IdCardSnapshot {
  const _IdCardSnapshot({
    required this.students,
    required this.academicYear,
    required this.school,
  });

  final List<Map<String, dynamic>> students;
  final String academicYear;
  final Map<String, dynamic> school;
}

class IdCardGenerationScreen extends StatefulWidget {
  const IdCardGenerationScreen({super.key, this.repository});

  final IdCardRepository? repository;

  @override
  State<IdCardGenerationScreen> createState() => _IdCardGenerationScreenState();
}

class _IdCardGenerationScreenState extends State<IdCardGenerationScreen> {
  late final IdCardRepository _repository =
      widget.repository ?? ApiIdCardRepository.legacyDefault;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedClass = 'All';
  RepositoryState<_IdCardSnapshot> _repositoryState =
      const RepositoryState.loading();
  final Set<String> _selectedIds = {};
  bool _generating = false;

  String _academicYear = '';
  Map<String, dynamic> _school = const {};

  List<String> get _classes {
    final classes =
        _students
            .map((student) => '${student['className'] ?? ''}'.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...classes];
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
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
      final result = await _repository.load();
      if (result.isFailure) {
        throw StateError(
          result.failureOrNull?.message ?? 'ID card data unavailable',
        );
      }
      final data = result.dataOrNull!;
      _students = data.students;
      _academicYear = data.academicYear;
      _school = data.school;
      _filteredStudents = List.from(_students);
      if (mounted) {
        setState(() {
          _repositoryState = RepositoryState(
            data: _IdCardSnapshot(
              students: List.unmodifiable(_students),
              academicYear: _academicYear,
              school: Map.unmodifiable(_school),
            ),
            source: RepositorySource.remote,
            phase: _students.isEmpty
                ? RepositoryPhase.empty
                : RepositoryPhase.ready,
            lastUpdated: DateTime.now().toUtc(),
          );
        });
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _repositoryState = previous.hasData
            ? RepositoryState(
                data: previous.data,
                source: RepositorySource.cache,
                isStale: true,
                error: error,
                lastUpdated: previous.lastUpdated,
              )
            : RepositoryState.error(error: error);
      });
    }
  }

  void _filterStudents() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredStudents = _students.where((s) {
        final matchesSearch =
            q.isEmpty ||
            (s['name'] as String? ?? '').toLowerCase().contains(q) ||
            (s['admissionNo'] as String? ?? '').toLowerCase().contains(q) ||
            (s['rollNo'] as String? ?? '').toLowerCase().contains(q);
        final matchesClass =
            _selectedClass == 'All' ||
            (s['className'] as String? ?? '') == _selectedClass;
        return matchesSearch && matchesClass;
      }).toList();
    });
  }

  Future<void> _generateIdCard(Map<String, dynamic> student) async {
    if (_academicYear.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active academic year is unavailable.')),
      );
      return;
    }
    setState(() => _generating = true);
    try {
      final pdfService = PdfService.getInstance();
      final pdfBytes = await pdfService.generateIdCard(
        studentName: student['name'] as String? ?? '',
        className: student['className'] as String? ?? '',
        rollNo: student['rollNo'] as String? ?? '',
        admissionNo: student['admissionNo'] as String? ?? '',
        parentName: student['parentName'] as String? ?? '',
        contactNo: student['contact'] as String? ?? '',
        bloodGroup: student['bloodGroup'] as String? ?? '',
        academicYear: _academicYear,
        schoolName: _schoolText('name'),
        schoolAddress: _schoolText('address'),
        schoolContact: _schoolText('phone'),
      );
      if (mounted) {
        setState(() => _generating = false);
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name:
              'ID_Card_${student['name']?.toString().replaceAll(' ', '_') ?? 'Student'}',
        );
      }
    } on Object {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to generate ID card. Please try again.',
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: context.appTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _generateBulkIdCards() async {
    if (_selectedIds.isEmpty) return;
    if (_academicYear.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active academic year is unavailable.')),
      );
      return;
    }
    setState(() => _generating = true);
    try {
      final selected = _students
          .where((s) => _selectedIds.contains(s['id']))
          .toList();
      final pdfService = PdfService.getInstance();
      for (final student in selected) {
        final pdfBytes = await pdfService.generateIdCard(
          studentName: student['name'] as String? ?? '',
          className: student['className'] as String? ?? '',
          rollNo: student['rollNo'] as String? ?? '',
          admissionNo: student['admissionNo'] as String? ?? '',
          parentName: student['parentName'] as String? ?? '',
          contactNo: student['contact'] as String? ?? '',
          bloodGroup: student['bloodGroup'] as String? ?? '',
          academicYear: _academicYear,
          schoolName: _schoolText('name'),
          schoolAddress: _schoolText('address'),
          schoolContact: _schoolText('phone'),
        );
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name:
              'ID_Card_${student['name']?.toString().replaceAll(' ', '_') ?? 'Student'}',
        );
      }
      if (mounted) {
        setState(() {
          _generating = false;
          _selectedIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${selected.length} ID cards generated!',
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: context.appTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Object {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  String _schoolText(String key) {
    final fallbackKey = key == 'name'
        ? 'school_name'
        : key == 'phone'
        ? 'contact'
        : 'school_address';
    final value = _school[key] ?? _school[fallbackKey];
    return value?.toString().trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF151C26)
        : context.appTheme.background;
    final surfaceColor = isDark
        ? const Color(0xFF1E2530)
        : context.appTheme.surface;
    final onSurfaceColor = isDark
        ? const Color(0xFFE8EDF2)
        : context.appTheme.onSurface;
    final mutedColor = isDark
        ? const Color(0xFF90A4AE)
        : context.appTheme.muted;
    final outlineColor = isDark
        ? const Color(0xFF2D3748)
        : context.appTheme.outlineVariant;
    final surfaceVariantColor = isDark
        ? const Color(0xFF252D3A)
        : context.appTheme.surfaceVariant;

    return SchoolDeskModuleScaffold(
      title: 'ID Cards',
      subtitle: 'Generate and print student ID cards',
      drawer: PrincipalDrawer(
        selectedIndex: PrincipalNav.dashboard,
        onDestinationSelected: (_) {},
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        if (_selectedIds.isNotEmpty)
          TextButton.icon(
            onPressed: _generating ? null : _generateBulkIdCards,
            icon: const Icon(Icons.print_rounded, size: 18),
            label: Text(
              'Print ${_selectedIds.length}',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
          ),
      ],
      body: SchoolDeskRepositoryStateView<_IdCardSnapshot>(
        state: _repositoryState,
        onRetry: _init,
        emptyTitle: 'No students found',
        emptyMessage: 'No students exist for this principal scope.',
        errorTitle: 'ID card data unavailable',
        data: (_) => Container(
          color: bgColor,
          child: Column(
            children: [
              Container(
                color: surfaceColor,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => _filterStudents(),
                      style: GoogleFonts.dmSans(color: onSurfaceColor),
                      decoration: InputDecoration(
                        hintText: 'Search by name, admission no...',
                        hintStyle: GoogleFonts.dmSans(color: mutedColor),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: mutedColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: outlineColor),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _classes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final cls = _classes[i];
                          final isSelected = _selectedClass == cls;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedClass = cls);
                              _filterStudents();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.appTheme.primary
                                    : surfaceVariantColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                cls,
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.white : mutedColor,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: isDark
                    ? const Color(0xFF1A3A5C)
                    : context.appTheme.primaryContainer,
                child: Row(
                  children: [
                    Text(
                      '${_filteredStudents.length} students',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.appTheme.primary,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedIds.isNotEmpty)
                      Text(
                        '${_selectedIds.length} selected',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.appTheme.primary,
                        ),
                      ),
                    if (_selectedIds.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _selectedIds.clear()),
                        child: Text(
                          'Clear',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: context.appTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _filteredStudents.isEmpty
                    ? Center(
                        child: Text(
                          'No students found',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: mutedColor,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredStudents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _buildStudentCard(
                          _filteredStudents[i],
                          surfaceColor,
                          onSurfaceColor,
                          mutedColor,
                          outlineColor,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(
    Map<String, dynamic> student,
    Color surfaceColor,
    Color onSurfaceColor,
    Color mutedColor,
    Color outlineColor,
  ) {
    final id = student['id'] as String? ?? '';
    final isSelected = _selectedIds.contains(id);

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? context.appTheme.primaryContainer : surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? context.appTheme.primary : outlineColor,
        ),
      ),
      child: ListTile(
        leading: GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(id);
              } else {
                _selectedIds.add(id);
              }
            });
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? context.appTheme.primary
                  : context.appTheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : Center(
                    child: Text(
                      (student['name'] as String? ?? 'S')[0].toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.appTheme.primary,
                      ),
                    ),
                  ),
          ),
        ),
        title: Text(
          student['name'] as String? ?? '',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: onSurfaceColor,
          ),
        ),
        subtitle: Text(
          'Class ${student['className'] ?? ''} • Roll ${student['rollNo'] ?? ''} • ${student['admissionNo'] ?? ''}',
          style: GoogleFonts.dmSans(fontSize: 12, color: mutedColor),
        ),
        trailing: _generating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: Icon(
                  Icons.badge_rounded,
                  color: context.appTheme.primary,
                ),
                tooltip: 'Generate ID Card',
                onPressed: () => _generateIdCard(student),
              ),
      ),
    );
  }
}
