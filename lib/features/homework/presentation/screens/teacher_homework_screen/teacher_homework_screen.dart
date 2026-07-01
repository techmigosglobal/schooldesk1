import 'package:flutter/material.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/homework/homework.dart';

class TeacherHomeworkScreen extends StatefulWidget {
  const TeacherHomeworkScreen({super.key});

  @override
  State<TeacherHomeworkScreen> createState() => _TeacherHomeworkScreenState();
}

class _TeacherHomeworkScreenState extends State<TeacherHomeworkScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _homework = const [];
  Map<String, int> _submissionCounts = const {};
  bool _skippedToday = false;
  String _reminderStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final staffId = RoleAccessService.teacherStaffId;
      final rows = await BackendApiClient.instance.getHomework(
        teacherId: staffId.isEmpty ? null : staffId,
      );
      final reminder = await _loadReminderStatus();
      final counts = <String, int>{};
      for (final row in rows.take(12)) {
        final id = _homeworkId(row);
        if (id.isEmpty) continue;
        final submissions = await BackendApiClient.instance
            .getHomeworkSubmissions(id);
        counts[id] = teacherFlowList(
          submissions['submissions'] ?? submissions['data'],
        ).length;
      }
      if (!mounted) return;
      setState(() {
        _homework = rows;
        _submissionCounts = counts;
        _reminderStatus = teacherFlowText(
          reminder['status'],
          fallback: _isHomeworkSubmittedTodayFromRows(rows)
              ? 'assigned'
              : 'pending',
        ).toLowerCase();
        _skippedToday = _reminderStatus == 'skipped';
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

  Future<Map<String, dynamic>> _loadReminderStatus() async {
    try {
      return await BackendApiClient.instance.getTodayHomeworkReminderStatus(
        sectionId: RoleAccessService.teacherClassId,
      );
    } catch (_) {
      return const {};
    }
  }

  Future<void> _skipToday() async {
    try {
      final reminder = await BackendApiClient.instance
          .skipTodayHomeworkReminder(
            sectionId: RoleAccessService.teacherClassId,
            reason: 'Teacher skipped homework assignment for today',
          );
      if (!mounted) return;
      setState(() {
        _reminderStatus = teacherFlowText(
          reminder['status'],
          fallback: 'skipped',
        ).toLowerCase();
        _skippedToday = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Homework reminder skipped for today')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to skip homework reminder: $error')),
      );
    }
  }

  Future<void> _openForm({Map<String, dynamic>? homework}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.teacherHomeworkForm,
      arguments: TeacherHomeworkFormArgs(
        teacherStaffId: RoleAccessService.teacherStaffId,
        defaultClassName: RoleAccessService.teacherClassName,
        defaultSubject: RoleAccessService.teacherSubject,
        assignedClasses: RoleAccessService.teacherAssignedClasses,
        students: RoleAccessService.teacherClassStudents,
        homework: homework,
      ),
    );
    if (result != null) await _loadHomework(forceRefresh: true);
  }

  Future<void> _deleteHomework(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Homework'),
        content: Text(
          'Are you sure you want to delete "${teacherFlowText(row['title'], fallback: 'Homework')}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: context.appTheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final id = _homeworkId(row);
      if (id.isEmpty) {
        throw Exception('Homework record is missing its server id.');
      }
      await BackendApiClient.instance.deleteHomework(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Homework deleted successfully')),
      );
      await _loadHomework(forceRefresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScaffold(
      title: 'Homework / Assignments',
      subtitle: 'Assignments, homework sharing, and submission review',
      selectedIndex: TeacherNav.diary,
      loading: _loading,
      error: _error,
      onRefresh: _loadHomework,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Assignment workspace',
            classLabel: RoleAccessService.teacherClassName,
            subject: RoleAccessService.teacherSubject,
            timeLabel: 'Create, edit, and review homework',
            actions: [
              TeacherFlowAction(
                label: 'Assign Homework',
                icon: Icons.add_task_rounded,
                filled: true,
                onTap: () => _openForm(),
              ),
              TeacherFlowAction(
                label: 'Class Diary',
                icon: Icons.menu_book_rounded,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.teacherDiary),
              ),
            ],
          ),
          if (!_loading && !_isHomeworkSubmittedToday() && !_skippedToday)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: TeacherFlowCard(
                icon: Icons.notification_important_rounded,
                title: 'Homework Pending',
                subtitle: 'You have not assigned homework for today.',
                status: 'Action required',
                statusColor: Colors.orange,
                body: TeacherFlowActionWrap(
                  actions: [
                    TeacherFlowAction(
                      label: 'Assign Now',
                      icon: Icons.add_task_rounded,
                      filled: true,
                      onTap: () => _openForm(),
                    ),
                    TeacherFlowAction(
                      label: 'Skip for Today',
                      icon: Icons.close_rounded,
                      onTap: _skipToday,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          TeacherFlowMetricGrid(
            metrics: [
              TeacherFlowMetric(
                label: 'Homework Logs',
                value: '${_homework.length}',
                icon: Icons.assignment_rounded,
                color: teacherFlowAccent,
                tone: const Color(0xFFE3FAF5),
              ),
              TeacherFlowMetric(
                label: 'Submissions',
                value:
                    '${_submissionCounts.values.fold<int>(0, (a, b) => a + b)}',
                icon: Icons.upload_file_rounded,
                color: Colors.indigo,
                tone: const Color(0xFFEAF0FF),
              ),
              TeacherFlowMetric(
                label: 'Due Soon',
                value: '${_homework.where(_isDueSoon).length}',
                icon: Icons.timer_rounded,
                color: Colors.orange,
                tone: const Color(0xFFFFF4E5),
              ),
              TeacherFlowMetric(
                label: 'Diary',
                value: 'Open',
                icon: Icons.menu_book_rounded,
                color: Colors.green,
                tone: const Color(0xFFEAFBF0),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TeacherFlowSectionHeader(title: 'Homework Log'),
          const SizedBox(height: 10),
          if (_homework.isEmpty)
            const TeacherFlowCard(
              icon: Icons.assignment_late_rounded,
              title: 'No homework yet',
              subtitle: 'Assignments you create for this class appear here.',
            )
          else
            ..._homework.map((row) {
              final id = _homeworkId(row);
              final title = teacherFlowText(row['title'], fallback: 'Homework');
              final subject = teacherFlowText(
                row['subject'] ?? row['subject_id'],
                fallback: RoleAccessService.teacherSubject,
              );
              final due = teacherFlowDateOnly(
                row['submission_date'] ?? row['due_date'],
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TeacherFlowCard(
                  icon: Icons.assignment_rounded,
                  title: title,
                  subtitle: teacherFlowText(
                    row['description'] ?? row['instructions'],
                    fallback: subject,
                  ),
                  status: due.isEmpty ? 'Open' : 'Due $due',
                  statusColor: _isDueSoon(row)
                      ? Colors.orange
                      : teacherFlowAccent,
                  body: TeacherFlowActionWrap(
                    actions: [
                      TeacherFlowAction(
                        label: 'Edit',
                        icon: Icons.edit_rounded,
                        onTap: () => _openForm(homework: row),
                      ),
                      TeacherFlowAction(
                        label: 'Review ${_submissionCounts[id] ?? 0}',
                        icon: Icons.rate_review_rounded,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.teacherDiary,
                        ).then((_) => _loadHomework(forceRefresh: true)),
                      ),
                      TeacherFlowAction(
                        label: 'Delete',
                        icon: Icons.delete_rounded,
                        onTap: () => _deleteHomework(row),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  bool _isDueSoon(Map<String, dynamic> row) {
    final due = DateTime.tryParse(
      teacherFlowDateOnly(row['submission_date'] ?? row['due_date']),
    );
    if (due == null) return false;
    final now = DateTime.now();
    return due.difference(DateTime(now.year, now.month, now.day)).inDays <= 2;
  }

  String _homeworkId(Map<String, dynamic> row) {
    return teacherFlowText(row['homework_id'] ?? row['id']);
  }

  bool _isHomeworkSubmittedToday() {
    if (_reminderStatus == 'assigned') return true;
    if (_reminderStatus == 'skipped') return false;
    return _isHomeworkSubmittedTodayFromRows(_homework);
  }

  bool _isHomeworkSubmittedTodayFromRows(List<Map<String, dynamic>> rows) {
    final today = DateTime.now();
    for (final row in rows) {
      final dateStr =
          row['created_at'] ?? row['homework_date'] ?? row['due_date'];
      final date = DateTime.tryParse(teacherFlowDateOnly(dateStr));
      if (date != null &&
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        return true;
      }
    }
    return false;
  }
}
