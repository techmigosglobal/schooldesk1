import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../routes/app_routes.dart';
import '../../services/backend_api_client.dart';
import '../../services/role_access_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../widgets/teacher_navigation.dart';

class TeacherReportsScreen extends StatefulWidget {
  const TeacherReportsScreen({super.key});

  @override
  State<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends State<TeacherReportsScreen> {
  int _selectedNavIndex = 12;
  late final String _selectedClass;
  bool _loading = true;
  String? _exportingReport;

  final List<Map<String, dynamic>> _reportTypes = [
    {
      'title': 'Class Attendance Report',
      'icon': Icons.how_to_reg_rounded,
      'color': AppTheme.primary,
      'desc': 'Daily/monthly attendance summary for your class',
      'type': 'attendance',
    },
    {
      'title': 'Student Marks Report',
      'icon': Icons.bar_chart_rounded,
      'color': AppTheme.secondary,
      'desc': 'Test scores and performance trends',
      'type': 'marks',
    },
    {
      'title': 'Homework Submission Report',
      'icon': Icons.assignment_turned_in_rounded,
      'color': AppTheme.accent,
      'desc': 'Homework completion rates for your class',
      'type': 'homework',
    },
    {
      'title': 'Syllabus Progress Report',
      'icon': Icons.menu_book_rounded,
      'color': const Color(0xFF6C3483),
      'desc': 'Chapter completion status for your class',
      'type': 'syllabus',
    },
    {
      'title': 'Weak Students Report',
      'icon': Icons.warning_rounded,
      'color': AppTheme.error,
      'desc': 'Students needing academic support',
      'type': 'weak',
    },
    {
      'title': 'Discipline Report',
      'icon': Icons.report_problem_rounded,
      'color': AppTheme.warning,
      'desc': 'Incidents and disciplinary actions',
      'type': 'discipline',
    },
  ];

  Map<String, List<Map<String, dynamic>>> _attendanceSummary = {};

  @override
  void initState() {
    super.initState();
    _selectedClass = RoleAccessService.teacherClassName;
    _loadData();
  }

  Future<void> _loadData() async {
    final sessions = await BackendApiClient.instance.getAttendanceSessions(
      sectionId: RoleAccessService.teacherClassId,
    );
    final present = sessions.fold<int>(
      0,
      (sum, session) => sum + session.presentCount,
    );
    final marked = sessions.fold<int>(
      0,
      (sum, session) => sum + session.totalStudents,
    );
    final absent = marked > present ? marked - present : 0;
    setState(() {
      _attendanceSummary = {
        _selectedClass: [
          {
            'month': 'Backend',
            'present': present,
            'absent': absent,
            'late': 0,
            'total': marked,
          },
        ],
      };
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final drawer = TeacherDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Reports',
        subtitle: 'Create class reports and jump into report cards',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Reports',
      subtitle: 'Create class reports and jump into report cards',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.teacher,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        TextButton.icon(
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.reportCardGenerator),
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
          label: Text(
            'Report Cards',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildClassSelector(),
            const SizedBox(height: 20),
            Text(
              'Available Reports',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisExtent: 130,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _reportTypes.length,
              itemBuilder: (context, i) => _buildReportCard(_reportTypes[i]),
            ),
            const SizedBox(height: 20),
            _buildAttendanceSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildClassSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Class',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [_selectedClass].map((c) {
                final isSelected = _selectedClass == c;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() {}),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Class $c',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> r) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openReportPreview(r),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (r['color'] as Color).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                r['icon'] as IconData,
                color: r['color'] as Color,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              r['title'] as String,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(
                  Icons.download_rounded,
                  size: 12,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 3),
                Text(
                  'Export',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSummary() {
    final data = _attendanceSummary[_selectedClass] ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attendance Summary - Class $_selectedClass',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => _exportReport('Attendance Report'),
                child: Text(
                  'Export',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...data.map((d) => _buildMonthRow(d)),
        ],
      ),
    );
  }

  Widget _buildMonthRow(Map<String, dynamic> d) {
    final total =
        d['total'] as int? ?? (d['present'] as int) + (d['absent'] as int);
    final pct = total > 0 ? (d['present'] as int) / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              d['month'] as String,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppTheme.errorContainer,
                    color: AppTheme.success,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${d['present']} present - ${d['absent']} absent - ${d['late']} late',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openReportPreview(Map<String, dynamic> report) async {
    final format = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _TeacherReportPreviewPage(
          report: report,
          className: _selectedClass,
        ),
      ),
    );
    if (!mounted || format == null) return;
    await _exportReport('${report['title']} (${format.toUpperCase()})');
  }

  Future<void> _exportReport(String name) async {
    if (_exportingReport != null) return;
    setState(() => _exportingReport = name);
    try {
      final export = await BackendApiClient.instance.createReportExport(
        '/exams/report-cards/exports',
        reportTitle: name,
        format: name.toLowerCase().contains('csv') ? 'csv' : 'pdf',
        reportType: 'teacher_report',
        scope: 'teacher',
        parameters: {
          'class': _selectedClass,
          'section_id': RoleAccessService.teacherClassId,
          'teacher_id': RoleAccessService.teacherStaffId,
          'requested_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name export ${export['status'] ?? 'requested'} for Class $_selectedClass',
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report export failed: $error'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingReport = null);
    }
  }
}

class _TeacherReportPreviewPage extends StatelessWidget {
  final Map<String, dynamic> report;
  final String className;

  const _TeacherReportPreviewPage({
    required this.report,
    required this.className,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Preview')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (report['color'] as Color).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    report['icon'] as IconData,
                    color: report['color'] as Color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report['title'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Class $className',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              report['desc'] as String,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'csv'),
              icon: const Icon(Icons.table_chart_rounded, size: 16),
              label: const Text('Export CSV'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'pdf'),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: const Text('Export PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
