import 'package:flutter/material.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

import 'package:schooldesk1/core/navigation/schooldesk_navigation.dart';

final class _TeacherClassesSnapshot {
  const _TeacherClassesSnapshot(this.students);

  final List<Map<String, dynamic>> students;
}

class TeacherClassesScreen extends StatefulWidget {
  const TeacherClassesScreen({super.key});

  @override
  State<TeacherClassesScreen> createState() => _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends State<TeacherClassesScreen> {
  RepositoryState<_TeacherClassesSnapshot> _repositoryState =
      const RepositoryState.loading();
  List<Map<String, dynamic>> _students = const [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
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
      await RoleAccessService.initialize();
      if (!mounted) return;
      setState(() {
        _students = RoleAccessService.teacherAssignedStudents;
        _repositoryState = RepositoryState(
          data: _TeacherClassesSnapshot(List.unmodifiable(_students)),
          source: RepositorySource.remote,
          lastUpdated: DateTime.now().toUtc(),
        );
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _repositoryState = previous.hasData
            ? RepositoryState(
                data: previous.data,
                source: RepositorySource.cache,
                isStale: true,
                error: 'Unable to load assigned class from the server.',
                lastUpdated: previous.lastUpdated,
              )
            : const RepositoryState.error(
                error: 'Unable to load assigned class from the server.',
              );
      });
    }
  }

  List<Map<String, dynamic>> get _assignedClasses =>
      RoleAccessService.teacherAssignedClasses;

  List<Map<String, dynamic>> _studentsForClass(String sectionId) => _students
      .where((student) => teacherFlowText(student['class_id']) == sectionId)
      .toList();

  String _assignmentRole(Map<String, dynamic> assignment) {
    if (assignment['is_class_teacher'] == true) return 'Class teacher';
    if (assignment['is_co_teacher'] == true) return 'Co-teacher';
    return 'Subject teacher';
  }

  String _assignmentSubjects(Map<String, dynamic> assignment) {
    final subjects = assignment['subjects'];
    if (subjects is List) {
      final names = subjects
          .whereType<Map>()
          .map((subject) => teacherFlowText(subject['subject_name']))
          .where((name) => name.isNotEmpty)
          .toSet()
          .join(', ');
      if (names.isNotEmpty) return names;
    }
    return teacherFlowText(
      assignment['subject_name'],
      fallback: _assignmentRole(assignment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classLabel = RoleAccessService.teacherClassName;
    final linkedStudentPreview = _students.isEmpty
        ? 'No linked students'
        : '${_students.length} linked student${_students.length == 1 ? '' : 's'}: '
              '${teacherFlowText(_students.first['name'], fallback: 'Student')}';
    return TeacherFlowScaffold(
      title: 'My Classes',
      subtitle: 'Your class teacher section, students, and classroom actions',
      selectedIndex: TeacherNav.classes,
      loading: _repositoryState.isLoading && !_repositoryState.hasData,
      error: _repositoryState.isError && !_repositoryState.hasData
          ? '${_repositoryState.error}'
          : null,
      onRefresh: _loadClasses,
      child: SchoolDeskRepositoryStateView<_TeacherClassesSnapshot>(
        state: _repositoryState,
        onRetry: _loadClasses,
        emptyTitle: 'No assigned class',
        emptyMessage: 'No class data is available for this teacher scope.',
        data: (_) => TeacherFlowScrollView(
          children: [
            if (!RoleAccessService.hasTeacherStaffLink)
              const TeacherFlowCard(
                icon: Icons.badge_outlined,
                title: 'Your teacher account is not linked to a staff profile.',
                subtitle: 'Please contact Admin/Principal.',
              )
            else
              TeacherCurrentClassCard(
                greeting: 'Classroom context',
                classLabel: classLabel,
                subject: RoleAccessService.teacherSubject,
                timeLabel: linkedStudentPreview,
                actions: [
                  TeacherFlowAction(
                    label: 'Timetable',
                    icon: Icons.calendar_month_rounded,
                    filled: true,
                    onTap: () => SchoolDeskNavigation.push(
                      context,
                      AppRoutes.teacherTimetable,
                    ),
                  ),
                  TeacherFlowAction(
                    label: 'Attendance',
                    icon: Icons.how_to_reg_rounded,
                    onTap: () => SchoolDeskNavigation.push(
                      context,
                      AppRoutes.teacherAttendance,
                    ),
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
                  color: Colors.indigo,
                  tone: const Color(0xFFEAF0FF),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const TeacherFlowSectionHeader(title: 'Primary Class Roll'),
            const SizedBox(height: 10),
            if (_students.isEmpty)
              const TeacherFlowCard(
                icon: Icons.group_off_rounded,
                title: 'No linked students',
                subtitle:
                    'Students appear here only when the backend assigns them to your section.',
              )
            else
              ..._students.map(
                (student) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TeacherFlowCard(
                    icon: Icons.person_rounded,
                    title: teacherFlowText(
                      student['name'],
                      fallback: 'Student',
                    ),
                    subtitle:
                        '${teacherFlowText(student['roll'], fallback: 'Roll not assigned')} · ${teacherFlowText(student['status'], fallback: 'active')}',
                    status: teacherFlowText(
                      student['class'],
                      fallback: classLabel,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            const TeacherFlowSectionHeader(title: 'Assigned Classes'),
            const SizedBox(height: 10),
            if (_assignedClasses.isEmpty)
              const TeacherFlowCard(
                icon: Icons.class_outlined,
                title: 'No assigned classes found',
                subtitle: 'Contact Admin/Principal to verify your assignments.',
              )
            else
              ..._assignedClasses.map((assignment) {
                final sectionId = teacherFlowText(
                  assignment['section_id'] ?? assignment['id'],
                );
                final students = _studentsForClass(sectionId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TeacherFlowCard(
                    icon: Icons.class_rounded,
                    title: teacherFlowText(
                      assignment['label'],
                      fallback: teacherFlowText(
                        assignment['section_name'],
                        fallback: 'Assigned class',
                      ),
                    ),
                    subtitle:
                        '${_assignmentRole(assignment)} · ${_assignmentSubjects(assignment)}',
                    trailing: Text(
                      '${students.length} student${students.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
