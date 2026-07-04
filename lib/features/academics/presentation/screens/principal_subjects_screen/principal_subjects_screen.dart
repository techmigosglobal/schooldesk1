// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';
import 'package:schooldesk1/core/widgets/principal_directory_ui.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

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
  List<Map<String, dynamic>> _timetableSlots = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _workspaceView = 'Subjects';
  String _selectedGradeId = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        api.getTimetableSlots(),
      ]);
      final payload = results[0] as Map<String, dynamic>;
      if (!mounted) return;
      final timetableSlots = results[6] as List<Map<String, dynamic>>;
      final existingSubjectIds = <String>{
        for (final subject in _asListMap(payload['subjects']))
          _text(subject['subject_id'] ?? subject['id']),
      };
      final extraSubjects = <Map<String, dynamic>>[];
      for (final slot in timetableSlots) {
        final subjectId = _text(slot['subject_id']);
        if (subjectId.isEmpty || existingSubjectIds.contains(subjectId)) {
          continue;
        }
        existingSubjectIds.add(subjectId);
        final subjectPayload = slot['subject'];
        final subjectName = subjectPayload is Map
            ? _text(subjectPayload['subject_name'] ?? subjectPayload['name'])
            : _text(slot['subject_name']);
        final subjectCode = subjectPayload is Map
            ? _text(subjectPayload['subject_code'] ?? subjectPayload['code'])
            : '';
        extraSubjects.add({
          'subject_id': subjectId,
          'subject_name': subjectName,
          'subject_code': subjectCode,
        });
      }
      setState(() {
        _analytics = _asMap(payload['analytics']);
        _subjects = [
          ..._asListMap(payload['subjects']),
          ...extraSubjects,
        ];
        _gradeSubjects = results[1] as List<Map<String, dynamic>>;
        _staffSubjects = results[2] as List<Map<String, dynamic>>;
        _gradeOptions = _asListMap(payload['grade_options']);
        _grades = results[3] as List<GradeModel>;
        _sections = results[4] as List<SectionModel>;
        _staff = (results[5] as PaginatedList<StaffModel>).data;
        _timetableSlots = timetableSlots;
        final activeGrades = _activeGradesFrom(_grades, _sections);
        if (_selectedGradeId.isEmpty ||
            !activeGrades.any((grade) => grade.id == _selectedGradeId)) {
          _selectedGradeId = activeGrades.isEmpty ? '' : activeGrades.first.id;
        }
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

  List<GradeModel> get _activeGrades => _activeGradesFrom(_grades, _sections);

  List<GradeModel> _activeGradesFrom(
    List<GradeModel> grades,
    List<SectionModel> sections,
  ) {
    final activeGradeIds = sections.map((section) => section.gradeId).toSet();
    return grades.where((grade) => activeGradeIds.contains(grade.id)).toList()
      ..sort((left, right) {
        final order = left.gradeNumber.compareTo(right.gradeNumber);
        if (order != 0) return order;
        return left.gradeName.compareTo(right.gradeName);
      });
  }

  GradeModel? get _selectedGrade {
    for (final grade in _activeGrades) {
      if (grade.id == _selectedGradeId) return grade;
    }
    return _activeGrades.isEmpty ? null : _activeGrades.first;
  }

  List<_ClassSubjectRow> get _selectedClassSubjects {
    final grade = _selectedGrade;
    if (grade == null) return const [];
    final query = _search.trim().toLowerCase();
    final gradeSubjects = _activeGradeSubjects
        .where((row) => _text(row['grade_id']) == grade.id)
        .toList();
    final staffSubjects = _activeStaffSubjects
        .where((row) => _text(row['grade_id']) == grade.id)
        .toList();
    final subjectIds = <String>{
      ...gradeSubjects.map((row) => _text(row['subject_id'])),
      ...staffSubjects.map((row) => _text(row['subject_id'])),
    }..removeWhere((id) => id.isEmpty);
    return subjectIds
        .map((subjectId) {
          final subject = _subjectById(subjectId);
          final assignments =
              staffSubjects
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
            subjectName: _text(subject['subject_name'], fallback: 'Subject'),
            subjectCode: _text(subject['subject_code']),
            gradeSubjectId: _text(gradeSubject['id']),
            assignments: assignments,
          );
        })
        .where((row) {
          if (query.isEmpty) return true;
          return row.searchText.contains(query);
        })
        .toList()
      ..sort((left, right) => left.subjectName.compareTo(right.subjectName));
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
    final selectedGrade = _selectedGrade;
    final subjects = _selectedClassSubjects;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFF),
      bottomNavigationBar: const PrincipalShellBottomBar(),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF6C4CFF),
          onRefresh: _loadData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _SubjectsDirectoryHeader(
                  title: 'Subjects',
                  subtitle: _subjectsScopeLabel,
                  onFilter: () => _openClassesHubForSubjects(),
                ),
              ),
              SliverToBoxAdapter(child: _buildClassSubjectFilters()),
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
              else if (selectedGrade == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyStateWidget(
                      icon: Icons.menu_book_rounded,
                      title: 'No active classes found',
                      description:
                          'Create classes in Class Hub, then map subjects and teachers.',
                      actionLabel: 'Go to Classes Hub',
                      onAction: () async {
                        await Navigator.pushNamed(
                          context,
                          AppRoutes.principalClasses,
                        );
                        if (context.mounted) await _loadData();
                      },
                    ),
                  ),
                )
              else if (subjects.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyStateWidget(
                      icon: Icons.menu_book_rounded,
                      title: 'No subjects found',
                      description:
                          'No backend subject mappings match ${selectedGrade.gradeName}.',
                      actionLabel: 'Setup Subjects',
                      onAction: () =>
                          _openClassesHubForSubjects(gradeId: selectedGrade.id),
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(child: _buildSelectedClassSummary()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 96),
                  sliver: SliverList.builder(
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      final teacher = _primaryAssignment(subject.assignments);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _PrincipalSubjectCard(
                          row: subject,
                          classLabel: selectedGrade.gradeName,
                          teacher: teacher,
                          onTeacherTap: teacher == null
                              ? null
                              : () => _openTeacherSubjectDetail(
                                  teacher.teacherId,
                                ),
                          onSetup: () => _openClassesHubForSubjects(
                            gradeId: selectedGrade.id,
                            subjectId: subject.subjectId,
                          ),
                        ),
                      );
                    },
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

  Set<String> get _activeSubjectIds {
    final ids = <String>{
      ..._activeGradeSubjects.map((row) => _text(row['subject_id'])),
      ..._activeStaffSubjects.map((row) => _text(row['subject_id'])),
    };
    for (final slot in _timetableSlots) {
      ids.add(_text(slot['subject_id']));
      final subject = slot['subject'];
      if (subject is Map) {
        ids.add(_text(subject['subject_id'] ?? subject['id']));
      }
    }
    ids.removeWhere((id) => id.isEmpty);
    return ids;
  }

  String get _subjectsScopeLabel {
    final count = _activeGrades.length;
    if (count == 0) return 'No active classes';
    return '$count active ${count == 1 ? 'class' : 'classes'}';
  }

  Widget _buildClassSubjectFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SubjectSearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 18),
          _ClassSelectField(
            grades: _activeGrades,
            selectedGradeId: _selectedGradeId,
            onChanged: (value) => setState(() => _selectedGradeId = value),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6C4CFF),
                side: const BorderSide(color: Color(0xFFE7E1FF)),
                backgroundColor: const Color(0xFFF8F5FF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => setState(() {
                _search = '';
                _searchController.clear();
                _selectedGradeId = _activeGrades.isEmpty
                    ? ''
                    : _activeGrades.first.id;
              }),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                'Reset',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedClassSummary() {
    final grade = _selectedGrade;
    final subjectCount = _selectedClassSubjects.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 66),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7F3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0E1D2440),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Showing subjects for ',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF67728A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    TextSpan(
                      text: grade?.gradeName ?? 'Class',
                      style: const TextStyle(
                        color: Color(0xFF6C4CFF),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EFFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE3D9FF)),
              ),
              child: Text(
                '$subjectCount ${subjectCount == 1 ? 'Subject' : 'Subjects'}',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF6C4CFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTeacherSubjectDetail(String teacherId) async {
    if (teacherId.trim().isEmpty) return;
    final staff = _staffById(teacherId);
    final assignments =
        _activeStaffSubjects
            .where((row) => _text(row['staff_id']) == teacherId)
            .map(_assignmentFromRow)
            .toList()
          ..sort((left, right) {
            final subjectOrder = left.subjectName.compareTo(right.subjectName);
            if (subjectOrder != 0) return subjectOrder;
            return left.classLabel.compareTo(right.classLabel);
          });
    if (!mounted) return;
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _TeacherSubjectsDetailScreen(
          teacherName: _staffName(
            staff,
            fallback: assignments.isEmpty
                ? 'Teacher'
                : assignments.first.teacherName,
          ),
          designation: staff?.designation ?? 'Teacher',
          assignments: assignments,
          onSetup: () => Navigator.of(context).pop('classhub'),
        ),
      ),
    );
    if (!mounted || action != 'classhub') return;
    await _openClassesHubForSubjects();
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
              onPressed: () async {
                await Navigator.pushNamed(context, AppRoutes.principalClasses);
                if (context.mounted) await _loadData();
              },
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
          ? context.appTheme.warning
          : context.appTheme.success,
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
      statusColor: load.subjectCount == 0
          ? context.appTheme.warning
          : context.appTheme.primary,
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
                    ? context.appTheme.warning
                    : context.appTheme.success,
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
              title: 'Class Subject Coverage',
              trailing: PrincipalStatusPill(
                label: '${load.subjectCount} subjects',
                color: load.subjectCount == 0
                    ? context.appTheme.warning
                    : context.appTheme.primary,
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
      await _openClassesHubForSubjects();
      return;
    }
    if (action.startsWith('classhub:')) {
      final parts = action.split(':');
      await _openClassesHubForSubjects(
        gradeId: parts.length > 1 ? parts[1] : '',
        sectionId: parts.length > 2 ? parts[2] : '',
      );
    }
  }

  Future<void> _openClassesHubForSubjects({
    String gradeId = '',
    String sectionId = '',
    String subjectId = '',
  }) async {
    await Navigator.pushNamed(
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
    if (mounted) await _loadData();
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
              color: context.appTheme.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: context.appTheme.onSurface.withAlpha(14),
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

class _SubjectSearchField extends StatelessWidget {
  const _SubjectSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF111827),
      ),
      decoration: InputDecoration(
        hintText: 'Search subjects...',
        hintStyle: GoogleFonts.dmSans(
          color: const Color(0xFF8A94A8),
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF526079)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE1E6F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE1E6F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF6C4CFF), width: 1.4),
        ),
      ),
    );
  }
}

