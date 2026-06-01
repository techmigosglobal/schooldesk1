import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';
import 'package:schooldesk1/core/widgets/principal_directory_ui.dart';

class PrincipalSubjectsScreen extends StatefulWidget {
  const PrincipalSubjectsScreen({super.key});

  @override
  State<PrincipalSubjectsScreen> createState() =>
      _PrincipalSubjectsScreenState();
}

class _PrincipalSubjectsScreenState extends State<PrincipalSubjectsScreen> {
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _analytics = {};
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _gradeSubjects = [];
  List<Map<String, dynamic>> _staffSubjects = [];
  List<Map<String, dynamic>> _gradeOptions = [];
  List<GradeModel> _grades = [];
  List<SectionModel> _sections = [];
  List<StaffModel> _staff = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _workspaceView = 'Classes';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait<Object>([
        api.getPrincipalSubjectsOverview(),
        api.getRawList(
          '/grade-subjects',
          queryParameters: const {'page_size': 500},
        ),
        api.getRawList(
          '/staff-subjects',
          queryParameters: const {'page_size': 500},
        ),
        api.getGrades(),
        api.getSections(),
        api.getStaff(page: 1, pageSize: 500),
      ]);
      final payload = results[0] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _summary = _asMap(payload['summary']);
        _analytics = _asMap(payload['analytics']);
        _subjects = _asListMap(payload['subjects']);
        _gradeSubjects = results[1] as List<Map<String, dynamic>>;
        _staffSubjects = results[2] as List<Map<String, dynamic>>;
        _gradeOptions = _asListMap(payload['grade_options']);
        _grades = results[3] as List<GradeModel>;
        _sections = results[4] as List<SectionModel>;
        _staff = (results[5] as PaginatedList<StaffModel>).data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredSubjects {
    final query = _search.trim().toLowerCase();
    return _subjects.where((row) {
      final teacherNames = _asListMap(
        row['assigned_teachers'],
      ).map((teacher) => _text(teacher['name'])).join(' ');
      final searchable = [
        _text(row['subject_name']),
        _text(row['department']),
        teacherNames,
      ].join(' ').toLowerCase();
      final matchesSearch = query.isEmpty || searchable.contains(query);
      return matchesSearch;
    }).toList();
  }

  List<_ClassSubjectCoverage> get _classCoverage {
    final rows =
        _grades.map((grade) {
          final sections =
              _sections.where((section) => section.gradeId == grade.id).toList()
                ..sort((left, right) {
                  return left.sectionName.compareTo(right.sectionName);
                });
          final mappedSubjects = _gradeSubjects
              .where((row) => _text(row['grade_id']) == grade.id)
              .toList();
          final assignedSubjects = _staffSubjects
              .where((row) => _text(row['grade_id']) == grade.id)
              .toList();
          final subjectIds = <String>{
            ...mappedSubjects.map((row) => _text(row['subject_id'])),
            ...assignedSubjects.map((row) => _text(row['subject_id'])),
          }..removeWhere((id) => id.isEmpty);

          final subjectRows =
              subjectIds.map((subjectId) {
                final subject = _subjectById(subjectId);
                final assignments =
                    assignedSubjects
                        .where((row) => _text(row['subject_id']) == subjectId)
                        .map(_assignmentFromRow)
                        .toList()
                      ..sort(
                        (left, right) =>
                            left.teacherName.compareTo(right.teacherName),
                      );
                final gradeSubject = _gradeSubjectFor(grade.id, subjectId);
                return _ClassSubjectRow(
                  subjectId: subjectId,
                  subjectName: _text(
                    subject['subject_name'],
                    fallback: 'Subject not found',
                  ),
                  subjectCode: _text(subject['subject_code']),
                  gradeSubjectId: _text(gradeSubject['id']),
                  assignments: assignments,
                );
              }).toList()..sort(
                (left, right) => left.subjectName.compareTo(right.subjectName),
              );

          return _ClassSubjectCoverage(
            grade: grade,
            sections: sections,
            subjects: subjectRows,
          );
        }).toList()..sort((left, right) {
          final order = left.grade.gradeNumber.compareTo(
            right.grade.gradeNumber,
          );
          if (order != 0) return order;
          return left.grade.gradeName.compareTo(right.grade.gradeName);
        });

    final query = _search.trim().toLowerCase();
    if (query.isEmpty || _workspaceView != 'Classes') return rows;
    return rows.where((row) => row.searchText.contains(query)).toList();
  }

