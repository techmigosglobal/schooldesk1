import 'package:flutter/material.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

class TeacherPerformanceScreen extends StatefulWidget {
  const TeacherPerformanceScreen({super.key});

  @override
  State<TeacherPerformanceScreen> createState() =>
      _TeacherPerformanceScreenState();
}

class _TeacherPerformanceScreenState extends State<TeacherPerformanceScreen> {
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  List<_StudentPerformanceRow> _students = const [];

  @override
  void initState() {
    super.initState();
    _loadPerformance();
  }

  Future<void> _loadPerformance() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final reportCards = await _optionalRaw('/report-cards', {
        'section_id': RoleAccessService.teacherClassId,
      });
      final rows =
          RoleAccessService.teacherClassStudents
              .map((student) => _mapStudent(student, reportCards))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _students = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _optionalRaw(
    String path,
    Map<String, dynamic> queryParameters,
  ) async {
    try {
      return await BackendApiClient.instance.getRawList(
        path,
        queryParameters: queryParameters,
      );
    } catch (_) {
      return const [];
    }
  }

  _StudentPerformanceRow _mapStudent(
    Map<String, dynamic> student,
    List<Map<String, dynamic>> reportCards,
  ) {
    final studentId = teacherFlowText(student['id']);
    final card = reportCards.firstWhere(
      (row) => teacherFlowText(row['student_id']) == studentId,
      orElse: () => const {},
    );
    final percent = _number(
      card['percentage'] ??
          card['percent'] ??
          card['average_percent'] ??
          student['performance'],
    );
    final grade = teacherFlowText(
      card['grade'] ?? card['overall_grade'] ?? student['grade'],
      fallback: percent == 0 ? 'N/A' : _gradeFromPercent(percent),
    );
    return _StudentPerformanceRow(
      id: studentId,
      name: teacherFlowText(student['name'], fallback: 'Student'),
      roll: teacherFlowText(
        student['roll'] ?? student['admission_number'],
        fallback: '-',
      ),
      percent: percent,
      grade: grade,
      status: _statusFromPercent(percent),
    );
  }

  List<_StudentPerformanceRow> get _filteredStudents {
    if (_filter == 'all') return _students;
    return _students.where((student) => student.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final needsSupport = _students
        .where((student) => student.status == 'support')
        .length;
    final strong = _students
        .where((student) => student.status == 'strong')
        .length;
    return TeacherFlowScaffold(
      title: 'Student Performance',
      subtitle: 'Monitor learning signals and act on support needs',
      selectedIndex: 5,
      loading: _loading,
      error: _error,
      onRefresh: _loadPerformance,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Class progress board',
            classLabel: teacherCurrentClassLabel(),
            subject: RoleAccessService.teacherSubject,
            timeLabel: '${_students.length} students',
            actions: [
              TeacherFlowAction(
                label: 'Student Notes',
                icon: Icons.note_add_rounded,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.teacherStudentNotes),
              ),
              TeacherFlowAction(
                label: 'Reports',
                icon: Icons.analytics_rounded,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.teacherReports),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TeacherFlowMetricGrid(
            metrics: [
              TeacherFlowMetric(
                label: 'Students',
                value: '${_students.length}',
                icon: Icons.groups_rounded,
                color: AppTheme.primary,
                tone: const Color(0xFFEAF3FF),
              ),
              TeacherFlowMetric(
                label: 'Strong',
                value: '$strong',
                icon: Icons.trending_up_rounded,
                color: AppTheme.success,
                tone: const Color(0xFFEAFBF5),
              ),
              TeacherFlowMetric(
                label: 'Needs support',
                value: '$needsSupport',
                icon: Icons.support_rounded,
                color: AppTheme.warning,
                tone: const Color(0xFFFFF7E6),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _filterStrip(),
          const SizedBox(height: 18),
          if (_filteredStudents.isEmpty)
            const TeacherFlowCard(
              icon: Icons.insights_rounded,
              title: 'No performance rows',
              subtitle:
                  'Students and report card signals from backend appear here.',
            )
          else
            ..._filteredStudents.map(
              (student) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _performanceCard(student),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterStrip() {
    final filters = const {
      'all': 'All',
      'strong': 'Strong',
      'steady': 'Steady',
      'support': 'Support',
      'unknown': 'No Data',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in filters.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: _filter == entry.key,
                onSelected: (_) => setState(() => _filter = entry.key),
              ),
            ),
        ],
      ),
    );
  }

  Widget _performanceCard(_StudentPerformanceRow row) {
    final color = _statusColor(row.status);
    final percentLabel = row.percent <= 0
        ? 'Report pending'
        : '${row.percent.toStringAsFixed(1)}%';
    return TeacherFlowCard(
      icon: Icons.person_search_rounded,
      title: row.name,
      subtitle: 'Roll ${row.roll} · $percentLabel',
      status: teacherFlowTitleCase(row.status),
      statusColor: color,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (row.percent / 100).clamp(0, 1),
              minHeight: 8,
              backgroundColor: color.withAlpha(26),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          TeacherFlowActionWrap(
            actions: [
              TeacherFlowAction(
                label: 'Add Note',
                icon: Icons.note_add_rounded,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.teacherStudentNotes,
                  arguments: {'student_id': row.id, 'student_name': row.name},
                ),
              ),
              TeacherFlowAction(
                label: 'Grade ${row.grade}',
                icon: Icons.grade_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  String _statusFromPercent(double percent) {
    if (percent <= 0) return 'unknown';
    if (percent >= 75) return 'strong';
    if (percent >= 50) return 'steady';
    return 'support';
  }

  String _gradeFromPercent(double percent) {
    if (percent >= 90) return 'A+';
    if (percent >= 75) return 'A';
    if (percent >= 60) return 'B';
    if (percent >= 45) return 'C';
    return 'D';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'strong':
        return AppTheme.success;
      case 'steady':
        return AppTheme.primary;
      case 'support':
        return AppTheme.warning;
      default:
        return teacherFlowMuted;
    }
  }
}

class _StudentPerformanceRow {
  final String id;
  final String name;
  final String roll;
  final double percent;
  final String grade;
  final String status;

  const _StudentPerformanceRow({
    required this.id,
    required this.name,
    required this.roll,
    required this.percent,
    required this.grade,
    required this.status,
  });
}
