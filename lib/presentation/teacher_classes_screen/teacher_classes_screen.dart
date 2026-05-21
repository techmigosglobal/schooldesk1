import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../routes/app_routes.dart';
import '../../services/role_access_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../widgets/teacher_navigation.dart';

class TeacherClassesScreen extends StatefulWidget {
  const TeacherClassesScreen({super.key});

  @override
  State<TeacherClassesScreen> createState() => _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends State<TeacherClassesScreen> {
  int _selectedNavIndex = 1;
  List<Map<String, dynamic>> _classes = const [];
  bool _loading = true;
  String? _error;

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
        _classes = _buildAssignedClasses();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load assigned class from the server.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _buildAssignedClasses() {
    final teacher = RoleAccessService.loggedInTeacher;
    final className = RoleAccessService.teacherClassName;
    final classId = RoleAccessService.teacherClassId;
    final subject = RoleAccessService.teacherSubject;
    final students = RoleAccessService.teacherClassStudents;

    if (classId.isEmpty && className == 'Not assigned') return const [];

    return [
      {
        'class': className,
        'subject': subject,
        'strength': students.length,
        'classTeacher': true,
        'teacherName': teacher['name'],
        'students': students,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final title = _classes.isEmpty
        ? 'My Classes'
        : 'My Class — ${_classes.first['class']}';
    return SchoolDeskModuleScaffold(
      title: title,
      subtitle: 'Review assigned sections, student lists, and class actions',
      drawer: TeacherDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.teacher,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: AppTheme.error),
          ),
        ),
      );
    }
    if (_classes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No assigned class found for this teacher account.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: AppTheme.muted),
          ),
        ),
      );
    }
    return _buildClassDetail(_classes.first);
  }

  Widget _buildClassDetail(Map<String, dynamic> cls) {
    final students = cls['students'] as List<Map<String, dynamic>>;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClassSummaryCard(cls),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Student List',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${students.length} students',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...students.map((s) => _buildStudentRow(s, cls['class'] as String)),
        ],
      ),
    );
  }

  Widget _buildClassSummaryCard(Map<String, dynamic> cls) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A5276), Color(0xFF2E86C1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class ${cls['class']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    cls['subject'] as String,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Class Teacher',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatChip('Strength', '${cls['strength']}'),
              const SizedBox(width: 12),
              _buildStatChip('Subject', cls['subject'] as String),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.teacherAttendance),
                  icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                  label: const Text('Mark Attendance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A5276),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.teacherHomework),
                  icon: const Icon(
                    Icons.assignment_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Add Homework',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildStudentRow(Map<String, dynamic> s, String className) {
    final grade = (s['grade'] as String? ?? 'N/A').trim();
    final gradeColor = grade.startsWith('A')
        ? AppTheme.success
        : grade.startsWith('B')
        ? AppTheme.info
        : AppTheme.warning;
    final roll = (s['roll'] as String? ?? s['student_code'] as String? ?? '')
        .trim();
    final displayRoll = roll.isEmpty ? '-' : roll;
    final attendance = (s['attendance'] as String? ?? 'Not marked').trim();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                displayRoll,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
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
                  s['name'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                Text(
                  'Class $className · Attendance: $attendance',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: gradeColor.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              grade,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: gradeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
