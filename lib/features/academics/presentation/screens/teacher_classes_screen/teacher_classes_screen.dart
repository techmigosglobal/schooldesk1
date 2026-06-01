import 'package:flutter/material.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

class TeacherClassesScreen extends StatefulWidget {
  const TeacherClassesScreen({super.key});

  @override
  State<TeacherClassesScreen> createState() => _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends State<TeacherClassesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _classes = const [];
  List<Map<String, dynamic>> _students = const [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      if (!mounted) return;
      setState(() {
        _classes = RoleAccessService.teacherAssignedClasses;
        _students = RoleAccessService.teacherClassStudents;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load assigned class from the server.';
      });
    }
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
      subtitle: 'Assigned sections, students, and classroom actions',
      selectedIndex: 1,
      loading: _loading,
      error: _error,
      onRefresh: _loadClasses,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Classroom context',
            classLabel: classLabel,
            subject: RoleAccessService.teacherSubject,
            timeLabel: linkedStudentPreview,
            actions: [
              TeacherFlowAction(
                label: 'Attendance',
                icon: Icons.how_to_reg_rounded,
                filled: true,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.teacherAttendance),
              ),
              TeacherFlowAction(
                label: 'Homework',
                icon: Icons.assignment_rounded,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.teacherHomework),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TeacherFlowMetricGrid(
            metrics: [
              TeacherFlowMetric(
                label: 'Classes',
                value: '${_classes.length}',
                icon: Icons.class_rounded,
                color: teacherFlowAccent,
                tone: const Color(0xFFE3FAF5),
              ),
              TeacherFlowMetric(
                label: 'Students',
                value: '${_students.length}',
                icon: Icons.groups_rounded,
                color: Colors.indigo,
                tone: const Color(0xFFEAF0FF),
              ),
              TeacherFlowMetric(
                label: 'Subject',
                value: RoleAccessService.teacherSubject,
                icon: Icons.menu_book_rounded,
                color: Colors.orange,
                tone: const Color(0xFFFFF4E5),
              ),
              TeacherFlowMetric(
                label: 'Role',
                value: 'Class Teacher',
                icon: Icons.verified_user_rounded,
                color: Colors.green,
                tone: const Color(0xFFEAFBF0),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TeacherFlowSectionHeader(title: 'Student Roll'),
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
                  title: teacherFlowText(student['name'], fallback: 'Student'),
                  subtitle:
                      '${teacherFlowText(student['roll'], fallback: 'Roll not assigned')} · ${teacherFlowText(student['status'], fallback: 'active')}',
                  status: teacherFlowText(
                    student['class'],
                    fallback: classLabel,
                  ),
                  body: TeacherFlowActionWrap(
                    actions: [
                      TeacherFlowAction(
                        label: 'Notes',
                        icon: Icons.note_alt_rounded,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.teacherStudentNotes,
                        ),
                      ),
                      TeacherFlowAction(
                        label: 'Performance',
                        icon: Icons.trending_up_rounded,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.teacherPerformance,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
