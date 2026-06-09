import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';
import 'package:schooldesk1/core/widgets/principal_directory_ui.dart';

class PrincipalSubjectsScreen extends StatefulWidget {
  const PrincipalSubjectsScreen({super.key});

  @override
  State<PrincipalSubjectsScreen> createState() =>
      _PrincipalSubjectsScreenState();
}

class _PrincipalSubjectsScreenState extends State<PrincipalSubjectsScreen> {
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
  String _workspaceView = 'Subjects';

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
    final activeSubjectIds = _activeSubjectIds;
    if (_activeGradeIds.isEmpty) return const [];
    final query = _search.trim().toLowerCase();
    return _subjects.where((row) {
      final subjectId = _text(row['subject_id'] ?? row['id']);
      if (!activeSubjectIds.contains(subjectId)) return false;
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
        _grades.where((grade) => _activeGradeIds.contains(grade.id)).map((
          grade,
        ) {
          final sections =
              _sections.where((section) => section.gradeId == grade.id).toList()
                ..sort((left, right) {
                  return left.sectionName.compareTo(right.sectionName);
                });
          final mappedSubjects = _activeGradeSubjects
              .where((row) => _text(row['grade_id']) == grade.id)
              .toList();
          final assignedSubjects = _activeStaffSubjects
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
    for (final row in _activeStaffSubjects) {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      bottomNavigationBar: const PrincipalShellBottomBar(),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0969FF),
          onRefresh: _loadData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _SubjectsDirectoryHeader(
                  title: _workspaceView == 'Subjects'
                      ? 'Subjects'
                      : 'Subjects Directory',
                  subtitle: _subjectsScopeLabel,
                  onFilter: _showViewFilterSheet,
                ),
              ),
              SliverToBoxAdapter(child: _buildDirectoryFilters()),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyStateWidget(
                      icon: Icons.cloud_off_rounded,
                      title: 'Unable to load subjects',
                      description: _error!,
                      actionLabel: 'Retry',
                      onAction: _loadData,
                    ),
                  ),
                )
              else if (cards.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyStateWidget(
                      icon: Icons.menu_book_rounded,
                      title: _activeGradeIds.isEmpty
                          ? 'No active classes found'
                          : 'No subject rows found',
                      description: _activeGradeIds.isEmpty
                          ? 'Create classes in Class Hub, then map subjects and teachers.'
                          : 'Open a class in Class Hub for subject setup, or adjust the directory filters.',
                      actionLabel: 'Go to Classes Hub',
                      onAction: () => Navigator.pushNamed(
                        context,
                        AppRoutes.principalClasses,
                      ),
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(child: _buildMetricsStrip()),
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
                SliverToBoxAdapter(child: _buildClassHubCta()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    child: _buildAnalyticsSection(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Set<String> get _activeGradeIds =>
      _sections.map((section) => section.gradeId).toSet();

  Set<String> get _activeSectionIds =>
      _sections.map((section) => section.id).toSet();

  List<Map<String, dynamic>> get _activeGradeSubjects => _gradeSubjects
      .where((row) => _activeGradeIds.contains(_text(row['grade_id'])))
      .toList();

  List<Map<String, dynamic>> get _activeStaffSubjects =>
      _staffSubjects.where((row) {
        final gradeId = _text(row['grade_id']);
        final sectionId = _text(row['section_id']);
        return _activeGradeIds.contains(gradeId) &&
            (sectionId.isEmpty || _activeSectionIds.contains(sectionId));
      }).toList();

  Set<String> get _activeSubjectIds => {
    ..._activeGradeSubjects.map((row) => _text(row['subject_id'])),
    ..._activeStaffSubjects.map((row) => _text(row['subject_id'])),
  }..removeWhere((id) => id.isEmpty);

  String get _subjectsScopeLabel {
    if (_classCoverage.length == 1) {
      final coverage = _classCoverage.first;
      final section = coverage.sections.isEmpty
          ? ''
          : ' - ${coverage.sections.first.sectionName}';
      return '${coverage.grade.gradeName}$section';
    }
    if (_classCoverage.isEmpty) return 'No active class mappings';
    return '${_classCoverage.length} active classes';
  }

  Widget _buildMetricsStrip() {
    final activeSubjects = _filteredSubjects;
    final coreSubjects = activeSubjects.where((subject) {
      return _text(
            subject['subject_type'],
            fallback: 'core',
          ).toLowerCase().trim() ==
          'core';
    }).length;
    final teacherCount = _activeStaffSubjects
        .map((row) => _text(row['staff_id']))
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
      child: Row(
        children: [
          Expanded(
            child: _SubjectMetricCard(
              icon: Icons.menu_book_rounded,
              label: 'Total Subjects',
              value: '${activeSubjects.length}',
              color: const Color(0xFF0969FF),
              tone: const Color(0xFFEAF2FF),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SubjectMetricCard(
              icon: Icons.fact_check_rounded,
              label: 'Core Subjects',
              value: '$coreSubjects',
              color: const Color(0xFF21A85B),
              tone: const Color(0xFFE9F8EF),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SubjectMetricCard(
              icon: Icons.groups_rounded,
              label: 'Teachers',
              value: '$teacherCount',
              color: const Color(0xFFF09B22),
              tone: const Color(0xFFFFF3DE),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassHubCta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 2, 22, 24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0969FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.principalClasses),
              icon: const Icon(Icons.account_tree_outlined),
              label: Text(
                'Setup Subjects in Class Hub',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Subject creation, removal, and teacher assignment happen from the selected class.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: const Color(0xFF5E6C84),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
    final assignments = _activeStaffSubjects
        .where((row) => _text(row['subject_id']) == subjectId)
        .map(_assignmentFromRow)
        .toList();
    final primaryAssignment = _primaryAssignment(assignments);
    return _SubjectDirectoryTile(
      subjectName: _text(subject['subject_name'], fallback: 'Subject'),
      subjectCode: _text(subject['subject_code'], fallback: 'No code'),
      subjectType: _text(subject['subject_type'], fallback: 'core'),
      teacherName: primaryAssignment?.teacherName ?? 'Teacher not assigned',
      teacherRole: primaryAssignment == null ? '' : 'Main Teacher',
      trailing: IconButton(
        tooltip: 'Setup in Classes Hub',
        icon: const Icon(Icons.account_tree_outlined),
        onPressed: () => _handleSubjectAction('subjects', subject),
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
        tooltip: 'Setup subjects in Classes Hub',
        icon: const Icon(Icons.account_tree_outlined),
        onPressed: () => _openClassesHubForSubjects(gradeId: coverage.grade.id),
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
        tooltip: 'Open Classes Hub',
        icon: const Icon(Icons.account_tree_outlined),
        onPressed: _openClassesHubForSubjects,
      ),
      onTap: () => _openTeacherLoadDetail(load),
    );
  }

  Future<void> _handleSubjectAction(
    String action,
    Map<String, dynamic> subject,
  ) async {
    final subjectId = _text(subject['subject_id'] ?? subject['id']);
    _openClassesHubForSubjects(subjectId: subjectId);
  }

  Future<void> _openSubjectDetail(
    Map<String, dynamic> subject, [
    List<Map<String, dynamic>>? gradeRowsOverride,
    List<_SubjectAssignment>? assignmentsOverride,
  ]) async {
    final subjectId = _text(subject['subject_id'] ?? subject['id']);
    final gradeRows =
        gradeRowsOverride ??
        _activeGradeSubjects
            .where((row) => _text(row['subject_id']) == subjectId)
            .toList();
    final assignments =
        assignmentsOverride ??
        _activeStaffSubjects
            .where((row) => _text(row['subject_id']) == subjectId)
            .map(_assignmentFromRow)
            .toList();
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (detailContext) => _SubjectDetailScreen(
          subjectName: _text(subject['subject_name'], fallback: 'Subject'),
          subjectCode: _text(subject['subject_code'], fallback: '-'),
          subjectType: _text(subject['subject_type'], fallback: 'core'),
          credits: _num(subject['credit_hours']).toStringAsFixed(0),
          teacher: _primaryAssignment(assignments),
          weeklyPeriods: _weeklyPeriods(gradeRows),
          applicableClasses: _applicableClasses(gradeRows),
        ),
      ),
    );
    if (!mounted || action == null) return;
    await _handleSubjectAction(action, subject);
  }

  _SubjectAssignment? _primaryAssignment(List<_SubjectAssignment> assignments) {
    if (assignments.isEmpty) return null;
    final primary = assignments.where((assignment) => assignment.isPrimary);
    return primary.isEmpty ? assignments.first : primary.first;
  }

  String _weeklyPeriods(List<Map<String, dynamic>> gradeRows) {
    if (gradeRows.isEmpty) return '0';
    final periods =
        gradeRows
            .map((row) => _int(row['periods_per_week']))
            .where((value) => value > 0)
            .toSet()
            .toList()
          ..sort();
    if (periods.isEmpty) return '0';
    if (periods.length == 1) return '${periods.first}';
    return '${periods.first}-${periods.last}';
  }

  String _applicableClasses(List<Map<String, dynamic>> gradeRows) {
    final labels =
        gradeRows
            .map((row) => _gradeName(_text(row['grade_id'])))
            .where((name) => name.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (labels.isEmpty) return 'No active class';
    if (labels.length <= 2) return labels.join(', ');
    return '${labels.take(2).join(', ')} +${labels.length - 2}';
  }

  Future<void> _showViewFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SubjectViewSheet(
        selected: _workspaceView,
        onSelected: (value) {
          Navigator.pop(context);
          setState(() => _workspaceView = value);
        },
      ),
    );
  }

  Future<void> _openClassCoverageDetail(_ClassSubjectCoverage coverage) async {
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (detailContext) => PrincipalDetailPage(
          title: coverage.grade.gradeName,
          menuItems: const [
            PopupMenuItem(value: 'classhub', child: Text('Open Classes Hub')),
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
                          onTap: () => Navigator.pop(detailContext, 'classhub'),
                        ),
                    ],
            ),
            PrincipalDetailCard(
              title: 'Actions',
              children: [
                PrincipalActionTile(
                  icon: Icons.account_tree_outlined,
                  title: 'Setup subjects in Classes Hub',
                  subtitle:
                      'Open this class and use Step 2 for subject and teacher changes',
                  onTap: () => Navigator.pop(detailContext, 'classhub'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mounted || action != 'classhub') return;
    _openClassesHubForSubjects(gradeId: coverage.grade.id);
  }

  Future<void> _openTeacherLoadDetail(_TeacherSubjectLoad load) async {
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (detailContext) => PrincipalDetailPage(
          title: load.teacherName,
          menuItems: const [
            PopupMenuItem(value: 'classhub', child: Text('Open Classes Hub')),
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
                              'classhub:${assignment.gradeId}:${assignment.sectionId}',
                            );
                          },
                        ),
                    ],
            ),
            PrincipalDetailCard(
              title: 'Actions',
              children: [
                PrincipalActionTile(
                  icon: Icons.account_tree_outlined,
                  title: 'Open Classes Hub',
                  subtitle:
                      'Choose the class where this teacher assignment should change',
                  onTap: () => Navigator.pop(detailContext, 'classhub'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'classhub') {
      _openClassesHubForSubjects();
      return;
    }
    if (action.startsWith('classhub:')) {
      final parts = action.split(':');
      _openClassesHubForSubjects(
        gradeId: parts.length > 1 ? parts[1] : '',
        sectionId: parts.length > 2 ? parts[2] : '',
      );
    }
  }

  void _openClassesHubForSubjects({
    String gradeId = '',
    String sectionId = '',
    String subjectId = '',
  }) {
    Navigator.pushNamed(
      context,
      AppRoutes.principalClasses,
      arguments: {
        'class_hub_action': 'subjects',
        'action': 'subjects',
        'selectedStep': 'subject_mapping',
        if (gradeId.isNotEmpty) 'grade_id': gradeId,
        if (gradeId.isNotEmpty) 'classId': gradeId,
        if (sectionId.isNotEmpty) 'section_id': sectionId,
        if (sectionId.isNotEmpty) 'sectionId': sectionId,
        if (subjectId.isNotEmpty) 'subject_id': subjectId,
        'source': 'principal_subjects',
      },
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

class _SubjectsDirectoryHeader extends StatelessWidget {
  const _SubjectsDirectoryHeader({
    required this.title,
    required this.subtitle,
    required this.onFilter,
  });

  final String title;
  final String subtitle;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5F6F89),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(14),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'Filter subjects',
              onPressed: onFilter,
              icon: const Icon(Icons.filter_alt_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectMetricCard extends StatelessWidget {
  const _SubjectMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3EAF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF667085),
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF101828),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectDirectoryTile extends StatelessWidget {
  const _SubjectDirectoryTile({
    required this.subjectName,
    required this.subjectCode,
    required this.subjectType,
    required this.teacherName,
    required this.teacherRole,
    required this.trailing,
    required this.onTap,
  });

  final String subjectName;
  final String subjectCode;
  final String subjectType;
  final String teacherName;
  final String teacherRole;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = subjectType.trim().isEmpty ? 'core' : subjectType.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 80),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE3EAF5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _SubjectGlyph(label: subjectName),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    subjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        subjectCode,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF5F6F89),
                        ),
                      ),
                      _SubjectBadge(label: type),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 142),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SubjectTeacherAvatar(name: teacherName),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          teacherName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF101828),
                          ),
                        ),
                        if (teacherRole.isNotEmpty)
                          Text(
                            teacherRole,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF5F6F89),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SubjectGlyph extends StatelessWidget {
  const _SubjectGlyph({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = _subjectColors(label);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: colors.$2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(_subjectIcon(label), color: colors.$1, size: 28),
    );
  }
}

class _SubjectBadge extends StatelessWidget {
  const _SubjectBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final activity =
        label.toLowerCase().contains('activity') ||
        label.toLowerCase().contains('art') ||
        label.toLowerCase().contains('music');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: activity ? const Color(0xFFFFEAF4) : const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _titleCase(label),
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: activity ? const Color(0xFFD94383) : const Color(0xFF0969FF),
        ),
      ),
    );
  }
}

class _SubjectTeacherAvatar extends StatelessWidget {
  const _SubjectTeacherAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FF),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0969FF),
          ),
        ),
      ),
    );
  }
}

