import 'package:flutter/material.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
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
      final assignedClasses = RoleAccessService.teacherAssignedClasses;
      setState(() {
        _classes = assignedClasses;
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
      subtitle: 'Your class teacher section, students, and classroom actions',
      selectedIndex: TeacherNav.classes,
      loading: _loading,
      error: _error,
      onRefresh: _loadClasses,
      child: TeacherFlowScrollView(
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
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.teacherTimetable),
                ),
                TeacherFlowAction(
                  label: 'Attendance',
                  icon: Icons.how_to_reg_rounded,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.teacherAttendance),
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
                  title: teacherFlowText(student['name'], fallback: 'Student'),
                  subtitle:
                      '${teacherFlowText(student['roll'], fallback: 'Roll not assigned')} · ${teacherFlowText(student['status'], fallback: 'active')}',
                  status: teacherFlowText(
                    student['class'],
                    fallback: classLabel,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
