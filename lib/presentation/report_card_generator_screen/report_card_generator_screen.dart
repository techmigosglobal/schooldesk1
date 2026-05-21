import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../services/backend_api_client.dart';
import '../../services/backend_data_service.dart';
import '../../services/pdf_service.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

class ReportCardGeneratorScreen extends StatefulWidget {
  const ReportCardGeneratorScreen({super.key});

  @override
  State<ReportCardGeneratorScreen> createState() =>
      _ReportCardGeneratorScreenState();
}

class _ReportCardGeneratorScreenState extends State<ReportCardGeneratorScreen>
    with SingleTickerProviderStateMixin {
  int _selectedDrawerIndex = 6;
  late TabController _tabController;
  BackendDataService? _storage;
  bool _loading = true;

  String _selectedClass = 'All Classes';
  String _selectedExam = 'Term 2 Exam 2025';
  String _searchQuery = '';

  final List<String> _classes = [
    'All Classes',
    '5-A',
    '6-A',
    '6-B',
    '7-B',
    '8-C',
    '9-A',
    '10-A',
  ];
  final List<String> _exams = [
    'Term 1 Exam 2024',
    'Mid-Term 2024',
    'Term 2 Exam 2025',
    'Annual Exam 2025',
  ];

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _examResults = [];
  Map<String, double> _attendanceMap = {};

  final Set<String> _selectedStudents = {};
  String? _generatingStudentId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    _storage = await BackendDataService.getInstance();

    final students = await _storage!.getList(BackendDataService.kStudents);
    final results = await _storage!.getList(BackendDataService.kExamResults);

    // Build attendance map from students
    final Map<String, double> attMap = {};
    for (final s in students) {
      final id = s['id'] as String? ?? '';
      attMap[id] = (s['attendancePercent'] as num?)?.toDouble() ?? 85.0;
    }

    setState(() {
      _students = students;
      _examResults = results;
      _attendanceMap = attMap;
      _loading = false;
    });
  }

  String _gradeFromMarks(double marks) {
    if (marks >= 90) return 'A+';
    if (marks >= 80) return 'A';
    if (marks >= 70) return 'B+';
    if (marks >= 60) return 'B';
    if (marks >= 50) return 'C';
    if (marks >= 40) return 'D';
    return 'F';
  }

  String _resultFromPercentage(double pct) {
    return pct >= 40 ? 'PASS' : 'FAIL';
  }

  List<Map<String, dynamic>> get _filteredStudents {
    return _students.where((s) {
      final matchClass =
          _selectedClass == 'All Classes' ||
          s['classSection'] == _selectedClass;
      final matchSearch =
          _searchQuery.isEmpty ||
          (s['name'] as String? ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (s['rollNumber'] as String? ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      return matchClass && matchSearch;
    }).toList();
  }

  List<Map<String, dynamic>> _getStudentResults(String studentId) {
    return _examResults
        .where((r) => r['studentId'] == studentId && r['exam'] == _selectedExam)
        .toList();
  }

  Map<String, dynamic> _computeStudentSummary(String studentId) {
    final results = _getStudentResults(studentId);
    if (results.isEmpty) {
      return {
        'totalMarks': 0,
        'obtainedMarks': 0,
        'percentage': 0.0,
        'grade': 'N/A',
        'result': 'N/A',
      };
    }
    final total = results.fold(
      0,
      (sum, r) => sum + ((r['maxMarks'] as num?)?.toInt() ?? 100),
    );
    final obtained = results.fold(
      0,
      (sum, r) => sum + ((r['marksObtained'] as num?)?.toInt() ?? 0),
    );
    final pct = total > 0 ? (obtained / total) * 100 : 0.0;
    return {
      'totalMarks': total,
      'obtainedMarks': obtained,
      'percentage': pct,
      'grade': _gradeFromMarks(pct),
      'result': _resultFromPercentage(pct),
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 840;
    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: isTablet
          ? null
          : PrincipalDrawer(
              selectedIndex: _selectedDrawerIndex,
              onDestinationSelected: (i) =>
                  setState(() => _selectedDrawerIndex = i),
            ),
      body: isTablet ? _buildTabletLayout(context) : _buildPhoneLayout(context),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (ctx, inner) => [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppTheme.surface,
          leading: Builder(
            builder: (c) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(c).openDrawer(),
            ),
          ),
          title: Text(
            'Report Card Generator',
            style: GoogleFonts.dmSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            if (_selectedStudents.isNotEmpty)
              TextButton.icon(
                onPressed: _generateBulkReportCards,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(
                  '${_selectedStudents.length} PDF',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Students'),
              Tab(text: 'Preview'),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [_buildStudentsTab(), _buildPreviewTab()],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Row(
      children: [
        PrincipalDrawer(
          selectedIndex: _selectedDrawerIndex,
          onDestinationSelected: (i) =>
              setState(() => _selectedDrawerIndex = i),
        ),
        Expanded(
          child: NestedScrollView(
            headerSliverBuilder: (ctx, inner) => [
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: AppTheme.surface,
                title: Text(
                  'Report Card Generator',
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                actions: [
                  if (_selectedStudents.isNotEmpty)
                    TextButton.icon(
                      onPressed: _generateBulkReportCards,
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: Text(
                        'Generate ${_selectedStudents.length} PDF(s)',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Students'),
                    Tab(text: 'Preview'),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [_buildStudentsTab(), _buildPreviewTab()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentsTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: _filteredStudents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No students found',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredStudents.length,
                  itemBuilder: (_, i) =>
                      _buildStudentCard(_filteredStudents[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Search bar
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search student name or roll number...',
              hintStyle: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppTheme.muted,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.outlineVariant),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: true,
              fillColor: AppTheme.surfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  value: _selectedClass,
                  items: _classes,
                  label: 'Class',
                  onChanged: (v) => setState(() => _selectedClass = v!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  value: _selectedExam,
                  items: _exams,
                  label: 'Exam',
                  onChanged: (v) => setState(() => _selectedExam = v!),
                ),
              ),
            ],
          ),
          if (_filteredStudents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() {
                    if (_selectedStudents.length == _filteredStudents.length) {
                      _selectedStudents.clear();
                    } else {
                      _selectedStudents.addAll(
                        _filteredStudents.map((s) => s['id'] as String),
                      );
                    }
                  }),
                  icon: Icon(
                    _selectedStudents.length == _filteredStudents.length
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                    size: 16,
                  ),
                  label: Text(
                    _selectedStudents.length == _filteredStudents.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: GoogleFonts.dmSans(fontSize: 12),
                  ),
                ),
                const Spacer(),
                if (_selectedStudents.isNotEmpty)
                  Text(
                    '${_selectedStudents.length} selected',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.onSurface),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final sid = student['id'] as String;
    final summary = _computeStudentSummary(sid);
    final isSelected = _selectedStudents.contains(sid);
    final pct = (summary['percentage'] as double).toStringAsFixed(1);
    final grade = summary['grade'] as String;
    final result = summary['result'] as String;
    final attendance = _attendanceMap[sid] ?? 85.0;
    final hasResults = _getStudentResults(sid).isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          if (isSelected) {
            _selectedStudents.remove(sid);
          } else {
            _selectedStudents.add(sid);
          }
        }),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.outlineVariant,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    (student['name'] as String? ?? 'S').substring(0, 1),
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student['name'] as String? ?? '',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${student['classSection']} • Roll: ${student['rollNumber']}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _miniStat(
                          '${attendance.toStringAsFixed(0)}%',
                          'Attend.',
                          attendance >= 75 ? AppTheme.success : AppTheme.error,
                        ),
                        const SizedBox(width: 8),
                        if (hasResults) ...[
                          _miniStat(
                            '$pct%',
                            'Score',
                            _colorForPct(double.tryParse(pct) ?? 0),
                          ),
                          const SizedBox(width: 8),
                          _miniStat(grade, 'Grade', AppTheme.primary),
                        ] else
                          _miniStat('N/A', 'No Results', AppTheme.muted),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              Column(
                children: [
                  if (hasResults)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: result == 'PASS'
                            ? AppTheme.successContainer
                            : AppTheme.errorContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        result,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: result == 'PASS'
                              ? AppTheme.success
                              : AppTheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  _generatingStudentId == sid
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          onPressed: hasResults
                              ? () => _generateSingleReportCard(student)
                              : null,
                          icon: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: hasResults
                                ? AppTheme.primary
                                : AppTheme.muted,
                            size: 22,
                          ),
                          tooltip: hasResults
                              ? 'Generate Report Card'
                              : 'No results available',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(label, style: GoogleFonts.dmSans(fontSize: 9, color: color)),
        ],
      ),
    );
  }

  Color _colorForPct(double pct) {
    if (pct >= 75) return AppTheme.success;
    if (pct >= 50) return AppTheme.warning;
    return AppTheme.error;
  }

  Widget _buildPreviewTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary stats
        _buildSummaryStats(),
        const SizedBox(height: 16),
        Text(
          'Class Performance Overview',
          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        ..._students.map((s) => _buildStudentPreviewRow(s)),
      ],
    );
  }

  Widget _buildSummaryStats() {
    final studentsWithResults = _students
        .where((s) => _getStudentResults(s['id'] as String).isNotEmpty)
        .toList();
    final passCount = studentsWithResults.where((s) {
      final summary = _computeStudentSummary(s['id'] as String);
      return summary['result'] == 'PASS';
    }).length;
    final avgPct = studentsWithResults.isEmpty
        ? 0.0
        : studentsWithResults.fold(0.0, (sum, s) {
                final summary = _computeStudentSummary(s['id'] as String);
                return sum + (summary['percentage'] as double);
              }) /
              studentsWithResults.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedExam,
            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statCard(
                '${studentsWithResults.length}',
                'Students',
                Colors.white,
              ),
              const SizedBox(width: 12),
              _statCard('$passCount', 'Passed', Colors.greenAccent),
              const SizedBox(width: 12),
              _statCard(
                '${(studentsWithResults.length - passCount)}',
                'Failed',
                Colors.redAccent,
              ),
              const SizedBox(width: 12),
              _statCard(
                '${avgPct.toStringAsFixed(1)}%',
                'Avg Score',
                Colors.amberAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 10, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentPreviewRow(Map<String, dynamic> student) {
    final sid = student['id'] as String;
    final summary = _computeStudentSummary(sid);
    final hasResults = _getStudentResults(sid).isNotEmpty;
    final pct = (summary['percentage'] as double);
    final grade = summary['grade'] as String;
    final attendance = _attendanceMap[sid] ?? 85.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                (student['name'] as String? ?? 'S').substring(0, 1),
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['name'] as String? ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${student['classSection']} • ${student['rollNumber']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          if (hasResults) ...[
            SizedBox(
              width: 80,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: AppTheme.outlineVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _colorForPct(pct),
                      ),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${pct.toStringAsFixed(1)}% • $grade',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${attendance.toStringAsFixed(0)}%',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: attendance >= 75 ? AppTheme.success : AppTheme.error,
              ),
            ),
            const SizedBox(width: 8),
            _generatingStudentId == sid
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    onPressed: () => _generateSingleReportCard(student),
                    icon: const Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
          ] else
            Text(
              'No Results',
              style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
            ),
        ],
      ),
    );
  }

  Future<void> _generateSingleReportCard(Map<String, dynamic> student) async {
    final sid = student['id'] as String;
    setState(() => _generatingStudentId = sid);

    try {
      await _requestReportCardExport(student);
      final pdfBytes = await _buildReportCardPdf(student);
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(pdfBytes),
        name: 'ReportCard_${student['name']}_$_selectedExam',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report card: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingStudentId = null);
    }
  }

  Future<void> _generateBulkReportCards() async {
    if (_selectedStudents.isEmpty) return;

    final selected = _students.where((s) {
      final sid = s['id'] as String? ?? '';
      return _selectedStudents.contains(sid) &&
          _getStudentResults(sid).isNotEmpty;
    }).toList();
    if (selected.isEmpty) return;

    try {
      await BackendApiClient.instance.createReportExport(
        '/exams/report-cards/exports',
        reportTitle: 'Bulk report cards - $_selectedExam',
        format: 'pdf',
        reportType: 'report_card_bulk',
        scope: 'bulk',
        parameters: {
          'exam': _selectedExam,
          'student_ids': selected.map((s) => s['id']).toList(),
          'student_count': selected.length,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request report-card export: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    int successCount = 0;
    for (final student in selected) {
      try {
        final pdfBytes = await _buildReportCardPdf(student);
        await Printing.layoutPdf(
          onLayout: (_) async => Uint8List.fromList(pdfBytes),
          name: 'ReportCard_${student['name']}_$_selectedExam',
        );
        successCount++;
      } catch (_) {}
    }

    setState(() {
      _selectedStudents.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated $successCount report card(s) successfully'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _requestReportCardExport(Map<String, dynamic> student) {
    final sid = student['id'] as String;
    return BackendApiClient.instance.createReportExport(
      '/exams/report-cards/exports',
      reportTitle: 'Report card - ${student['name'] ?? sid}',
      format: 'pdf',
      reportType: 'report_card',
      scope: 'student',
      parameters: {
        'student_id': sid,
        'student_name': student['name'],
        'class_section': student['classSection'],
        'roll_number': student['rollNumber'],
        'exam': _selectedExam,
      },
    );
  }

  Future<List<int>> _buildReportCardPdf(Map<String, dynamic> student) async {
    final sid = student['id'] as String;
    final results = _getStudentResults(sid);
    final summary = _computeStudentSummary(sid);
    final attendance = _attendanceMap[sid] ?? 85.0;

    final subjects = results
        .map(
          (r) => {
            'subject': r['subject'] as String? ?? '',
            'maxMarks': (r['maxMarks'] as num?)?.toDouble() ?? 100.0,
            'obtainedMarks': (r['marksObtained'] as num?)?.toDouble() ?? 0.0,
            'grade': r['grade'] as String? ?? 'N/A',
            'remarks': _remarkForGrade(r['grade'] as String? ?? 'N/A'),
          },
        )
        .toList();

    final pdfService = PdfService.getInstance();
    return await pdfService.generateReportCard(
      studentName: student['name'] as String? ?? 'Student',
      className: student['classSection'] as String? ?? 'N/A',
      rollNo: student['rollNumber'] as String? ?? 'N/A',
      examName: _selectedExam,
      academicYear: '2024–25',
      subjects: subjects,
      totalMarks: (summary['totalMarks'] as int).toDouble(),
      obtainedMarks: (summary['obtainedMarks'] as int).toDouble(),
      percentage: summary['percentage'] as double,
      grade: summary['grade'] as String,
      result: summary['result'] as String,
      attendancePercent: attendance,
      parentName: student['guardianName'] as String? ?? 'Parent',
    );
  }

  String _remarkForGrade(String grade) {
    switch (grade) {
      case 'A+':
        return 'Outstanding';
      case 'A':
        return 'Excellent';
      case 'B+':
        return 'Very Good';
      case 'B':
        return 'Good';
      case 'C':
        return 'Average';
      case 'D':
        return 'Below Average';
      default:
        return 'Needs Improvement';
    }
  }
}