  List<_TeacherSubjectLoad> get _teacherLoads {
    final grouped = <String, List<_SubjectAssignment>>{};
    for (final row in _staffSubjects) {
      final assignment = _assignmentFromRow(row);
      if (assignment.teacherId.isEmpty) continue;
      grouped.putIfAbsent(assignment.teacherId, () => []).add(assignment);
    }
    final loads =
        grouped.entries.map((entry) {
          final staff = _staffById(entry.key);
          final teacherName = _staffName(
            staff,
            fallback: entry.value.first.teacherName,
          );
          final assignments = entry.value
            ..sort((left, right) {
              final subjectOrder = left.subjectName.compareTo(
                right.subjectName,
              );
              if (subjectOrder != 0) return subjectOrder;
              return left.classLabel.compareTo(right.classLabel);
            });
          return _TeacherSubjectLoad(
            teacherId: entry.key,
            teacherName: teacherName,
            designation: staff?.designation ?? '',
            assignments: assignments,
          );
        }).toList()..sort(
          (left, right) => left.teacherName.compareTo(right.teacherName),
        );

    final query = _search.trim().toLowerCase();
    if (query.isEmpty || _workspaceView != 'Teachers') return loads;
    return loads.where((row) => row.searchText.contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cards = _directoryCards;
    return PrincipalDirectoryScaffold(
      title: 'Subjects Directory',
      subtitle: 'Catalog, class mappings, and teacher load in one workflow',
      loading: _loading,
      error: _error,
      onRefresh: _loadData,
      onAdd: () => _openSubjectEditor(),
      addTooltip: 'Create subject',
      filters: _buildDirectoryFilters(),
      isEmpty: !_loading && _error == null && cards.isEmpty,
      emptyState: const EmptyStateWidget(
        icon: Icons.menu_book_rounded,
        title: 'No subject rows found',
        description: 'Create a subject or adjust the directory filters.',
      ),
      slivers: [
        SliverToBoxAdapter(
          child: PrincipalDirectoryMetricStrip(
            metrics: [
              PrincipalDirectoryMetric(
                label: 'Subjects',
                value: '${_int(_summary['total_subjects'])}',
                icon: Icons.menu_book_rounded,
                color: AppTheme.primary,
                tone: const Color(0xFFEFF6FF),
              ),
              PrincipalDirectoryMetric(
                label: 'Classes Mapped',
                value: '${_int(_summary['classes_covered_count'])}',
                icon: Icons.apartment_rounded,
                color: AppTheme.success,
                tone: const Color(0xFFECFDF3),
              ),
              PrincipalDirectoryMetric(
                label: 'Teachers',
                value: '${_int(_summary['assigned_teacher_count'])}',
                icon: Icons.groups_rounded,
                color: AppTheme.warning,
                tone: const Color(0xFFFFF7ED),
              ),
              PrincipalDirectoryMetric(
                label: 'Syllabus Pending',
                value:
                    '${_num(_summary['average_pending_syllabus']).toStringAsFixed(0)}%',
                icon: Icons.track_changes_rounded,
                color: AppTheme.error,
                tone: const Color(0xFFFEEFEE),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
          sliver: SliverList.builder(
            itemCount: cards.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: cards[index],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            child: _buildAnalyticsSection(),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectoryFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
      child: Column(
        children: [
          PrincipalDirectorySearchBox(
            hint: 'Search class, subject, or teacher...',
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                for (final option in const [
                  ('Classes', Icons.apartment_rounded),
                  ('Subjects', Icons.menu_book_rounded),
                  ('Teachers', Icons.groups_rounded),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PrincipalDirectoryChip(
                      label: option.$1,
                      icon: option.$2,
                      selected: _workspaceView == option.$1,
                      onTap: () => setState(() => _workspaceView = option.$1),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: PrincipalDirectoryChip(
                    label: 'Map Class / Teacher',
                    icon: Icons.account_tree_rounded,
                    selected: false,
                    onTap: () => _openMappingEditor(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> get _directoryCards {
    return switch (_workspaceView) {
      'Subjects' => [
        for (final subject in _filteredSubjects)
          _buildSubjectDirectoryTile(subject),
      ],
      'Teachers' => [
        for (final load in _teacherLoads) _buildTeacherDirectoryTile(load),
      ],
      _ => [
        for (final coverage in _classCoverage)
          _buildClassCoverageDirectoryTile(coverage),
      ],
    };
  }

  Widget _buildSubjectDirectoryTile(Map<String, dynamic> subject) {
    final subjectId = _text(subject['subject_id'] ?? subject['id']);
    final gradeRows = _gradeSubjects
        .where((row) => _text(row['subject_id']) == subjectId)
        .toList();
    final assignments = _staffSubjects
        .where((row) => _text(row['subject_id']) == subjectId)
        .map(_assignmentFromRow)
        .toList();
    final teacherCount = assignments
        .map((assignment) => assignment.teacherId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
    return PrincipalDirectoryCard(
      icon: Icons.menu_book_outlined,
      title: _text(subject['subject_name'], fallback: 'Subject'),
      subtitle:
          '${_text(subject['subject_code'], fallback: 'No code')} | ${_text(subject['department'], fallback: 'Academics')}',
      status: gradeRows.isEmpty ? 'Unmapped' : 'Mapped',
      statusColor: gradeRows.isEmpty ? AppTheme.warning : AppTheme.success,
      chips: [
        PrincipalInfoPill(
          icon: Icons.apartment_rounded,
          label: '${gradeRows.length} classes',
        ),
        PrincipalInfoPill(
          icon: Icons.groups_rounded,
          label: '$teacherCount teachers',
        ),
        PrincipalInfoPill(
          icon: Icons.category_outlined,
          label: _text(subject['subject_type'], fallback: 'core'),
        ),
      ],
      trailing: PopupMenuButton<String>(
        tooltip: 'Subject options',
        onSelected: (value) => _handleSubjectAction(value, subject),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'assign', child: Text('Map / assign')),
          PopupMenuItem(value: 'edit', child: Text('Edit subject')),
          PopupMenuItem(value: 'delete', child: Text('Delete subject')),
        ],
      ),
      onTap: () => _openSubjectDetail(subject),
    );
  }

  Widget _buildClassCoverageDirectoryTile(_ClassSubjectCoverage coverage) {
    return PrincipalDirectoryCard(
      icon: Icons.apartment_rounded,
      title: coverage.grade.gradeName,
      subtitle: coverage.sectionSummary,
      status: coverage.subjects.isEmpty ? 'Needs mapping' : 'Mapped',
      statusColor: coverage.subjects.isEmpty
          ? AppTheme.warning
          : AppTheme.success,
      chips: [
        PrincipalInfoPill(
          icon: Icons.menu_book_outlined,
          label: '${coverage.subjects.length} subjects',
        ),
        PrincipalInfoPill(
          icon: Icons.groups_rounded,
          label: coverage.teacherSummary,
        ),
      ],
      trailing: IconButton(
        tooltip: 'Add Subject / Teacher',
        icon: const Icon(Icons.add_rounded),
        onPressed: () => _openMappingEditor(initialGradeId: coverage.grade.id),
      ),
      onTap: () => _openClassCoverageDetail(coverage),
    );
  }

  Widget _buildTeacherDirectoryTile(_TeacherSubjectLoad load) {
    return PrincipalDirectoryCard(
      icon: Icons.badge_outlined,
      title: load.teacherName,
      subtitle: load.designation.isEmpty ? 'Teacher load' : load.designation,
      status: '${load.subjectCount} subjects',
      statusColor: load.subjectCount == 0 ? AppTheme.warning : AppTheme.primary,
      chips: [
        PrincipalInfoPill(
          icon: Icons.apartment_rounded,
          label: '${load.classCount} classes',
        ),
        if (load.assignments.isNotEmpty)
          PrincipalInfoPill(
            icon: Icons.menu_book_outlined,
            label: load.assignments.first.subjectName,
          ),
      ],
      trailing: IconButton(
        tooltip: 'Assign subject',
        icon: const Icon(Icons.add_rounded),
        onPressed: () => _openMappingEditor(initialTeacherId: load.teacherId),
      ),
      onTap: () => _openTeacherLoadDetail(load),
    );
  }

  Future<void> _handleSubjectAction(
    String action,
    Map<String, dynamic> subject,
  ) async {
    final subjectId = _text(subject['subject_id'] ?? subject['id']);
    switch (action) {
      case 'assign':
        await _openMappingEditor(initialSubjectId: subjectId);
        break;
      case 'edit':
        await _openSubjectEditor(subject: subject);
        break;
      case 'delete':
        await _deleteSubject(subject);
        break;
    }
  }

  Future<void> _openSubjectDetail(
    Map<String, dynamic> subject, [
    List<Map<String, dynamic>>? gradeRowsOverride,
    List<_SubjectAssignment>? assignmentsOverride,
  ]) async {
    final subjectId = _text(subject['subject_id'] ?? subject['id']);
    final gradeRows =
        gradeRowsOverride ??
        _gradeSubjects
            .where((row) => _text(row['subject_id']) == subjectId)
            .toList();
    final assignments =
        assignmentsOverride ??
        _staffSubjects
            .where((row) => _text(row['subject_id']) == subjectId)
            .map(_assignmentFromRow)
            .toList();
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (detailContext) => PrincipalDetailPage(
          title: _text(subject['subject_name'], fallback: 'Subject Details'),
          menuItems: const [
            PopupMenuItem(value: 'assign', child: Text('Map / assign')),
            PopupMenuItem(value: 'edit', child: Text('Edit subject')),
            PopupMenuItem(value: 'delete', child: Text('Delete subject')),
          ],
          onMenuSelected: (value) => Navigator.pop(detailContext, value),
          children: [
            PrincipalDetailCard(
              title: 'Subject Profile',
              trailing: PrincipalStatusPill(
                label: gradeRows.isEmpty ? 'Unmapped' : 'Mapped',
                color: gradeRows.isEmpty ? AppTheme.warning : AppTheme.success,
              ),
              children: [
                PrincipalDetailRow(
                  label: 'Code',
                  value: _text(subject['subject_code'], fallback: '-'),
                ),
                PrincipalDetailRow(
                  label: 'Department',
                  value: _text(subject['department'], fallback: 'Academics'),
                ),
                PrincipalDetailRow(
                  label: 'Type',
                  value: _text(subject['subject_type'], fallback: 'core'),
                ),
                PrincipalDetailRow(
                  label: 'Credits',
                  value: _num(subject['credit_hours']).toStringAsFixed(0),
                ),
              ],
            ),
            PrincipalDetailCard(
              title: 'Class Coverage',
              children: gradeRows.isEmpty
                  ? const [Text('No class mappings yet.')]
                  : [
                      for (final row in gradeRows)
                        PrincipalActionTile(
                          icon: Icons.apartment_rounded,
                          title: _gradeName(_text(row['grade_id'])),
                          subtitle:
                              '${_int(row['periods_per_week'])} periods per week',
                        ),
                    ],
            ),
            PrincipalDetailCard(
              title: 'Teacher Assignments',
              children: assignments.isEmpty
                  ? const [Text('No teachers assigned yet.')]
                  : [
                      for (final assignment in assignments)
                        PrincipalActionTile(
                          icon: Icons.badge_outlined,
                          title: assignment.teacherName,
                          subtitle: assignment.classLabel,
                          onTap: () => Navigator.pop(detailContext, 'assign'),
                        ),
                    ],
            ),
            PrincipalDetailCard(
              title: 'Actions',
              children: [
                PrincipalActionTile(
                  icon: Icons.account_tree_rounded,
                  title: 'Map / assign',
                  subtitle: 'Attach this subject to classes and teachers',
                  onTap: () => Navigator.pop(detailContext, 'assign'),
                ),
                PrincipalActionTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit subject',
                  subtitle: 'Update name, code, department, or credits',
                  onTap: () => Navigator.pop(detailContext, 'edit'),
                ),
                PrincipalActionTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete subject',
                  subtitle: 'Backend blocks deletion when linked records exist',
                  color: AppTheme.error,
                  onTap: () => Navigator.pop(detailContext, 'delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    await _handleSubjectAction(action, subject);
  }

  Future<void> _openClassCoverageDetail(_ClassSubjectCoverage coverage) async {
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (detailContext) => PrincipalDetailPage(
          title: coverage.grade.gradeName,
          menuItems: const [
            PopupMenuItem(
              value: 'assign',
              child: Text('Add Subject / Teacher'),
            ),
          ],
          onMenuSelected: (value) => Navigator.pop(detailContext, value),
          children: [
            PrincipalDetailCard(
              title: 'Class Coverage',
              trailing: PrincipalStatusPill(
                label: coverage.subjects.isEmpty ? 'Needs mapping' : 'Mapped',
                color: coverage.subjects.isEmpty
                    ? AppTheme.warning
                    : AppTheme.success,
              ),
              children: [
                PrincipalDetailRow(
                  label: 'Sections',
                  value: coverage.sectionSummary,
                ),
                PrincipalDetailRow(
                  label: 'Teachers',
                  value: coverage.teacherSummary,
                ),
                PrincipalDetailRow(
                  label: 'Subjects',
                  value: '${coverage.subjects.length}',
                ),
              ],
            ),
            PrincipalDetailCard(
              title: 'Subjects',
              children: coverage.subjects.isEmpty
                  ? const [Text('No subjects mapped to this class yet.')]
                  : [
                      for (final subject in coverage.subjects)
                        PrincipalActionTile(
                          icon: Icons.menu_book_outlined,
                          title: subject.subjectName,
                          subtitle: subject.teacherSummary,
                          onTap: () => Navigator.pop(detailContext, 'assign'),
                        ),
                    ],
            ),
            PrincipalDetailCard(
              title: 'Actions',
              children: [
                PrincipalActionTile(
                  icon: Icons.add_rounded,
                  title: 'Add Subject / Teacher',
                  subtitle: 'Open the mapping input screen for this class',
                  onTap: () => Navigator.pop(detailContext, 'assign'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mounted || action != 'assign') return;
    await _openMappingEditor(initialGradeId: coverage.grade.id);
  }

  Future<void> _openTeacherLoadDetail(_TeacherSubjectLoad load) async {
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (detailContext) => PrincipalDetailPage(
          title: load.teacherName,
          menuItems: const [
            PopupMenuItem(value: 'assign', child: Text('Assign subject')),
          ],
          onMenuSelected: (value) => Navigator.pop(detailContext, value),
          children: [
            PrincipalDetailCard(
              title: 'Teacher Load',
              trailing: PrincipalStatusPill(
                label: '${load.subjectCount} subjects',
                color: load.subjectCount == 0
                    ? AppTheme.warning
                    : AppTheme.primary,
              ),
              children: [
                PrincipalDetailRow(
                  label: 'Designation',
                  value: load.designation.isEmpty ? '-' : load.designation,
                ),
                PrincipalDetailRow(
                  label: 'Classes',
                  value: '${load.classCount}',
                ),
                PrincipalDetailRow(
                  label: 'Subjects',
                  value: '${load.subjectCount}',
                ),
              ],
            ),
            PrincipalDetailCard(
              title: 'Assignments',
              children: load.assignments.isEmpty
                  ? const [Text('No subject assignments yet.')]
                  : [
                      for (final assignment in load.assignments)
                        PrincipalActionTile(
                          icon: Icons.menu_book_outlined,
                          title: assignment.subjectName,
                          subtitle: assignment.classLabel,
                          onTap: () {
                            Navigator.pop(
                              detailContext,
                              'edit:${assignment.id}',
                            );
                          },
                        ),
                    ],
            ),
            PrincipalDetailCard(
              title: 'Actions',
              children: [
                PrincipalActionTile(
                  icon: Icons.add_rounded,
                  title: 'Assign subject',
                  subtitle: 'Open the mapping input screen for this teacher',
                  onTap: () => Navigator.pop(detailContext, 'assign'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'assign') {
      await _openMappingEditor(initialTeacherId: load.teacherId);
      return;
    }
    if (action.startsWith('edit:')) {
      final assignmentId = action.substring('edit:'.length);
      final assignment = load.assignments.firstWhere(
        (item) => item.id == assignmentId,
        orElse: () => load.assignments.first,
      );
      await _openMappingEditor(assignment: assignment);
    }
  }

  Future<void> _openSubjectEditor({Map<String, dynamic>? subject}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrincipalInputPage(
          title: _text(subject?['subject_id'] ?? subject?['id']).isEmpty
              ? 'Create Subject'
              : 'Edit Subject',
          icon: Icons.menu_book_rounded,
          child: _SubjectEditorSheet(subject: subject),
        ),
      ),
    );
    if (saved == true) {
      await _loadData();
    }
  }

  Future<void> _openMappingEditor({
    String initialGradeId = '',
    String initialSubjectId = '',
    String initialTeacherId = '',
    _SubjectAssignment? assignment,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrincipalInputPage(
          title: assignment == null
              ? 'Map Subject to Class'
              : 'Edit Teacher Assignment',
          icon: Icons.account_tree_rounded,
          child: _SubjectMappingSheet(
            subjects: _subjects,
            grades: _grades,
            sections: _sections,
            staff: _staff,
            gradeSubjects: _gradeSubjects,
            assignment: assignment,
            initialGradeId: initialGradeId,
            initialSubjectId: initialSubjectId,
            initialTeacherId: initialTeacherId,
          ),
        ),
      ),
    );
    if (saved == true) {
      await _loadData();
    }
  }

  Future<void> _deleteSubject(Map<String, dynamic> subject) async {
    final subjectId = _text(subject['subject_id'] ?? subject['id']);
    final subjectName = _text(subject['subject_name'], fallback: 'Subject');
    if (subjectId.isEmpty) return;
    final confirmed = await _confirm(
      title: 'Delete subject?',
      message:
          'Delete $subjectName only if it is not linked to classes, timetable, attendance, or exams.',
      actionLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await BackendApiClient.instance.deleteRaw('/subjects/$subjectId');
      await _loadData();
      _showSnack('$subjectName deleted');
    } catch (error) {
      _showSnack(
        'Unable to delete $subjectName. Remove class mappings and timetable links first.',
        error: true,
      );
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  Map<String, dynamic> _subjectById(String subjectId) {
    for (final subject in _subjects) {
      if (_text(subject['subject_id'] ?? subject['id']) == subjectId) {
        return subject;
      }
    }
    return {};
  }

  Map<String, dynamic> _gradeSubjectFor(String gradeId, String subjectId) {
    for (final row in _gradeSubjects) {
      if (_text(row['grade_id']) == gradeId &&
          _text(row['subject_id']) == subjectId) {
        return row;
      }
    }
    return {};
  }

  StaffModel? _staffById(String staffId) {
    for (final staff in _staff) {
      if (staff.id == staffId) return staff;
    }
    return null;
  }

  SectionModel? _sectionById(String sectionId) {
    for (final section in _sections) {
      if (section.id == sectionId) return section;
    }
    return null;
  }

  String _gradeName(String gradeId) {
    for (final grade in _grades) {
      if (grade.id == gradeId) return grade.gradeName;
    }
    for (final grade in _gradeOptions) {
      if (_text(grade['id']) == gradeId) {
        return _text(grade['name'], fallback: 'Class');
      }
    }
    return '';
  }

  _SubjectAssignment _assignmentFromRow(Map<String, dynamic> row) {
    final staffId = _text(row['staff_id']);
    final subjectId = _text(row['subject_id']);
    final gradeId = _text(row['grade_id']);
    final sectionId = _text(row['section_id']);
    final staff = _staffById(staffId);
    final section = _sectionById(sectionId);
    final subject = _subjectById(subjectId);
    final gradeName = _gradeName(gradeId);
    final sectionName = section?.sectionName ?? _sectionNameFromRow(row);
    return _SubjectAssignment(
      id: _text(row['id']),
      teacherId: staffId,
      teacherName: _staffName(
        staff,
        fallback: _text(
          _asMap(row['staff'])['name'] ??
              _asMap(row['staff'])['first_name'] ??
              row['teacher_name'],
          fallback: 'Teacher',
        ),
      ),
      subjectId: subjectId,
      subjectName: _text(subject['subject_name'], fallback: 'Subject'),
      gradeId: gradeId,
      gradeName: gradeName.isEmpty ? 'Class' : gradeName,
      sectionId: sectionId,
      sectionName: sectionName,
      isPrimary: row['is_primary'] == true,
    );
  }

  Widget _buildAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics',
          style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _AnalyticsListCard(
          title: 'Subject-wise Topper List',
          icon: Icons.workspace_premium_rounded,
          rows: _asListMap(_analytics['subject_toppers']),
          empty: 'No subject topper data yet.',
          labelBuilder: (row) =>
              '${_text(row['student_name'], fallback: 'Student')} - ${_num(row['score']).toStringAsFixed(0)}%',
          subLabelBuilder: (row) =>
              '${_text(row['class_name'], fallback: 'Class pending')} · ${_text(row['exam_name'], fallback: 'Exam')}',
        ),
        _AnalyticsListCard(
          title: 'Weak Subject Detection',
          icon: Icons.warning_amber_rounded,
          rows: _asListMap(_analytics['weak_subjects']),
          empty: 'No weak-subject signal found.',
          labelBuilder: (row) =>
              _text(row['subject_name'], fallback: 'Subject'),
          subLabelBuilder: (row) =>
              '${_num(row['value']).round()} weak score signal(s)',
        ),
        _AnalyticsListCard(
          title: 'Syllabus Completion Tracker',
          icon: Icons.track_changes_rounded,
          rows: _asListMap(_analytics['syllabus_completion_tracker']),
          empty: 'No syllabus tracker data yet.',
          labelBuilder: (row) =>
              _text(row['subject_name'], fallback: 'Subject'),
          subLabelBuilder: (row) =>
              '${_num(row['completion_percent']).round()}% complete · ${_int(row['topics_completed'])}/${_int(row['topics_total'])} topics',
        ),
        _AnalyticsListCard(
          title: 'Teacher Performance',
          icon: Icons.groups_3_rounded,
          rows: _asListMap(_analytics['teacher_performance']),
          empty: 'No teacher performance data yet.',
          labelBuilder: (row) =>
              _text(row['teacher_name'], fallback: 'Teacher not assigned'),
          subLabelBuilder: (row) =>
              '${_text(row['subject_name'], fallback: 'Subject')} · Avg ${_num(row['average_student_score']).toStringAsFixed(0)}%',
        ),
        _AnalyticsListCard(
          title: 'Homework Consistency',
          icon: Icons.assignment_turned_in_rounded,
          rows: _asListMap(_analytics['homework_consistency']),
          empty: 'No homework consistency data yet.',
          labelBuilder: (row) =>
              _text(row['subject_name'], fallback: 'Subject'),
          subLabelBuilder: (row) =>
              '${_num(row['consistency']).round()}% consistency · ${_int(row['homework_pending'])} pending',
        ),
      ],
    );
  }
}

class _ClassSubjectCoverage {
  final GradeModel grade;
  final List<SectionModel> sections;
  final List<_ClassSubjectRow> subjects;

  const _ClassSubjectCoverage({
    required this.grade,
    required this.sections,
    required this.subjects,
  });

  String get sectionSummary {
    if (sections.isEmpty) return 'No sections created';
    return sections
        .map((section) => 'Section ${section.sectionName}')
        .join(', ');
  }

  String get teacherSummary {
    final names =
        subjects
            .expand((subject) => subject.assignments)
            .map((assignment) => assignment.teacherName)
            .where((name) => name.isNotEmpty && name != 'Teacher')
            .toSet()
            .toList()
          ..sort();
    if (names.isEmpty) return 'Teachers not assigned';
    return names.join(', ');
  }

  String get searchText => [
    grade.gradeName,
    sectionSummary,
    teacherSummary,
    subjects.map((subject) => subject.searchText).join(' '),
  ].join(' ').toLowerCase();
}

class _ClassSubjectRow {
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final String gradeSubjectId;
  final List<_SubjectAssignment> assignments;

  const _ClassSubjectRow({
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.gradeSubjectId,
    required this.assignments,
  });

  String get teacherSummary {
    final names =
        assignments
            .map((assignment) => assignment.teacherName)
            .where((name) => name.isNotEmpty && name != 'Teacher')
            .toSet()
            .toList()
          ..sort();
    return names.isEmpty ? 'Teacher not assigned' : names.join(', ');
  }

  String get searchText => [
    subjectName,
    subjectCode,
    teacherSummary,
    assignments.map((assignment) => assignment.classLabel).join(' '),
  ].join(' ').toLowerCase();
}

class _SubjectAssignment {
  final String id;
  final String teacherId;
  final String teacherName;
  final String subjectId;
  final String subjectName;
  final String gradeId;
  final String gradeName;
  final String sectionId;
  final String sectionName;
  final bool isPrimary;

  const _SubjectAssignment({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.subjectId,
    required this.subjectName,
    required this.gradeId,
    required this.gradeName,
    required this.sectionId,
    required this.sectionName,
    required this.isPrimary,
  });

  String get classLabel {
    if (sectionName.trim().isEmpty) return gradeName;
    return '$gradeName - $sectionName';
  }
}

class _TeacherSubjectLoad {
  final String teacherId;
  final String teacherName;
  final String designation;
  final List<_SubjectAssignment> assignments;

  const _TeacherSubjectLoad({
    required this.teacherId,
    required this.teacherName,
    required this.designation,
    required this.assignments,
  });

  int get subjectCount =>
      assignments.map((assignment) => assignment.subjectId).toSet().length;

  int get classCount =>
      assignments.map((assignment) => assignment.classLabel).toSet().length;

  String get searchText => [
    teacherName,
    designation,
    assignments.map((assignment) => assignment.subjectName).join(' '),
    assignments.map((assignment) => assignment.classLabel).join(' '),
  ].join(' ').toLowerCase();
}

class _SubjectEditorSheet extends StatefulWidget {
  final Map<String, dynamic>? subject;

  const _SubjectEditorSheet({this.subject});

  @override
  State<_SubjectEditorSheet> createState() => _SubjectEditorSheetState();
}

class _SubjectEditorSheetState extends State<_SubjectEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _departmentController;
  late final TextEditingController _typeController;
  late final TextEditingController _creditController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final subject = widget.subject ?? {};
    _nameController = TextEditingController(
      text: _text(subject['subject_name']),
    );
    _codeController = TextEditingController(
      text: _text(subject['subject_code']),
    );
    _departmentController = TextEditingController(
      text: _text(subject['department'], fallback: 'Academics'),
    );
    _typeController = TextEditingController(
      text: _text(subject['subject_type'], fallback: 'core'),
    );
    _creditController = TextEditingController(
      text: _num(subject['credit_hours']).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _departmentController.dispose();
    _typeController.dispose();
    _creditController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = {
      'subject_name': _nameController.text.trim(),
      'subject_code': _codeController.text.trim(),
      'subject_type': _typeController.text.trim().isEmpty
          ? 'core'
          : _typeController.text.trim(),
      'department_name': _departmentController.text.trim().isEmpty
          ? 'Academics'
          : _departmentController.text.trim(),
      'credit_hours': double.tryParse(_creditController.text.trim()) ?? 0,
      'subject_color': _text(widget.subject?['subject_color']),
    };
    try {
      final id = _text(widget.subject?['subject_id'] ?? widget.subject?['id']);
      if (id.isEmpty) {
        await BackendApiClient.instance.createRaw('/subjects', payload);
      } else {
        await BackendApiClient.instance.updateRaw('/subjects/$id', payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = _text(
      widget.subject?['subject_id'] ?? widget.subject?['id'],
    ).isNotEmpty;
    return _SheetFrame(
      title: editing ? 'Edit Subject' : 'Create Subject',
      icon: Icons.menu_book_rounded,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Subject Name'),
              validator: (value) =>
                  _text(value).isEmpty ? 'Enter subject name' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codeController,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Code'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _typeController,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Type'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _departmentController,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Department'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _creditController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Credits'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GoogleFonts.dmSans(
                  color: AppTheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : 'Save Subject'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectMappingSheet extends StatefulWidget {
  final List<Map<String, dynamic>> subjects;
  final List<GradeModel> grades;
  final List<SectionModel> sections;
  final List<StaffModel> staff;
  final List<Map<String, dynamic>> gradeSubjects;
  final _SubjectAssignment? assignment;
  final String initialGradeId;
  final String initialSubjectId;
  final String initialTeacherId;

  const _SubjectMappingSheet({
    required this.subjects,
    required this.grades,
    required this.sections,
    required this.staff,
    required this.gradeSubjects,
    this.assignment,
    this.initialGradeId = '',
    this.initialSubjectId = '',
    this.initialTeacherId = '',
  });

  @override
  State<_SubjectMappingSheet> createState() => _SubjectMappingSheetState();
}

class _SubjectMappingSheetState extends State<_SubjectMappingSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _periodsController;
  String _subjectId = '';
  String _gradeId = '';
  String _sectionId = '';
  String _teacherId = '';
  bool _isPrimary = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final assignment = widget.assignment;
    _subjectId = assignment?.subjectId ?? widget.initialSubjectId;
    _gradeId = assignment?.gradeId ?? widget.initialGradeId;
    _sectionId = assignment?.sectionId ?? '';
    _teacherId = assignment?.teacherId ?? widget.initialTeacherId;
    _isPrimary = assignment?.isPrimary ?? true;
    final gradeSubject = _existingGradeSubject(_gradeId, _subjectId);
    _periodsController = TextEditingController(
      text: _int(gradeSubject['periods_per_week']).toString(),
    );
  }

  @override
  void dispose() {
    _periodsController.dispose();
    super.dispose();
  }

  List<SectionModel> get _availableSections {
    return widget.sections
        .where((section) => section.gradeId == _gradeId)
        .toList()
      ..sort((left, right) => left.sectionName.compareTo(right.sectionName));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final assignmentId = widget.assignment?.id ?? '';
      if (_teacherId.isEmpty && assignmentId.isNotEmpty) {
        throw Exception('Select teacher for an existing assignment.');
      }
      await BackendApiClient.instance.savePrincipalSubjectMapping(
        subjectId: _subjectId,
        gradeId: _gradeId,
        sectionId: _sectionId,
        teacherId: _teacherId,
        assignmentId: assignmentId,
        periodsPerWeek: int.tryParse(_periodsController.text.trim()) ?? 0,
        isPrimary: _isPrimary,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  Map<String, dynamic> _existingGradeSubject(String gradeId, String subjectId) {
    for (final row in widget.gradeSubjects) {
      if (_text(row['grade_id']) == gradeId &&
          _text(row['subject_id']) == subjectId) {
        return row;
      }
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: widget.assignment == null
          ? 'Map Subject to Class'
          : 'Edit Teacher Assignment',
      icon: Icons.account_tree_rounded,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _subjectId.isEmpty ? null : _subjectId,
              decoration: const InputDecoration(labelText: 'Subject'),
              items: widget.subjects.map((subject) {
                final id = _text(subject['subject_id'] ?? subject['id']);
                return DropdownMenuItem(
                  value: id,
                  child: Text(
                    _text(subject['subject_name'], fallback: 'Subject'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              validator: (value) =>
                  _text(value).isEmpty ? 'Select subject' : null,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _subjectId = value ?? ''),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _gradeId.isEmpty ? null : _gradeId,
              decoration: const InputDecoration(labelText: 'Class'),
              items: widget.grades
                  .map(
                    (grade) => DropdownMenuItem(
                      value: grade.id,
                      child: Text(
                        grade.gradeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              validator: (value) =>
                  _text(value).isEmpty ? 'Select class' : null,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _gradeId = value ?? '';
                      _sectionId = '';
                    }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _sectionId,
              decoration: const InputDecoration(
                labelText: 'Section',
                helperText: 'Choose All sections or a specific section.',
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('All sections')),
                ..._availableSections.map(
                  (section) => DropdownMenuItem(
                    value: section.id,
                    child: Text('Section ${section.sectionName}'),
                  ),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _sectionId = value ?? ''),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _teacherId,
              decoration: const InputDecoration(
                labelText: 'Teacher / Staff',
                helperText: 'Optional. Leave empty to map subject only.',
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Teacher not assigned yet'),
                ),
                ...widget.staff.map(
                  (staff) => DropdownMenuItem(
                    value: staff.id,
                    child: Text(
                      _staffName(staff),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _teacherId = value ?? ''),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _periodsController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Periods / Week',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Primary',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                    ),
                    value: _isPrimary,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _isPrimary = value),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GoogleFonts.dmSans(
                  color: AppTheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : 'Save Mapping'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SheetFrame({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 16,
        bottom:
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD3DEE8),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(icon, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class SubjectCommandCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ValueChanged<String> onAction;

  const SubjectCommandCard({
    super.key,
    required this.data,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final teachers = _asListMap(data['assigned_teachers']);
    final classes = _asListMap(data['classes_covered']);
    final coverage = _asListMap(data['teacher_class_coverage']).isEmpty
        ? _teacherCoverageFromAssignments(teachers)
        : _asListMap(data['teacher_class_coverage']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBD4FF)),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(data['subject_name'], fallback: 'Subject'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        _text(data['department'], fallback: 'General'),
                        _text(data['subject_type']),
                        _text(data['subject_code']),
                      ].where((value) => value.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InlineInfo(
            icon: Icons.groups_rounded,
            label: 'Assigned Teachers',
            value: coverage.isEmpty
                ? 'Not assigned'
                : coverage
                      .map(
                        (row) =>
                            _text(row['teacher_name'], fallback: 'Teacher'),
                      )
                      .take(3)
                      .join(', '),
          ),
          const SizedBox(height: 8),
          _InlineInfo(
            icon: Icons.meeting_room_rounded,
            label: 'Classes Covered',
            value: classes.isEmpty
                ? 'Not mapped'
                : classes
                      .map((row) => _text(row['name'], fallback: 'Class'))
                      .take(4)
                      .join(', '),
          ),
          if (coverage.isNotEmpty) ...[
            const SizedBox(height: 10),
            _TeacherClassCoverageList(rows: coverage),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 360;
              final width = narrow
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricTile(
                    width: width,
                    icon: Icons.trending_up_rounded,
                    label: 'Avg Score',
                    value:
                        '${_num(data['average_student_score']).toStringAsFixed(0)}%',
                    tone: const Color(0xFFEFF6FF),
                    color: AppTheme.primary,
                  ),
                  _MetricTile(
                    width: width,
                    icon: Icons.track_changes_rounded,
                    label: 'Syllabus Pending',
                    value:
                        '${_num(data['pending_syllabus_percent']).toStringAsFixed(0)}%',
                    tone: const Color(0xFFFFF7ED),
                    color: AppTheme.warning,
                  ),
                  _MetricTile(
                    width: width,
                    icon: Icons.assignment_turned_in_rounded,
                    label: 'Homework',
                    value:
                        '${_num(data['homework_consistency']).toStringAsFixed(0)}%',
                    tone: const Color(0xFFECFDF3),
                    color: AppTheme.success,
                  ),
                  _MetricTile(
                    width: width,
                    icon: Icons.warning_amber_rounded,
                    label: 'Weak Signals',
                    value: '${_int(data['weak_student_count'])}',
                    tone: const Color(0xFFFEEFEE),
                    color: AppTheme.error,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                label: 'Map Teacher to Class',
                icon: Icons.switch_account_rounded,
                onTap: () => onAction('assign_teacher'),
              ),
              _ActionButton(
                label: 'Review Subject Reports',
                icon: Icons.bar_chart_rounded,
                onTap: () => onAction('review_reports'),
              ),
              _ActionButton(
                label: 'Schedule Meetings',
                icon: Icons.event_available_rounded,
                onTap: () => onAction('schedule_meeting'),
              ),
              _ActionButton(
                label: 'View Teaching Materials',
                icon: Icons.folder_open_rounded,
                onTap: () => onAction('view_materials'),
              ),
              _ActionButton(
                label: 'Assign Corrective Action',
                icon: Icons.task_alt_rounded,
                onTap: () => onAction('corrective_action'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InlineInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1F2937),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              color: AppTheme.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _TeacherClassCoverageList extends StatelessWidget {
  final List<Map<String, dynamic>> rows;

  const _TeacherClassCoverageList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD7E6F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Teacher-Class Mapping',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows.take(4).map((row) {
            final classSummary = _teacherClassSummary(row);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_int(row['class_count'])}',
                      style: GoogleFonts.dmSans(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _text(row['teacher_name'], fallback: 'Teacher'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFF111827),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          classSummary.isEmpty
                              ? 'No class mapped'
                              : classSummary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: AppTheme.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color tone;
  final Color color;

  const _MetricTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primary,
        side: const BorderSide(color: Color(0xFF99B8FF)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _AnalyticsListCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> rows;
  final String empty;
  final String Function(Map<String, dynamic>) labelBuilder;
  final String Function(Map<String, dynamic>) subLabelBuilder;

  const _AnalyticsListCard({
    required this.title,
    required this.icon,
    required this.rows,
    required this.empty,
    required this.labelBuilder,
    required this.subLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              empty,
              style: GoogleFonts.dmSans(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...rows
                .take(6)
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                labelBuilder(row),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subLabelBuilder(row),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: AppTheme.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class SubjectActionSheet extends StatefulWidget {
  final Map<String, dynamic> subject;
  final String actionType;
  final List<Map<String, dynamic>> teacherOptions;
  final List<Map<String, dynamic>> gradeOptions;

  const SubjectActionSheet({
    super.key,
    required this.subject,
    required this.actionType,
    required this.teacherOptions,
    required this.gradeOptions,
  });

  @override
  State<SubjectActionSheet> createState() => SubjectActionSheetState();
}

class SubjectActionSheetState extends State<SubjectActionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _messageController;
  String _teacherId = '';
  String _gradeId = '';
  String _priority = 'normal';
  bool _saving = false;
  String? _error;

  bool get _isTeacherAssignment => widget.actionType == 'assign_teacher';

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: _defaultMessage(widget.actionType),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.createPrincipalSubjectAction(
        subjectId: _text(widget.subject['subject_id']),
        actionType: widget.actionType,
        title: _actionTitle(widget.actionType),
        message: _messageController.text.trim(),
        priority: _priority,
        teacherId: _teacherId,
        gradeId: _gradeId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 16,
        bottom:
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3DEE8),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.task_alt_rounded, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _actionTitle(widget.actionType),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _text(widget.subject['subject_name'], fallback: 'Subject'),
                style: GoogleFonts.dmSans(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_isTeacherAssignment) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _teacherId.isEmpty ? null : _teacherId,
                  decoration: const InputDecoration(labelText: 'Teacher'),
                  items: widget.teacherOptions
                      .map(
                        (teacher) => DropdownMenuItem(
                          value: _text(teacher['id']),
                          child: Text(
                            _text(teacher['name'], fallback: 'Teacher'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  validator: (value) => _isTeacherAssignment
                      ? _required(value, 'Select teacher')
                      : null,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _teacherId = value ?? ''),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _gradeId.isEmpty ? null : _gradeId,
                  decoration: const InputDecoration(labelText: 'Class / Grade'),
                  items: widget.gradeOptions
                      .map(
                        (grade) => DropdownMenuItem(
                          value: _text(grade['id']),
                          child: Text(
                            _text(grade['name'], fallback: 'Class'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  validator: (value) => _isTeacherAssignment
                      ? _required(value, 'Select class')
                      : null,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _gradeId = value ?? ''),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _priority = value ?? 'normal'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageController,
                enabled: !_saving,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Instruction'),
                validator: (value) => _required(value, 'Enter instruction'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.dmSans(
                    color: AppTheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Saving...' : 'Save Action'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _defaultMessage(String actionType) {
    final subject = _text(widget.subject['subject_name'], fallback: 'subject');
    switch (actionType) {
      case 'assign_teacher':
        return 'Map the selected teacher to a class for $subject and monitor coverage in the next review.';
      case 'review_reports':
        return 'Review marks, weak areas, and class-wise performance for $subject.';
      case 'schedule_meeting':
        return 'Schedule a review meeting for $subject faculty and agree corrective actions.';
      case 'view_materials':
        return 'Review teaching materials and lesson readiness for $subject.';
      default:
        return 'Create a corrective action plan for $subject and track progress.';
    }
  }

  static String _actionTitle(String actionType) {
    switch (actionType) {
      case 'assign_teacher':
        return 'Map Teacher to Class';
      case 'review_reports':
        return 'Review Subject Reports';
      case 'schedule_meeting':
        return 'Schedule Meeting';
      case 'view_materials':
        return 'View Teaching Materials';
      default:
        return 'Assign Corrective Action';
    }
  }

  static String? _required(String? value, String message) {
    if ((value ?? '').trim().isEmpty) return message;
    return null;
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry('$key', val));
  }
  return {};
}

List<Map<String, dynamic>> _asListMap(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => item.map((key, val) => MapEntry('$key', val)))
        .toList();
  }
  return [];
}

List<Map<String, dynamic>> _teacherCoverageFromAssignments(
  List<Map<String, dynamic>> teachers,
) {
  final grouped = <String, Map<String, dynamic>>{};
  for (final teacher in teachers) {
    final teacherId = _text(
      teacher['id'] ?? teacher['teacher_id'] ?? teacher['staff_id'],
    );
    final teacherName = _text(
      teacher['name'] ?? teacher['teacher_name'],
      fallback: 'Teacher',
    );
    final key = teacherId.isNotEmpty ? teacherId : teacherName;
    final row = grouped.putIfAbsent(
      key,
      () => {
        'teacher_id': teacherId,
        'teacher_name': teacherName,
        'classes': <Map<String, dynamic>>[],
        'class_names': <String>[],
        'class_count': 0,
      },
    );
    final gradeId = _text(teacher['grade_id']);
    final className = _text(
      teacher['grade_name'] ?? teacher['class_name'],
      fallback: 'Class',
    );
    final names = row['class_names'] as List<String>;
    if (className.isNotEmpty && !names.contains(className)) {
      names.add(className);
      (row['classes'] as List<Map<String, dynamic>>).add({
        'grade_id': gradeId,
        'class_name': className,
      });
      row['class_count'] = names.length;
      row['class_summary'] = names.join(', ');
    }
  }
  return grouped.values.toList();
}

String _teacherClassSummary(Map<String, dynamic> row) {
  final summary = _text(row['class_summary']);
  if (summary.isNotEmpty) return summary;
  final names = row['class_names'];
  if (names is List) {
    return names
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .join(', ');
  }
  final classes = _asListMap(row['classes']);
  return classes
      .map((item) => _text(item['class_name'] ?? item['name']))
      .where((item) => item.isNotEmpty)
      .join(', ');
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _staffName(StaffModel? staff, {String fallback = 'Staff'}) {
  if (staff == null) return fallback;
  final fullName = staff.fullName.trim();
  if (fullName.isNotEmpty) return fullName;
  final email = _text(staff.email);
  if (email.isNotEmpty) return email;
  final code = _text(staff.staffCode);
  if (code.isNotEmpty) return code;
  return fallback;
}

String _sectionNameFromRow(Map<String, dynamic> row) {
  final section = _asMap(row['section']);
  return _text(
    section['section_name'] ?? section['name'] ?? row['section_name'],
  );
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
