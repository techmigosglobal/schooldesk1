import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../routes/app_routes.dart';
import '../../services/backend_api_client.dart';
import '../../services/backend_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_navigation.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import 'academic_management_form_screens.dart';

class AcademicManagementScreen extends StatefulWidget {
  final String ownerRole;

  const AcademicManagementScreen({super.key, this.ownerRole = 'admin'});

  @override
  State<AcademicManagementScreen> createState() =>
      _AcademicManagementScreenState();
}

class _AcademicManagementScreenState extends State<AcademicManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  BackendDataService? _storage;
  bool _loading = true;

  List<Map<String, dynamic>> _academicYears = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _curriculum = [];
  List<Map<String, dynamic>> _staff = [];
  bool get _isAdminOwner => widget.ownerRole.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _storage = await BackendDataService.getInstance();
    await _storage!.ensureAcademicManagementLoaded();
    final academicYears = await _storage!.getList(
      BackendDataService.kAcademicYears,
    );
    final subjects = await _storage!.getList(
      BackendDataService.kAcademicSubjects,
    );
    final classes = await _storage!.getList(
      BackendDataService.kAcademicClasses,
    );
    final curriculum = await _storage!.getList(
      BackendDataService.kAcademicCurriculum,
    );
    final staff = await _storage!.getList(BackendDataService.kAdminTeachers);
    setState(() {
      _academicYears = academicYears;
      _subjects = subjects;
      _classes = classes;
      _curriculum = curriculum;
      _staff = staff;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Academic Management',
      subtitle: _isAdminOwner
          ? 'Configure years, subjects, classes, and curriculum records'
          : 'Review academic structure, classes, subjects, and curriculum records',
      drawer: _buildDrawer(),
      floatingActionButton: DashboardFabWidget(
        role: _isAdminOwner ? DashboardRole.admin : DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _refresh,
          tooltip: 'Refresh academic data',
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(text: 'Academic Years'),
          Tab(text: 'Subjects'),
          Tab(text: 'Classes'),
          Tab(text: 'Curriculum'),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildDrawer() {
    if (_isAdminOwner) {
      return AdminDrawer(selectedIndex: 15, onDestinationSelected: (_) {});
    }
    return PrincipalDrawer(selectedIndex: 12, onDestinationSelected: (_) {});
  }

  Widget _buildContent() {
    return _loading
        ? const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          )
        : TabBarView(
            controller: _tabController,
            children: [
              _AcademicYearsTab(
                years: _academicYears,
                storage: _storage!,
                onRefresh: _refresh,
                isAdminOwner: _isAdminOwner,
                ownerRole: widget.ownerRole,
              ),
              _SubjectsTab(
                subjects: _subjects,
                storage: _storage!,
                onRefresh: _refresh,
                isAdminOwner: _isAdminOwner,
                ownerRole: widget.ownerRole,
              ),
              _ClassesTab(
                classes: _classes,
                staff: _staff,
                storage: _storage!,
                onRefresh: _refresh,
                isAdminOwner: _isAdminOwner,
                ownerRole: widget.ownerRole,
              ),
              _CurriculumTab(
                curriculum: _curriculum,
                classes: _classes,
                subjects: _subjects,
                storage: _storage!,
                onRefresh: _refresh,
                isAdminOwner: _isAdminOwner,
                ownerRole: widget.ownerRole,
              ),
            ],
          );
  }
}

// ─── Academic Years Tab ──────────────────────────────────────────────────────

class _AcademicYearsTab extends StatelessWidget {
  final List<Map<String, dynamic>> years;
  final BackendDataService storage;
  final VoidCallback onRefresh;
  final bool isAdminOwner;
  final String ownerRole;

  const _AcademicYearsTab({
    required this.years,
    required this.storage,
    required this.onRefresh,
    required this.isAdminOwner,
    required this.ownerRole,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            title: 'Academic Years',
            subtitle: '${years.length} years configured',
            onAdd: isAdminOwner ? () => _openYearForm(context) : null,
          ),
          const SizedBox(height: 12),
          ...years.map(
            (y) => _AcademicYearCard(
              year: y,
              onActivate: isAdminOwner ? () => _activateYear(context, y) : null,
              onEdit: isAdminOwner
                  ? () => _openYearForm(context, year: y)
                  : null,
              onDelete: isAdminOwner ? () => _deleteYear(context, y) : null,
            ),
          ),
          if (years.isEmpty)
            const _EmptyState(
              icon: Icons.calendar_today_rounded,
              message: 'No academic years configured',
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _activateYear(
    BuildContext context,
    Map<String, dynamic> year,
  ) async {
    try {
      await BackendApiClient.instance.updateAcademicYear(
        '${year['id'] ?? ''}',
        yearLabel: _yearLabel(year),
        startDate: _yearStartDate(year),
        endDate: _yearEndDate(year),
        isCurrent: true,
      );
      onRefresh();
      _showAcademicSnack(
        context,
        '${year['name']} activated - visible to all modules',
      );
    } catch (error) {
      _showAcademicSnack(context, _academicError(error), isError: true);
    }
  }

  Future<void> _deleteYear(
    BuildContext context,
    Map<String, dynamic> year,
  ) async {
    final confirmed = await _confirmAcademicDelete(
      context,
      title: 'Delete Academic Year',
      message:
          'Delete "${year['name']}"? The backend will block this if classes, terms, fees, attendance, or events are linked.',
    );
    if (confirmed != true) return;
    try {
      await storage.deleteAcademicYearRecord('${year['id'] ?? ''}');
      onRefresh();
      _showAcademicSnack(context, 'Academic year deleted');
    } catch (error) {
      _showAcademicSnack(context, _academicError(error), isError: true);
    }
  }

  Future<void> _openYearForm(
    BuildContext context, {
    Map<String, dynamic>? year,
  }) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.academicYearForm,
      arguments: AcademicYearFormArgs(ownerRole: ownerRole, year: year),
    );
    if (!context.mounted || result is! AcademicFormResult) return;
    onRefresh();
    _showAcademicSnack(context, result.message, isWarning: result.isWarning);
  }

  String _yearLabel(Map<String, dynamic> year) =>
      '${year['name'] ?? year['year_label'] ?? year['year'] ?? ''}'.trim();

  String _yearStartDate(Map<String, dynamic> year) =>
      '${year['start_date'] ?? year['start'] ?? '2026-04-01'}'.split('T').first;

  String _yearEndDate(Map<String, dynamic> year) =>
      '${year['end_date'] ?? year['end'] ?? '2027-03-31'}'.split('T').first;
}

class _AcademicYearCard extends StatelessWidget {
  final Map<String, dynamic> year;
  final VoidCallback? onActivate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _AcademicYearCard({
    required this.year,
    required this.onActivate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = year['status'] == 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppTheme.primary : AppTheme.outlineVariant,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.primaryContainer
                  : AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              size: 20,
              color: isActive ? AppTheme.primary : AppTheme.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        year['name'] as String? ?? '',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${year['start'] ?? ''} – ${year['end'] ?? ''}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isActive && onActivate != null)
            TextButton(
              onPressed: onActivate,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
              ),
              child: Text(
                'Activate',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppTheme.muted,
              ),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppTheme.error,
              ),
              tooltip: 'Delete academic year',
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}

// ─── Subjects Tab ────────────────────────────────────────────────────────────

class _SubjectsTab extends StatelessWidget {
  final List<Map<String, dynamic>> subjects;
  final BackendDataService storage;
  final VoidCallback onRefresh;
  final bool isAdminOwner;
  final String ownerRole;

  const _SubjectsTab({
    required this.subjects,
    required this.storage,
    required this.onRefresh,
    required this.isAdminOwner,
    required this.ownerRole,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            title: 'Subjects',
            subtitle: '${subjects.length} subjects configured',
            onAdd: isAdminOwner ? () => _openSubjectForm(context) : null,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: subjects
                .map(
                  (s) => _SubjectChip(
                    subject: s,
                    onEdit: isAdminOwner
                        ? () => _openSubjectForm(context, subject: s)
                        : null,
                    onDelete: isAdminOwner
                        ? () => _deleteSubject(context, s)
                        : null,
                  ),
                )
                .toList(),
          ),
          if (subjects.isEmpty)
            const _EmptyState(
              icon: Icons.book_outlined,
              message: 'No subjects configured',
            ),
          const SizedBox(height: 24),
          _buildSubjectTable(context),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSubjectTable(BuildContext context) {
    if (subjects.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              'Subject Details',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1),
          ...subjects.map(
            (s) => _SubjectRow(
              subject: s,
              onEdit: isAdminOwner
                  ? () => _openSubjectForm(context, subject: s)
                  : null,
              onDelete: isAdminOwner ? () => _deleteSubject(context, s) : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubject(
    BuildContext context,
    Map<String, dynamic> subject,
  ) async {
    // Confirmation-only dialog: no user input is collected here.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Remove Subject',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Remove "${subject['name']}" from the subject list?',
          style: GoogleFonts.dmSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await storage.deleteAcademicSubjectRecord('${subject['id'] ?? ''}');
        onRefresh();
        _showAcademicSnack(context, 'Subject removed');
      } catch (error) {
        _showAcademicSnack(context, _academicError(error), isError: true);
      }
    }
  }

  Future<void> _openSubjectForm(
    BuildContext context, {
    Map<String, dynamic>? subject,
  }) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.academicSubjectForm,
      arguments: AcademicSubjectFormArgs(
        ownerRole: ownerRole,
        subject: subject,
      ),
    );
    if (!context.mounted || result is! AcademicFormResult) return;
    onRefresh();
    _showAcademicSnack(context, result.message, isWarning: result.isWarning);
  }
}

class _SubjectChip extends StatelessWidget {
  final Map<String, dynamic> subject;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _SubjectChip({
    required this.subject,
    required this.onEdit,
    required this.onDelete,
  });

  Color _typeColor(String type) {
    switch (type) {
      case 'Core':
        return AppTheme.primary;
      case 'Elective':
        return AppTheme.secondary;
      case 'Co-curricular':
        return AppTheme.success;
      default:
        return AppTheme.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = subject['type'] as String? ?? 'Core';
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            subject['name'] as String? ?? '',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (onEdit != null || onDelete != null) const SizedBox(width: 4),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              tooltip: 'Edit subject',
              icon: Icon(Icons.edit_outlined, size: 14, color: color),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              visualDensity: VisualDensity.compact,
            ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              tooltip: 'Delete subject',
              icon: Icon(Icons.close_rounded, size: 14, color: color),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  final Map<String, dynamic> subject;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _SubjectRow({
    required this.subject,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              subject['name'] as String? ?? '',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              subject['code'] as String? ?? '—',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                subject['type'] as String? ?? '',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '${subject['periodsPerWeek'] ?? 5} periods',
              style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
              textAlign: TextAlign.right,
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit subject',
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              tooltip: 'Delete subject',
              color: AppTheme.error,
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

// ─── Classes Tab ─────────────────────────────────────────────────────────────

class _ClassesTab extends StatelessWidget {
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> staff;
  final BackendDataService storage;
  final VoidCallback onRefresh;
  final bool isAdminOwner;
  final String ownerRole;

  const _ClassesTab({
    required this.classes,
    required this.staff,
    required this.storage,
    required this.onRefresh,
    required this.isAdminOwner,
    required this.ownerRole,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            title: 'Classes & Sections',
            subtitle: isAdminOwner
                ? '${classes.length} active classes · new requests go to Principal'
                : '${classes.length} classes configured',
            onAdd: isAdminOwner ? () => _openClassForm(context) : null,
          ),
          const SizedBox(height: 12),
          ...classes.map(
            (c) => _ClassCard(
              classData: c,
              onEdit: isAdminOwner
                  ? () => _openClassForm(context, classData: c)
                  : null,
              onDelete: isAdminOwner ? () => _deleteClass(context, c) : null,
            ),
          ),
          if (classes.isEmpty)
            const _EmptyState(
              icon: Icons.class_outlined,
              message: 'No classes configured',
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _openClassForm(
    BuildContext context, {
    Map<String, dynamic>? classData,
  }) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.academicClassForm,
      arguments: AcademicClassFormArgs(
        ownerRole: ownerRole,
        staff: staff,
        classData: classData,
      ),
    );
    if (!context.mounted || result is! AcademicFormResult) return;
    onRefresh();
    _showAcademicSnack(context, result.message, isWarning: result.isWarning);
  }

  Future<void> _deleteClass(
    BuildContext context,
    Map<String, dynamic> classData,
  ) async {
    final confirmed = await _confirmAcademicDelete(
      context,
      title: 'Delete Class',
      message:
          'Delete "${classData['name']}" and its sections? The backend will block this if students, timetable, attendance, homework, or meetings are linked.',
    );
    if (confirmed != true) return;
    try {
      await storage.deleteAcademicClassRecord(classData);
      onRefresh();
      _showAcademicSnack(context, 'Class deleted');
    } catch (error) {
      _showAcademicSnack(context, _academicError(error), isError: true);
    }
  }
}

class _ClassCard extends StatelessWidget {
  final Map<String, dynamic> classData;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ClassCard({
    required this.classData,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sections =
        (classData['sections'] as List?)?.map((s) => s.toString()).toList() ??
        [];
    final classTeacher = '${classData['classTeacher'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.class_rounded,
              size: 20,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classData['name'] as String? ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: sections
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Section $s',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 4),
                Text(
                  'Strength: ${classData['strength'] ?? 40}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  classTeacher.isEmpty
                      ? 'Class Teacher: Not assigned'
                      : 'Class Teacher: $classTeacher',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppTheme.muted,
              ),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppTheme.error,
              ),
              tooltip: 'Delete class',
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}

// ─── Curriculum Tab ──────────────────────────────────────────────────────────

class _CurriculumTab extends StatelessWidget {
  final List<Map<String, dynamic>> curriculum;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> subjects;
  final BackendDataService storage;
  final VoidCallback onRefresh;
  final bool isAdminOwner;
  final String ownerRole;

  const _CurriculumTab({
    required this.curriculum,
    required this.classes,
    required this.subjects,
    required this.storage,
    required this.onRefresh,
    required this.isAdminOwner,
    required this.ownerRole,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            title: 'Curriculum Overview',
            subtitle: 'Class-wise subject mapping',
            onAdd: isAdminOwner ? () => _openCurriculumForm(context) : null,
          ),
          const SizedBox(height: 12),
          ...curriculum.map(
            (c) => _CurriculumCard(
              item: c,
              onTogglePublish: isAdminOwner
                  ? () => _togglePublish(context, c)
                  : null,
              onEdit: isAdminOwner
                  ? () => _openCurriculumForm(context, item: c)
                  : null,
              onDelete: isAdminOwner
                  ? () => _deleteCurriculum(context, c)
                  : null,
            ),
          ),
          if (curriculum.isEmpty)
            const _EmptyState(
              icon: Icons.menu_book_outlined,
              message: 'No curriculum entries configured',
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _togglePublish(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final isPublished = item['published'] == true;
    final updated = curriculum.map((c) {
      if (c['id'] == item['id']) {
        return {...c, 'published': !isPublished};
      }
      return c;
    }).toList();
    final next = updated.firstWhere((c) => c['id'] == item['id']);
    try {
      await storage.saveAcademicCurriculumRecord(next);
      onRefresh();
      _showAcademicSnack(
        context,
        isPublished
            ? 'Curriculum unpublished'
            : 'Curriculum published - visible to Teachers & Parents',
        isWarning: isPublished,
      );
    } catch (error) {
      _showAcademicSnack(context, _academicError(error), isError: true);
    }
  }

  Future<void> _openCurriculumForm(
    BuildContext context, {
    Map<String, dynamic>? item,
  }) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.academicCurriculumForm,
      arguments: AcademicCurriculumFormArgs(
        ownerRole: ownerRole,
        classes: classes,
        subjects: subjects,
        item: item,
      ),
    );
    if (!context.mounted || result is! AcademicFormResult) return;
    onRefresh();
    _showAcademicSnack(context, result.message, isWarning: result.isWarning);
  }

  Future<void> _deleteCurriculum(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final confirmed = await _confirmAcademicDelete(
      context,
      title: 'Delete Curriculum Entry',
      message: 'Delete "${item['class']}" ${item['term'] ?? ''}?',
    );
    if (confirmed != true) return;
    try {
      await storage.deleteAcademicCurriculumRecord('${item['id'] ?? ''}');
      onRefresh();
      _showAcademicSnack(context, 'Curriculum entry deleted');
    } catch (error) {
      _showAcademicSnack(context, _academicError(error), isError: true);
    }
  }
}

class _CurriculumCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTogglePublish;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CurriculumCard({
    required this.item,
    required this.onTogglePublish,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPublished = item['published'] == true;
    final subjects =
        (item['subjects'] as List?)?.map((s) => s.toString()).toList() ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
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
                      item['class'] as String? ?? '',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item['term'] as String? ?? '',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onTogglePublish,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isPublished
                        ? AppTheme.successContainer
                        : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPublished
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_outlined,
                        size: 14,
                        color: isPublished ? AppTheme.success : AppTheme.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPublished ? 'Published' : 'Draft',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPublished
                              ? AppTheme.success
                              : AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Edit curriculum',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppTheme.muted,
                  visualDensity: VisualDensity.compact,
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete curriculum',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppTheme.error,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: subjects
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onAdd;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ),
        ),
        if (onAdd != null)
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppTheme.outline),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

Future<bool?> _confirmAcademicDelete(
  BuildContext context, {
  required String title,
  required String message,
}) {
  // Confirmation-only dialog: deletion requires an explicit yes/no choice,
  // but no form input is collected.
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        title,
        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
      ),
      content: Text(message, style: GoogleFonts.dmSans(fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Delete'),
        ),
      ],
    ),
  );
}

void _showAcademicSnack(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isWarning = false,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: GoogleFonts.dmSans(fontSize: 13)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError
          ? AppTheme.error
          : isWarning
          ? AppTheme.warning
          : AppTheme.success,
    ),
  );
}

String _academicError(Object error) {
  final raw = error.toString();
  final server = RegExp(r'ServerException\([^)]*\):\s*(.*)').firstMatch(raw);
  if (server != null) return server.group(1)?.trim() ?? raw;
  final network = RegExp(r'NetworkException\([^)]*\):\s*(.*)').firstMatch(raw);
  if (network != null) return network.group(1)?.trim() ?? raw;
  return raw.replaceFirst('Exception: ', '').trim();
}
