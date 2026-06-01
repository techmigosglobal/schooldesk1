import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import 'package:schooldesk1/core/services/backend_data_service.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

class IdCardGenerationScreen extends StatefulWidget {
  const IdCardGenerationScreen({super.key});

  @override
  State<IdCardGenerationScreen> createState() => _IdCardGenerationScreenState();
}

class _IdCardGenerationScreenState extends State<IdCardGenerationScreen> {
  BackendDataService? _storage;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedClass = 'All';
  bool _loading = true;
  final Set<String> _selectedIds = {};
  bool _generating = false;

  final List<String> _classes = [
    'All',
    '1A',
    '1B',
    '2A',
    '2B',
    '3A',
    '3B',
    '4A',
    '4B',
    '5A',
    '5B',
    '6A',
    '6B',
    '7A',
    '7B',
    '8A',
    '8B',
    '9A',
    '9B',
    '10A',
    '10B',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _storage = await BackendDataService.getInstance();
    _students =
        await _storage?.getList(BackendDataService.kAdminStudents) ?? [];
    _filteredStudents = List.from(_students);
    if (mounted) setState(() => _loading = false);
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
        academicYear: '2024-25',
      );
      if (mounted) {
        setState(() => _generating = false);
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name:
              'ID_Card_${student['name']?.toString().replaceAll(' ', '_') ?? 'Student'}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to generate ID card. Please try again.',
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _generateBulkIdCards() async {
    if (_selectedIds.isEmpty) return;
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
          academicYear: '2024-25',
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
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF151C26) : AppTheme.background;
    final surfaceColor = isDark ? const Color(0xFF1E2530) : AppTheme.surface;
    final onSurfaceColor = isDark
        ? const Color(0xFFE8EDF2)
        : AppTheme.onSurface;
    final mutedColor = isDark ? const Color(0xFF90A4AE) : AppTheme.muted;
    final outlineColor = isDark
        ? const Color(0xFF2D3748)
        : AppTheme.outlineVariant;
    final surfaceVariantColor = isDark
        ? const Color(0xFF252D3A)
        : AppTheme.surfaceVariant;

    return SchoolDeskModuleScaffold(
      title: 'ID Cards',
      subtitle: 'Generate and print student ID cards',
      drawer: AdminDrawer(selectedIndex: 12, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
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
      body: Container(
        color: bgColor,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
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
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 6),
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
                                        ? AppTheme.primary
                                        : surfaceVariantColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    cls,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : mutedColor,
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
                        : AppTheme.primaryContainer,
                    child: Row(
                      children: [
                        Text(
                          '${_filteredStudents.length} students',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedIds.isNotEmpty)
                          Text(
                            '${_selectedIds.length} selected',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
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
                                color: AppTheme.error,
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
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
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
        color: isSelected ? AppTheme.primaryContainer : surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? AppTheme.primary : outlineColor),
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
              color: isSelected ? AppTheme.primary : AppTheme.primaryContainer,
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
                        color: AppTheme.primary,
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
                icon: const Icon(Icons.badge_rounded, color: AppTheme.primary),
                tooltip: 'Generate ID Card',
                onPressed: () => _generateIdCard(student),
              ),
      ),
    );
  }
}
