import 'package:flutter/material.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

class TeacherReportsScreen extends StatefulWidget {
  const TeacherReportsScreen({super.key});

  @override
  State<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends State<TeacherReportsScreen> {
  bool _loading = true;
  String? _error;
  String? _exportingReport;
  List<AttendanceSessionModel> _sessions = const [];
  List<Map<String, dynamic>> _homework = const [];
  List<Map<String, dynamic>> _notes = const [];
  List<Map<String, dynamic>> _incidents = const [];
  List<Map<String, dynamic>> _exports = const [];

  static const _reportTypes = [
    _TeacherReportType(
      title: 'Class Attendance Report',
      type: 'attendance',
      icon: Icons.how_to_reg_rounded,
      color: AppTheme.primary,
      description: 'Daily and period-wise attendance evidence',
    ),
    _TeacherReportType(
      title: 'Homework Submission Report',
      type: 'homework',
      icon: Icons.assignment_turned_in_rounded,
      color: teacherFlowAccent,
      description: 'Assigned work and submission follow-up',
    ),
    _TeacherReportType(
      title: 'Student Support Report',
      type: 'support',
      icon: Icons.support_rounded,
      color: AppTheme.warning,
      description: 'Notes, conduct items, and support actions',
    ),
    _TeacherReportType(
      title: 'Report Cards Export',
      type: 'report_cards',
      icon: Icons.picture_as_pdf_rounded,
      color: AppTheme.secondary,
      description: 'Jump into generated academic report cards',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final api = BackendApiClient.instance;
      final results = await Future.wait<dynamic>([
        api.getAttendanceSessions(sectionId: RoleAccessService.teacherClassId),
        api.getHomework(
          sectionId: RoleAccessService.teacherClassId,
          teacherId: RoleAccessService.teacherStaffId,
        ),
        _optionalRaw('/student-notes'),
        _optionalRaw('/discipline-incidents'),
        _optionalRaw('/exams/report-cards/exports'),
      ]);
      if (!mounted) return;
      setState(() {
        _sessions = (results[0] as List)
            .whereType<AttendanceSessionModel>()
            .toList();
        _homework = (results[1] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _notes = (results[2] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .where(_belongsToTeacher)
            .toList();
        _incidents = (results[3] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .where(_belongsToTeacher)
            .toList();
        _exports = (results[4] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
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

  Future<List<Map<String, dynamic>>> _optionalRaw(String path) async {
    try {
      return await BackendApiClient.instance.getRawList(path);
    } catch (_) {
      return const [];
    }
  }

  bool _belongsToTeacher(Map<String, dynamic> row) {
    final teacherId = teacherFlowText(row['teacher_id'] ?? row['staff_id']);
    final studentId = teacherFlowText(row['student_id']);
    if (teacherId.isNotEmpty && teacherId == RoleAccessService.teacherStaffId) {
      return true;
    }
    if (studentId.isEmpty) return false;
    return RoleAccessService.teacherClassStudents.any(
      (student) => teacherFlowText(student['id']) == studentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final marked = _sessions.fold<int>(
      0,
      (total, session) => total + session.totalStudents,
    );
    final present = _sessions.fold<int>(
      0,
      (total, session) => total + session.presentCount,
    );
    final attendancePercent = marked == 0 ? 0 : (present / marked) * 100;
    return TeacherFlowScaffold(
      title: 'Reports',
      subtitle: 'Class evidence, exports, and report card actions',
      selectedIndex: 12,
      loading: _loading,
      error: _error,
      onRefresh: _loadReports,
      actions: [
        IconButton(
          tooltip: 'Report Cards',
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.reportCardGenerator),
          icon: const Icon(Icons.picture_as_pdf_rounded),
        ),
      ],
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Class reporting desk',
            classLabel: teacherCurrentClassLabel(),
            subject: RoleAccessService.teacherSubject,
            timeLabel: '${_exports.length} export requests',
          ),
          const SizedBox(height: 18),
          TeacherFlowMetricGrid(
            metrics: [
              TeacherFlowMetric(
                label: 'Attendance',
                value: '${attendancePercent.toStringAsFixed(0)}%',
                icon: Icons.how_to_reg_rounded,
                color: AppTheme.primary,
                tone: const Color(0xFFEAF3FF),
              ),
              TeacherFlowMetric(
                label: 'Homework',
                value: '${_homework.length}',
                icon: Icons.assignment_rounded,
                color: teacherFlowAccent,
                tone: const Color(0xFFEAFBF5),
              ),
              TeacherFlowMetric(
                label: 'Notes',
                value: '${_notes.length}',
                icon: Icons.sticky_note_2_rounded,
                color: AppTheme.warning,
                tone: const Color(0xFFFFF7E6),
              ),
              TeacherFlowMetric(
                label: 'Conduct',
                value: '${_incidents.length}',
                icon: Icons.health_and_safety_rounded,
                color: AppTheme.error,
                tone: const Color(0xFFFFF0F0),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const TeacherFlowSectionHeader(title: 'Create Report Export'),
          const SizedBox(height: 10),
          ..._reportTypes.map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _reportCard(report),
            ),
          ),
          const SizedBox(height: 8),
          const TeacherFlowSectionHeader(title: 'Recent Export Requests'),
          const SizedBox(height: 10),
          if (_exports.isEmpty)
            const TeacherFlowCard(
              icon: Icons.cloud_download_outlined,
              title: 'No export requests',
              subtitle: 'Generated teacher report exports will appear here.',
            )
          else
            ..._exports
                .take(8)
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TeacherFlowCard(
                      icon: Icons.cloud_done_rounded,
                      title: teacherFlowText(
                        row['report_title'] ?? row['report'],
                        fallback: 'Report export',
                      ),
                      subtitle: teacherFlowText(
                        row['created_at'],
                        fallback: 'Requested from teacher reports',
                      ),
                      status: teacherFlowTitleCase(
                        teacherFlowText(row['status'], fallback: 'requested'),
                      ),
                      statusColor: teacherFlowAccent,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _reportCard(_TeacherReportType report) {
    final exporting = _exportingReport == report.title;
    return TeacherFlowCard(
      icon: report.icon,
      title: report.title,
      subtitle: report.description,
      status: exporting ? 'Exporting' : 'Ready',
      statusColor: exporting ? AppTheme.warning : report.color,
      body: TeacherFlowActionWrap(
        actions: [
          TeacherFlowAction(
            label: 'PDF',
            icon: Icons.picture_as_pdf_rounded,
            filled: true,
            onTap: exporting ? null : () => _exportReport(report, 'pdf'),
          ),
          TeacherFlowAction(
            label: 'CSV',
            icon: Icons.table_chart_rounded,
            onTap: exporting ? null : () => _exportReport(report, 'csv'),
          ),
          if (report.type == 'report_cards')
            TeacherFlowAction(
              label: 'Open Cards',
              icon: Icons.open_in_new_rounded,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.reportCardGenerator),
            ),
        ],
      ),
    );
  }

  Future<void> _exportReport(_TeacherReportType report, String format) async {
    if (_exportingReport != null) return;
    setState(() => _exportingReport = report.title);
    try {
      final export = await BackendApiClient.instance.createReportExport(
        '/exams/report-cards/exports',
        reportTitle: '${report.title} (${format.toUpperCase()})',
        format: format,
        reportType: 'teacher_${report.type}',
        scope: 'teacher',
        parameters: {
          'class': RoleAccessService.teacherClassName,
          'section_id': RoleAccessService.teacherClassId,
          'teacher_id': RoleAccessService.teacherStaffId,
          'requested_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${report.title} export ${export['status'] ?? 'requested'}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadReports();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report export failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingReport = null);
    }
  }
}

class _TeacherReportType {
  final String title;
  final String type;
  final IconData icon;
  final Color color;
  final String description;

  const _TeacherReportType({
    required this.title,
    required this.type,
    required this.icon,
    required this.color,
    required this.description,
  });
}
