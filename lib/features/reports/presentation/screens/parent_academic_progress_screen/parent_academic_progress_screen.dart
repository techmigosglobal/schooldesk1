import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';

class ParentAcademicProgressScreen extends StatefulWidget {
  const ParentAcademicProgressScreen({super.key});

  @override
  State<ParentAcademicProgressScreen> createState() =>
      _ParentAcademicProgressScreenState();
}

class _ParentAcademicProgressScreenState
    extends State<ParentAcademicProgressScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 1;
  late TabController _tabController;
  int _activeChildIndex = 0;

  static const _headerColor = Color(0xFF1A6B4A);

  List<Map<String, dynamic>> _children = [];
  final Map<String, List<Map<String, dynamic>>> _subjectsByStudent = {};
  final Map<String, List<Map<String, dynamic>>> _reportCardsByStudent = {};
  final Map<String, List<Map<String, dynamic>>> _remarksByStudent = {};
  bool _loading = true;
  String? _error;

  String? get _activeStudentId => _children.isEmpty
      ? null
      : (_children[_activeChildIndex]['id'] ?? '').toString();

  List<Map<String, dynamic>> get _subjects =>
      _subjectsByStudent[_activeStudentId] ?? const [];

  List<Map<String, dynamic>> get _remarks =>
      _remarksByStudent[_activeStudentId] ?? const [];

  List<Map<String, dynamic>> get _reportCards =>
      _reportCardsByStudent[_activeStudentId] ?? const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final children = await BackendApiClient.instance.getMyStudents();
      final subjectData = <String, List<Map<String, dynamic>>>{};
      final reportData = <String, List<Map<String, dynamic>>>{};
      final remarkData = <String, List<Map<String, dynamic>>>{};

      for (final child in children) {
        final studentId = (child['id'] ?? '').toString();
        if (studentId.isEmpty) continue;

        final marks = await BackendApiClient.instance.getRawList(
          '/students/$studentId/marks',
        );
        subjectData[studentId] = marks.map((m) {
          final schedule = m['exam_schedule'] is Map
              ? Map<String, dynamic>.from(m['exam_schedule'] as Map)
              : const <String, dynamic>{};
          final subject = schedule['subject'] is Map
              ? Map<String, dynamic>.from(schedule['subject'] as Map)
              : const <String, dynamic>{};
          // Backend integration: marks, max marks, subject, and teacher labels
          // are shown only when returned by the academic APIs.
          final maxMarks = (schedule['max_marks'] as num?)?.toInt();
          final obtained = (m['marks_obtained'] as num?)?.toInt();
          return {
            'subject': subject['subject_name'] ?? '',
            'marks': obtained,
            'max': maxMarks,
            'grade': m['grade_label'] ?? '',
            'teacher': m['teacher_name'] ?? schedule['teacher_name'] ?? '',
            'color': AppTheme.primary,
            'exam': schedule['exam_id'] ?? '',
          };
        }).toList();

        final reportCards = await BackendApiClient.instance.getRawList(
          '/exams/report-cards',
          queryParameters: {'student_id': studentId},
        );
        reportData[studentId] = reportCards.map(_reportCardFromApi).toList();

        final diaryRows = await BackendApiClient.instance.getRawList(
          '/diary-entries',
          queryParameters: {'student_id': studentId},
        );
        remarkData[studentId] = diaryRows
            .where((d) => '${d['remarks'] ?? d['remark'] ?? ''}'.isNotEmpty)
            .map(
              (d) => {
                'teacher': d['created_by'] ?? d['teacher_name'] ?? '',
                'subject': d['subject'] ?? '',
                'remark': d['remarks'] ?? d['remark'] ?? '',
                'date': d['date'] ?? d['created_at'] ?? '',
                'positive': true,
              },
            )
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _children = children;
        _subjectsByStudent
          ..clear()
          ..addAll(subjectData);
        _reportCardsByStudent
          ..clear()
          ..addAll(reportData);
        _remarksByStudent
          ..clear()
          ..addAll(remarkData);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Academic Progress',
      subtitle: 'Review marks, report cards, and teacher remarks',
      drawer: ParentDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Marks'),
          Tab(text: 'Report Cards'),
          Tab(text: 'Remarks'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildStateMessage('Unable to load academic progress', _error!)
          : _children.isEmpty
          ? _buildStateMessage(
              'No linked students',
              'Ask the school admin to link students to this parent account.',
            )
          : Column(
              children: [
                _buildChildSelector(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMarksTab(),
                      _buildReportCardsTab(),
                      _buildRemarksTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStateMessage(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildSelector() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.child_care_rounded, size: 16, color: AppTheme.muted),
          const SizedBox(width: 8),
          Text(
            'Viewing:',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          ),
          const SizedBox(width: 8),
          ...List.generate(_children.length, (i) {
            final isActive = i == _activeChildIndex;
            return GestureDetector(
              onTap: () => setState(() => _activeChildIndex = i),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isActive ? _headerColor : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_children[i]['name'] ?? _children[i]['first_name'] ?? 'Student'}'
                      .split(' ')
                      .first,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppTheme.onSurface,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMarksTab() {
    if (_subjects.isEmpty) {
      return _buildStateMessage(
        'No marks published',
        'Marks will appear here after exams are published by the school.',
      );
    }
    final scored = _subjects.where(_hasScore).toList();
    final avg = scored.isEmpty
        ? null
        : scored
                  .map(
                    (s) =>
                        ((s['marks'] as num).toDouble() /
                            (s['max'] as num).toDouble()) *
                        100,
                  )
                  .reduce((a, b) => a + b) /
              scored.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverallCard(avg),
          const SizedBox(height: 16),
          Text(
            'Subject-wise Performance',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ..._subjects.map((s) => _subjectCard(s)),
        ],
      ),
    );
  }

  Widget _buildOverallCard(double? avg) {
    final best = _subjectExtreme(high: true);
    final needsWork = _subjectExtreme(high: false);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A6B4A), Color(0xFF2E8B57)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Average',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  avg == null ? '—' : '${avg.toStringAsFixed(1)}%',
                  style: GoogleFonts.dmSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Based on published backend marks',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              _miniStat('Best', best),
              const SizedBox(height: 8),
              _miniStat('Needs Work', needsWork),
            ],
          ),
        ],
      ),
    );
  }

  String _subjectExtreme({required bool high}) {
    if (_subjects.isEmpty) return 'Not published';
    Map<String, dynamic>? selected;
    double? selectedPct;
    for (final subject in _subjects) {
      if (!_hasScore(subject)) continue;
      final marks = (subject['marks'] as num).toDouble();
      final max = (subject['max'] as num).toDouble();
      final double pct = marks / max * 100;
      if (selectedPct == null ||
          (high ? pct > selectedPct : pct < selectedPct)) {
        selected = subject;
        selectedPct = pct;
      }
    }
    if (selected == null || selectedPct == null) return 'Not published';
    final subject = _text(selected['subject'], fallback: 'Subject');
    return '$subject ${selectedPct.toStringAsFixed(0)}%';
  }

  Widget _miniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 10, color: Colors.white60),
          ),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subjectCard(Map<String, dynamic> s) {
    final subject = _text(s['subject'], fallback: 'Subject not published');
    final teacher = _text(s['teacher']);
    final grade = _text(s['grade']);
    final hasScore = _hasScore(s);
    final pct = hasScore
        ? (s['marks'] as num).toDouble() / (s['max'] as num).toDouble()
        : 0.0;
    final marksLabel = hasScore
        ? '${(s['marks'] as num).toInt()}/${(s['max'] as num).toInt()}'
        : '—';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (s['color'] as Color).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _initials(subject),
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: s['color'] as Color,
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
                      subject,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (teacher.isNotEmpty)
                      Text(
                        'Teacher: $teacher',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppTheme.muted,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    marksLabel,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: s['color'] as Color,
                    ),
                  ),
                  if (grade.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (s['color'] as Color).withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        grade,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: s['color'] as Color,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppTheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(s['color'] as Color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCardsTab() {
    if (_reportCards.isEmpty) {
      return _buildStateMessage(
        'No report cards',
        'Published report cards will appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [..._reportCards.map((r) => _reportCardItem(r))],
    );
  }

  Map<String, dynamic> _reportCardFromApi(Map<String, dynamic> card) {
    final exam = card['exam'] is Map
        ? Map<String, dynamic>.from(card['exam'] as Map)
        : const <String, dynamic>{};
    final percent = (card['percentage'] as num?)?.toDouble();
    final rank = (card['class_rank'] as num?)?.toInt() ?? 0;
    return {
      'id': card['id'],
      'term': exam['exam_name'] ?? card['exam_id'] ?? 'Report Card',
      'percentage': percent == null ? '' : '${percent.toStringAsFixed(1)}%',
      'rank': rank <= 0 ? '-' : rank.toString(),
      'status': card['published_at'] == null ? 'Pending' : 'Published',
    };
  }

  Widget _reportCardItem(Map<String, dynamic> r) {
    final isPublished = r['status'] == 'Published';
    final percentage = _text(r['percentage']);
    final rank = _text(r['rank']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isPublished
                  ? AppTheme.successContainer
                  : AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPublished ? Icons.description_rounded : Icons.schedule_rounded,
              color: isPublished ? AppTheme.success : AppTheme.muted,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['term'],
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (percentage.isNotEmpty)
                      Text(
                        'Score: $percentage',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppTheme.muted,
                        ),
                      ),
                    if (rank.isNotEmpty && rank != '-')
                      Text(
                        'Rank: $rank',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppTheme.muted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (isPublished)
            ElevatedButton.icon(
              onPressed: () => _requestReportCard(r),
              icon: const Icon(Icons.download_rounded, size: 14),
              label: const Text('Download'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _headerColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                textStyle: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Upcoming',
                style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _requestReportCard(Map<String, dynamic> reportCard) async {
    final studentId = _activeStudentId;
    if (studentId == null || studentId.isEmpty) return;
    try {
      final export = await BackendApiClient.instance.createReportExport(
        '/exams/report-cards/exports',
        reportTitle: 'Report card ${reportCard['term'] ?? ''}'.trim(),
        format: 'pdf',
        reportType: 'report_card',
        scope: 'parent',
        parameters: {'student_id': studentId, 'term': reportCard['term']},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Report card export ${export['status'] ?? 'requested'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report card export is not available: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Widget _buildRemarksTab() {
    if (_remarks.isEmpty) {
      return _buildStateMessage(
        'No teacher remarks',
        'Teacher remarks and diary observations will appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [..._remarks.map((r) => _remarkCard(r))],
    );
  }

  Widget _remarkCard(Map<String, dynamic> r) {
    final subject = _text(r['subject'], fallback: 'Remark');
    final teacher = _text(r['teacher']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: r['positive'] == true
              ? AppTheme.success.withAlpha(80)
              : AppTheme.warning.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                r['positive'] == true
                    ? Icons.thumb_up_rounded
                    : Icons.info_rounded,
                color: r['positive'] == true
                    ? AppTheme.success
                    : AppTheme.warning,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                subject,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                r['date'],
                style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            r['remark'],
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          if (teacher.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '— $teacher',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppTheme.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasScore(Map<String, dynamic> subject) {
    final marks = subject['marks'];
    final max = subject['max'];
    return marks is num && max is num && max > 0;
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _initials(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return '--';
    return compact.substring(0, compact.length < 2 ? 1 : 2).toUpperCase();
  }
}
