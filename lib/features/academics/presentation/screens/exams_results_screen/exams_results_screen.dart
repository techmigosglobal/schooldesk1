import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/backend_data_service.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:printing/printing.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class ExamsResultsScreen extends StatefulWidget {
  const ExamsResultsScreen({super.key});

  @override
  State<ExamsResultsScreen> createState() => _ExamsResultsScreenState();
}

class _ExamsResultsScreenState extends State<ExamsResultsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedDrawerIndex = 6;
  late TabController _tabController;
  String _selectedExam = 'Unit Test 1';

  final List<String> _exams = [
    'Unit Test 1',
    'Half Yearly',
    'Unit Test 2',
    'Annual Exam',
  ];

  List<Map<String, dynamic>> _examSchedule = [];
  List<Map<String, dynamic>> _results = [];
  BackendDataService? _storage;

  final List<Map<String, dynamic>> _pendingApprovals = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    _storage = await BackendDataService.getInstance();
    final examSchedule = await _storage!.getList(
      BackendDataService.kExamSchedule,
    );
    final results = await _storage!.getList(BackendDataService.kExamResults);
    setState(() {
      _examSchedule = examSchedule;
      _results = results;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Exam Records',
      subtitle: 'Review exam schedules, results, approvals, and analytics',
      drawer: PrincipalDrawer(
        selectedIndex: _selectedDrawerIndex,
        onDestinationSelected: (i) => setState(() => _selectedDrawerIndex = i),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Schedule'),
          Tab(text: 'Results'),
          Tab(text: 'Approvals'),
          Tab(text: 'Analytics'),
        ],
      ),
      body: MediaQuery.of(context).size.width >= 840
          ? _buildTabletLayout(context)
          : _buildPhoneLayout(context),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildScheduleTab(),
        _buildResultsTab(),
        _buildApprovalsTab(),
        _buildAnalyticsTab(),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return _buildPhoneLayout(context);
  }

  Widget _buildScheduleTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Exam Schedule — Term 2 2025',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Chip(label: Text('Admin managed')),
          ],
        ),
        const SizedBox(height: 12),
        ..._examSchedule.asMap().entries.map(
          (e) => _buildExamCard(e.value, e.key),
        ),
      ],
    );
  }

  Widget _buildExamCard(Map<String, dynamic> e, int index) {
    final isPending = e['status'] == 'pending_approval';
    final isRejected = e['status'] == 'rejected';
    return GestureDetector(
      onTap: () => _openExamDetail(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPending
                ? context.appTheme.warning.withAlpha(100)
                : isRejected
                ? context.appTheme.error.withAlpha(80)
                : context.appTheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.appTheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    e['date'].toString().split(' ')[0],
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appTheme.primary,
                    ),
                  ),
                  Text(
                    e['date'].toString().split(' ')[1],
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      color: context.appTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e['subject'],
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${e['class']} · ${e['time']} · ${e['duration']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: context.appTheme.muted,
                    ),
                  ),
                  Text(
                    'Venue: ${e['room']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: context.appTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (isPending)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.appTheme.warningContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Pending',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.warning,
                  ),
                ),
              )
            else if (isRejected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.appTheme.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Rejected',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.error,
                  ),
                ),
              )
            else
              Icon(
                Icons.check_circle_rounded,
                color: context.appTheme.success,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExamDetail(Map<String, dynamic> exam) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _ExamDetailPage(exam: exam)),
    );
  }

  Widget _buildResultsTab() {
    return Column(
      children: [
        Container(
          color: context.appTheme.surface,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.filter_list_rounded,
                size: 16,
                color: context.appTheme.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedExam,
                    items: _exams
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: GoogleFonts.dmSans(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedExam = v!),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildResultCard(_results[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(Map<String, dynamic> r) {
    Color gradeColor;
    switch (r['grade']) {
      case 'A+':
        gradeColor = context.appTheme.success;
        break;
      case 'A':
        gradeColor = context.appTheme.accent;
        break;
      case 'B+':
      case 'B':
        gradeColor = context.appTheme.info;
        break;
      case 'C':
        gradeColor = context.appTheme.warning;
        break;
      default:
        gradeColor = context.appTheme.error;
    }

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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: gradeColor.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#${r['rank']}',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: gradeColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['name'],
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Class ${r['class']} · Roll: ${r['roll']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: context.appTheme.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'M:${r['math']} | Sc:${r['science']} | En:${r['english']} | Hi:${r['hindi']} | SS:${r['social']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: context.appTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${r['percent']}%',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: gradeColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: gradeColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  r['grade'],
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: gradeColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _generateMarksheet(r),
                child: Text(
                  'Marksheet',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: context.appTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _generateMarksheet(Map<String, dynamic> r) async {
    try {
      final pdfService = PdfService.getInstance();
      final subjects = [
        {
          'subject': 'Mathematics',
          'maxMarks': 100,
          'obtainedMarks': r['math'] ?? 0,
          'grade': _getGrade((r['math'] ?? 0).toDouble()),
        },
        {
          'subject': 'Science',
          'maxMarks': 100,
          'obtainedMarks': r['science'] ?? 0,
          'grade': _getGrade((r['science'] ?? 0).toDouble()),
        },
        {
          'subject': 'English',
          'maxMarks': 100,
          'obtainedMarks': r['english'] ?? 0,
          'grade': _getGrade((r['english'] ?? 0).toDouble()),
        },
        {
          'subject': 'Hindi',
          'maxMarks': 100,
          'obtainedMarks': r['hindi'] ?? 0,
          'grade': _getGrade((r['hindi'] ?? 0).toDouble()),
        },
        {
          'subject': 'Social Studies',
          'maxMarks': 100,
          'obtainedMarks': r['social'] ?? 0,
          'grade': _getGrade((r['social'] ?? 0).toDouble()),
        },
      ];
      final total = subjects.fold<double>(
        0,
        (sum, s) => sum + (s['maxMarks'] as num).toDouble(),
      );
      final obtained = subjects.fold<double>(
        0,
        (sum, s) => sum + (s['obtainedMarks'] as num).toDouble(),
      );
      final pct = total > 0 ? (obtained / total * 100) : 0.0;

      final pdfBytes = await pdfService.generateMarksheet(
        studentName: r['name'] as String? ?? '',
        className: 'Class ${r['class'] ?? ''}',
        rollNo: r['roll']?.toString() ?? '',
        examName: _selectedExam,
        academicYear: '2024-25',
        subjects: subjects,
        totalMarks: total,
        obtainedMarks: obtained,
        percentage: pct,
        grade: r['grade'] as String? ?? '',
        result: pct >= 35 ? 'PASS' : 'FAIL',
      );
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name:
            'Marksheet_${r['name']?.toString().replaceAll(' ', '_') ?? 'Student'}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate marksheet.')),
        );
      }
    }
  }

  String _getGrade(double marks) {
    if (marks >= 90) return 'A+';
    if (marks >= 80) return 'A';
    if (marks >= 70) return 'B+';
    if (marks >= 60) return 'B';
    if (marks >= 50) return 'C';
    if (marks >= 35) return 'D';
    return 'F';
  }

  Widget _buildApprovalsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Pending Exam Approvals',
          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ..._pendingApprovals.map((a) => _buildApprovalCard(a)),
      ],
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.appTheme.infoContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  a['type'],
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.info,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                a['date'],
                style: GoogleFonts.dmSans(fontSize: 11, color: context.appTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            a['subject'],
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'By: ${a['submittedBy']}',
            style: GoogleFonts.dmSans(fontSize: 12, color: context.appTheme.muted),
          ),
          const SizedBox(height: 6),
          Text(
            a['details'],
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: context.appTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleApproval(a, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.appTheme.error,
                    side: BorderSide(color: context.appTheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleApproval(a, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final avgPercent =
        _results.fold<double>(
          0,
          (s, r) => s + (r['percent'] as num).toDouble(),
        ) /
        (_results.isEmpty ? 1 : _results.length);
    final toppers = _results.where((r) => r['grade'] == 'A+').length;
    final weak = _results.where((r) => (r['percent'] as num) < 50).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [context.appTheme.primary, context.appTheme.primary.withAlpha(200)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.appTheme.surface.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Card Records',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Admin-generated report cards appear in the Results tab.',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Class Average',
                '${avgPercent.toStringAsFixed(1)}%',
                Icons.bar_chart_rounded,
                context.appTheme.primary,
                context.appTheme.primaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Toppers (A+)',
                '$toppers students',
                Icons.emoji_events_rounded,
                context.appTheme.secondary,
                context.appTheme.secondaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Pass Rate',
                '${_results.isEmpty ? 0 : ((_results.length - weak) / _results.length * 100).toStringAsFixed(0)}%',
                Icons.check_circle_outline_rounded,
                context.appTheme.success,
                context.appTheme.successContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Need Support',
                '$weak students',
                Icons.support_agent_outlined,
                context.appTheme.error,
                context.appTheme.errorContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Grade Distribution',
          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildGradeBar(
          'A+',
          _results.where((r) => r['grade'] == 'A+').length,
          _results.length,
          context.appTheme.success,
        ),
        _buildGradeBar(
          'A',
          _results.where((r) => r['grade'] == 'A').length,
          _results.length,
          context.appTheme.accent,
        ),
        _buildGradeBar(
          'B+/B',
          _results.where((r) => r['grade'] == 'B+' || r['grade'] == 'B').length,
          _results.length,
          context.appTheme.info,
        ),
        _buildGradeBar(
          'C',
          _results.where((r) => r['grade'] == 'C').length,
          _results.length,
          context.appTheme.warning,
        ),
        _buildGradeBar(
          'D/F',
          _results.where((r) => r['grade'] == 'D' || r['grade'] == 'F').length,
          _results.length,
          context.appTheme.error,
        ),
        const SizedBox(height: 20),
        Text(
          'Students Needing Support',
          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ..._results
            .where((r) => (r['percent'] as num) < 60)
            .take(5)
            .map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildWeakAreaCard(
                  '${r['name'] ?? 'Student'}',
                  1,
                  'Overall score ${r['percent']}%',
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.dmSans(fontSize: 11, color: context.appTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeBar(String grade, int count, int total, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              grade,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? count / total : 0,
                minHeight: 10,
                backgroundColor: context.appTheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: GoogleFonts.dmSans(fontSize: 12, color: context.appTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildWeakAreaCard(String subject, int count, String note) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appTheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appTheme.error.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.trending_down_rounded,
            size: 18,
            color: context.appTheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.error,
                  ),
                ),
                Text(
                  '$count record${count == 1 ? '' : 's'} · $note',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: context.appTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleApproval(Map<String, dynamic> a, bool approved) {
    setState(() => _pendingApprovals.remove(a));
    // Also update exam schedule status
    final examIdx = _examSchedule.indexWhere(
      (e) => e['subject'].toString().contains(
        a['subject'].toString().split(' ').first,
      ),
    );
    if (examIdx >= 0) {
      _examSchedule[examIdx]['status'] = approved ? 'scheduled' : 'rejected';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approved
              ? '${a['subject']} approved successfully'
              : '${a['subject']} rejected',
        ),
        backgroundColor: approved ? context.appTheme.success : context.appTheme.error,
      ),
    );
  }
}

class _ExamDetailPage extends StatefulWidget {
  final Map<String, dynamic> exam;

  const _ExamDetailPage({required this.exam});

  @override
  State<_ExamDetailPage> createState() => _ExamDetailPageState();
}

class _ExamDetailPageState extends State<_ExamDetailPage> {
  String? _blockingMessage;
  bool _submittingAdvice = false;

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    return Scaffold(
      appBar: AppBar(title: const Text('Exam Details')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${exam['subject'] ?? ''}',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${exam['class'] ?? ''} · ${exam['duration'] ?? ''}',
              style: GoogleFonts.dmSans(fontSize: 13, color: context.appTheme.muted),
            ),
            const SizedBox(height: 20),
            _ExamDetailRow(label: 'Date', value: '${exam['date'] ?? ''}'),
            _ExamDetailRow(label: 'Time', value: '${exam['time'] ?? ''}'),
            _ExamDetailRow(label: 'Venue', value: '${exam['room'] ?? ''}'),
            if (_blockingMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.appTheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _blockingMessage!,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: context.appTheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submittingAdvice ? null : _raiseAdvice,
              icon: _submittingAdvice
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.report_problem_outlined),
              label: Text(_submittingAdvice ? 'Submitting' : 'Raise Advice'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _raiseAdvice() async {
    setState(() {
      _submittingAdvice = true;
      _blockingMessage = null;
    });
    try {
      final exam = widget.exam;
      await BackendApiClient.instance.createRaw('/principal/exam-advice', {
        'exam_schedule_id': exam['id'] ?? '',
        'subject': exam['subject'] ?? '',
        'class': exam['class'] ?? '',
        'message':
            'Principal review requested for ${exam['subject'] ?? 'exam schedule'}.',
        'status': 'open',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exam advice submitted for follow-up.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _blockingMessage = 'Failed to submit exam advice: $e');
    } finally {
      if (mounted) setState(() => _submittingAdvice = false);
    }
  }
}

class _ExamDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _ExamDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appTheme.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not available' : value,
              style: GoogleFonts.dmSans(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