class _ClassSelectField extends StatelessWidget {
  const _ClassSelectField({
    required this.grades,
    required this.selectedGradeId,
    required this.onChanged,
  });

  final List<GradeModel> grades;
  final String selectedGradeId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = grades.any((grade) => grade.id == selectedGradeId)
        ? selectedGradeId
        : (grades.isEmpty ? null : grades.first.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E6F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF526079),
          ),
          items: [
            for (final grade in grades)
              DropdownMenuItem(
                value: grade.id,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select Class',
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF6C4CFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      grade.gradeName,
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF111827),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}

class _PrincipalSubjectCard extends StatelessWidget {
  const _PrincipalSubjectCard({
    required this.row,
    required this.classLabel,
    required this.teacher,
    required this.onTeacherTap,
    required this.onSetup,
  });

  final _ClassSubjectRow row;
  final String classLabel;
  final _SubjectAssignment? teacher;
  final VoidCallback? onTeacherTap;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final teacherName = teacher?.teacherName ?? 'Teacher not assigned';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTeacherTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 124),
          padding: const EdgeInsets.fromLTRB(14, 16, 8, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE7EBF3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x101D2440),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      row.subjectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF111827),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      classLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF6C4CFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _SubjectTeacherAvatar(name: teacherName),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            teacherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              color: const Color(0xFF667085),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (teacher != null) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF6C4CFF),
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Subject actions',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF526079),
                ),
                onSelected: (_) => onSetup(),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'setup',
                    child: Text('Setup in Class Hub'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 42),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3D9FF)),
      ),
      child: Text(
        _compactClassLabel(label),
        textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(
          color: const Color(0xFF6C4CFF),
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TeacherSubjectsDetailScreen extends StatelessWidget {
  const _TeacherSubjectsDetailScreen({
    required this.teacherName,
    required this.designation,
    required this.assignments,
    required this.onSetup,
  });

  final String teacherName;
  final String designation;
  final List<_SubjectAssignment> assignments;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final assignedClass = assignments.isEmpty
        ? 'No class'
        : assignments.first.classLabel;
    final subjectIds = assignments.map((row) => row.subjectId).toSet();
    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFF),
      bottomNavigationBar: const PrincipalShellBottomBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 96),
          children: [
            _SubjectsDirectoryHeader(
              title: 'Teacher Subjects',
              subtitle: 'Subjects handled by this teacher',
              onFilter: onSetup,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: _subjectPanelDecoration(context).copyWith(
                color: const Color(0xFFFCFAFF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _TeacherPortrait(name: teacherName),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                teacherName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  color: const Color(0xFF111827),
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF6C4CFF),
                              size: 22,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          designation.trim().isEmpty ? 'Teacher' : designation,
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFF6C4CFF),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _TeacherMiniMetric(
                                icon: Icons.school_outlined,
                                label: 'Assigned Class',
                                value: assignedClass,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _TeacherMiniMetric(
                                icon: Icons.groups_2_outlined,
                                label: 'Can teach',
                                value:
                                    '${subjectIds.length} ${subjectIds.length == 1 ? 'Subject' : 'Subjects'}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Subjects this teacher can teach',
              style: GoogleFonts.dmSans(
                color: const Color(0xFF111827),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            if (assignments.isEmpty)
              EmptyStateWidget(
                icon: Icons.menu_book_rounded,
                title: 'No subjects assigned',
                description:
                    'Use Class Hub to assign this teacher to class subjects.',
                actionLabel: 'Open Class Hub',
                onAction: onSetup,
              )
            else
              for (final assignment in assignments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _TeacherSubjectRow(
                    assignment: assignment,
                    onTap: onSetup,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _TeacherPortrait extends StatelessWidget {
  const _TeacherPortrait({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF0EAFF),
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A1D2440),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: GoogleFonts.dmSans(
            color: const Color(0xFF6C4CFF),
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _TeacherMiniMetric extends StatelessWidget {
  const _TeacherMiniMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE6E0F7)),
          ),
          child: Icon(icon, color: const Color(0xFF6C4CFF), size: 22),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF7B8498),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF111827),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeacherSubjectRow extends StatelessWidget {
  const _TeacherSubjectRow({required this.assignment, required this.onTap});

  final _SubjectAssignment assignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: _subjectPanelDecoration(context),
        child: Row(
          children: [
            _SubjectGlyph(label: assignment.subjectName),
            const SizedBox(width: 18),
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    assignment.subjectName,
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFF111827),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _ClassChip(label: assignment.gradeName),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF526079),
              size: 30,
            ),
          ],
        ),
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
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3EAF5)),
        boxShadow: [
          BoxShadow(
            color: context.appTheme.onSurface.withAlpha(10),
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
          color: context.appTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE3EAF5)),
          boxShadow: [
            BoxShadow(
              color: context.appTheme.onSurface.withAlpha(10),
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
        border: Border.all(color: context.appTheme.surface, width: 2),
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
              decoration: _subjectPanelDecoration(context),
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
              decoration: _subjectPanelDecoration(context),
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
                onPressed: () => Navigator.pop(context, 'classhub'),
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
      decoration: BoxDecoration(
        color: context.appTheme.surface,
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

BoxDecoration _subjectPanelDecoration(BuildContext context) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: const Color(0xFFE3EAF5)),
    boxShadow: [
      BoxShadow(
        color: context.appTheme.onSurface.withAlpha(10),
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
    return Icons.science_outlined;
  }
  if (value.contains('social') || value.contains('history')) {
    return Icons.public_rounded;
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

String _compactClassLabel(String label) {
  final clean = label.trim();
  if (clean.isEmpty) return '-';
  final roman = RegExp(
    r'\b([IVXLCDM]+)\b',
    caseSensitive: false,
  ).firstMatch(clean);
  if (roman != null) return roman.group(1)!.toUpperCase();
  final number = RegExp(r'\d+').firstMatch(clean);
  if (number != null) return number.group(0)!;
  return clean.length <= 3 ? clean : clean.substring(0, 1).toUpperCase();
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
        color: context.appTheme.surface,
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
                child: Icon(
                  Icons.menu_book_rounded,
                  color: context.appTheme.primary,
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
                        color: context.appTheme.muted,
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
                    color: context.appTheme.primary,
                  ),
                  _MetricTile(
                    width: width,
                    icon: Icons.assignment_turned_in_rounded,
                    label: 'Homework',
                    value:
                        '${_num(data['homework_consistency']).toStringAsFixed(0)}%',
                    tone: const Color(0xFFECFDF3),
                    color: context.appTheme.success,
                  ),
                  _MetricTile(
                    width: width,
                    icon: Icons.warning_amber_rounded,
                    label: 'Weak Signals',
                    value: '${_int(data['weak_student_count'])}',
                    tone: const Color(0xFFFEEFEE),
                    color: context.appTheme.error,
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
        Icon(icon, size: 18, color: context.appTheme.primary),
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
              color: context.appTheme.muted,
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
              Icon(
                Icons.hub_outlined,
                size: 18,
                color: context.appTheme.primary,
              ),
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
                      color: context.appTheme.primary.withAlpha(18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_int(row['class_count'])}',
                      style: GoogleFonts.dmSans(
                        color: context.appTheme.primary,
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
                            color: context.appTheme.muted,
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
              color: context.appTheme.onSurfaceVariant,
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
        foregroundColor: context.appTheme.primary,
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
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.appTheme.primary, size: 20),
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
                color: context.appTheme.muted,
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
                                  color: context.appTheme.muted,
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
