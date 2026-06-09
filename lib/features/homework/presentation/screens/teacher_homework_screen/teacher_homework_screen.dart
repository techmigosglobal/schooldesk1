import 'package:flutter/material.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_form_screens.dart';

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

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final staffId = RoleAccessService.teacherStaffId;
      final sectionId = RoleAccessService.teacherClassId;
      final rows = await BackendApiClient.instance.getHomework(
        sectionId: sectionId.isEmpty ? null : sectionId,
        teacherId: staffId.isEmpty ? null : staffId,
      );
      final counts = <String, int>{};
      for (final row in rows.take(12)) {
        final id = teacherFlowText(row['id']);
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
    if (result != null) await _loadHomework();
  }

  Future<void> _logNoHomework() async {
    final sectionId = RoleAccessService.teacherClassId;
    await BackendApiClient.instance.createRaw('/diary-entries', {
      'section_id': sectionId,
      'teacher_id': RoleAccessService.teacherStaffId,
      'staff_id': RoleAccessService.teacherStaffId,
      'entry_type': 'no_homework',
      'type': 'no_homework',
      'title': 'No Homework Today',
      'class': RoleAccessService.teacherClassName,
      'subject': RoleAccessService.teacherSubject,
      'homework': 'No homework',
      'content':
          'No homework assigned for ${RoleAccessService.teacherSubject} today.',
      'notes':
          'No homework assigned for ${RoleAccessService.teacherSubject} today.',
      'date': DateTime.now().toUtc().toIso8601String(),
      'entry_date': teacherFlowDate(DateTime.now()),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No homework logged'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _loadHomework();
  }

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScaffold(
      title: 'Homework / Diary',
      subtitle: 'Period completion, homework sharing, and submission review',
      selectedIndex: 3,
      loading: _loading,
      error: _error,
      onRefresh: _loadHomework,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Homework'),
      ),
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Period completion',
            classLabel: RoleAccessService.teacherClassName,
            subject: RoleAccessService.teacherSubject,
            timeLabel: 'Homework, classwork, or no-homework log',
            actions: [
              TeacherFlowAction(
                label: 'Assign Homework',
                icon: Icons.add_task_rounded,
                filled: true,
                onTap: () => _openForm(),
              ),
              TeacherFlowAction(
                label: 'No Homework',
                icon: Icons.task_alt_rounded,
                onTap: _logNoHomework,
              ),
            ],
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
                label: 'No Homework',
                value: '1 tap',
                icon: Icons.done_all_rounded,
                color: Colors.green,
                tone: const Color(0xFFEAFBF0),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TeacherFlowSectionHeader(title: 'Subject-wise Homework Logs'),
          const SizedBox(height: 10),
          if (_homework.isEmpty)
            const TeacherFlowCard(
              icon: Icons.assignment_late_rounded,
              title: 'No homework yet',
              subtitle: 'Assign homework or log no-homework after a period.',
            )
          else
            ..._homework.map((row) {
              final id = teacherFlowText(row['id']);
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
                          AppRoutes.teacherHomeworkSubmissions,
                          arguments: TeacherHomeworkSubmissionsArgs(
                            homework: row,
                          ),
                        ).then((_) => _loadHomework()),
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
}
