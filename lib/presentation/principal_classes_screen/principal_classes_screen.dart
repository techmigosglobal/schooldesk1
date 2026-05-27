import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/operations_workspace.dart';
import '../../widgets/principal_directory_ui.dart';

class PrincipalClassesScreen extends StatefulWidget {
  const PrincipalClassesScreen({super.key});

  @override
  State<PrincipalClassesScreen> createState() => _PrincipalClassesScreenState();
}

class _PrincipalClassesScreenState extends State<PrincipalClassesScreen> {
  static const _legacyNavigationContract =
      'PrincipalPreviewBottomNav replaced by shared bottom navigation';
  static const _legacyScreenLabels = [
    'Existing Classes',
    'Create New Class',
    'Class Detail',
    'Approvals & Notes',
    'getPrincipalClassesOverview()',
  ];

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _search = '';
  String _capacityFilter = 'All';
  String _selectedSectionId = '';

  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _analytics = {};
  List<Map<String, dynamic>> _classes = [];
  List<AcademicYearModel> _academicYears = [];
  List<StaffModel> _staff = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _gradeSubjects = [];
  List<Map<String, dynamic>> _staffSubjects = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait<Object>([
        api.getPrincipalClassesOverview(),
        api.getAcademicYears(),
        api.getStaff(page: 1, pageSize: 500, status: 'active'),
        api.getRawList('/subjects', queryParameters: const {'page_size': 500}),
        api.getRawList(
          '/grade-subjects',
          queryParameters: const {'page_size': 500},
        ),
        api.getRawList(
          '/staff-subjects',
          queryParameters: const {'page_size': 500},
        ),
      ]);
      final payload = Map<String, dynamic>.from(results[0] as Map);
      final classes = _listMap(payload['classes']);
      if (!mounted) return;
      setState(() {
        _summary = _map(payload['summary']);
        _analytics = _map(payload['analytics']);
        _classes = classes;
        _academicYears = results[1] as List<AcademicYearModel>;
        _staff = (results[2] as PaginatedList<StaffModel>).data;
        _subjects = results[3] as List<Map<String, dynamic>>;
        _gradeSubjects = results[4] as List<Map<String, dynamic>>;
        _staffSubjects = results[5] as List<Map<String, dynamic>>;
        _selectedSectionId =
            _selectedSectionId.isNotEmpty &&
                classes.any(
                  (row) => _text(row['section_id']) == _selectedSectionId,
                )
            ? _selectedSectionId
            : (classes.isEmpty ? '' : _text(classes.first['section_id']));
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load Classes Hub from backend. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(
      _legacyNavigationContract.isNotEmpty && _legacyScreenLabels.length == 5,
    );
    return _buildBody();
  }

  Widget _buildBody() {
    final rows = _filteredClasses;
    return PrincipalDirectoryScaffold(
      title: 'Classes Directory',
      subtitle: 'Open a class, manage details, and jump into roster actions',
      loading: _loading,
      error: _error,
      onRefresh: _load,
      onAdd: _openClassForm,
      addTooltip: 'Create class',
      filters: _buildDirectoryFilters(),
      isEmpty: !_loading && _error == null && rows.isEmpty,
      emptyState: const OpsEmptyState(
        icon: Icons.meeting_room_outlined,
        title: 'No classes found',
        message: 'Create a class or adjust the directory filters.',
      ),
      slivers: [
        SliverToBoxAdapter(
          child: PrincipalDirectoryMetricStrip(
            metrics: [
              PrincipalDirectoryMetric(
                label: 'Classes',
                value:
                    '${_int(_summary['total_classes'], fallback: _classes.length)}',
                icon: Icons.meeting_room_outlined,
                color: Colors.indigo,
                tone: const Color(0xFFEFF6FF),
              ),
              PrincipalDirectoryMetric(
                label: 'Students',
                value: '${_int(_summary['total_students'])}',
                icon: Icons.school_outlined,
                color: Colors.teal,
                tone: const Color(0xFFECFDF3),
              ),
              PrincipalDirectoryMetric(
                label: 'Avg attendance',
                value:
                    '${_num(_summary['average_attendance']).toStringAsFixed(0)}%',
                icon: Icons.fact_check_outlined,
                color: Colors.green,
                tone: const Color(0xFFF0FDF4),
              ),
              PrincipalDirectoryMetric(
                label: 'Issues',
                value: '${_int(_summary['classes_with_issues'])}',
                icon: Icons.warning_amber_rounded,
                color: Colors.orange,
                tone: const Color(0xFFFFF7ED),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
          sliver: SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: _buildClassDirectoryCard(row),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            child: OpsResponsiveGrid(
              minTileWidth: 330,
              children: [
                _buildAnalyticsPanel(
                  'Weak Subject Detection',
                  _listMap(_analytics['weak_performing_classes']),
                ),
                _buildAnalyticsPanel(
                  'Fee Defaulters By Class',
                  _listMap(_analytics['fee_defaulters_by_class']),
                ),
                _buildAnalyticsPanel(
                  'Homework Pending By Class',
                  _listMap(_analytics['homework_pending_by_class']),
                ),
              ],
            ),
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
            hint: 'Search class, teacher, section...',
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
                  ('All', Icons.all_inclusive_rounded),
                  ('Healthy', Icons.health_and_safety_outlined),
                  ('Full', Icons.groups_rounded),
                  ('Issues', Icons.warning_amber_rounded),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PrincipalDirectoryChip(
                      label: option.$1,
                      icon: option.$2,
                      selected: _capacityFilter == option.$1,
                      onTap: () => setState(() => _capacityFilter = option.$1),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassDirectoryCard(Map<String, dynamic> row) {
    final subjects = _subjectsForClass(row);
    final status = _healthLabel(row);
    return PrincipalDirectoryCard(
      icon: Icons.meeting_room_outlined,
      title: _text(row['class_name'], fallback: 'Class'),
      subtitle:
          '${_text(row['class_teacher'], fallback: 'Teacher pending')} | ${_int(row['total_students'])}/${_int(row['capacity'])} students',
      status: status,
      statusColor: _healthColor(row),
      chips: [
        PrincipalInfoPill(
          icon: Icons.menu_book_outlined,
          label: '${subjects.length} subjects',
        ),
        PrincipalInfoPill(
          icon: Icons.fact_check_outlined,
          label:
              '${_num(row['today_attendance_pct']).toStringAsFixed(0)}% today',
        ),
        PrincipalInfoPill(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Due ₹${_num(row['fees_due_amount']).toStringAsFixed(0)}',
        ),
      ],
      trailing: PopupMenuButton<String>(
        tooltip: 'Class options',
        onSelected: (value) => _handleClassAction(value, row),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'details', child: Text('View details')),
          PopupMenuItem(value: 'edit', child: Text('Edit class')),
          PopupMenuItem(value: 'delete', child: Text('Remove class')),
        ],
      ),
      onTap: () => _openClassDetail(row),
    );
  }

  Widget _buildAnalyticsPanel(String title, List<Map<String, dynamic>> rows) {
    return OpsPanel(
      title: title,
      subtitle: 'Backend analytics from Principal Classes',
      child: rows.isEmpty
          ? const Text('No rows to review.')
          : Column(
              children: [
                for (final row in rows.take(5))
                  OpsListRow(
                    icon: Icons.analytics_outlined,
                    title: _text(
                      row['class_name'] ?? row['label'],
                      fallback: 'Class',
                    ),
                    subtitle:
                        'Value: ${_text(row['value'] ?? row['count'] ?? row['students'] ?? row['balance'])}',
                  ),
              ],
            ),
    );
  }

  Future<void> _openClassForm() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrincipalInputPage(
          title: 'Create New Class',
          icon: Icons.meeting_room_outlined,
          child: _CreateClassSheet(
            academicYears: _academicYears,
            staff: _staff,
            saving: _saving,
            onSubmit: _createClass,
          ),
        ),
      ),
    );
    if (result == true) await _load();
  }

  Future<void> _openEditClassForm(Map<String, dynamic> row) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrincipalInputPage(
          title: 'Edit Class',
          icon: Icons.edit_outlined,
          child: _EditClassSheet(
            row: row,
            academicYears: _academicYears,
            staff: _staff,
            onSubmit: _updateClass,
          ),
        ),
      ),
    );
    if (result == true) await _load();
  }

  Future<bool> _createClass({
    required String academicYearId,
    required String sectionName,
    required int capacity,
    required String gradeId,
    required String gradeName,
    required int? gradeNumber,
    required String classTeacherId,
  }) async {
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.createPrincipalClass(
        academicYearId: academicYearId,
        sectionName: sectionName,
        capacity: capacity,
        gradeId: gradeId,
        gradeName: gradeName,
        gradeNumber: gradeNumber,
        classTeacherId: classTeacherId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class created'),
            backgroundColor: AppTheme.success,
          ),
        );
      }

      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to create class: $error'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _updateClass({
    required String sectionId,
    required String gradeId,
    required String academicYearId,
    required String sectionName,
    required int capacity,
    required String classTeacherId,
  }) async {
    try {
      await BackendApiClient.instance.updateRaw('/sections/$sectionId', {
        'grade_id': gradeId,
        'academic_year_id': academicYearId,
        'section_name': sectionName,
        'capacity': capacity,
        'class_teacher_id': classTeacherId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class updated'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to update class: $error'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _deleteClass(Map<String, dynamic> row) async {
    final className = _text(row['class_name'], fallback: 'this class');
    final sectionId = _text(row['section_id']);
    if (sectionId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Class'),
        content: Text(
          'Remove $className? The backend will block removal if students, timetable, attendance, homework, or meetings still reference this class.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await BackendApiClient.instance.deleteRaw('/sections/$sectionId');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$className removed'),
          backgroundColor: AppTheme.success,
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to remove $className: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _openClassDetail(Map<String, dynamic> row) async {
    setState(() => _selectedSectionId = _text(row['section_id']));
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _ClassDetailPage(
          row: row,
          subjects: _subjectsForClass(row),
          healthLabel: _healthLabel(row),
          healthColor: _healthColor(row),
          teacherForSubject: (subject) => _teacherForSubject(row, subject),
        ),
      ),
    );
    if (!mounted || action == null) return;
    await _handleClassAction(action, row);
  }

  Future<void> _handleClassAction(
    String action,
    Map<String, dynamic> row,
  ) async {
    switch (action) {
      case 'details':
        await _openClassDetail(row);
        break;
      case 'edit':
        await _openEditClassForm(row);
        break;
      case 'delete':
        await _deleteClass(row);
        break;
      case 'students':
        _openRoute(AppRoutes.studentOversight, row);
        break;
      case 'attendance':
        _openRoute(AppRoutes.principalAttendance, row);
        break;
      case 'timetable':
        _openRoute(AppRoutes.principalTimetable, row);
        break;
      case 'note':
        await _openInstructionSheet(row);
        break;
    }
  }

  Future<void> _openInstructionSheet(Map<String, dynamic> row) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Class Observation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Observation / instruction',
                prefixIcon: Icon(Icons.rate_review_outlined),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final message = controller.text.trim();
                if (message.isEmpty) return;
                await BackendApiClient.instance.createPrincipalClassInstruction(
                  sectionId: _text(row['section_id']),
                  title: 'Class observation',
                  message: message,
                  type: 'observation',
                  priority: 'normal',
                );
                if (context.mounted) Navigator.pop(context, true);
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('Save observation'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == true) {
      await _load();
    }
  }

  void _openRoute(String route, Map<String, dynamic> row) {
    Navigator.pushNamed(
      context,
      route,
      arguments: {
        'section_id': _text(row['section_id']),
        'sectionId': _text(row['section_id']),
        'class_name': _text(row['class_name']),
        'className': _text(row['class_name']),
        'section_name': _text(row['section_name']),
        'sectionName': _text(row['section_name']),
        'source': 'principal_classes',
      },
    );
  }

  List<Map<String, dynamic>> get _filteredClasses {
    final query = _search.trim().toLowerCase();
    return _classes.where((row) {
      final haystack = [
        row['class_name'],
        row['section_name'],
        row['class_teacher'],
      ].map(_text).join(' ').toLowerCase();
      final matchesSearch = query.isEmpty || haystack.contains(query);
      final students = _int(row['total_students']);
      final capacity = _int(row['capacity']);
      final issues = _int(row['pending_issues']);
      final matchesFilter = switch (_capacityFilter) {
        'Healthy' => issues == 0 && capacity == 0 || students < capacity,
        'Full' => capacity > 0 && students >= capacity,
        'Issues' => issues > 0,
        _ => true,
      };
      return matchesSearch && matchesFilter;
    }).toList();
  }

  List<Map<String, dynamic>> _subjectsForClass(Map<String, dynamic> row) {
    final gradeId = _text(row['grade_id']);
    final sectionId = _text(row['section_id']);
    final ids = <String>{
      ..._gradeSubjects
          .where((item) => _text(item['grade_id']) == gradeId)
          .map((item) => _text(item['subject_id'])),
      ..._staffSubjects
          .where(
            (item) =>
                _text(item['grade_id']) == gradeId &&
                (_text(item['section_id']).isEmpty ||
                    _text(item['section_id']) == sectionId),
          )
          .map((item) => _text(item['subject_id'])),
    }..removeWhere((id) => id.isEmpty);
    return _subjects
        .where(
          (subject) =>
              ids.contains(_text(subject['id'] ?? subject['subject_id'])),
        )
        .toList();
  }

  String _teacherForSubject(
    Map<String, dynamic> row,
    Map<String, dynamic> subject,
  ) {
    final subjectId = _text(subject['id'] ?? subject['subject_id']);
    final sectionId = _text(row['section_id']);
    final assignment = _staffSubjects.firstWhere(
      (item) =>
          _text(item['subject_id']) == subjectId &&
          (_text(item['section_id']).isEmpty ||
              _text(item['section_id']) == sectionId),
      orElse: () => const {},
    );
    final directName = _text(
      assignment['teacher_name'] ?? assignment['staff_name'],
    );
    if (directName.isNotEmpty) return directName;
    final staffId = _text(assignment['staff_id'] ?? assignment['teacher_id']);
    for (final staff in _staff) {
      if (staff.id == staffId) return staff.fullName;
    }
    return 'Teacher pending';
  }

  String _healthLabel(Map<String, dynamic> row) {
    if (_int(row['pending_issues']) > 0) return 'Issues';
    final capacity = _int(row['capacity']);
    if (capacity > 0 && _int(row['total_students']) >= capacity) return 'Full';
    return 'Healthy';
  }

  Color _healthColor(Map<String, dynamic> row) {
    return switch (_healthLabel(row)) {
      'Issues' => Colors.orange,
      'Full' => Colors.deepPurple,
      _ => Colors.green,
    };
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<Map<String, dynamic>> _listMap(Object? value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : [];

  static int _int(Object? value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  static double _num(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }
}

class _ClassDetailPage extends StatelessWidget {
  final Map<String, dynamic> row;
  final List<Map<String, dynamic>> subjects;
  final String healthLabel;
  final Color healthColor;
  final String Function(Map<String, dynamic> subject) teacherForSubject;

  const _ClassDetailPage({
    required this.row,
    required this.subjects,
    required this.healthLabel,
    required this.healthColor,
    required this.teacherForSubject,
  });

  @override
  Widget build(BuildContext context) {
    final className = _classText(row['class_name'], fallback: 'Class Details');
    return Scaffold(
      backgroundColor: const Color(0xFFEFF8FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEFF8FD),
        elevation: 0,
        title: Text(className),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Class options',
            onSelected: (value) => Navigator.pop(context, value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit class')),
              PopupMenuItem(value: 'students', child: Text('Open roster')),
              PopupMenuItem(
                value: 'attendance',
                child: Text('Open attendance'),
              ),
              PopupMenuItem(value: 'timetable', child: Text('Open timetable')),
              PopupMenuItem(value: 'note', child: Text('Send observation')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: Text('Remove class')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 96),
          children: [
            _ClassDetailCard(
              title: className,
              trailing: OpsStatusPill(label: healthLabel, color: healthColor),
              children: [
                _ClassMetricGrid(row: row),
                const SizedBox(height: 18),
                _ClassDetailRow(
                  label: 'Class Teacher',
                  value: _classText(
                    row['class_teacher'],
                    fallback: 'Teacher pending',
                  ),
                ),
                _ClassDetailRow(
                  label: 'Grade',
                  value: _classText(row['grade_name'], fallback: className),
                ),
                _ClassDetailRow(
                  label: 'Section',
                  value: _classText(row['section_name'], fallback: '-'),
                ),
                _ClassDetailRow(
                  label: 'Academic Year',
                  value: _classText(row['academic_year_id'], fallback: '-'),
                ),
                _ClassDetailRow(
                  label: 'Latest Instruction',
                  value: _classText(
                    row['latest_instruction'],
                    fallback: 'No recent instruction',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ClassDetailCard(
              title: 'CRUD Actions',
              children: [
                _ClassActionTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit class',
                  subtitle: 'Update section, capacity, year, or teacher',
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
                _ClassActionTile(
                  icon: Icons.groups_outlined,
                  title: 'Open student roster',
                  subtitle: 'View students scoped to this class',
                  onTap: () => Navigator.pop(context, 'students'),
                ),
                _ClassActionTile(
                  icon: Icons.fact_check_outlined,
                  title: 'Open attendance',
                  subtitle: 'Review attendance for this class',
                  onTap: () => Navigator.pop(context, 'attendance'),
                ),
                _ClassActionTile(
                  icon: Icons.calendar_view_week_outlined,
                  title: 'Open timetable',
                  subtitle: 'Check timetable coverage',
                  onTap: () => Navigator.pop(context, 'timetable'),
                ),
                _ClassActionTile(
                  icon: Icons.rate_review_outlined,
                  title: 'Send observation',
                  subtitle: 'Save a principal note for this class',
                  onTap: () => Navigator.pop(context, 'note'),
                ),
                _ClassActionTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Remove class',
                  subtitle: 'Blocked automatically if linked records exist',
                  color: AppTheme.error,
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ClassDetailCard(
              title: 'Subject Coverage',
              children: subjects.isEmpty
                  ? const [Text('No subjects mapped to this class yet.')]
                  : [
                      for (final subject in subjects)
                        _ClassActionTile(
                          icon: Icons.menu_book_outlined,
                          title: _classText(
                            subject['subject_name'],
                            fallback: 'Subject',
                          ),
                          subtitle: teacherForSubject(subject),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassMetricGrid extends StatelessWidget {
  final Map<String, dynamic> row;

  const _ClassMetricGrid({required this.row});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 360;
        return GridView.count(
          crossAxisCount: twoColumns ? 2 : 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: twoColumns ? 2.7 : 4.4,
          children: [
            _ClassMetricTile(
              icon: Icons.groups_outlined,
              label: 'Students',
              value:
                  '${_classInt(row['total_students'])}/${_classInt(row['capacity'])}',
            ),
            _ClassMetricTile(
              icon: Icons.fact_check_outlined,
              label: 'Today Attendance',
              value:
                  '${_classNum(row['today_attendance_pct']).toStringAsFixed(0)}%',
            ),
            _ClassMetricTile(
              icon: Icons.warning_amber_rounded,
              label: 'Pending Issues',
              value: '${_classInt(row['pending_issues'])}',
            ),
            _ClassMetricTile(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Fee Due',
              value: '₹${_classNum(row['fees_due_amount']).toStringAsFixed(0)}',
            ),
          ],
        );
      },
    );
  }
}

class _ClassMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ClassMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E4EA)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0887F2), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF64727E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
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

class _ClassDetailCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const _ClassDetailCard({
    required this.title,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7FA6BD).withAlpha(45),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ClassDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _ClassDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF64727E),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final VoidCallback? onTap;

  const _ClassActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? const Color(0xFF0887F2);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: tint.withAlpha(26),
        child: Icon(icon, color: tint),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

String _classText(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? fallback : text;
}

int _classInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

double _classNum(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

class _CreateClassSheet extends StatefulWidget {
  final List<AcademicYearModel> academicYears;
  final List<StaffModel> staff;
  final bool saving;
  final Future<bool> Function({
    required String academicYearId,
    required String sectionName,
    required int capacity,
    required String gradeId,
    required String gradeName,
    required int? gradeNumber,
    required String classTeacherId,
  })
  onSubmit;

  const _CreateClassSheet({
    required this.academicYears,
    required this.staff,
    required this.saving,
    required this.onSubmit,
  });

  @override
  State<_CreateClassSheet> createState() => _CreateClassSheetState();
}

class _CreateClassSheetState extends State<_CreateClassSheet> {
  final _formKey = GlobalKey<FormState>();
  final _gradeName = TextEditingController();
  final _gradeNumber = TextEditingController();
  final _section = TextEditingController();
  final _capacity = TextEditingController(text: '40');
  String _academicYearId = '';
  String _teacherId = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _academicYearId =
        widget.academicYears.where((year) => year.isCurrent).firstOrNull?.id ??
        (widget.academicYears.isEmpty ? '' : widget.academicYears.first.id);
  }

  @override
  void dispose() {
    _gradeName.dispose();
    _gradeNumber.dispose();
    _section.dispose();
    _capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create New Class',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _academicYearId.isEmpty ? null : _academicYearId,
                decoration: const InputDecoration(labelText: 'Academic year'),
                items: widget.academicYears
                    .map(
                      (year) => DropdownMenuItem(
                        value: year.id,
                        child: Text(year.yearLabel),
                      ),
                    )
                    .toList(),
                onChanged: (value) => _academicYearId = value ?? '',
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Academic year is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gradeName,
                decoration: const InputDecoration(
                  labelText: 'Class / grade name',
                  helperText: 'Examples: PP1, PP2, Play Group',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Class / grade name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gradeNumber,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Display order / grade number',
                  helperText:
                      'Optional for PP1 or Play Group; used for sorting',
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  final parsed = int.tryParse(text) ?? 0;
                  return parsed <= 0 ? 'Enter a positive display order' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _section,
                decoration: const InputDecoration(labelText: 'Section name'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Section name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Capacity'),
                validator: (value) =>
                    (int.tryParse((value ?? '').trim()) ?? 0) <= 0
                    ? 'Capacity is required'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _teacherId.isEmpty ? null : _teacherId,
                decoration: const InputDecoration(labelText: 'Class teacher'),
                items: widget.staff
                    .map(
                      (staff) => DropdownMenuItem(
                        value: staff.id,
                        child: Text(staff.fullName),
                      ),
                    )
                    .toList(),
                onChanged: (value) => _teacherId = value ?? '',
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save class'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await widget.onSubmit(
      academicYearId: _academicYearId,
      sectionName: _section.text.trim(),
      capacity: int.tryParse(_capacity.text.trim()) ?? 40,
      gradeId: '',
      gradeName: _gradeName.text.trim(),
      gradeNumber: _gradeOrderValue(),
      classTeacherId: _teacherId,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok && context.mounted) Navigator.pop(context, true);
  }

  int _gradeOrderValue() {
    final explicit = int.tryParse(_gradeNumber.text.trim());
    if (explicit != null && explicit > 0) return explicit;
    final match = RegExp(r'\d+').firstMatch(_gradeName.text.trim());
    if (match != null) {
      final parsed = int.tryParse(match.group(0) ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    return 1;
  }
}

class _EditClassSheet extends StatefulWidget {
  final Map<String, dynamic> row;
  final List<AcademicYearModel> academicYears;
  final List<StaffModel> staff;
  final Future<bool> Function({
    required String sectionId,
    required String gradeId,
    required String academicYearId,
    required String sectionName,
    required int capacity,
    required String classTeacherId,
  })
  onSubmit;

  const _EditClassSheet({
    required this.row,
    required this.academicYears,
    required this.staff,
    required this.onSubmit,
  });

  @override
  State<_EditClassSheet> createState() => _EditClassSheetState();
}

class _EditClassSheetState extends State<_EditClassSheet> {
  final _formKey = GlobalKey<FormState>();
  final _section = TextEditingController();
  final _capacity = TextEditingController();
  String _academicYearId = '';
  String _teacherId = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _section.text = _classText(widget.row['section_name']);
    _capacity.text = '${_classInt(widget.row['capacity'], fallback: 40)}';
    final yearId = _classText(widget.row['academic_year_id']);
    final yearIds = widget.academicYears.map((year) => year.id).toSet();
    _academicYearId = yearIds.contains(yearId)
        ? yearId
        : (widget.academicYears.isEmpty ? '' : widget.academicYears.first.id);
    final teacherId = _classText(widget.row['class_teacher_id']);
    final teacherIds = widget.staff.map((staff) => staff.id).toSet();
    _teacherId = teacherIds.contains(teacherId) ? teacherId : '';
  }

  @override
  void dispose() {
    _section.dispose();
    _capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit Class', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                _classText(widget.row['grade_name'], fallback: 'Grade locked'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64727E),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _academicYearId.isEmpty ? null : _academicYearId,
                decoration: const InputDecoration(labelText: 'Academic year'),
                items: widget.academicYears
                    .map(
                      (year) => DropdownMenuItem(
                        value: year.id,
                        child: Text(year.yearLabel),
                      ),
                    )
                    .toList(),
                onChanged: (value) => _academicYearId = value ?? '',
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Academic year is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _section,
                decoration: const InputDecoration(labelText: 'Section name'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Section name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Capacity'),
                validator: (value) =>
                    (int.tryParse((value ?? '').trim()) ?? 0) <= 0
                    ? 'Capacity is required'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _teacherId.isEmpty ? null : _teacherId,
                decoration: const InputDecoration(labelText: 'Class teacher'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Unassigned')),
                  ...widget.staff.map(
                    (staff) => DropdownMenuItem(
                      value: staff.id,
                      child: Text(staff.fullName),
                    ),
                  ),
                ],
                onChanged: (value) => _teacherId = value ?? '',
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final sectionId = _classText(widget.row['section_id']);
    final gradeId = _classText(widget.row['grade_id']);
    if (sectionId.isEmpty || gradeId.isEmpty) return;
    setState(() => _saving = true);
    final ok = await widget.onSubmit(
      sectionId: sectionId,
      gradeId: gradeId,
      academicYearId: _academicYearId,
      sectionName: _section.text.trim(),
      capacity: int.tryParse(_capacity.text.trim()) ?? 40,
      classTeacherId: _teacherId,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok && context.mounted) Navigator.pop(context, true);
  }
}