class _SubjectDetailScreen extends StatelessWidget {
  const _SubjectDetailScreen({
    required this.subjectName,
    required this.subjectCode,
    required this.subjectType,
    required this.credits,
    required this.teacher,
    required this.weeklyPeriods,
    required this.applicableClasses,
  });

  final String subjectName;
  final String subjectCode;
  final String subjectType;
  final String credits;
  final _SubjectAssignment? teacher;
  final String weeklyPeriods;
  final String applicableClasses;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      bottomNavigationBar: const PrincipalShellBottomBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            _SubjectsDirectoryHeader(
              title: 'Subject Details',
              subtitle: applicableClasses,
              onFilter: () => Navigator.pop(context),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _subjectPanelDecoration(),
              child: Row(
                children: [
                  _SubjectGlyph(label: subjectName),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              subjectName,
                              style: GoogleFonts.dmSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF101828),
                              ),
                            ),
                            _SubjectBadge(label: subjectType),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Code: $subjectCode',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF5F6F89),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Subject Information',
              style: GoogleFonts.dmSans(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF101828),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: _subjectPanelDecoration(),
              child: Column(
                children: [
                  _SubjectInfoRow(label: 'Subject Name', value: subjectName),
                  _SubjectInfoRow(label: 'Code', value: subjectCode),
                  _SubjectInfoRow(
                    label: 'Type',
                    value: _titleCase(subjectType),
                  ),
                  _SubjectInfoRow(label: 'Credits', value: credits),
                  _SubjectInfoRow(
                    label: 'Teacher',
                    value: teacher?.teacherName ?? 'Not assigned',
                    avatarName: teacher?.teacherName,
                  ),
                  _SubjectInfoRow(
                    label: 'Weekly Periods',
                    value: weeklyPeriods,
                  ),
                  _SubjectInfoRow(
                    label: 'Applicable Classes',
                    value: applicableClasses,
                  ),
                  _SubjectInfoRow(
                    label: 'Status',
                    value: teacher == null ? 'Needs teacher' : 'Active',
                    isLast: true,
                    status: teacher != null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD5E7FF)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF0969FF),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'To make changes to this subject, go to Classes Hub and update Step 2 subjects.',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F4F8F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0969FF),
                  side: const BorderSide(color: Color(0xFF0969FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.principalClasses,
                  arguments: const {
                    'class_hub_action': 'subjects',
                    'source': 'principal_subjects',
                  },
                ),
                icon: const Icon(Icons.apartment_rounded),
                label: Text(
                  'Go to Classes Hub',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectInfoRow extends StatelessWidget {
  const _SubjectInfoRow({
    required this.label,
    required this.value,
    this.avatarName,
    this.isLast = false,
    this.status,
  });

  final String label;
  final String value;
  final String? avatarName;
  final bool isLast;
  final bool? status;

  @override
  Widget build(BuildContext context) {
    final valueWidget = status == null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (avatarName != null) ...[
                _SubjectTeacherAvatar(name: avatarName!),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _valueStyle,
                ),
              ),
            ],
          )
        : _SubjectBadge(label: value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFE3EAF5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF5F6F89),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(child: valueWidget),
        ],
      ),
    );
  }
}

