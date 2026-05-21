import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/backend_api_client.dart';
import '../../services/role_access_service.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../widgets/teacher_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import 'teacher_homework_form_screens.dart';

class TeacherHomeworkScreen extends StatefulWidget {
  const TeacherHomeworkScreen({super.key});

  @override
  State<TeacherHomeworkScreen> createState() => _TeacherHomeworkScreenState();
}

class _TeacherHomeworkScreenState extends State<TeacherHomeworkScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 3;
  late TabController _tabController;
  String _assignedClass = 'Not assigned';
  String _assignedClassId = '';
  String _teacherStaffId = '';
  List<Map<String, dynamic>> _homeworks = [];
  bool _loading = true;
  String? _error;

  List<String> _classFilters = const ['All'];
  String _filterClass = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      _assignedClass = RoleAccessService.teacherClassName;
      _assignedClassId = RoleAccessService.teacherClassId;
      _teacherStaffId = RoleAccessService.teacherStaffId;
      _classFilters = ['All', _assignedClass];
      final allHomeworks = await BackendApiClient.instance.getHomework(
        teacherId: _teacherStaffId,
      );
      final mapped = allHomeworks
          .map(_mapHomeworkFromApi)
          .where(_belongsToAssignedScope)
          .toList();
      final withCounts = await _attachSubmissionCounts(mapped);
      if (!mounted) return;
      setState(() {
        _homeworks = withCounts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load homework from the server.';
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _mapHomeworkFromApi(Map<String, dynamic> h) {
    final dueDate = DateTime.tryParse('${h['due_date'] ?? ''}');
    final dueLabel = dueDate == null
        ? '${h['deadline'] ?? ''}'
        : DateFormat('d MMM yyyy').format(dueDate);
    final status = '${h['status'] ?? 'pending'}'.toLowerCase();
    return {
      'id': h['id'],
      'title': h['title'] ?? '',
      'class': h['class'] ?? h['class_name'] ?? _assignedClass,
      'section_id': h['section_id'] ?? '',
      'teacher_id': h['teacher_id'] ?? '',
      'student_id': h['student_id'] ?? '',
      'subject': h['subject'] ?? RoleAccessService.teacherSubject,
      'deadline': dueLabel,
      'dueDate': dueDate?.toIso8601String(),
      'instructions': h['description'] ?? h['instructions'] ?? '',
      'submitted': h['submitted'] ?? 0,
      'total': h['total'] ?? RoleAccessService.teacherClassStudents.length,
      'status': status == 'completed' ? 'completed' : 'active',
      'createdOn': h['created_at'] ?? '',
    };
  }

  bool _belongsToAssignedScope(Map<String, dynamic> h) {
    final teacherId = h['teacher_id']?.toString() ?? '';
    final sectionId = h['section_id']?.toString() ?? '';
    final className = h['class']?.toString() ?? '';
    if (_teacherStaffId.isNotEmpty && teacherId == _teacherStaffId) {
      return true;
    }
    if (_assignedClassId.isNotEmpty && sectionId == _assignedClassId) {
      return true;
    }
    return className.isEmpty || className == _assignedClass;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredHomeworks {
    return _homeworks.where((homework) {
      if (!_belongsToAssignedScope(homework)) return false;
      return _filterClass == 'All' || homework['class'] == _filterClass;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final drawer = TeacherDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Homework & Assignments',
        subtitle: 'Assign, review, and track class homework completion',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SchoolDeskModuleScaffold(
        title: 'Homework & Assignments',
        subtitle: 'Assign, review, and track class homework completion',
        drawer: drawer,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Homework & Assignments',
      subtitle: 'Assign, review, and track class homework completion',
      drawer: drawer,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DashboardFabWidget(role: DashboardRole.teacher),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: () => _openHomeworkForm(),
            backgroundColor: AppTheme.primary,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text(
              'New Homework',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Active'),
          Tab(text: 'Completed'),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHomeworkList('active'),
                _buildHomeworkList('completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _classFilters.map((c) {
            final isSelected = _filterClass == c;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filterClass = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    c == 'All' ? 'All Classes' : 'Class $c',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHomeworkList(String statusFilter) {
    final filtered = _filteredHomeworks
        .where((h) => h['status'] == statusFilter)
        .toList();
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 48,
              color: AppTheme.muted,
            ),
            const SizedBox(height: 12),
            Text(
              'No ${statusFilter == 'active' ? 'active' : 'completed'} homework',
              style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.muted),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, i) => _buildHomeworkCard(filtered[i]),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw) {
    final submitted = hw['submitted'] as int;
    final total = hw['total'] as int;
    final pct = total > 0 ? submitted / total : 0.0;
    final isCompleted = hw['status'] == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? AppTheme.success.withAlpha(60)
              : AppTheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hw['title'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _buildChip('Class ${hw['class']}', AppTheme.primary),
                        const SizedBox(width: 6),
                        _buildChip(hw['subject'] as String, AppTheme.secondary),
                      ],
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hw['instructions'] as String,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 12,
                color: AppTheme.muted,
              ),
              const SizedBox(width: 4),
              Text(
                'Due: ${hw['deadline']}',
                style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
              ),
              const Spacer(),
              Text(
                '$submitted/$total submitted',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppTheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppTheme.outlineVariant,
              color: pct >= 1.0 ? AppTheme.success : AppTheme.primary,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openSubmissions(hw),
                  icon: const Icon(Icons.list_alt_rounded, size: 14),
                  label: Text(
                    'Submissions',
                    style: GoogleFonts.dmSans(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openHomeworkForm(homework: hw),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: Text('Edit', style: GoogleFonts.dmSans(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _attachSubmissionCounts(
    List<Map<String, dynamic>> rows,
  ) async {
    final enriched = <Map<String, dynamic>>[];
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) {
        enriched.add(row);
        continue;
      }
      try {
        final response = await BackendApiClient.instance.getHomeworkSubmissions(
          id,
        );
        final summary = Map<String, dynamic>.from(
          response['summary'] as Map? ?? {},
        );
        enriched.add({
          ...row,
          'submitted': _intValue(summary['submitted']),
          'total': _intValue(summary['total']),
        });
      } catch (_) {
        enriched.add(row);
      }
    }
    return enriched;
  }

  Future<void> _openHomeworkForm({Map<String, dynamic>? homework}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.teacherHomeworkForm,
      arguments: TeacherHomeworkFormArgs(
        teacherStaffId: _teacherStaffId,
        defaultClassName: _assignedClass,
        defaultSubject: RoleAccessService.teacherSubject,
        assignedClasses: RoleAccessService.teacherAssignedClasses,
        students: RoleAccessService.teacherClassStudents,
        homework: homework,
      ),
    );
    if (!mounted) return;
    if (result is TeacherHomeworkResult) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadData();
    }
  }

  Future<void> _openSubmissions(Map<String, dynamic> homework) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.teacherHomeworkSubmissions,
      arguments: TeacherHomeworkSubmissionsArgs(homework: homework),
    );
    if (mounted) await _loadData();
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