class _SubjectViewSheet extends StatelessWidget {
  const _SubjectViewSheet({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in const [
            ('Subjects', Icons.menu_book_rounded),
            ('Classes', Icons.apartment_rounded),
            ('Teachers', Icons.groups_rounded),
          ])
            ListTile(
              leading: Icon(item.$2),
              title: Text(item.$1),
              trailing: selected == item.$1
                  ? const Icon(Icons.check_rounded, color: Color(0xFF0969FF))
                  : null,
              onTap: () => onSelected(item.$1),
            ),
        ],
      ),
    );
  }
}

BoxDecoration _subjectPanelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: const Color(0xFFE3EAF5)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(10),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

TextStyle get _valueStyle => GoogleFonts.dmSans(
  fontSize: 14,
  fontWeight: FontWeight.w900,
  color: const Color(0xFF101828),
);

IconData _subjectIcon(String label) {
  final value = label.toLowerCase();
  if (value.contains('math')) return Icons.calculate_outlined;
  if (value.contains('english') || value.contains('language')) {
    return Icons.abc_rounded;
  }
  if (value.contains('science') || value.contains('evs')) {
    return Icons.eco_outlined;
  }
  if (value.contains('computer')) return Icons.computer_rounded;
  if (value.contains('music')) return Icons.music_note_rounded;
  if (value.contains('physical') || value.contains('sport')) {
    return Icons.directions_run_rounded;
  }
  if (value.contains('art')) return Icons.palette_outlined;
  return Icons.menu_book_rounded;
}

(Color, Color) _subjectColors(String label) {
  final value = label.toLowerCase();
  if (value.contains('math')) {
    return (const Color(0xFF1FB56A), const Color(0xFFE8F8EF));
  }
  if (value.contains('science') || value.contains('evs')) {
    return (const Color(0xFFF59E0B), const Color(0xFFFFF4DD));
  }
  if (value.contains('hindi') || value.contains('language')) {
    return (const Color(0xFF7C3AED), const Color(0xFFF1EAFE));
  }
  if (value.contains('art') || value.contains('music')) {
    return (const Color(0xFFE83E8C), const Color(0xFFFFEAF4));
  }
  if (value.contains('physical') || value.contains('sport')) {
    return (const Color(0xFF00A7A7), const Color(0xFFE7F9F8));
  }
  return (const Color(0xFF0969FF), const Color(0xFFEAF2FF));
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty || value == 'Teacher not assigned') return 'NA';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String _titleCase(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return clean;
  return clean
      .split(RegExp(r'\s+'))
      .map((word) {
        if (word.isEmpty) return word;
        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
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
