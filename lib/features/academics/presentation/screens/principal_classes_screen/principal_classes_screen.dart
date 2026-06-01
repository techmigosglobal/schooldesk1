import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/operations_workspace.dart';
import 'package:schooldesk1/core/widgets/principal_directory_ui.dart';

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
  List<Map<String, dynamic>> _classes = [];
  List<AcademicYearModel> _academicYears = [];
  List<StaffModel> _staff = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _gradeSubjects = [];
  List<Map<String, dynamic>> _staffSubjects = [];
  List<Map<String, dynamic>> _events = [];
  int _unreadNotifications = 0;

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
      final optionalRows = await Future.wait<List<Map<String, dynamic>>>([
        _loadOptionalRows(api.getEvents()),
        _loadOptionalRows(api.getNotifications()),
      ]);
      final payload = Map<String, dynamic>.from(results[0] as Map);
      final classes = _listMap(payload['classes']);
      final notifications = optionalRows[1];
      if (!mounted) return;
      setState(() {
        _summary = _map(payload['summary']);
        _classes = classes;
        _academicYears = results[1] as List<AcademicYearModel>;
        _staff = (results[2] as PaginatedList<StaffModel>).data;
        _subjects = results[3] as List<Map<String, dynamic>>;
        _gradeSubjects = results[4] as List<Map<String, dynamic>>;
        _staffSubjects = results[5] as List<Map<String, dynamic>>;
        _events = optionalRows[0];
        _unreadNotifications = notifications
            .where(_isUnreadNotification)
            .length;
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

  Future<List<Map<String, dynamic>>> _loadOptionalRows(
    Future<List<Map<String, dynamic>>> request,
  ) async {
    try {
      return await request;
    } catch (_) {
      return const [];
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
    final showAddFab = !_loading && _error == null && rows.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F8FF),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: showAddFab
          ? SizedBox(
              width: _classesCompact(context) ? 56 : 60,
              height: _classesCompact(context) ? 56 : 60,
              child: FloatingActionButton(
                heroTag: 'classes-directory-add-class',
                onPressed: _openClassForm,
                tooltip: 'Add class',
                backgroundColor: const Color(0xFF1478F2),
                foregroundColor: Colors.white,
                elevation: 10,
                shape: const CircleBorder(),
                child: Icon(
                  Icons.add_rounded,
                  size: _classesCompact(context) ? 30 : 32,
                ),
              ),
            )
          : null,
      bottomNavigationBar: const _ClassesDirectoryBottomBar(),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF1478F2),
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: _classesPagePadding(context),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _classesContentMaxWidth(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ClassesDirectoryHeader(
                        unreadNotifications: _unreadNotifications,
                        onMenu: _showDirectoryMenu,
                        onNotifications: () => Navigator.pushNamed(
                          context,
                          AppRoutes.notificationCenter,
                          arguments: 'principal',
                        ),
                      ),
                      SizedBox(height: _classesCompact(context) ? 20 : 28),
                      _ClassesDirectorySearchField(
                        onChanged: (value) => setState(() => _search = value),
                        onFilter: _showClassFilterSheet,
                      ),
                      const SizedBox(height: 16),
                      _ClassesDirectoryMetricStrip(
                        classes: _int(
                          _summary['total_classes'],
                          fallback: _classes.length,
                        ),
                        students: _int(_summary['total_students']),
                        attendance: _num(_summary['average_attendance']),
                        issues: _int(_summary['classes_with_issues']),
                      ),
                      const SizedBox(height: 16),
                      _ClassesTodayCard(
                        eventsToday: _eventsForToday.length,
                        onCalendar: () => Navigator.pushNamed(
                          context,
                          AppRoutes.eventsCalendar,
                        ),
                      ),
                      SizedBox(height: _classesCompact(context) ? 16 : 20),
                      _ClassesDirectorySectionHeader(
                        title: 'Your Classes',
                        actionLabel: 'View all',
                        onAction: () => setState(() {
                          _capacityFilter = 'All';
                          _search = '';
                        }),
                      ),
                      const SizedBox(height: 12),
                      if (_loading)
                        const _ClassesDirectoryLoadingCard()
                      else if (_error != null)
                        _ClassesDirectoryErrorCard(
                          message: _error!,
                          onRetry: _load,
                        )
                      else if (rows.isEmpty)
                        _ClassesDirectoryEmptyCard(onAdd: _openClassForm)
                      else
                        for (final row in rows)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _ClassesDirectoryClassCard(
                              row: row,
                              subjects: _subjectsForClass(row),
                              healthLabel: _healthLabel(row),
                              healthColor: _healthColor(row),
                              onTap: () => _openClassDetail(row),
                              onAction: (action) =>
                                  _handleClassAction(action, row),
                            ),
                          ),
                      const SizedBox(height: 10),
                      _ClassesQuickActions(
                        onAddClass: _openClassForm,
                        onAddSubject: () => Navigator.pushNamed(
                          context,
                          AppRoutes.principalSubjects,
                        ),
                        onAddTeacher: () => Navigator.pushNamed(
                          context,
                          AppRoutes.staffManagement,
                        ),
                        onAttendance: () => rows.isEmpty
                            ? Navigator.pushNamed(
                                context,
                                AppRoutes.principalAttendance,
                              )
                            : _openRoute(
                                AppRoutes.principalAttendance,
                                rows.first,
                              ),
                        onFees: () => Navigator.pushNamed(
                          context,
                          AppRoutes.feeMonitoring,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _eventsForToday {
    final today = DateTime.now();
    return _events.where((event) {
      final date = _dateFromEvent(event);
      return date != null && _sameDate(date, today);
    }).toList();
  }

  Future<void> _showDirectoryMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClassesDirectoryActionSheet(
        title: 'Classes',
        actions: [
          _ClassesSheetAction(
            icon: Icons.refresh_rounded,
            label: 'Refresh directory',
            onTap: () {
              Navigator.pop(context);
              _load();
            },
          ),
          _ClassesSheetAction(
            icon: Icons.add_rounded,
            label: 'Add class',
            onTap: () {
              Navigator.pop(context);
              _openClassForm();
            },
          ),
          _ClassesSheetAction(
            icon: Icons.event_outlined,
            label: 'Open calendar',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.eventsCalendar);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showClassFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClassesDirectoryActionSheet(
        title: 'Filter classes',
        actions: [
          for (final option in const [
            ('All', Icons.all_inclusive_rounded),
            ('Healthy', Icons.health_and_safety_outlined),
            ('Full', Icons.groups_rounded),
            ('Issues', Icons.warning_amber_rounded),
          ])
            _ClassesSheetAction(
              icon: option.$2,
              label: option.$1,
              selected: _capacityFilter == option.$1,
              onTap: () {
                Navigator.pop(context);
                setState(() => _capacityFilter = option.$1);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _openClassForm() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CreateClassSetupPage(
          academicYears: _academicYears,
          staff: _staff,
          subjects: _subjects,
          gradeSubjects: _gradeSubjects,
          staffSubjects: _staffSubjects,
          saving: _saving,
          onSubmit: _createClass,
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

  Future<Map<String, dynamic>?> _createClass({
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
      final created = await BackendApiClient.instance.createPrincipalClass(
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

      return created;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to create class: $error'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _updateClass({
    required String sectionId,
    required String gradeId,
    required String gradeName,
    required int? gradeNumber,
    required String academicYearId,
    required String sectionName,
    required int capacity,
    required String classTeacherId,
  }) async {
    try {
      await BackendApiClient.instance.updatePrincipalClassSetup(
        sectionId: sectionId,
        gradeId: gradeId,
        gradeName: gradeName,
        gradeNumber: gradeNumber,
        academicYearId: academicYearId,
        sectionName: sectionName,
        capacity: capacity,
        classTeacherId: classTeacherId,
      );
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
          'Remove $className? The backend blocks removal while active students are still linked and safely cleans class setup records.',
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
      await BackendApiClient.instance.deletePrincipalClass(
        sectionId: sectionId,
      );
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
      case 'subjects':
        await _openSubjectSetup(row);
        break;
      case 'setup_timetable':
        await _openTimetableSetup(row);
        break;
      case 'setup_fees':
        await _openFeesSetup(row);
        break;
      case 'note':
        await _openInstructionSheet(row);
        break;
    }
  }

  Future<void> _openSubjectSetup(Map<String, dynamic> row) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AssignSubjectsSetupPage(
          classRow: row,
          setupPayload: const {},
          academicYears: _academicYears,
          staff: _staff,
          initialSubjects: _subjects,
          initialGradeSubjects: _gradeSubjects,
          initialStaffSubjects: _staffSubjects,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openTimetableSetup(Map<String, dynamic> row) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _GenerateTimetableSetupPage(
          classRow: row,
          academicYears: _academicYears,
          staff: _staff,
          initialSubjects: _subjects,
          initialGradeSubjects: _gradeSubjects,
          initialStaffSubjects: _staffSubjects,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openFeesSetup(Map<String, dynamic> row) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            _FeesSetupPage(classRow: row, academicYears: _academicYears),
      ),
    );
    if (changed == true) await _load();
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
        'Healthy' => issues == 0 && (capacity == 0 || students < capacity),
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

  static bool _isUnreadNotification(Map<String, dynamic> notification) {
    final readAt = _text(notification['read_at']);
    final isRead = '${notification['is_read'] ?? notification['read'] ?? ''}'
        .trim()
        .toLowerCase();
    return readAt.isEmpty && isRead != 'true' && isRead != '1';
  }

  static DateTime? _dateFromEvent(Map<String, dynamic> event) {
    final raw = _text(
      event['start_datetime'] ??
          event['start_date'] ??
          event['event_date'] ??
          event['date'],
    );
    return raw.isEmpty ? null : DateTime.tryParse(raw);
  }

  static bool _sameDate(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

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

const Color _classesDirectoryBg = Color(0xFFF2F8FF);
const Color _classesDirectoryInk = Color(0xFF071333);
const Color _classesDirectoryMuted = Color(0xFF526078);
const Color _classesDirectoryBlue = Color(0xFF1478F2);

bool _classesCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 390;

bool _classesPhone(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 430;

bool _classesTiny(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 340;

double _classesContentMaxWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 600) return 520;
  if (width < 900) return 720;
  return 860;
}

EdgeInsets _classesPagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final horizontal = width < 370
      ? 14.0
      : width < 430
      ? 20.0
      : 24.0;
  return EdgeInsets.fromLTRB(horizontal, 18, horizontal, 34);
}

class _ClassesDirectoryHeader extends StatelessWidget {
  final int unreadNotifications;
  final VoidCallback onMenu;
  final VoidCallback onNotifications;

  const _ClassesDirectoryHeader({
    required this.unreadNotifications,
    required this.onMenu,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _classesCompact(context);
    final tiny = _classesTiny(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ClassesHeaderIconButton(
          tooltip: 'Menu',
          icon: Icons.menu_rounded,
          onTap: onMenu,
        ),
        SizedBox(width: compact ? 12 : 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Class Hub',
                semanticsLabel: 'Classes Directory',
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: GoogleFonts.dmSans(
                  color: _classesDirectoryInk,
                  fontSize: tiny
                      ? 24
                      : compact
                      ? 26
                      : 30,
                  fontWeight: FontWeight.w900,
                  height: 1.02,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: compact ? 6 : 9),
              Text(
                'Open a class, manage details, and jump into roster actions',
                maxLines: tiny ? 3 : 2,
                overflow: TextOverflow.visible,
                style: GoogleFonts.dmSans(
                  color: _classesDirectoryMuted,
                  fontSize: tiny
                      ? 12.5
                      : compact
                      ? 13.5
                      : 15,
                  fontWeight: FontWeight.w600,
                  height: 1.18,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: compact ? 8 : 14),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _ClassesHeaderIconButton(
              tooltip: 'Notifications',
              icon: unreadNotifications > 0
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none_rounded,
              onTap: onNotifications,
            ),
            if (unreadNotifications > 0)
              Positioned(
                right: 7,
                top: 5,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D4F),
                    shape: BoxShape.circle,
                    border: Border.all(color: _classesDirectoryBg, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ClassesHeaderIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _ClassesHeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _classesCompact(context);
    final tiny = _classesTiny(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: tiny
              ? 40
              : compact
              ? 44
              : 48,
          height: tiny
              ? 40
              : compact
              ? 44
              : 48,
          child: Icon(
            icon,
            color: _classesDirectoryInk,
            size: tiny
                ? 25
                : compact
                ? 28
                : 32,
          ),
        ),
      ),
    );
  }
}

class _ClassesDirectorySearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback onFilter;

  const _ClassesDirectorySearchField({
    required this.onChanged,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _classesCompact(context);
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 54 : 60),
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5E2F1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF86A5C7).withAlpha(24),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(width: compact ? 12 : 16),
          Icon(
            Icons.search_rounded,
            color: _classesDirectoryMuted,
            size: compact ? 26 : 30,
          ),
          SizedBox(width: compact ? 7 : 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              maxLines: 1,
              style: GoogleFonts.dmSans(
                color: _classesDirectoryInk,
                fontSize: compact ? 14.5 : 16.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                hintText: 'Search class, teacher, section',
                hintStyle: GoogleFonts.dmSans(
                  color: _classesDirectoryMuted,
                  fontSize: compact ? 14.5 : 16.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Filter classes',
            onPressed: onFilter,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(Icons.tune_rounded, size: compact ? 24 : 28),
            color: _classesDirectoryMuted,
          ),
          SizedBox(width: compact ? 4 : 8),
        ],
      ),
    );
  }
}

class _ClassesDirectoryMetricStrip extends StatelessWidget {
  final int classes;
  final int students;
  final double attendance;
  final int issues;

  const _ClassesDirectoryMetricStrip({
    required this.classes,
    required this.students,
    required this.attendance,
    required this.issues,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _classesPanelDecoration(radius: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 520
              ? 2
              : constraints.maxWidth < 780
              ? 3
              : 4;
          final spacing = constraints.maxWidth < 360 ? 8.0 : 10.0;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: 10,
            children: [
              SizedBox(
                width: width,
                child: _ClassesMetricTile(
                  icon: Icons.meeting_room_outlined,
                  value: '$classes',
                  label: 'Classes',
                  color: _classesDirectoryBlue,
                  tone: const Color(0xFFEAF3FF),
                ),
              ),
              SizedBox(
                width: width,
                child: _ClassesMetricTile(
                  icon: Icons.school_outlined,
                  value: '$students',
                  label: 'Students',
                  color: const Color(0xFF25B65A),
                  tone: const Color(0xFFEAFBF0),
                ),
              ),
              SizedBox(
                width: width,
                child: _ClassesMetricTile(
                  icon: Icons.stacked_line_chart_rounded,
                  value: '${attendance.toStringAsFixed(0)}%',
                  label: 'Avg attendance',
                  color: const Color(0xFF7C3AED),
                  tone: const Color(0xFFF4ECFF),
                ),
              ),
              SizedBox(
                width: width,
                child: _ClassesMetricTile(
                  icon: Icons.warning_amber_rounded,
                  value: '$issues',
                  label: 'Issues',
                  color: const Color(0xFFF97316),
                  tone: const Color(0xFFFFF1E6),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ClassesMetricTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color tone;

  const _ClassesMetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _classesCompact(context);
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 92 : 104),
      padding: EdgeInsets.fromLTRB(
        compact ? 9 : 12,
        compact ? 10 : 13,
        compact ? 8 : 10,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(35)),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: compact ? 36 : 42,
            height: compact ? 36 : 42,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: compact ? 23 : 27),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: _classesDirectoryInk,
                  fontSize: compact ? 21 : 25,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: _classesDirectoryInk,
                  fontSize: compact ? 10.5 : 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassesTodayCard extends StatelessWidget {
  final int eventsToday;
  final VoidCallback onCalendar;

  const _ClassesTodayCard({
    required this.eventsToday,
    required this.onCalendar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final details = Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              color: _classesDirectoryBlue,
              size: compact ? 30 : 35,
            ),
            SizedBox(width: compact ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _todayLabel(),
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.visible,
                    style: GoogleFonts.dmSans(
                      color: _classesDirectoryInk,
                      fontSize: compact ? 14.5 : 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    eventsToday == 0
                        ? 'No scheduled events today'
                        : '$eventsToday scheduled event${eventsToday == 1 ? '' : 's'} today',
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.visible,
                    style: GoogleFonts.dmSans(
                      color: _classesDirectoryMuted,
                      fontSize: compact ? 12.5 : 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final button = OutlinedButton(
          onPressed: onCalendar,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(compact ? 112 : 126, 44),
            foregroundColor: _classesDirectoryBlue,
            side: const BorderSide(color: Color(0xFFD5E5F7)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            textStyle: GoogleFonts.dmSans(
              fontSize: compact ? 13 : 14.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          child: const Text('View calendar'),
        );

        return Container(
          padding: EdgeInsets.fromLTRB(18, 16, compact ? 14 : 16, 16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(225),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD5E5F7)),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    details,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: button),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 10),
                    button,
                  ],
                ),
        );
      },
    );
  }
}

class _ClassesDirectorySectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _ClassesDirectorySectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.dmSans(
              color: _classesDirectoryInk,
              fontSize: _classesCompact(context) ? 18 : 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: _classesDirectoryBlue,
            textStyle: GoogleFonts.dmSans(
              fontSize: _classesCompact(context) ? 14.5 : 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _SetupProgressChip extends StatelessWidget {
  final int number;
  final String label;
  final bool active;
  final bool complete;

  const _SetupProgressChip({
    required this.number,
    required this.label,
    required this.active,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    final color = complete
        ? const Color(0xFF3DBB75)
        : active
        ? _CreateClassSetupPageState._primary
        : const Color(0xFFE6EDF5);
    final textColor = complete || active
        ? Colors.white
        : _CreateClassSetupPageState._ink;
    return Container(
      width: 132,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? _CreateClassSetupPageState._primary
              : _CreateClassSetupPageState._line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: complete
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    )
                  : Text(
                      '$number',
                      style: GoogleFonts.dmSans(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: active
                    ? _CreateClassSetupPageState._primary
                    : _CreateClassSetupPageState._ink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassesDirectoryClassCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final List<Map<String, dynamic>> subjects;
  final String healthLabel;
  final Color healthColor;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  const _ClassesDirectoryClassCard({
    required this.row,
    required this.subjects,
    required this.healthLabel,
    required this.healthColor,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final students = _classInt(row['total_students']);
    final capacity = _classInt(row['capacity']);
    final issues = _classInt(row['pending_issues']);
    final dueFees = _classNum(row['fees_due_amount']);
    final compact = _classesCompact(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: _classesPanelDecoration(radius: 17),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ClassesIconTile(
                    icon: Icons.meeting_room_outlined,
                    color: _classesDirectoryBlue,
                    tone: const Color(0xFFEAF3FF),
                    size: compact ? 52 : 58,
                  ),
                  SizedBox(width: compact ? 12 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _classText(row['class_name'], fallback: 'Class'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: _classesDirectoryInk,
                            fontSize: compact ? 22 : 26,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _ClassesStatusPill(
                            label: healthLabel,
                            color: healthColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_classText(row['class_teacher'], fallback: 'Teacher pending')}  •  $students/$capacity students',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: _classesDirectoryMuted,
                            fontSize: compact ? 13 : 14.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Class options',
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: _classesDirectoryInk,
                      size: compact ? 27 : 30,
                    ),
                    onSelected: onAction,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'details',
                        child: Text('View details'),
                      ),
                      PopupMenuItem(value: 'edit', child: Text('Edit class')),
                      PopupMenuItem(
                        value: 'students',
                        child: Text('Open roster'),
                      ),
                      PopupMenuItem(
                        value: 'attendance',
                        child: Text('Open attendance'),
                      ),
                      PopupMenuItem(
                        value: 'timetable',
                        child: Text('Open timetable'),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'subjects',
                        child: Text('Setup subjects'),
                      ),
                      PopupMenuItem(
                        value: 'setup_timetable',
                        child: Text('Generate timetable'),
                      ),
                      PopupMenuItem(
                        value: 'setup_fees',
                        child: Text('Setup fees'),
                      ),
                      PopupMenuItem(value: 'note', child: Text('Save note')),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Remove class'),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: compact ? 14 : 16),
              Container(
                padding: EdgeInsets.symmetric(vertical: compact ? 11 : 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFDDE8F6)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final metrics = [
                      _ClassesClassMetric(
                        icon: Icons.groups_2_outlined,
                        color: _classesDirectoryBlue,
                        value: '$students/$capacity',
                        label: 'Students',
                      ),
                      _ClassesClassMetric(
                        icon: Icons.menu_book_outlined,
                        color: const Color(0xFF7487FF),
                        value: '${subjects.length}',
                        label: 'Subjects',
                      ),
                      _ClassesClassMetric(
                        icon: Icons.check_circle_outline_rounded,
                        color: const Color(0xFF22B85F),
                        value:
                            '${_classNum(row['today_attendance_pct']).toStringAsFixed(0)}%',
                        label: 'Attendance',
                      ),
                      _ClassesClassMetric(
                        icon: Icons.currency_rupee_rounded,
                        color: const Color(0xFFF97316),
                        value: _formatCurrencyCompact(dueFees),
                        label: 'Due Fees',
                      ),
                    ];
                    if (constraints.maxWidth < 370) {
                      final tileWidth = (constraints.maxWidth - 1) / 2;
                      return Wrap(
                        children: [
                          for (final metric in metrics)
                            SizedBox(
                              width: tileWidth,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: metric,
                              ),
                            ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        for (var i = 0; i < metrics.length; i++) ...[
                          Expanded(child: metrics[i]),
                          if (i < metrics.length - 1) _ClassesMetricDivider(),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 13),
              Container(
                constraints: const BoxConstraints(minHeight: 50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6FDFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDCEFE9)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: compact ? 14 : 15,
                      backgroundColor: issues > 0
                          ? const Color(0xFFFFE8D8)
                          : const Color(0xFFD8F6E6),
                      child: Icon(
                        issues > 0
                            ? Icons.priority_high_rounded
                            : Icons.check_rounded,
                        color: issues > 0
                            ? const Color(0xFFF97316)
                            : const Color(0xFF22B85F),
                        size: compact ? 18 : 19,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        issues == 0
                            ? 'No pending actions'
                            : '$issues pending action${issues == 1 ? '' : 's'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: _classesDirectoryInk,
                          fontSize: compact ? 14 : 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF5B6475),
                      size: 28,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassesClassMetric extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _ClassesClassMetric({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _classesCompact(context);
    return Column(
      children: [
        Icon(icon, color: color, size: compact ? 22 : 26),
        SizedBox(height: compact ? 5 : 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: _classesDirectoryInk,
            fontSize: compact ? 14.5 : 17,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: _classesDirectoryMuted,
            fontSize: compact ? 10.5 : 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ClassesMetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 58, color: const Color(0xFFDDE8F6));
  }
}

class _ClassesStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _ClassesStatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final compact = _classesCompact(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          color: color,
          fontSize: compact ? 12.5 : 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ClassesIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color tone;
  final double size;

  const _ClassesIconTile({
    required this.icon,
    required this.color,
    required this.tone,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: size * 0.56),
    );
  }
}

class _ClassesQuickActions extends StatelessWidget {
  final VoidCallback onAddClass;
  final VoidCallback onAddSubject;
  final VoidCallback onAddTeacher;
  final VoidCallback onAttendance;
  final VoidCallback onFees;

  const _ClassesQuickActions({
    required this.onAddClass,
    required this.onAddSubject,
    required this.onAddTeacher,
    required this.onAttendance,
    required this.onFees,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _classesCompact(context);
    return Container(
      padding: EdgeInsets.fromLTRB(14, compact ? 15 : 17, 14, 15),
      decoration: _classesPanelDecoration(radius: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.dmSans(
              color: _classesDirectoryInk,
              fontSize: compact ? 16 : 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: compact ? 12 : 15),
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = compact ? 8.0 : 12.0;
              final columns = constraints.maxWidth < 340
                  ? 2
                  : constraints.maxWidth < 560
                  ? 3
                  : 5;
              final tileWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _ClassesQuickActionTile(
                      icon: Icons.add_rounded,
                      label: 'Add\nClass',
                      color: _classesDirectoryBlue,
                      tone: const Color(0xFFEAF3FF),
                      onTap: onAddClass,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _ClassesQuickActionTile(
                      icon: Icons.menu_book_outlined,
                      label: 'Add\nSubject',
                      color: const Color(0xFF25B65A),
                      tone: const Color(0xFFEAFBF0),
                      onTap: onAddSubject,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _ClassesQuickActionTile(
                      icon: Icons.person_outline_rounded,
                      label: 'Add\nTeacher',
                      color: const Color(0xFF7C3AED),
                      tone: const Color(0xFFF4ECFF),
                      onTap: onAddTeacher,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _ClassesQuickActionTile(
                      icon: Icons.calendar_month_outlined,
                      label: 'Attendance',
                      color: const Color(0xFFF97316),
                      tone: const Color(0xFFFFF1E6),
                      onTap: onAttendance,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _ClassesQuickActionTile(
                      icon: Icons.currency_rupee_rounded,
                      label: 'Fees',
                      color: const Color(0xFF12AFC6),
                      tone: const Color(0xFFE6F8FB),
                      onTap: onFees,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClassesQuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color tone;
  final VoidCallback onTap;

  const _ClassesQuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _classesCompact(context);
    return Semantics(
      button: true,
      label: label.replaceAll('\n', ' '),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 76 : 84),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 5,
            vertical: compact ? 9 : 11,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(38)),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(14),
                blurRadius: 13,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: compact ? 29 : 32,
                height: compact ? 29 : 32,
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: compact ? 21 : 24),
              ),
              SizedBox(height: compact ? 6 : 8),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: _classesDirectoryInk,
                  fontSize: compact ? 10.5 : 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassesDirectoryLoadingCard extends StatelessWidget {
  const _ClassesDirectoryLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 152,
      alignment: Alignment.center,
      decoration: _classesPanelDecoration(radius: 17),
      child: const CircularProgressIndicator(color: _classesDirectoryBlue),
    );
  }
}

class _ClassesDirectoryErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ClassesDirectoryErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _classesPanelDecoration(radius: 17),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppTheme.error, size: 38),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: _classesDirectoryMuted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.3,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ClassesDirectoryEmptyCard extends StatelessWidget {
  final VoidCallback onAdd;

  const _ClassesDirectoryEmptyCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _classesPanelDecoration(radius: 17),
      child: Column(
        children: [
          const _ClassesIconTile(
            icon: Icons.meeting_room_outlined,
            color: _classesDirectoryBlue,
            tone: Color(0xFFEAF3FF),
            size: 62,
          ),
          const SizedBox(height: 12),
          Text(
            'No classes found',
            style: GoogleFonts.dmSans(
              color: _classesDirectoryInk,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a class or adjust the directory filters.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: _classesDirectoryMuted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Class'),
          ),
        ],
      ),
    );
  }
}

class _ClassesDirectoryBottomBar extends StatelessWidget {
  const _ClassesDirectoryBottomBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7186A3).withAlpha(36),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              _ClassesBottomNavItem(
                label: 'Home',
                icon: Icons.home_rounded,
                selected: true,
                onTap: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.principalDashboard,
                  (_) => false,
                ),
              ),
              _ClassesBottomNavItem(
                label: 'Search',
                icon: Icons.search_rounded,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.globalSearch,
                  arguments: 'principal',
                ),
              ),
              _ClassesBottomNavItem(
                label: 'Inbox',
                icon: Icons.mail_outline_rounded,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.principalInbox),
              ),
              _ClassesBottomNavItem(
                label: 'Profile',
                icon: Icons.person_outline_rounded,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.profileScreen,
                  arguments: 'principal',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassesBottomNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ClassesBottomNavItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _classesCompact(context);
    final color = selected ? _classesDirectoryBlue : _classesDirectoryInk;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: BoxConstraints(minHeight: compact ? 54 : 60),
            padding: EdgeInsets.symmetric(vertical: compact ? 6 : 7),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEAF3FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: compact ? 22 : 24),
                SizedBox(height: compact ? 3 : 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: color,
                    fontSize: compact ? 11.5 : 12.5,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassesDirectoryActionSheet extends StatelessWidget {
  final String title;
  final List<_ClassesSheetAction> actions;

  const _ClassesDirectoryActionSheet({
    required this.title,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: GoogleFonts.dmSans(
                color: _classesDirectoryInk,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            for (final action in actions)
              ListTile(
                minVerticalPadding: 8,
                leading: Icon(
                  action.icon,
                  color: action.selected
                      ? _classesDirectoryBlue
                      : _classesDirectoryMuted,
                ),
                title: Text(
                  action.label,
                  style: GoogleFonts.dmSans(
                    color: _classesDirectoryInk,
                    fontWeight: action.selected
                        ? FontWeight.w900
                        : FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                trailing: action.selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: _classesDirectoryBlue,
                      )
                    : null,
                onTap: action.onTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _ClassesSheetAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  const _ClassesSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
}

BoxDecoration _classesPanelDecoration({required double radius}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFE2ECF7)),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF86A5C7).withAlpha(22),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

String _todayLabel() {
  final now = DateTime.now();
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return 'Today is ${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
}

String _formatCurrencyCompact(num value) {
  if (value == 0) return '₹0';
  if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
  if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
  return '₹${value.round()}';
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
        title: Text(className, maxLines: 1, overflow: TextOverflow.ellipsis),
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
              PopupMenuDivider(),
              PopupMenuItem(value: 'subjects', child: Text('Setup subjects')),
              PopupMenuItem(
                value: 'setup_timetable',
                child: Text('Generate timetable'),
              ),
              PopupMenuItem(value: 'setup_fees', child: Text('Setup fees')),
              PopupMenuItem(value: 'note', child: Text('Send observation')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: Text('Remove class')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            _classesPhone(context) ? 16 : 22,
            12,
            _classesPhone(context) ? 16 : 22,
            96,
          ),
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
              title: 'Class Hub Actions',
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
                  icon: Icons.menu_book_outlined,
                  title: 'Setup subjects',
                  subtitle: 'Assign subjects and teachers for this class',
                  onTap: () => Navigator.pop(context, 'subjects'),
                ),
                _ClassActionTile(
                  icon: Icons.auto_fix_high_rounded,
                  title: 'Generate timetable',
                  subtitle: 'Create a smart timetable for this class',
                  onTap: () => Navigator.pop(context, 'setup_timetable'),
                ),
                _ClassActionTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Setup fees',
                  subtitle: 'Create or reuse a fee structure for this class',
                  onTap: () => Navigator.pop(context, 'setup_fees'),
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
    final phone = _classesPhone(context);
    return Container(
      padding: EdgeInsets.all(phone ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(phone ? 10 : 8),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidget = Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF64727E),
              fontWeight: FontWeight.w800,
            ),
          );
          final valueWidget = Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          );
          if (constraints.maxWidth < 330) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 4), valueWidget],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 124, child: labelWidget),
              Expanded(child: valueWidget),
            ],
          );
        },
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

Map<String, dynamic> _classMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _classLabel(String gradeName, String sectionName) {
  final grade = gradeName.trim();
  final section = sectionName.trim();
  if (grade.isEmpty) return section.isEmpty ? 'Class' : section;
  if (section.isEmpty) return grade;
  if (grade.toLowerCase().contains(section.toLowerCase())) return grade;
  return '$grade - $section';
}

class _CreateClassSetupPage extends StatefulWidget {
  final List<AcademicYearModel> academicYears;
  final List<StaffModel> staff;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> gradeSubjects;
  final List<Map<String, dynamic>> staffSubjects;
  final bool saving;
  final Future<Map<String, dynamic>?> Function({
    required String academicYearId,
    required String sectionName,
    required int capacity,
    required String gradeId,
    required String gradeName,
    required int? gradeNumber,
    required String classTeacherId,
  })
  onSubmit;

  const _CreateClassSetupPage({
    required this.academicYears,
    required this.staff,
    required this.subjects,
    required this.gradeSubjects,
    required this.staffSubjects,
    required this.saving,
    required this.onSubmit,
  });

  @override
  State<_CreateClassSetupPage> createState() => _CreateClassSetupPageState();
}

class _CreateClassSetupPageState extends State<_CreateClassSetupPage> {
  static const _background = Color(0xFFF3F9FF);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF697386);
  static const _line = Color(0xFFDCE6F2);
  static const _primary = Color(0xFF1E63F3);

  final _formKey = GlobalKey<FormState>();
  final _gradeName = TextEditingController();
  final _gradeNumber = TextEditingController();
  final _section = TextEditingController();
  final _capacity = TextEditingController(text: '40');
  String _academicYearId = '';
  String _teacherId = '';
  bool _saving = false;

  bool get _busy => _saving || widget.saving;

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
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            const _ClassSetupHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: _ClassSetupCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _ClassSetupCardHeader(),
                            const SizedBox(height: 20),
                            const _ClassSetupStepRail(activeIndex: 0),
                            const SizedBox(height: 22),
                            _ClassSetupInputField(
                              label: 'Class Name',
                              required: true,
                              controller: _gradeName,
                              hint: 'Enter class name',
                              icon: Icons.school_outlined,
                              iconColor: _primary,
                              iconTone: const Color(0xFFEAF2FF),
                              enabled: !_busy,
                              textCapitalization: TextCapitalization.words,
                              validator: (value) => (value ?? '').trim().isEmpty
                                  ? 'Class name is required'
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            _ClassSetupTwoColumnRow(
                              children: [
                                _ClassSetupInputField(
                                  label: 'Section',
                                  required: true,
                                  controller: _section,
                                  hint: 'Enter section',
                                  icon: Icons.groups_2_outlined,
                                  iconColor: const Color(0xFF7C3AED),
                                  iconTone: const Color(0xFFF3E8FF),
                                  enabled: !_busy,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  validator: (value) =>
                                      (value ?? '').trim().isEmpty
                                      ? 'Section is required'
                                      : null,
                                ),
                                _ClassSetupSelectField(
                                  label: 'Academic Year',
                                  required: true,
                                  value: _academicYearId,
                                  hint: 'Select year',
                                  icon: Icons.calendar_month_outlined,
                                  iconColor: const Color(0xFF16A34A),
                                  iconTone: const Color(0xFFEAFBF0),
                                  enabled: !_busy,
                                  items: widget.academicYears
                                      .map(
                                        (year) => DropdownMenuItem(
                                          value: year.id,
                                          child: Text(
                                            year.yearLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _academicYearId = value),
                                  validator: (value) =>
                                      (value ?? '').trim().isEmpty
                                      ? 'Academic year is required'
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _ClassSetupTwoColumnRow(
                              children: [
                                _ClassSetupInputField(
                                  label: 'Capacity',
                                  required: true,
                                  controller: _capacity,
                                  hint: '0',
                                  icon: Icons.event_seat_outlined,
                                  iconColor: const Color(0xFFE11D48),
                                  iconTone: const Color(0xFFFFEAF1),
                                  enabled: !_busy,
                                  keyboardType: TextInputType.number,
                                  validator: (value) =>
                                      (int.tryParse((value ?? '').trim()) ??
                                              0) <=
                                          0
                                      ? 'Capacity is required'
                                      : null,
                                ),
                                _ClassSetupSelectField(
                                  label: 'Class Teacher',
                                  value: _teacherId,
                                  hint: 'Choose teacher',
                                  icon: Icons.person_pin_outlined,
                                  iconColor: const Color(0xFFF59E0B),
                                  iconTone: const Color(0xFFFFF7E8),
                                  enabled: !_busy,
                                  items: [
                                    const DropdownMenuItem(
                                      value: '',
                                      child: Text('Not assigned'),
                                    ),
                                    ...widget.staff.map(
                                      (staff) => DropdownMenuItem(
                                        value: staff.id,
                                        child: Text(
                                          staff.fullName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _teacherId = value),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _ClassSetupInputField(
                              label: 'Display Order',
                              controller: _gradeNumber,
                              hint: 'Optional sorting order',
                              icon: Icons.format_list_numbered_rounded,
                              iconColor: const Color(0xFF0EA5E9),
                              iconTone: const Color(0xFFEAF8FF),
                              enabled: !_busy,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final text = (value ?? '').trim();
                                if (text.isEmpty) return null;
                                final parsed = int.tryParse(text) ?? 0;
                                return parsed <= 0
                                    ? 'Enter a positive display order'
                                    : null;
                              },
                            ),
                            const SizedBox(height: 24),
                            const _ClassSetupTip(),
                            const SizedBox(height: 26),
                            _ClassSetupActionButton(
                              saving: _busy,
                              onPressed: _busy ? null : _save,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final created = await widget.onSubmit(
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
    if (created != null && context.mounted) {
      Navigator.of(context).pushReplacement<bool, bool>(
        MaterialPageRoute(
          builder: (_) => _AssignSubjectsSetupPage(
            classRow: _createdClassRow(created),
            setupPayload: created,
            academicYears: widget.academicYears,
            staff: widget.staff,
            initialSubjects: widget.subjects,
            initialGradeSubjects: widget.gradeSubjects,
            initialStaffSubjects: widget.staffSubjects,
          ),
        ),
        result: true,
      );
    }
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

  Map<String, dynamic> _createdClassRow(Map<String, dynamic> created) {
    final section = _classMap(created['section']);
    final grade = _classMap(created['grade']);
    final sectionName = _classText(
      section['section_name'],
      fallback: _section.text.trim(),
    );
    final gradeName = _classText(
      grade['grade_name'],
      fallback: _gradeName.text.trim(),
    );
    final capacity = _classInt(
      section['capacity'],
      fallback: int.tryParse(_capacity.text.trim()) ?? 40,
    );
    return {
      'section_id': _classText(section['id'] ?? section['section_id']),
      'grade_id': _classText(grade['id'] ?? section['grade_id']),
      'academic_year_id': _classText(
        section['academic_year_id'],
        fallback: _academicYearId,
      ),
      'class_name': _classLabel(gradeName, sectionName),
      'section_name': sectionName,
      'grade_name': gradeName,
      'grade_number': _classInt(
        grade['grade_number'],
        fallback: _gradeOrderValue(),
      ),
      'capacity': capacity,
      'class_teacher_id': _classText(
        section['class_teacher_id'],
        fallback: _teacherId,
      ),
      'total_students': 0,
    };
  }
}

class _ClassSetupHeader extends StatelessWidget {
  const _ClassSetupHeader();

  @override
  Widget build(BuildContext context) {
    final phone = _classesPhone(context);
    final tiny = _classesTiny(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(phone ? 14 : 30, 16, phone ? 14 : 30, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: _CreateClassSetupPageState._ink,
            iconSize: tiny ? 26 : 30,
          ),
          SizedBox(
            width: tiny
                ? 4
                : phone
                ? 8
                : 16,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Class',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: _CreateClassSetupPageState._ink,
                    fontSize: tiny
                        ? 21
                        : phone
                        ? 24
                        : 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a new class to your school',
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.dmSans(
                    color: _CreateClassSetupPageState._muted,
                    fontSize: tiny
                        ? 12.5
                        : phone
                        ? 14
                        : 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (!tiny) ...[
            const SizedBox(width: 10),
            Container(
              width: phone ? 50 : 68,
              height: phone ? 50 : 68,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB7CEE5).withAlpha(70),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.maps_home_work_rounded,
                color: _CreateClassSetupPageState._primary,
                size: phone ? 27 : 34,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClassSetupCard extends StatelessWidget {
  final Widget child;

  const _ClassSetupCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final phone = _classesPhone(context);
    return Container(
      padding: EdgeInsets.all(phone ? 18 : 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(phone ? 18 : 24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9DB9D2).withAlpha(45),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ClassSetupCardHeader extends StatelessWidget {
  const _ClassSetupCardHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: _CreateClassSetupPageState._primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.maps_home_work_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Classes Setup',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: _CreateClassSetupPageState._ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter class details to start the setup flow.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: _CreateClassSetupPageState._muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(height: 1, color: _CreateClassSetupPageState._line),
      ],
    );
  }
}

class _ClassSetupStepRail extends StatelessWidget {
  final int activeIndex;

  const _ClassSetupStepRail({required this.activeIndex});

  static const _steps = [
    'Classes setup',
    'Subjects creation and assigning teachers',
    'Time Table Generation',
    'Fee setup',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _steps.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final active = index == activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? _CreateClassSetupPageState._primary
                  : const Color(0xFFF3F7FC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? _CreateClassSetupPageState._primary
                    : _CreateClassSetupPageState._line,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${index + 1}',
                  style: GoogleFonts.dmSans(
                    color: active ? Colors.white : const Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _steps[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: active ? Colors.white : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ClassSetupTwoColumnRow extends StatelessWidget {
  final List<Widget> children;

  const _ClassSetupTwoColumnRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 18),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 28),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _ClassSetupInputField extends StatelessWidget {
  final String label;
  final bool required;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final Color iconTone;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _ClassSetupInputField({
    required this.label,
    this.required = false,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.iconTone,
    required this.enabled,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return _ClassSetupFieldShell(
      label: label,
      required: required,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: _fieldTextStyle,
        decoration: _fieldDecoration(
          hint: hint,
          icon: icon,
          iconColor: iconColor,
          iconTone: iconTone,
        ),
        validator: validator,
      ),
    );
  }
}

class _ClassSetupSelectField extends StatelessWidget {
  final String label;
  final bool required;
  final String value;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final Color iconTone;
  final bool enabled;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const _ClassSetupSelectField({
    required this.label,
    this.required = false,
    required this.value,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.iconTone,
    required this.enabled,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = items.any((item) => item.value == value);
    return _ClassSetupFieldShell(
      label: label,
      required: required,
      child: DropdownButtonFormField<String>(
        initialValue: hasValue ? value : null,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        decoration: _fieldDecoration(
          hint: hint,
          icon: icon,
          iconColor: iconColor,
          iconTone: iconTone,
        ),
        items: items,
        onChanged: enabled
            ? (selected) => onChanged?.call(selected ?? '')
            : null,
        validator: validator,
      ),
    );
  }
}

class _ClassSetupFieldShell extends StatelessWidget {
  final String label;
  final bool required;
  final Widget child;

  const _ClassSetupFieldShell({
    required this.label,
    required this.required,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: GoogleFonts.dmSans(
              color: _CreateClassSetupPageState._ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
            children: [
              if (required)
                TextSpan(
                  text: ' *',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFEF4444),
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _ClassSetupTip extends StatelessWidget {
  const _ClassSetupTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4E9FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Color(0xFFDDEEFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: _CreateClassSetupPageState._primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tip',
                  style: GoogleFonts.dmSans(
                    color: _CreateClassSetupPageState._ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This creates the class and first section on the central academic server.',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF334155),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
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

class _ClassSetupActionButton extends StatelessWidget {
  final bool saving;
  final VoidCallback? onPressed;

  const _ClassSetupActionButton({
    required this.saving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final phone = _classesPhone(context);
    return SizedBox(
      height: phone ? 56 : 62,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _CreateClassSetupPageState._primary,
          disabledBackgroundColor: const Color(0xFF9BB9F8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_rounded, size: 28),
        label: Text(
          saving ? 'Saving...' : 'Save & Continue',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: phone ? 18 : 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

TextStyle get _fieldTextStyle => GoogleFonts.dmSans(
  color: _CreateClassSetupPageState._ink,
  fontSize: 17,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
);

InputDecoration _fieldDecoration({
  required String hint,
  required IconData icon,
  required Color iconColor,
  required Color iconTone,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.dmSans(
      color: const Color(0xFF98A2B3),
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    filled: true,
    fillColor: Colors.white,
    prefixIcon: Padding(
      padding: const EdgeInsets.all(10),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: iconTone,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 26),
      ),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 66, minHeight: 66),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _CreateClassSetupPageState._line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _CreateClassSetupPageState._line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: _CreateClassSetupPageState._primary,
        width: 1.4,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFEF4444)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.4),
    ),
  );
}

class _AssignSubjectsSetupPage extends StatefulWidget {
  final Map<String, dynamic> classRow;
  final Map<String, dynamic> setupPayload;
  final List<AcademicYearModel> academicYears;
  final List<StaffModel> staff;
  final List<Map<String, dynamic>> initialSubjects;
  final List<Map<String, dynamic>> initialGradeSubjects;
  final List<Map<String, dynamic>> initialStaffSubjects;

  const _AssignSubjectsSetupPage({
    required this.classRow,
    required this.setupPayload,
    required this.academicYears,
    required this.staff,
    required this.initialSubjects,
    required this.initialGradeSubjects,
    required this.initialStaffSubjects,
  });

  @override
  State<_AssignSubjectsSetupPage> createState() =>
      _AssignSubjectsSetupPageState();
}

class _AssignSubjectsSetupPageState extends State<_AssignSubjectsSetupPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _gradeSubjects = [];
  List<Map<String, dynamic>> _staffSubjects = [];

  static const _background = _CreateClassSetupPageState._background;

  String get _sectionId => _classText(widget.classRow['section_id']);
  String get _gradeId => _classText(widget.classRow['grade_id']);
  String get _academicYearId => _classText(widget.classRow['academic_year_id']);
  String get _sectionName => _classText(widget.classRow['section_name']);
  String get _gradeName => _classText(widget.classRow['grade_name']);
  String get _className => _classText(
    widget.classRow['class_name'],
    fallback: _classLabel(_gradeName, _sectionName),
  );

  @override
  void initState() {
    super.initState();
    _subjects = _mergedRows([
      widget.initialSubjects,
      _listMap(widget.setupPayload['subjects']),
    ]);
    _gradeSubjects = _mergedRows([
      widget.initialGradeSubjects,
      _listMap(widget.setupPayload['grade_subjects']),
    ]);
    _staffSubjects = _mergedRows([
      widget.initialStaffSubjects,
      _listMap(widget.setupPayload['staff_subjects']),
    ]);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        BackendApiClient.instance.getRawList(
          '/subjects',
          queryParameters: const {'page_size': 500},
        ),
        BackendApiClient.instance.getRawList(
          '/grade-subjects',
          queryParameters: {'grade_id': _gradeId, 'page_size': 500},
        ),
        BackendApiClient.instance.getRawList(
          '/staff-subjects',
          queryParameters: {'grade_id': _gradeId, 'page_size': 500},
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _subjects = results[0];
        _gradeSubjects = results[1];
        _staffSubjects = results[2];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load subject setup from backend. $error';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _mappedSubjects {
    final ids = <String>{
      ..._gradeSubjects
          .where((row) => _classText(row['grade_id']) == _gradeId)
          .map((row) => _classText(row['subject_id'])),
      ..._staffSubjects
          .where((row) => _isClassStaffSubject(row))
          .map((row) => _classText(row['subject_id'])),
    }..removeWhere((id) => id.isEmpty);
    final rows = _subjects
        .where((subject) => ids.contains(_subjectId(subject)))
        .toList();
    rows.sort(
      (left, right) =>
          _subjectName(left).toLowerCase().compareTo(_subjectName(right)),
    );
    return rows;
  }

  bool _isClassStaffSubject(Map<String, dynamic> row) {
    final sectionId = _classText(row['section_id']);
    return _classText(row['grade_id']) == _gradeId &&
        (sectionId.isEmpty || sectionId == _sectionId);
  }

  Map<String, dynamic> _gradeSubjectFor(String subjectId) {
    return _gradeSubjects.firstWhere(
      (row) =>
          _classText(row['grade_id']) == _gradeId &&
          _classText(row['subject_id']) == subjectId,
      orElse: () => const {},
    );
  }

  Map<String, dynamic> _staffSubjectFor(String subjectId) {
    final exact = _staffSubjects.where(
      (row) =>
          _classText(row['subject_id']) == subjectId &&
          _classText(row['grade_id']) == _gradeId &&
          _classText(row['section_id']) == _sectionId,
    );
    if (exact.isNotEmpty) return exact.first;
    return _staffSubjects.firstWhere(
      (row) =>
          _classText(row['subject_id']) == subjectId &&
          _classText(row['grade_id']) == _gradeId &&
          _classText(row['section_id']).isEmpty,
      orElse: () => const {},
    );
  }

  Future<void> _openAddSubject() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AddSelectSubjectSetupPage(
          classRow: widget.classRow,
          mappedSubjectIds: _mappedSubjects.map(_subjectId).toSet(),
          staff: widget.staff,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _setTeacher(
    Map<String, dynamic> subject,
    String teacherId,
  ) async {
    final subjectId = _subjectId(subject);
    if (subjectId.isEmpty || _saving) return;
    final assignment = _staffSubjectFor(subjectId);
    final assignmentId = _classText(assignment['id']);
    setState(() => _saving = true);
    try {
      if (teacherId.isEmpty && assignmentId.isNotEmpty) {
        await BackendApiClient.instance.updatePrincipalClassSetup(
          sectionId: _sectionId,
          gradeId: _gradeId,
          academicYearId: _academicYearId,
          sectionName: _sectionName,
          capacity: _classInt(widget.classRow['capacity'], fallback: 40),
          classTeacherId: _classText(widget.classRow['class_teacher_id']),
          subjectMappings: [
            {
              'subject_id': subjectId,
              'staff_subject_id': assignmentId,
              'delete': true,
            },
          ],
        );
      } else {
        await BackendApiClient.instance.savePrincipalSubjectMapping(
          subjectId: subjectId,
          gradeId: _gradeId,
          sectionId: _sectionId,
          teacherId: teacherId,
          assignmentId: assignmentId,
          periodsPerWeek: _classInt(
            _gradeSubjectFor(subjectId)['periods_per_week'],
          ),
          isPrimary: true,
        );
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save teacher assignment: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeSubject(Map<String, dynamic> subject) async {
    final subjectId = _subjectId(subject);
    if (subjectId.isEmpty || _saving) return;
    final gradeSubjectId = _classText(_gradeSubjectFor(subjectId)['id']);
    final staffSubjectId = _classText(_staffSubjectFor(subjectId)['id']);
    if (gradeSubjectId.isEmpty && staffSubjectId.isEmpty) return;
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.updatePrincipalClassSetup(
        sectionId: _sectionId,
        gradeId: _gradeId,
        academicYearId: _academicYearId,
        sectionName: _sectionName,
        capacity: _classInt(widget.classRow['capacity'], fallback: 40),
        classTeacherId: _classText(widget.classRow['class_teacher_id']),
        subjectMappings: [
          {
            'subject_id': subjectId,
            'grade_subject_id': gradeSubjectId,
            'staff_subject_id': staffSubjectId,
            'delete': true,
          },
        ],
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to remove subject: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _mappedSubjects;
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _SetupFlowHeader(
              title: 'Assign Subjects',
              subtitle: 'Add subjects and assign teachers for $_className',
              icon: Icons.menu_book_rounded,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: Column(
                          children: [
                            _ClassDetailsSetupCard(
                              academicYear: _academicYearLabel(),
                              className: _className,
                              capacity:
                                  '${_classInt(widget.classRow['capacity'], fallback: 40)} Students',
                            ),
                            const SizedBox(height: 18),
                            _SetupPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _SectionTitleWithCount(
                                          title: 'Subjects in this Class',
                                          count: subjects.length,
                                        ),
                                      ),
                                      _RoundAddButton(onTap: _openAddSubject),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  if (_loading)
                                    const Padding(
                                      padding: EdgeInsets.all(28),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  else if (_error != null)
                                    _SetupErrorBox(
                                      message: _error!,
                                      onRetry: _load,
                                    )
                                  else if (subjects.isEmpty)
                                    const _SetupEmptyBox(
                                      message:
                                          'No backend subjects are assigned to this class yet.',
                                    )
                                  else
                                    ...subjects.map(
                                      (subject) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: _AssignedSubjectTile(
                                          subject: subject,
                                          staff: widget.staff,
                                          teacherId: _safeTeacherId(
                                            _classText(
                                              _staffSubjectFor(
                                                _subjectId(subject),
                                              )['staff_id'],
                                            ),
                                          ),
                                          busy: _saving,
                                          onTeacherChanged: (teacherId) =>
                                              _setTeacher(subject, teacherId),
                                          onRemove: () =>
                                              _removeSubject(subject),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  const _SubjectSetupTip(),
                                  const SizedBox(height: 20),
                                  _SetupPrimaryButton(
                                    label: 'Continue Setup',
                                    icon: Icons.arrow_forward_rounded,
                                    saving: _saving,
                                    onPressed: _saving
                                        ? null
                                        : () => Navigator.of(context)
                                              .pushReplacement<bool, bool>(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      _GenerateTimetableSetupPage(
                                                        classRow:
                                                            widget.classRow,
                                                        academicYears: widget
                                                            .academicYears,
                                                        staff: widget.staff,
                                                        initialSubjects:
                                                            _subjects,
                                                        initialGradeSubjects:
                                                            _gradeSubjects,
                                                        initialStaffSubjects:
                                                            _staffSubjects,
                                                      ),
                                                ),
                                                result: true,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _safeTeacherId(String teacherId) {
    return widget.staff.any((staff) => staff.id == teacherId) ? teacherId : '';
  }

  String _academicYearLabel() {
    for (final year in widget.academicYears) {
      if (year.id == _academicYearId) return year.yearLabel;
    }
    return _academicYearId.isEmpty ? '-' : _academicYearId;
  }
}

class _GenerateTimetableSetupPage extends StatefulWidget {
  final Map<String, dynamic> classRow;
  final List<AcademicYearModel> academicYears;
  final List<StaffModel> staff;
  final List<Map<String, dynamic>> initialSubjects;
  final List<Map<String, dynamic>> initialGradeSubjects;
  final List<Map<String, dynamic>> initialStaffSubjects;

  const _GenerateTimetableSetupPage({
    required this.classRow,
    required this.academicYears,
    required this.staff,
    required this.initialSubjects,
    required this.initialGradeSubjects,
    required this.initialStaffSubjects,
  });

  @override
  State<_GenerateTimetableSetupPage> createState() =>
      _GenerateTimetableSetupPageState();
}

class _GenerateTimetableSetupPageState
    extends State<_GenerateTimetableSetupPage> {
  static const _background = _CreateClassSetupPageState._background;
  static const _primary = _CreateClassSetupPageState._primary;
  static const _days = [1, 2, 3, 4, 5, 6];

  bool _loading = true;
  bool _generating = false;
  bool _publishing = false;
  String? _error;
  int _phase = 0;
  int _activeDay = 1;

  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _gradeSubjects = [];
  List<Map<String, dynamic>> _staffSubjects = [];
  List<Map<String, dynamic>> _terms = [];
  List<Map<String, dynamic>> _templates = [];
  Map<String, dynamic>? _preview;

  String _termId = '';
  String _startTime = '08:30';
  int _periodsPerDay = 8;
  int _periodDurationMinutes = 40;
  int _gapMinutes = 5;
  int _shortBreakPeriod = 4;
  int _lunchBreakPeriod = 7;

  bool _distributeEvenly = true;
  bool _noSubjectsOnBreak = true;
  bool _preferMornings = true;
  bool _avoidConsecutive = true;
  bool _considerAvailability = false;

  String get _sectionId => _classText(widget.classRow['section_id']);
  String get _gradeId => _classText(widget.classRow['grade_id']);
  String get _academicYearId => _classText(widget.classRow['academic_year_id']);
  String get _className => _classText(
    widget.classRow['class_name'],
    fallback: _classLabel(
      _classText(widget.classRow['grade_name']),
      _classText(widget.classRow['section_name']),
    ),
  );

  @override
  void initState() {
    super.initState();
    _subjects = widget.initialSubjects;
    _gradeSubjects = widget.initialGradeSubjects;
    _staffSubjects = widget.initialStaffSubjects;
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
        api.getRawList('/subjects', queryParameters: const {'page_size': 500}),
        api.getRawList(
          '/grade-subjects',
          queryParameters: {'grade_id': _gradeId, 'page_size': 500},
        ),
        api.getRawList(
          '/staff-subjects',
          queryParameters: {'grade_id': _gradeId, 'page_size': 500},
        ),
        _academicYearId.isEmpty
            ? Future.value(<Map<String, dynamic>>[])
            : api.getTerms(_academicYearId),
        _academicYearId.isEmpty
            ? Future.value(<Map<String, dynamic>>[])
            : api.getTimetableTemplates(academicYearId: _academicYearId),
      ]);
      if (!mounted) return;
      final templates = results[4] as List<Map<String, dynamic>>;
      setState(() {
        _subjects = results[0] as List<Map<String, dynamic>>;
        _gradeSubjects = results[1] as List<Map<String, dynamic>>;
        _staffSubjects = results[2] as List<Map<String, dynamic>>;
        _terms = results[3] as List<Map<String, dynamic>>;
        _templates = templates;
        _termId = _initialId(
          _termId,
          _terms.map((term) => _classText(term['id'])),
        );
        if (_termId.isEmpty && _terms.isNotEmpty) {
          _termId = _classText(_terms.first['id']);
        }
        _applyTemplate(templates.firstOrNull);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load timetable setup from backend. $error';
        _loading = false;
      });
    }
  }

  void _applyTemplate(Map<String, dynamic>? template) {
    if (template == null || template.isEmpty) return;
    final start = _classText(template['start_time']);
    if (start.isNotEmpty) _startTime = start;
    final periods = _classInt(template['periods_per_day']);
    if (periods > 0) _periodsPerDay = periods;
    final duration = _classInt(template['period_duration_minutes']);
    if (duration > 0) _periodDurationMinutes = duration;
    final gap = _classInt(template['gap_minutes'], fallback: -1);
    if (gap >= 0) _gapMinutes = gap;
  }

  List<Map<String, dynamic>> get _mappedSubjects {
    final ids = <String>{
      ..._gradeSubjects
          .where((row) => _classText(row['grade_id']) == _gradeId)
          .map((row) => _classText(row['subject_id'])),
      ..._staffSubjects
          .where((row) => _isClassStaffSubject(row))
          .map((row) => _classText(row['subject_id'])),
    }..removeWhere((id) => id.isEmpty);
    final rows = _subjects
        .where((subject) => ids.contains(_subjectId(subject)))
        .toList();
    rows.sort(
      (left, right) =>
          _subjectName(left).toLowerCase().compareTo(_subjectName(right)),
    );
    return rows;
  }

  int get _totalPeriodsPerWeek {
    var total = 0;
    for (final subject in _mappedSubjects) {
      final row = _gradeSubjectFor(_subjectId(subject));
      final periods = _classInt(row['periods_per_week']);
      total += periods > 0 ? periods : 1;
    }
    return total;
  }

  bool _isClassStaffSubject(Map<String, dynamic> row) {
    final sectionId = _classText(row['section_id']);
    return _classText(row['grade_id']) == _gradeId &&
        (sectionId.isEmpty || sectionId == _sectionId);
  }

  Map<String, dynamic> _gradeSubjectFor(String subjectId) {
    return _gradeSubjects.firstWhere(
      (row) =>
          _classText(row['grade_id']) == _gradeId &&
          _classText(row['subject_id']) == subjectId,
      orElse: () => const {},
    );
  }

  Map<String, dynamic> _staffSubjectFor(String subjectId) {
    final exact = _staffSubjects.where(
      (row) =>
          _classText(row['subject_id']) == subjectId &&
          _classText(row['grade_id']) == _gradeId &&
          _classText(row['section_id']) == _sectionId,
    );
    if (exact.isNotEmpty) return exact.first;
    return _staffSubjects.firstWhere(
      (row) =>
          _classText(row['subject_id']) == subjectId &&
          _classText(row['grade_id']) == _gradeId &&
          _classText(row['section_id']).isEmpty,
      orElse: () => const {},
    );
  }

  String _teacherNameFor(String subjectId) {
    final assignment = _staffSubjectFor(subjectId);
    final direct = _classText(
      assignment['teacher_name'] ?? assignment['staff_name'],
    );
    if (direct.isNotEmpty) return direct;
    final staffId = _classText(assignment['staff_id']);
    for (final staff in widget.staff) {
      if (staff.id == staffId) return staff.fullName;
    }
    return 'Teacher pending';
  }

  Future<void> _openSubjectEdit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AddSelectSubjectSetupPage(
          classRow: widget.classRow,
          mappedSubjectIds: _mappedSubjects.map(_subjectId).toSet(),
          staff: widget.staff,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _editTimings() async {
    final result = await showModalBottomSheet<_TimetableTimingConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimetableTimingSheet(
        initial: _TimetableTimingConfig(
          startTime: _startTime,
          periodsPerDay: _periodsPerDay,
          periodDurationMinutes: _periodDurationMinutes,
          gapMinutes: _gapMinutes,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _startTime = result.startTime;
      _periodsPerDay = result.periodsPerDay;
      _periodDurationMinutes = result.periodDurationMinutes;
      _gapMinutes = result.gapMinutes;
      _preview = null;
    });
  }

  Future<void> _editBreaks() async {
    final result = await showModalBottomSheet<({int shortBreak, int lunch})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimetableBreakSheet(
        shortBreakPeriod: _shortBreakPeriod,
        lunchBreakPeriod: _lunchBreakPeriod,
        periodsPerDay: _periodsPerDay,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _shortBreakPeriod = result.shortBreak;
      _lunchBreakPeriod = result.lunch;
      _preview = null;
    });
  }

  Future<void> _saveTemplate() async {
    await BackendApiClient.instance.saveTimetableTemplate(
      id: _classText(_templates.firstOrNull?['id']),
      academicYearId: _academicYearId,
      name: 'Class setup smart timetable',
      workingDays: _days,
      periodsPerDay: _periodsPerDay,
      periodDurationMinutes: _periodDurationMinutes,
      gapMinutes: _gapMinutes,
      startTime: _startTime,
      endTime: _endTime,
      breaks: _noSubjectsOnBreak ? _breakRows : const [],
      isDefault: true,
    );
  }

  Future<void> _generatePreview() async {
    if (_termId.isEmpty) {
      setState(() {
        _error =
            'Academic term is required before timetable generation. Add a term in Academic Management.';
      });
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      await _saveTemplate();
      final preview = await BackendApiClient.instance.previewSmartTimetable(
        sectionId: _sectionId,
        academicYearId: _academicYearId,
        termId: _termId,
        days: _days,
        periodsPerDay: _periodsPerDay,
        startTime: _startTime,
        periodDurationMinutes: _periodDurationMinutes,
        gapMinutes: _gapMinutes,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _phase = 2;
        _activeDay = _firstPreviewDay(preview);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Unable to generate timetable preview. $error');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _publish() async {
    if (_preview == null || _termId.isEmpty || _publishing) return;
    setState(() => _publishing = true);
    try {
      await _saveTemplate();
      final result = await BackendApiClient.instance.generateSmartTimetable(
        sectionId: _sectionId,
        academicYearId: _academicYearId,
        termId: _termId,
        days: _days,
        periodsPerDay: _periodsPerDay,
        startTime: _startTime,
        periodDurationMinutes: _periodDurationMinutes,
        gapMinutes: _gapMinutes,
        regenerateScope: true,
      );
      if (!mounted) return;
      final created = _listMap(result['created']).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created > 0
                ? 'Timetable published with $created backend periods.'
                : 'Timetable published. Existing backend periods were kept.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.of(context).pushReplacement<bool, bool>(
        MaterialPageRoute(
          builder: (_) => _FeesSetupPage(
            classRow: widget.classRow,
            academicYears: widget.academicYears,
          ),
        ),
        result: true,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to publish timetable: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(child: _phase == 2 ? _buildPreview() : _buildSetupPhase()),
    );
  }

  Widget _buildSetupPhase() {
    final title = _phase == 0 ? 'Generate Timetable' : 'Constraints';
    return Column(
      children: [
        _SetupFlowHeader(
          title: title,
          subtitle: _className,
          icon: Icons.calendar_month_rounded,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TimetableStepIndicator(activeIndex: _phase),
                        const SizedBox(height: 18),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_error != null)
                          _SetupErrorBox(message: _error!, onRetry: _load)
                        else if (_phase == 0)
                          _buildClassSettings()
                        else
                          _buildConstraints(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassSettings() {
    final subjects = _mappedSubjects;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimetableClassDetailsCard(
          academicYear: _academicYearLabel,
          className: _className,
          totalSubjects: subjects.length,
          totalPeriods: _totalPeriodsPerWeek,
        ),
        const SizedBox(height: 18),
        _SetupPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SetupSectionHeader(
                title: 'Subjects',
                count: subjects.length,
                actionLabel: 'Edit',
                actionIcon: Icons.edit_outlined,
                onAction: _openSubjectEdit,
              ),
              const SizedBox(height: 12),
              if (subjects.isEmpty)
                const _SetupEmptyBox(
                  message:
                      'Assign backend subjects before generating timetable.',
                )
              else
                ...subjects.map(
                  (subject) => _TimetableSubjectRow(
                    subject: subject,
                    teacherName: _teacherNameFor(_subjectId(subject)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SetupPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SetupSectionHeader(
                title: 'Class Timings',
                actionLabel: 'Edit',
                actionIcon: Icons.edit_outlined,
                onAction: _editTimings,
              ),
              const SizedBox(height: 12),
              _TimingValueRow(
                label: 'Start Time',
                value: _displayClock(_startTime),
              ),
              _TimingValueRow(
                label: 'End Time',
                value: _displayClock(_endTime),
              ),
              _TimingValueRow(
                label: 'Period Duration',
                value: '$_periodDurationMinutes Min',
              ),
              _TimingValueRow(label: 'Break Time', value: '$_gapMinutes Min'),
              const SizedBox(height: 16),
              _SetupPrimaryButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                saving: false,
                onPressed: subjects.isEmpty
                    ? null
                    : () => setState(() => _phase = 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConstraints() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SetupPanel(
          child: Column(
            children: [
              const _SetupPanelTitle(
                icon: Icons.settings_suggest_outlined,
                title: 'Concentration Preferences',
              ),
              const SizedBox(height: 12),
              _ConstraintToggle(
                value: _distributeEvenly,
                title: 'Distribute periods evenly',
                subtitle: 'Spread subjects evenly across the week',
                onChanged: (value) => setState(() => _distributeEvenly = value),
              ),
              _ConstraintToggle(
                value: _noSubjectsOnBreak,
                title: 'No subjects on break time',
                subtitle: 'Ensure break time is free',
                onChanged: (value) =>
                    setState(() => _noSubjectsOnBreak = value),
              ),
              _ConstraintToggle(
                value: _preferMornings,
                title: 'Prefer mornings for core subjects',
                subtitle: 'Assign core subjects in morning',
                onChanged: (value) => setState(() => _preferMornings = value),
              ),
              _ConstraintToggle(
                value: _avoidConsecutive,
                title: 'Avoid consecutive same subjects',
                subtitle: "Don't assign same subject back-to-back",
                onChanged: (value) => setState(() => _avoidConsecutive = value),
              ),
              _ConstraintToggle(
                value: _considerAvailability,
                title: 'Consider teacher availability',
                subtitle: 'Ensure assigned teachers are available',
                onChanged: (value) =>
                    setState(() => _considerAvailability = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SetupPanel(
          child: Column(
            children: [
              const _SetupPanelTitle(
                icon: Icons.settings_suggest_outlined,
                title: 'Break Settings',
              ),
              const SizedBox(height: 10),
              _BreakSettingTile(
                title: 'Short Break',
                subtitle: _breakTimeLabel(_shortBreakPeriod, 20),
                onTap: _editBreaks,
              ),
              _BreakSettingTile(
                title: 'Lunch Break',
                subtitle: _breakTimeLabel(_lunchBreakPeriod, 40),
                onTap: _editBreaks,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _AiOptimizationPanel(),
        const SizedBox(height: 18),
        _SetupPrimaryButton(
          label: 'Generate Timetable',
          icon: Icons.auto_fix_high_rounded,
          saving: _generating,
          onPressed: _generating ? null : _generatePreview,
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final suggestions = _previewSuggestionsForDay(_activeDay);
    return Column(
      children: [
        const _SetupFlowHeader(
          title: 'Timetable Preview',
          subtitle: 'Backend smart generation result',
          icon: Icons.ios_share_rounded,
        ),
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _TimetableSuccessPanel(),
                      const SizedBox(height: 14),
                      _TimetableDayTabs(
                        activeDay: _activeDay,
                        availableDays: _days,
                        onChanged: (day) => setState(() => _activeDay = day),
                      ),
                      const SizedBox(height: 12),
                      _SetupPanel(
                        child: suggestions.isEmpty
                            ? const _SetupEmptyBox(
                                message:
                                    'Backend preview returned no periods for this day.',
                              )
                            : Column(
                                children: [
                                  for (final row in suggestions)
                                    _TimetablePreviewRow(
                                      row: row,
                                      subject: _subjectForPreview(row),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      _SetupPrimaryButton(
                        label: 'Save & Publish',
                        icon: Icons.save_rounded,
                        saving: _publishing,
                        onPressed: _publishing ? null : _publish,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: () => _openManualTimetable(),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit Timetable Manually'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primary,
                            side: const BorderSide(
                              color: _CreateClassSetupPageState._line,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openManualTimetable() {
    Navigator.pushNamed(
      context,
      AppRoutes.principalTimetable,
      arguments: {
        'section_id': _sectionId,
        'sectionId': _sectionId,
        'class_name': _className,
        'className': _className,
        'source': 'class_setup_timetable',
      },
    );
  }

  List<Map<String, dynamic>> _previewSuggestionsForDay(int day) {
    return _listMap(
      _preview?['suggestions'],
    ).where((row) => _classInt(row['day_of_week']) == day).toList()..sort(
      (left, right) => _classInt(
        left['period_number'],
      ).compareTo(_classInt(right['period_number'])),
    );
  }

  Map<String, dynamic> _subjectForPreview(Map<String, dynamic> row) {
    final subjectId = _classText(row['subject_id']);
    if (subjectId.isEmpty) return const {};
    return _subjects.firstWhere(
      (subject) => _subjectId(subject) == subjectId,
      orElse: () => {
        'subject_name': row['subject_name'],
        'subject_code': subjectId,
      },
    );
  }

  int _firstPreviewDay(Map<String, dynamic> preview) {
    for (final row in _listMap(preview['suggestions'])) {
      final day = _classInt(row['day_of_week']);
      if (day > 0) return day;
    }
    return 1;
  }

  String get _academicYearLabel {
    for (final year in widget.academicYears) {
      if (year.id == _academicYearId) return year.yearLabel;
    }
    return _academicYearId.isEmpty ? '-' : _academicYearId;
  }

  String get _endTime {
    final total =
        _periodsPerDay * _periodDurationMinutes +
        (_periodsPerDay - 1).clamp(0, 99) * _gapMinutes;
    return _clockFromMinutes(_minutesFromClock(_startTime) + total);
  }

  List<Map<String, dynamic>> get _breakRows => [
    {
      'label': 'Short Break',
      'days': _days,
      'periods': [_shortBreakPeriod],
    },
    {
      'label': 'Lunch Break',
      'days': _days,
      'periods': [_lunchBreakPeriod],
    },
  ];

  String _breakTimeLabel(int afterPeriod, int minutes) {
    final start =
        _minutesFromClock(_startTime) +
        (afterPeriod - 1).clamp(0, 99) * (_periodDurationMinutes + _gapMinutes);
    return '${_displayClock(_clockFromMinutes(start))} - ${_displayClock(_clockFromMinutes(start + minutes))} ($minutes Min)';
  }
}

class _FeesSetupPage extends StatefulWidget {
  final Map<String, dynamic> classRow;
  final List<AcademicYearModel> academicYears;

  const _FeesSetupPage({required this.classRow, required this.academicYears});

  @override
  State<_FeesSetupPage> createState() => _FeesSetupPageState();
}

class _FeesSetupPageState extends State<_FeesSetupPage> {
  static const _background = _CreateClassSetupPageState._background;
  static const _primary = _CreateClassSetupPageState._primary;

  final _structureName = TextEditingController();
  final List<_FeeComponentDraft> _components = [];

  bool _loading = true;
  bool _saving = false;
  bool _useExisting = false;
  bool _reviewingExisting = false;
  int _stage = 0;
  String? _error;
  List<Map<String, dynamic>> _existingStructures = [];

  String get _sectionId => _classText(widget.classRow['section_id']);
  String get _gradeId => _classText(widget.classRow['grade_id']);
  String get _academicYearId => _classText(widget.classRow['academic_year_id']);
  String get _sectionName => _classText(widget.classRow['section_name']);
  String get _gradeName => _classText(widget.classRow['grade_name']);
  String get _className => _classText(
    widget.classRow['class_name'],
    fallback: _classLabel(_gradeName, _sectionName),
  );
  int get _capacity => _classInt(widget.classRow['capacity'], fallback: 40);
  int get _students =>
      _classInt(widget.classRow['total_students'], fallback: _capacity);

  @override
  void initState() {
    super.initState();
    _structureName.text = _defaultFeeStructureName(_academicYearLabel);
    _resetComponents(_defaultFeeComponents());
    _load();
  }

  @override
  void dispose() {
    _structureName.dispose();
    for (final component in _components) {
      component.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final structures = _academicYearId.isEmpty || _gradeId.isEmpty
          ? <Map<String, dynamic>>[]
          : await BackendApiClient.instance.getFeeStructures(
              academicYearId: _academicYearId,
              gradeId: _gradeId,
            );
      if (!mounted) return;
      setState(() {
        _existingStructures = structures;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load existing backend fee structures. $error';
        _loading = false;
      });
    }
  }

  void _resetComponents(List<_FeeComponentDraft> next) {
    for (final component in _components) {
      component.dispose();
    }
    _components
      ..clear()
      ..addAll(next);
  }

  void _continueFromChoice() {
    if (_useExisting) {
      if (_existingStructures.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No existing fee structure found for this class.',
            ),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
      setState(() {
        _reviewingExisting = true;
        _resetComponents(
          _existingStructures.map(_feeDraftFromBackend).toList(),
        );
        _structureName.text = _defaultFeeStructureName(_academicYearLabel);
        _stage = 2;
      });
      return;
    }
    setState(() {
      _reviewingExisting = false;
      if (_components.isEmpty) _resetComponents(_defaultFeeComponents());
      _stage = 1;
    });
  }

  void _saveComponentsForReview() {
    final name = _structureName.text.trim();
    if (name.isEmpty) {
      _showFeeError('Structure name is required.');
      return;
    }
    if (_components.isEmpty) {
      _showFeeError('Add at least one fee component.');
      return;
    }
    for (final component in _components) {
      if (component.name.isEmpty) {
        _showFeeError('Every fee component needs a name.');
        return;
      }
      if (component.amount < 0) {
        _showFeeError('Fee amount cannot be negative.');
        return;
      }
    }
    setState(() {
      _reviewingExisting = false;
      _stage = 2;
    });
  }

  Future<void> _assignFees() async {
    if (_saving) return;
    if (_sectionId.isEmpty || _gradeId.isEmpty || _academicYearId.isEmpty) {
      _showFeeError('Class, grade, and academic year are required.');
      return;
    }
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.updatePrincipalClassSetup(
        sectionId: _sectionId,
        gradeId: _gradeId,
        academicYearId: _academicYearId,
        sectionName: _sectionName,
        capacity: _capacity,
        classTeacherId: _classText(widget.classRow['class_teacher_id']),
        feeItems: _components
            .map((component) => component.toPayload())
            .toList(),
      );
      if (!mounted) return;
      setState(() => _stage = 3);
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showFeeError('Unable to assign fee structure: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addComponent() async {
    final component = await showModalBottomSheet<_FeeComponentDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddFeeComponentSheet(),
    );
    if (component == null || !mounted) return;
    setState(() => _components.add(component));
  }

  void _removeComponent(_FeeComponentDraft component) {
    setState(() {
      _components.remove(component);
      component.dispose();
    });
  }

  void _reorderComponents(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _components.removeAt(oldIndex);
      _components.insert(newIndex, item);
    });
  }

  void _showFeeError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _SetupFlowHeader(
              title: _headerTitle,
              subtitle: _headerSubtitle,
              icon: _headerIcon,
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 30,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: _stage == 0
                          ? _buildChoice()
                          : _stage == 1
                          ? _buildCreateStructure()
                          : _stage == 2
                          ? _buildReview()
                          : _buildAssigned(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FeeSetupProgressIndicator(activeIndex: 3),
        const SizedBox(height: 18),
        _FeeClassDetailsCard(
          academicYear: _academicYearLabel,
          className: _className,
          students: _students,
        ),
        const SizedBox(height: 22),
        Text('Fee Structure', style: _feeSectionTitleStyle),
        const SizedBox(height: 6),
        Text(
          'Select an option to continue',
          style: GoogleFonts.dmSans(
            color: _CreateClassSetupPageState._muted,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 16),
        if (_loading) const LinearProgressIndicator(minHeight: 3),
        if (_error != null) ...[
          if (_loading) const SizedBox(height: 12),
          _SetupErrorBox(message: _error!, onRetry: _load),
          const SizedBox(height: 12),
        ],
        _FeeChoiceCard(
          selected: _useExisting,
          title: 'Use Existing Fee Structure',
          subtitle: _existingStructures.isEmpty
              ? 'No saved structure found for this class yet'
              : 'Choose from ${_existingStructures.length} saved fee components',
          onTap: () => setState(() => _useExisting = true),
        ),
        const SizedBox(height: 12),
        _FeeChoiceCard(
          selected: !_useExisting,
          title: 'Create New Fee Structure',
          subtitle: 'Create a custom fee structure',
          onTap: () => setState(() => _useExisting = false),
        ),
        const SizedBox(height: 18),
        const _FeeInfoPanel(
          message:
              'You can create a new fee structure and assign it to this class.',
        ),
        const SizedBox(height: 20),
        _SetupPrimaryButton(
          label: 'Continue',
          icon: Icons.arrow_forward_rounded,
          saving: false,
          onPressed: _loading ? null : _continueFromChoice,
        ),
      ],
    );
  }

  Widget _buildCreateStructure() {
    return _SetupPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SetupPanelTitle(
            icon: Icons.receipt_long_rounded,
            title: 'Structure Details',
          ),
          const SizedBox(height: 20),
          _ClassSetupInputField(
            label: 'Structure Name',
            required: true,
            controller: _structureName,
            hint: 'Enter structure name',
            icon: Icons.receipt_long_outlined,
            iconColor: _primary,
            iconTone: const Color(0xFFEAF2FF),
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 18),
          _FeeReadOnlySelect(
            label: 'Applicable For',
            required: true,
            value: _className,
          ),
          const SizedBox(height: 24),
          _SetupSectionHeader(
            title: 'Fee Components',
            actionLabel: 'Add Component',
            actionIcon: Icons.add_rounded,
            onAction: _addComponent,
          ),
          const SizedBox(height: 12),
          if (_components.isEmpty)
            const _SetupEmptyBox(message: 'No fee components added yet.')
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _components.length,
              onReorder: _reorderComponents,
              itemBuilder: (context, index) {
                final component = _components[index];
                return _FeeComponentEditRow(
                  key: ValueKey(component.localKey),
                  index: index,
                  component: component,
                  enabled: !_saving,
                  onDelete: () => _removeComponent(component),
                );
              },
            ),
          const SizedBox(height: 16),
          const _FeeInfoPanel(
            message: 'You can add, remove or reorder components.',
          ),
          const SizedBox(height: 20),
          _SetupPrimaryButton(
            label: 'Save & Continue',
            icon: Icons.arrow_forward_rounded,
            saving: false,
            onPressed: _saving ? null : _saveComponentsForReview,
          ),
        ],
      ),
    );
  }

  Widget _buildReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FeeStructureSummaryCard(
          structureName: _structureName.text.trim(),
          className: _className,
          componentCount: _components.length,
          isNew: !_reviewingExisting,
        ),
        const SizedBox(height: 18),
        Text('Fee Components', style: _feeSectionTitleStyle),
        const SizedBox(height: 12),
        _SetupPanel(
          child: Column(
            children: [
              for (final component in _components)
                _FeeReviewComponentRow(component: component),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _FeeTotalsCard(oneTimeTotal: _oneTimeTotal, yearlyTotal: _yearlyTotal),
        const SizedBox(height: 20),
        _SetupPrimaryButton(
          label: 'Confirm & Assign',
          icon: Icons.check_box_rounded,
          saving: _saving,
          onPressed: _saving ? null : _assignFees,
        ),
      ],
    );
  }

  Widget _buildAssigned() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FeeAssignedSuccessCard(
          structureName: _structureName.text.trim(),
          className: _className,
        ),
        const SizedBox(height: 18),
        _FeeAssignmentDetailsCard(
          academicYear: _academicYearLabel,
          className: _className,
          structureName: _structureName.text.trim(),
          totalComponents: _components.length,
          oneTimeTotal: _oneTimeTotal,
          yearlyTotal: _yearlyTotal,
        ),
        const SizedBox(height: 20),
        _SetupPrimaryButton(
          label: 'Go to Class Dashboard',
          icon: Icons.grid_view_rounded,
          saving: false,
          onPressed: () => Navigator.pop(context, true),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Setup Next (Review)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: const BorderSide(color: _CreateClassSetupPageState._line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String get _headerTitle => switch (_stage) {
    0 => 'Fees Setup',
    1 => 'Create Fee Structure',
    2 => 'Review Fee Structure',
    _ => 'Fees Assigned',
  };

  String get _headerSubtitle => switch (_stage) {
    0 => 'Step 4 of 5',
    1 => 'Add components and configure amounts',
    2 => 'Review the details before assigning',
    _ => 'Fee structure has been assigned successfully',
  };

  IconData get _headerIcon =>
      _stage == 0 ? Icons.assignment_rounded : Icons.receipt_long_rounded;

  double get _oneTimeTotal => _components
      .where((component) => component.frequencyPayload == 'one_time')
      .fold<double>(0, (sum, component) => sum + component.amount);

  double get _yearlyTotal => _components
      .where((component) => component.frequencyPayload != 'one_time')
      .fold<double>(0, (sum, component) => sum + component.amount);

  String get _academicYearLabel {
    for (final year in widget.academicYears) {
      if (year.id == _academicYearId) return year.yearLabel;
    }
    return _academicYearId.isEmpty ? '-' : _academicYearId;
  }
}

class _AddSelectSubjectSetupPage extends StatefulWidget {
  final Map<String, dynamic> classRow;
  final Set<String> mappedSubjectIds;
  final List<StaffModel> staff;

  const _AddSelectSubjectSetupPage({
    required this.classRow,
    required this.mappedSubjectIds,
    required this.staff,
  });

  @override
  State<_AddSelectSubjectSetupPage> createState() =>
      _AddSelectSubjectSetupPageState();
}

class _AddSelectSubjectSetupPageState
    extends State<_AddSelectSubjectSetupPage> {
  bool _loading = true;
  String? _error;
  String _query = '';
  String _typeFilter = 'All';
  String _addingSubjectId = '';
  List<Map<String, dynamic>> _subjects = [];

  String get _gradeId => _classText(widget.classRow['grade_id']);
  String get _sectionId => _classText(widget.classRow['section_id']);

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
      final subjects = await BackendApiClient.instance.getRawList(
        '/subjects',
        queryParameters: const {'page_size': 500},
      );
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load available subjects from backend. $error';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _availableSubjects {
    final query = _query.trim().toLowerCase();
    final rows = _subjects.where((subject) {
      final subjectId = _subjectId(subject);
      if (subjectId.isEmpty || widget.mappedSubjectIds.contains(subjectId)) {
        return false;
      }
      final type = _classText(subject['subject_type'], fallback: 'core');
      final matchesType =
          _typeFilter == 'All' ||
          type.toLowerCase() == _typeFilter.toLowerCase();
      final matchesSearch =
          query.isEmpty || _subjectSearchText(subject).contains(query);
      return matchesType && matchesSearch;
    }).toList();
    rows.sort(
      (left, right) =>
          _subjectName(left).toLowerCase().compareTo(_subjectName(right)),
    );
    return rows;
  }

  List<String> get _typeOptions {
    final values = <String>{'All'};
    for (final subject in _subjects) {
      final type = _classText(subject['subject_type']);
      if (type.isNotEmpty) values.add(type);
    }
    return values.toList()..sort((left, right) {
      if (left == 'All') return -1;
      if (right == 'All') return 1;
      return left.compareTo(right);
    });
  }

  Future<void> _addSubject(Map<String, dynamic> subject) async {
    final subjectId = _subjectId(subject);
    if (subjectId.isEmpty || _addingSubjectId.isNotEmpty) return;
    setState(() => _addingSubjectId = subjectId);
    try {
      await BackendApiClient.instance.savePrincipalSubjectMapping(
        subjectId: subjectId,
        gradeId: _gradeId,
        sectionId: _sectionId,
        teacherId: '',
        periodsPerWeek: 0,
        isPrimary: true,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _addingSubjectId = '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to add subject: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _openCreateSubject() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CreateSubjectSetupPage(classRow: widget.classRow),
      ),
    );
    if (changed == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _availableSubjects;
    return Scaffold(
      backgroundColor: _CreateClassSetupPageState._background,
      body: SafeArea(
        child: Column(
          children: [
            const _SetupFlowHeader(
              title: 'Add / Select Subject',
              subtitle: 'Choose from existing subjects or create new',
              icon: Icons.menu_book_rounded,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: _SetupPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final search = TextField(
                                    onChanged: (value) =>
                                        setState(() => _query = value),
                                    decoration: _plainSearchDecoration(
                                      'Search subject by name or code',
                                    ),
                                  );
                                  final filter = _SubjectFilterButton(
                                    options: _typeOptions,
                                    selected: _typeFilter,
                                    onSelected: (value) =>
                                        setState(() => _typeFilter = value),
                                  );
                                  if (constraints.maxWidth < 330) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        search,
                                        const SizedBox(height: 10),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: filter,
                                        ),
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      Expanded(child: search),
                                      const SizedBox(width: 12),
                                      filter,
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              _SectionTitleWithCount(
                                title: 'Available Subjects',
                                count: rows.length,
                              ),
                              const SizedBox(height: 14),
                              if (_loading)
                                const Padding(
                                  padding: EdgeInsets.all(28),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (_error != null)
                                _SetupErrorBox(message: _error!, onRetry: _load)
                              else if (rows.isEmpty)
                                const _SetupEmptyBox(
                                  message:
                                      'No unassigned backend subjects match this search.',
                                )
                              else
                                ...rows.map(
                                  (subject) => _AvailableSubjectTile(
                                    subject: subject,
                                    adding:
                                        _addingSubjectId == _subjectId(subject),
                                    onAdd: () => _addSubject(subject),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              _CreateSubjectPrompt(onTap: _openCreateSubject),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateSubjectSetupPage extends StatefulWidget {
  final Map<String, dynamic> classRow;

  const _CreateSubjectSetupPage({required this.classRow});

  @override
  State<_CreateSubjectSetupPage> createState() =>
      _CreateSubjectSetupPageState();
}

class _CreateSubjectSetupPageState extends State<_CreateSubjectSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _creditsController = TextEditingController(text: '0');
  String _type = 'Core';
  String _department = 'Academics';
  String _subjectColor = '#1E63F3';
  bool _saving = false;
  String? _error;

  static const _types = ['Core', 'Elective', 'Language', 'Activity'];
  static const _departments = [
    'Academics',
    'Languages',
    'Arts',
    'Sports',
    'Technology',
  ];
  static const _colors = [
    '#1E63F3',
    '#40C46D',
    '#FB8C00',
    '#8B5CF6',
    '#F472B6',
    '#20BFC4',
    '#F5BF12',
    '#AEB7C2',
  ];

  String get _gradeId => _classText(widget.classRow['grade_id']);
  String get _sectionId => _classText(widget.classRow['section_id']);

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final subject = await BackendApiClient.instance.createRaw('/subjects', {
        'subject_name': _nameController.text.trim(),
        'subject_code': _codeController.text.trim(),
        'subject_type': _type.toLowerCase(),
        'department_name': _department,
        'credit_hours': double.tryParse(_creditsController.text.trim()) ?? 0,
        'subject_color': _subjectColor,
      });
      final subjectId = _subjectId(subject);
      if (subjectId.isEmpty) {
        throw Exception('Subject was created but no subject id was returned.');
      }
      await BackendApiClient.instance.savePrincipalSubjectMapping(
        subjectId: subjectId,
        gradeId: _gradeId,
        sectionId: _sectionId,
        teacherId: '',
        periodsPerWeek: 0,
        isPrimary: true,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
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
    return Scaffold(
      backgroundColor: _CreateClassSetupPageState._background,
      body: SafeArea(
        child: Column(
          children: [
            const _SetupFlowHeader(
              title: 'Create Subject',
              subtitle: 'Add a new subject to your school',
              icon: Icons.menu_book_rounded,
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 30,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: _SetupPanel(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _SubjectSetupCardHeader(),
                              const SizedBox(height: 22),
                              _ClassSetupInputField(
                                label: 'Subject Name',
                                required: true,
                                controller: _nameController,
                                hint: 'Enter subject name',
                                icon: Icons.edit_outlined,
                                iconColor: const Color(0xFF1E63F3),
                                iconTone: const Color(0xFFEAF2FF),
                                enabled: !_saving,
                                textCapitalization: TextCapitalization.words,
                                validator: (value) => _classText(value).isEmpty
                                    ? 'Subject name is required'
                                    : null,
                              ),
                              const SizedBox(height: 18),
                              _ClassSetupTwoColumnRow(
                                children: [
                                  _ClassSetupInputField(
                                    label: 'Code',
                                    required: true,
                                    controller: _codeController,
                                    hint: 'Enter code',
                                    icon: Icons.code_rounded,
                                    iconColor: const Color(0xFF7C3AED),
                                    iconTone: const Color(0xFFF3E8FF),
                                    enabled: !_saving,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    validator: (value) =>
                                        _classText(value).isEmpty
                                        ? 'Code is required'
                                        : null,
                                  ),
                                  _SimpleSetupDropdown(
                                    label: 'Type',
                                    required: true,
                                    value: _type,
                                    values: _types,
                                    icon: Icons.layers_outlined,
                                    iconColor: const Color(0xFF16A34A),
                                    iconTone: const Color(0xFFEAFBF0),
                                    enabled: !_saving,
                                    onChanged: (value) =>
                                        setState(() => _type = value),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _ClassSetupTwoColumnRow(
                                children: [
                                  _SimpleSetupDropdown(
                                    label: 'Department',
                                    required: true,
                                    value: _department,
                                    values: _departments,
                                    icon: Icons.account_balance_outlined,
                                    iconColor: const Color(0xFFF59E0B),
                                    iconTone: const Color(0xFFFFF7E8),
                                    enabled: !_saving,
                                    onChanged: (value) =>
                                        setState(() => _department = value),
                                  ),
                                  _ClassSetupInputField(
                                    label: 'Credits',
                                    controller: _creditsController,
                                    hint: '0',
                                    icon: Icons.stars_rounded,
                                    iconColor: const Color(0xFFE11D48),
                                    iconTone: const Color(0xFFFFEAF1),
                                    enabled: !_saving,
                                    keyboardType: TextInputType.number,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _SubjectColorPicker(
                                selected: _subjectColor,
                                colors: _colors,
                                enabled: !_saving,
                                onChanged: (value) =>
                                    setState(() => _subjectColor = value),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                _SetupErrorBox(message: _error!),
                              ],
                              const SizedBox(height: 24),
                              _SetupPrimaryButton(
                                label: 'Save Subject',
                                icon: Icons.save_rounded,
                                saving: _saving,
                                onPressed: _saving ? null : _save,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimetableStepIndicator extends StatelessWidget {
  final int activeIndex;

  const _TimetableStepIndicator({required this.activeIndex});

  static const _steps = [
    'Class & Settings',
    'Constraints',
    'Generate',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    if (_classesPhone(context)) {
      return SizedBox(
        height: 74,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _steps.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            return _SetupProgressChip(
              number: index + 1,
              label: _steps[index],
              active: index == activeIndex,
              complete: index < activeIndex,
            );
          },
        ),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: i < activeIndex
                        ? const Color(0xFF5BC48D)
                        : i == activeIndex
                        ? _CreateClassSetupPageState._primary
                        : const Color(0xFFE5EAF0),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: i < activeIndex
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 22,
                          )
                        : Text(
                            '${i + 1}',
                            style: GoogleFonts.dmSans(
                              color: i == activeIndex
                                  ? Colors.white
                                  : const Color(0xFF475569),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _steps[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: i == activeIndex
                        ? _CreateClassSetupPageState._primary
                        : _CreateClassSetupPageState._ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (i < _steps.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 27),
                child: Container(height: 2, color: const Color(0xFFD7E3F0)),
              ),
            ),
        ],
      ],
    );
  }
}

class _TimetableClassDetailsCard extends StatelessWidget {
  final String academicYear;
  final String className;
  final int totalSubjects;
  final int totalPeriods;

  const _TimetableClassDetailsCard({
    required this.academicYear,
    required this.className,
    required this.totalSubjects,
    required this.totalPeriods,
  });

  @override
  Widget build(BuildContext context) {
    return _SetupPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SetupPanelTitle(
            icon: Icons.school_rounded,
            title: 'Class Details',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final values = [
                _ClassDetailsValue(label: 'Academic Year', value: academicYear),
                _ClassDetailsValue(label: 'Class / Section', value: className),
                _ClassDetailsValue(
                  label: 'Total Subjects',
                  value: '$totalSubjects',
                ),
                _ClassDetailsValue(
                  label: 'Total Periods / Week',
                  value: '$totalPeriods',
                ),
              ];
              final columns = constraints.maxWidth < 520 ? 2 : 4;
              final spacing = constraints.maxWidth < 520 ? 14.0 : 18.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: 16,
                children: [
                  for (final value in values)
                    SizedBox(width: width, child: value),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SetupSectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const _SetupSectionHeader({
    required this.title,
    this.count,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heading = count == null
            ? Text(
                title,
                style: _sectionTitleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : _SectionTitleWithCount(title: title, count: count!);
        final action = actionLabel == null
            ? null
            : TextButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.edit_outlined, size: 16),
                label: Text(
                  actionLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _CreateClassSetupPageState._primary,
                  backgroundColor: const Color(0xFFF0F6FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
        if (action == null) return heading;
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: action),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            Flexible(child: action),
          ],
        );
      },
    );
  }
}

class _TimetableSubjectRow extends StatelessWidget {
  final Map<String, dynamic> subject;
  final String teacherName;

  const _TimetableSubjectRow({
    required this.subject,
    required this.teacherName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _CreateClassSetupPageState._line),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final teacher = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFFFF1E8),
                child: Text(
                  _initials(teacherName),
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF9A3412),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  teacherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: _CreateClassSetupPageState._ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 390) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _SubjectIconBadge(subject: subject),
                    const SizedBox(width: 12),
                    Expanded(child: _SubjectNameCode(subject: subject)),
                  ],
                ),
                const SizedBox(height: 10),
                teacher,
              ],
            );
          }
          return Row(
            children: [
              _SubjectIconBadge(subject: subject),
              const SizedBox(width: 12),
              Expanded(child: _SubjectNameCode(subject: subject)),
              const SizedBox(width: 12),
              SizedBox(width: 150, child: teacher),
            ],
          );
        },
      ),
    );
  }
}

class _TimingValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _TimingValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelText = Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: _CreateClassSetupPageState._muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          );
          final valueChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: _CreateClassSetupPageState._primary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          );
          if (constraints.maxWidth < 300) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelText,
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerLeft, child: valueChip),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: labelText),
              const SizedBox(width: 12),
              Flexible(child: valueChip),
            ],
          );
        },
      ),
    );
  }
}

class _SetupPanelTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SetupPanelTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _CreateClassSetupPageState._primary, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: _CreateClassSetupPageState._primary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConstraintToggle extends StatelessWidget {
  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  const _ConstraintToggle({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (next) => onChanged(next ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeColor: _CreateClassSetupPageState._primary,
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          color: _CreateClassSetupPageState._ink,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          color: _CreateClassSetupPageState._muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _BreakSettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BreakSettingTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          color: _CreateClassSetupPageState._ink,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          color: _CreateClassSetupPageState._muted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _AiOptimizationPanel extends StatelessWidget {
  const _AiOptimizationPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE9FAF2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1F2E2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF059669)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Optimization',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF047857),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Our AI will generate the most optimized timetable based on your preferences and rules.',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF356859),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    letterSpacing: 0,
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

class _TimetableSuccessPanel extends StatelessWidget {
  const _TimetableSuccessPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8FAEF),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFCFF2DC)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFF5BC48D),
            child: Icon(Icons.check_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timetable generated successfully!',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF047857),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'All subjects scheduled optimally.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF356859),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
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

class _TimetableDayTabs extends StatelessWidget {
  final int activeDay;
  final List<int> availableDays;
  final ValueChanged<int> onChanged;

  const _TimetableDayTabs({
    required this.activeDay,
    required this.availableDays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: availableDays.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = availableDays[index];
          final selected = day == activeDay;
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            label: Text(_dayShortLabel(day)),
            onSelected: (_) => onChanged(day),
            selectedColor: _CreateClassSetupPageState._primary,
            backgroundColor: Colors.white,
            side: const BorderSide(color: _CreateClassSetupPageState._line),
            labelStyle: GoogleFonts.dmSans(
              color: selected ? Colors.white : _CreateClassSetupPageState._ink,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          );
        },
      ),
    );
  }
}

class _TimetablePreviewRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final Map<String, dynamic> subject;

  const _TimetablePreviewRow({required this.row, required this.subject});

  bool get _isBreak => _classText(row['status']) == 'reserved_break';

  @override
  Widget build(BuildContext context) {
    final title = _classText(row['subject_name'], fallback: 'Period');
    final teacher = _classText(row['staff_name'], fallback: 'Teacher pending');
    final room = _classText(row['room_name']);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _isBreak ? const Color(0xFFFFF7DF) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _CreateClassSetupPageState._line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final timeBlock = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _timeRange(row),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: _CreateClassSetupPageState._ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isBreak
                      ? 'Break'
                      : 'Period ${_classInt(row['period_number'])}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: _CreateClassSetupPageState._muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          );
          final icon = _isBreak
              ? Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2C2),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.free_breakfast_outlined,
                    color: Color(0xFFD97706),
                  ),
                )
              : _SubjectIconBadge(subject: subject);
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: _CreateClassSetupPageState._ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isBreak ? 'Reserved break time' : teacher,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: _CreateClassSetupPageState._muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          );
          final roomChip = room.isEmpty
              ? const SizedBox.shrink()
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    room,
                    style: GoogleFonts.dmSans(
                      color: _CreateClassSetupPageState._primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                );
          if (constraints.maxWidth < 360) {
            return Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: timeBlock),
                      if (room.isNotEmpty) roomChip,
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(child: details),
                    ],
                  ),
                ],
              ),
            );
          }
          return Row(
            children: [
              SizedBox(width: 88, child: timeBlock),
              Container(
                width: 1,
                height: 64,
                color: _CreateClassSetupPageState._line,
              ),
              const SizedBox(width: 10),
              icon,
              const SizedBox(width: 12),
              Expanded(child: details),
              if (room.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: roomChip,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TimetableTimingConfig {
  final String startTime;
  final int periodsPerDay;
  final int periodDurationMinutes;
  final int gapMinutes;

  const _TimetableTimingConfig({
    required this.startTime,
    required this.periodsPerDay,
    required this.periodDurationMinutes,
    required this.gapMinutes,
  });
}

class _TimetableTimingSheet extends StatefulWidget {
  final _TimetableTimingConfig initial;

  const _TimetableTimingSheet({required this.initial});

  @override
  State<_TimetableTimingSheet> createState() => _TimetableTimingSheetState();
}

class _TimetableTimingSheetState extends State<_TimetableTimingSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _start;
  late final TextEditingController _periods;
  late final TextEditingController _duration;
  late final TextEditingController _gap;

  @override
  void initState() {
    super.initState();
    _start = TextEditingController(text: widget.initial.startTime);
    _periods = TextEditingController(text: '${widget.initial.periodsPerDay}');
    _duration = TextEditingController(
      text: '${widget.initial.periodDurationMinutes}',
    );
    _gap = TextEditingController(text: '${widget.initial.gapMinutes}');
  }

  @override
  void dispose() {
    _start.dispose();
    _periods.dispose();
    _duration.dispose();
    _gap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetPanel(
      title: 'Class Timings',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _start,
              decoration: const InputDecoration(labelText: 'Start time'),
              validator: (value) =>
                  _timeValid(_classText(value)) ? null : 'Use HH:MM time',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _periods,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Periods/day'),
                    validator: (value) =>
                        _classInt(value) > 0 ? null : 'Required',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minutes'),
                    validator: (value) =>
                        _classInt(value) > 0 ? null : 'Required',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _gap,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Break / gap min'),
              validator: (value) => _classInt(value, fallback: -1) >= 0
                  ? null
                  : 'Enter 0 or more',
            ),
            const SizedBox(height: 18),
            _SetupPrimaryButton(
              label: 'Apply Timings',
              icon: Icons.check_rounded,
              saving: false,
              onPressed: () {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(
                  context,
                  _TimetableTimingConfig(
                    startTime: _classText(_start.text),
                    periodsPerDay: _classInt(_periods.text),
                    periodDurationMinutes: _classInt(_duration.text),
                    gapMinutes: _classInt(_gap.text),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TimetableBreakSheet extends StatefulWidget {
  final int shortBreakPeriod;
  final int lunchBreakPeriod;
  final int periodsPerDay;

  const _TimetableBreakSheet({
    required this.shortBreakPeriod,
    required this.lunchBreakPeriod,
    required this.periodsPerDay,
  });

  @override
  State<_TimetableBreakSheet> createState() => _TimetableBreakSheetState();
}

class _TimetableBreakSheetState extends State<_TimetableBreakSheet> {
  late int _shortBreak;
  late int _lunch;

  @override
  void initState() {
    super.initState();
    _shortBreak = widget.shortBreakPeriod.clamp(1, widget.periodsPerDay);
    _lunch = widget.lunchBreakPeriod.clamp(1, widget.periodsPerDay);
  }

  @override
  Widget build(BuildContext context) {
    final options = [for (var i = 1; i <= widget.periodsPerDay; i++) i];
    return _BottomSheetPanel(
      title: 'Break Settings',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _shortBreak,
            decoration: const InputDecoration(labelText: 'Short break period'),
            items: options
                .map(
                  (period) => DropdownMenuItem(
                    value: period,
                    child: Text('Period $period'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _shortBreak = value ?? 4),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _lunch,
            decoration: const InputDecoration(labelText: 'Lunch break period'),
            items: options
                .map(
                  (period) => DropdownMenuItem(
                    value: period,
                    child: Text('Period $period'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _lunch = value ?? 7),
          ),
          const SizedBox(height: 18),
          _SetupPrimaryButton(
            label: 'Apply Breaks',
            icon: Icons.check_rounded,
            saving: false,
            onPressed: () => Navigator.pop(context, (
              shortBreak: _shortBreak,
              lunch: _lunch,
            )),
          ),
        ],
      ),
    );
  }
}

class _FeeSetupProgressIndicator extends StatelessWidget {
  final int activeIndex;

  const _FeeSetupProgressIndicator({required this.activeIndex});

  static const _steps = ['Class', 'Subjects', 'Timetable', 'Fees', 'Review'];

  @override
  Widget build(BuildContext context) {
    if (_classesPhone(context)) {
      return SizedBox(
        height: 74,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _steps.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            return _SetupProgressChip(
              number: index + 1,
              label: _steps[index],
              active: index == activeIndex,
              complete: index < activeIndex,
            );
          },
        ),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: i < activeIndex
                        ? const Color(0xFF3DBB75)
                        : i == activeIndex
                        ? _CreateClassSetupPageState._primary
                        : const Color(0xFFE6EDF5),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: i < activeIndex
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 18,
                          )
                        : Text(
                            '${i + 1}',
                            style: GoogleFonts.dmSans(
                              color: i == activeIndex
                                  ? Colors.white
                                  : const Color(0xFF475569),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _steps[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: i == activeIndex
                        ? _CreateClassSetupPageState._primary
                        : _CreateClassSetupPageState._ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (i < _steps.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 26),
                child: Container(height: 2, color: const Color(0xFFD7E3F0)),
              ),
            ),
        ],
      ],
    );
  }
}

class _FeeClassDetailsCard extends StatelessWidget {
  final String academicYear;
  final String className;
  final int students;

  const _FeeClassDetailsCard({
    required this.academicYear,
    required this.className,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    return _SetupPanel(
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Row(
                children: [
                  const _SetupIconCircle(
                    icon: Icons.school_rounded,
                    color: _CreateClassSetupPageState._primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Class Details',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: _CreateClassSetupPageState._primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              );
              final changeButton = TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text(
                  'Change',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _CreateClassSetupPageState._primary,
                  backgroundColor: const Color(0xFFF0F6FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
              if (constraints.maxWidth < 330) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerLeft, child: changeButton),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 10),
                  changeButton,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final values = [
                _ClassDetailsValue(label: 'Academic Year', value: academicYear),
                _ClassDetailsValue(label: 'Grade / Section', value: className),
                _ClassDetailsValue(label: 'Students', value: '$students'),
              ];
              if (constraints.maxWidth < 520) {
                return Wrap(
                  spacing: 14,
                  runSpacing: 16,
                  children: [
                    for (final item in values)
                      SizedBox(
                        width: (constraints.maxWidth - 14) / 2,
                        child: item,
                      ),
                  ],
                );
              }
              return Row(
                children: [for (final value in values) Expanded(child: value)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeeChoiceCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeeChoiceCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? _CreateClassSetupPageState._primary
                  : _CreateClassSetupPageState._line,
              width: selected ? 1.4 : 1,
            ),
            color: selected ? const Color(0xFFF4F8FF) : Colors.white,
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected
                    ? _CreateClassSetupPageState._primary
                    : const Color(0xFFB5C1D0),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: _CreateClassSetupPageState._ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: _CreateClassSetupPageState._muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeeInfoPanel extends StatelessWidget {
  final String message;

  const _FeeInfoPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF7FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4E9FF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _CreateClassSetupPageState._primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                color: _CreateClassSetupPageState._ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeReadOnlySelect extends StatelessWidget {
  final String label;
  final bool required;
  final String value;

  const _FeeReadOnlySelect({
    required this.label,
    this.required = false,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return _ClassSetupFieldShell(
      label: label,
      required: required,
      child: InputDecorator(
        decoration: _fieldDecoration(
          hint: label,
          icon: Icons.layers_outlined,
          iconColor: const Color(0xFF16A34A),
          iconTone: const Color(0xFFEAFBF0),
        ).copyWith(suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded)),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _fieldTextStyle,
        ),
      ),
    );
  }
}

class _FeeComponentEditRow extends StatelessWidget {
  final int index;
  final _FeeComponentDraft component;
  final bool enabled;
  final VoidCallback onDelete;

  const _FeeComponentEditRow({
    super.key,
    required this.index,
    required this.component,
    required this.enabled,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _CreateClassSetupPageState._line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final header = Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                enabled: enabled,
                child: const Icon(
                  Icons.drag_indicator_rounded,
                  color: Color(0xFF7C8798),
                ),
              ),
              const SizedBox(width: 8),
              _FeeComponentIcon(component: component),
              const SizedBox(width: 12),
              Expanded(
                child: _EditableFeeComponentName(
                  component: component,
                  enabled: enabled,
                ),
              ),
              IconButton(
                tooltip: 'Remove component',
                onPressed: enabled ? onDelete : null,
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppTheme.error,
              ),
            ],
          );
          final amount = _FeeAmountField(
            component: component,
            enabled: enabled,
          );
          if (constraints.maxWidth < 540) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, const SizedBox(height: 8), amount],
            );
          }
          return Row(
            children: [
              Expanded(child: header),
              const SizedBox(width: 12),
              SizedBox(width: 148, child: amount),
            ],
          );
        },
      ),
    );
  }
}

class _EditableFeeComponentName extends StatelessWidget {
  final _FeeComponentDraft component;
  final bool enabled;

  const _EditableFeeComponentName({
    required this.component,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: component.nameController,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      style: GoogleFonts.dmSans(
        color: _CreateClassSetupPageState._ink,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _FeeAmountField extends StatelessWidget {
  final _FeeComponentDraft component;
  final bool enabled;

  const _FeeAmountField({required this.component, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: component.amountController,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.end,
      style: GoogleFonts.dmSans(
        color: _CreateClassSetupPageState._ink,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      decoration: InputDecoration(
        prefixText: '₹ ',
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FBFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _CreateClassSetupPageState._line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _CreateClassSetupPageState._line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: _CreateClassSetupPageState._primary,
          ),
        ),
      ),
    );
  }
}

class _FeeStructureSummaryCard extends StatelessWidget {
  final String structureName;
  final String className;
  final int componentCount;
  final bool isNew;

  const _FeeStructureSummaryCard({
    required this.structureName,
    required this.className,
    required this.componentCount,
    required this.isNew,
  });

  @override
  Widget build(BuildContext context) {
    return _SetupPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SetupPanelTitle(
                  icon: Icons.receipt_long_rounded,
                  title: 'Structure Summary',
                ),
              ),
              if (isNew)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F8EC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'New',
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFF059669),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _FeeSummaryText(label: 'Name', value: structureName),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final values = [
                _FeeSummaryText(label: 'Applicable For', value: className),
                _FeeSummaryText(
                  label: 'Total Components',
                  value: '$componentCount',
                ),
              ];
              if (constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [values[0], const SizedBox(height: 14), values[1]],
                );
              }
              return Row(
                children: [
                  Expanded(child: values[0]),
                  Container(
                    width: 1,
                    height: 38,
                    color: const Color(0xFFE6EDF5),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: values[1]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeeSummaryText extends StatelessWidget {
  final String label;
  final String value;

  const _FeeSummaryText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final phone = _classesPhone(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: _CreateClassSetupPageState._muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value.isEmpty ? '-' : value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: _CreateClassSetupPageState._ink,
            fontSize: phone ? 13.5 : 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _FeeReviewComponentRow extends StatelessWidget {
  final _FeeComponentDraft component;

  const _FeeReviewComponentRow({required this.component});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _CreateClassSetupPageState._line),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final nameBlock = Row(
            children: [
              _FeeComponentIcon(component: component),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      component.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: _CreateClassSetupPageState._ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      component.frequencyLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: _CreateClassSetupPageState._muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final amount = Text(
            _formatCurrency(component.amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: _CreateClassSetupPageState._ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          );
          if (constraints.maxWidth < 320) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                nameBlock,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: amount),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: nameBlock),
              const SizedBox(width: 10),
              Flexible(child: amount),
            ],
          );
        },
      ),
    );
  }
}

class _FeeTotalsCard extends StatelessWidget {
  final double oneTimeTotal;
  final double yearlyTotal;

  const _FeeTotalsCard({required this.oneTimeTotal, required this.yearlyTotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD8E7FF)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final oneTime = _FeeTotalValue(
            label: 'Total (One Time)',
            value: _formatCurrency(oneTimeTotal),
          );
          final yearly = _FeeTotalValue(
            label: 'Total (Yearly)',
            value: _formatCurrency(yearlyTotal),
          );
          if (constraints.maxWidth < 340) {
            return Column(
              children: [
                oneTime,
                const SizedBox(height: 12),
                Container(height: 1, color: const Color(0xFFD8E7FF)),
                const SizedBox(height: 12),
                yearly,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: oneTime),
              Container(width: 1, height: 44, color: const Color(0xFFD8E7FF)),
              Expanded(child: yearly),
            ],
          );
        },
      ),
    );
  }
}

class _FeeTotalValue extends StatelessWidget {
  final String label;
  final String value;

  const _FeeTotalValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: _CreateClassSetupPageState._muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: _CreateClassSetupPageState._ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _FeeAssignedSuccessCard extends StatelessWidget {
  final String structureName;
  final String className;

  const _FeeAssignedSuccessCard({
    required this.structureName,
    required this.className,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFAF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCFEEDB)),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 36,
            backgroundColor: Color(0xFF20B565),
            child: Icon(Icons.check_rounded, color: Colors.white, size: 46),
          ),
          const SizedBox(height: 18),
          Text(
            'Fee Structure Assigned!',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: _CreateClassSetupPageState._ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${structureName.isEmpty ? 'Fee structure' : structureName} has been assigned to $className successfully.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: const Color(0xFF475569),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeAssignmentDetailsCard extends StatelessWidget {
  final String academicYear;
  final String className;
  final String structureName;
  final int totalComponents;
  final double oneTimeTotal;
  final double yearlyTotal;

  const _FeeAssignmentDetailsCard({
    required this.academicYear,
    required this.className,
    required this.structureName,
    required this.totalComponents,
    required this.oneTimeTotal,
    required this.yearlyTotal,
  });

  @override
  Widget build(BuildContext context) {
    return _SetupPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SetupPanelTitle(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Assignment Details',
          ),
          const SizedBox(height: 18),
          _FeeSummaryText(label: 'Academic Year', value: academicYear),
          const SizedBox(height: 14),
          _FeeSummaryText(label: 'Class / Section', value: className),
          const SizedBox(height: 14),
          _FeeSummaryText(label: 'Fee Structure', value: structureName),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final values = [
                _FeeSummaryText(
                  label: 'Total Components',
                  value: '$totalComponents',
                ),
                _FeeSummaryText(
                  label: 'Total (One Time)',
                  value: _formatCurrency(oneTimeTotal),
                ),
              ];
              if (constraints.maxWidth < 330) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [values[0], const SizedBox(height: 14), values[1]],
                );
              }
              return Row(
                children: [for (final value in values) Expanded(child: value)],
              );
            },
          ),
          const SizedBox(height: 14),
          _FeeSummaryText(
            label: 'Total (Yearly)',
            value: _formatCurrency(yearlyTotal),
          ),
        ],
      ),
    );
  }
}

class _FeeComponentIcon extends StatelessWidget {
  final _FeeComponentDraft component;

  const _FeeComponentIcon({required this.component});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: component.tone,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(component.icon, color: component.color, size: 23),
    );
  }
}

class _AddFeeComponentSheet extends StatefulWidget {
  const _AddFeeComponentSheet();

  @override
  State<_AddFeeComponentSheet> createState() => _AddFeeComponentSheetState();
}

class _AddFeeComponentSheetState extends State<_AddFeeComponentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetPanel(
      title: 'Add Fee Component',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ClassSetupInputField(
              label: 'Component Name',
              required: true,
              controller: _name,
              hint: 'Enter component name',
              icon: Icons.receipt_long_outlined,
              iconColor: _CreateClassSetupPageState._primary,
              iconTone: const Color(0xFFEAF2FF),
              enabled: true,
              textCapitalization: TextCapitalization.words,
              validator: (value) => _classText(value).isEmpty
                  ? 'Component name is required'
                  : null,
            ),
            const SizedBox(height: 14),
            _ClassSetupInputField(
              label: 'Amount',
              required: true,
              controller: _amount,
              hint: '0',
              icon: Icons.payments_outlined,
              iconColor: const Color(0xFF16A34A),
              iconTone: const Color(0xFFEAFBF0),
              enabled: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final parsed = double.tryParse(
                  _classText(value).replaceAll(',', ''),
                );
                return parsed == null || parsed < 0
                    ? 'Enter a valid amount'
                    : null;
              },
            ),
            const SizedBox(height: 18),
            _SetupPrimaryButton(
              label: 'Add Component',
              icon: Icons.add_rounded,
              saving: false,
              onPressed: () {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                final name = _name.text.trim();
                final amount =
                    double.tryParse(_amount.text.trim().replaceAll(',', '')) ??
                    0;
                Navigator.pop(
                  context,
                  _FeeComponentDraft(
                    name: name,
                    amount: amount,
                    icon: _feeComponentIconForName(name),
                    color: _feeComponentColorForName(name),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeeComponentDraft {
  final String localKey;
  final String structureId;
  final String feeCategoryId;
  final TextEditingController nameController;
  final TextEditingController amountController;
  final String frequency;
  final IconData icon;
  final Color color;
  final Color tone;
  final int dueDay;
  final double lateFinePerDay;

  _FeeComponentDraft({
    String localKey = '',
    this.structureId = '',
    this.feeCategoryId = '',
    required String name,
    required double amount,
    this.frequency = 'One Time',
    IconData? icon,
    Color? color,
    Color? tone,
    this.dueDay = 10,
    this.lateFinePerDay = 0,
  }) : localKey = localKey.isEmpty ? UniqueKey().toString() : localKey,
       nameController = TextEditingController(text: name),
       amountController = TextEditingController(
         text: _formatAmountInput(amount),
       ),
       icon = icon ?? _feeComponentIconForName(name),
       color = color ?? _feeComponentColorForName(name),
       tone = tone ?? _feeComponentToneForName(name);

  String get name => nameController.text.trim();

  double get amount =>
      double.tryParse(amountController.text.trim().replaceAll(',', '')) ?? 0;

  String get frequencyPayload => _feeFrequencyPayload(frequency);

  String get frequencyLabel => _feeFrequencyLabel(frequency);

  Map<String, dynamic> toPayload() => {
    if (structureId.isNotEmpty) 'id': structureId,
    if (feeCategoryId.isNotEmpty) 'fee_category_id': feeCategoryId,
    'category_name': name,
    'frequency': frequencyPayload,
    'amount': amount,
    'due_day': dueDay <= 0 ? 10 : dueDay,
    'late_fine_per_day': lateFinePerDay,
  };

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

class _BottomSheetPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _BottomSheetPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: GoogleFonts.dmSans(
                color: _CreateClassSetupPageState._ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SetupFlowHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SetupFlowHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final phone = _classesPhone(context);
    final tiny = _classesTiny(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(phone ? 14 : 24, 16, phone ? 14 : 24, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: _CreateClassSetupPageState._ink,
            iconSize: tiny ? 25 : 28,
          ),
          SizedBox(
            width: tiny
                ? 4
                : phone
                ? 8
                : 12,
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
                    color: _CreateClassSetupPageState._ink,
                    fontSize: tiny
                        ? 17
                        : phone
                        ? 19
                        : 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.dmSans(
                    color: _CreateClassSetupPageState._muted,
                    fontSize: tiny
                        ? 11.5
                        : phone
                        ? 12.5
                        : 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (!tiny) ...[
            const SizedBox(width: 10),
            Container(
              width: phone ? 46 : 60,
              height: phone ? 46 : 60,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB7CEE5).withAlpha(60),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: _CreateClassSetupPageState._primary,
                size: phone ? 24 : 31,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SetupPanel extends StatelessWidget {
  final Widget child;

  const _SetupPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    final phone = _classesPhone(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(phone ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(phone ? 12 : 14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9DB9D2).withAlpha(38),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ClassDetailsSetupCard extends StatelessWidget {
  final String academicYear;
  final String className;
  final String capacity;

  const _ClassDetailsSetupCard({
    required this.academicYear,
    required this.className,
    required this.capacity,
  });

  @override
  Widget build(BuildContext context) {
    return _SetupPanel(
      child: Column(
        children: [
          Row(
            children: [
              const _SetupIconCircle(
                icon: Icons.school_rounded,
                color: _CreateClassSetupPageState._primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Class Details',
                  style: GoogleFonts.dmSans(
                    color: _CreateClassSetupPageState._primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final items = [
                _ClassDetailsValue(label: 'Academic Year', value: academicYear),
                _ClassDetailsValue(label: 'Class / Section', value: className),
                _ClassDetailsValue(label: 'Capacity', value: capacity),
              ];
              if (constraints.maxWidth < 520) {
                return Wrap(
                  spacing: 14,
                  runSpacing: 16,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: (constraints.maxWidth - 14) / 2,
                        child: item,
                      ),
                  ],
                );
              }
              return Row(
                children: [for (final item in items) Expanded(child: item)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClassDetailsValue extends StatelessWidget {
  final String label;
  final String value;

  const _ClassDetailsValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final phone = _classesPhone(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: _CreateClassSetupPageState._muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: phone ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: _CreateClassSetupPageState._ink,
            fontSize: phone ? 14.5 : 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _SectionTitleWithCount extends StatelessWidget {
  final String title;
  final int count;

  const _SectionTitleWithCount({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: _CreateClassSetupPageState._ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.dmSans(
              color: _CreateClassSetupPageState._primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundAddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RoundAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CreateClassSetupPageState._primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 50,
          height: 50,
          child: Icon(Icons.add_rounded, color: Colors.white, size: 34),
        ),
      ),
    );
  }
}

class _AssignedSubjectTile extends StatelessWidget {
  final Map<String, dynamic> subject;
  final List<StaffModel> staff;
  final String teacherId;
  final bool busy;
  final ValueChanged<String> onTeacherChanged;
  final VoidCallback onRemove;

  const _AssignedSubjectTile({
    required this.subject,
    required this.staff,
    required this.teacherId,
    required this.busy,
    required this.onTeacherChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final safeTeacherId = staff.any((teacher) => teacher.id == teacherId)
        ? teacherId
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _CreateClassSetupPageState._line),
      ),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final subjectHeader = Row(
                  children: [
                    _SubjectIconBadge(subject: subject),
                    const SizedBox(width: 12),
                    Expanded(child: _SubjectNameCode(subject: subject)),
                  ],
                );
                final dropdown = _TeacherAssignmentDropdown(
                  staff: staff,
                  value: safeTeacherId,
                  enabled: !busy,
                  onChanged: onTeacherChanged,
                );
                if (constraints.maxWidth < 390) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      subjectHeader,
                      const SizedBox(height: 10),
                      dropdown,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: subjectHeader),
                    const SizedBox(width: 10),
                    SizedBox(width: 174, child: dropdown),
                  ],
                );
              },
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Subject actions',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'remove') onRemove();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'remove', child: Text('Remove subject')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeacherAssignmentDropdown extends StatelessWidget {
  final List<StaffModel> staff;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _TeacherAssignmentDropdown({
    required this.staff,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _CreateClassSetupPageState._line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          onChanged: enabled ? (next) => onChanged(next ?? '') : null,
          items: [
            const DropdownMenuItem(
              value: '',
              child: _TeacherMiniLabel(name: 'Assign teacher'),
            ),
            ...staff.map(
              (teacher) => DropdownMenuItem(
                value: teacher.id,
                child: _TeacherMiniLabel(name: teacher.fullName),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherMiniLabel extends StatelessWidget {
  final String name;

  const _TeacherMiniLabel({required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: const Color(0xFFFFF1E8),
          child: Text(
            _initials(name),
            style: GoogleFonts.dmSans(
              color: const Color(0xFF9A3412),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: _CreateClassSetupPageState._ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _SubjectNameCode extends StatelessWidget {
  final Map<String, dynamic> subject;

  const _SubjectNameCode({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _subjectName(subject),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: _CreateClassSetupPageState._ink,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _subjectCode(subject),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: _CreateClassSetupPageState._muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _SubjectIconBadge extends StatelessWidget {
  final Map<String, dynamic> subject;

  const _SubjectIconBadge({required this.subject});

  @override
  Widget build(BuildContext context) {
    final accent = _subjectAccent(subject);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: accent.withAlpha(24),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(_subjectIcon(subject), color: accent, size: 27),
    );
  }
}

class _AvailableSubjectTile extends StatelessWidget {
  final Map<String, dynamic> subject;
  final bool adding;
  final VoidCallback onAdd;

  const _AvailableSubjectTile({
    required this.subject,
    required this.adding,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _CreateClassSetupPageState._line),
        ),
      ),
      child: Row(
        children: [
          _SubjectIconBadge(subject: subject),
          const SizedBox(width: 14),
          Expanded(child: _SubjectNameCode(subject: subject)),
          Material(
            color: const Color(0xFFEAF2FF),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: adding ? null : onAdd,
              child: SizedBox(
                width: 40,
                height: 40,
                child: adding
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.add_rounded,
                        color: _CreateClassSetupPageState._primary,
                        size: 28,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectSetupTip extends StatelessWidget {
  const _SubjectSetupTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF7FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4E9FF)),
      ),
      child: Row(
        children: [
          const _SetupIconCircle(
            icon: Icons.lightbulb_outline_rounded,
            color: _CreateClassSetupPageState._primary,
            tone: Color(0xFFDDEEFF),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'You can add subjects and assign teachers now.\nYou can edit or add more later from class settings.',
              style: GoogleFonts.dmSans(
                color: _CreateClassSetupPageState._ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.3,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateSubjectPrompt extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateSubjectPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF7FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4E9FF)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Can't find the subject?",
                style: GoogleFonts.dmSans(
                  color: _CreateClassSetupPageState._ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create a new subject.',
                style: GoogleFonts.dmSans(
                  color: _CreateClassSetupPageState._muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Create Subject',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _CreateClassSetupPageState._primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 12), button],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 12),
              Flexible(child: button),
            ],
          );
        },
      ),
    );
  }
}

class _SubjectSetupCardHeader extends StatelessWidget {
  const _SubjectSetupCardHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const _SetupIconCircle(
              icon: Icons.menu_book_rounded,
              color: _CreateClassSetupPageState._primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Subject',
                    style: GoogleFonts.dmSans(
                      color: _CreateClassSetupPageState._ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Enter subject details to add to your curriculum.',
                    style: GoogleFonts.dmSans(
                      color: _CreateClassSetupPageState._muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: _CreateClassSetupPageState._line),
      ],
    );
  }
}

class _SimpleSetupDropdown extends StatelessWidget {
  final String label;
  final bool required;
  final String value;
  final List<String> values;
  final IconData icon;
  final Color iconColor;
  final Color iconTone;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _SimpleSetupDropdown({
    required this.label,
    this.required = false,
    required this.value,
    required this.values,
    required this.icon,
    required this.iconColor,
    required this.iconTone,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _ClassSetupFieldShell(
      label: label,
      required: required,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        decoration: _fieldDecoration(
          hint: label,
          icon: icon,
          iconColor: iconColor,
          iconTone: iconTone,
        ),
        items: values
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: enabled ? (next) => onChanged(next ?? value) : null,
      ),
    );
  }
}

class _SubjectColorPicker extends StatelessWidget {
  final String selected;
  final List<String> colors;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _SubjectColorPicker({
    required this.selected,
    required this.colors,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subject Color',
          style: GoogleFonts.dmSans(
            color: _CreateClassSetupPageState._ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 17,
          runSpacing: 12,
          children: [
            for (final color in colors)
              InkWell(
                onTap: enabled ? () => onChanged(color) : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 35,
                  height: 35,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected == color
                          ? _CreateClassSetupPageState._primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hexColor(color),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SubjectFilterButton extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _SubjectFilterButton({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Filter subjects',
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final option in options)
          PopupMenuItem(value: option, child: Text(option)),
      ],
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _CreateClassSetupPageState._line),
        ),
        child: const Icon(Icons.tune_rounded, color: Color(0xFF475569)),
      ),
    );
  }
}

class _SetupIconCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? tone;

  const _SetupIconCircle({required this.icon, required this.color, this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: tone ?? color, shape: BoxShape.circle),
      child: Icon(icon, color: tone == null ? Colors.white : color, size: 24),
    );
  }
}

class _SetupPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool saving;
  final VoidCallback? onPressed;

  const _SetupPrimaryButton({
    required this.label,
    required this.icon,
    required this.saving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final phone = _classesPhone(context);
    return SizedBox(
      height: phone ? 54 : 58,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 24),
        label: Text(
          saving ? 'Saving...' : label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: phone ? 16 : 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _CreateClassSetupPageState._primary,
          disabledBackgroundColor: const Color(0xFF9BB9F8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _SetupEmptyBox extends StatelessWidget {
  final String message;

  const _SetupEmptyBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _CreateClassSetupPageState._line),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(
          color: _CreateClassSetupPageState._muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SetupErrorBox extends StatelessWidget {
  final String message;
  final Future<void> Function()? onRetry;

  const _SetupErrorBox({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                color: const Color(0xFF991B1B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

InputDecoration _plainSearchDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.dmSans(
      color: const Color(0xFF98A2B3),
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: _CreateClassSetupPageState._line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: _CreateClassSetupPageState._line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(
        color: _CreateClassSetupPageState._primary,
        width: 1.4,
      ),
    ),
  );
}

List<Map<String, dynamic>> _mergedRows(
  List<List<Map<String, dynamic>>> groups,
) {
  final rows = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final group in groups) {
    for (final row in group) {
      final id = _classText(row['id'] ?? row['subject_id']);
      final key = id.isEmpty ? row.toString() : id;
      if (seen.add(key)) rows.add(row);
    }
  }
  return rows;
}

List<Map<String, dynamic>> _listMap(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : [];

String _subjectId(Map<String, dynamic> subject) =>
    _classText(subject['id'] ?? subject['subject_id']);

String _subjectName(Map<String, dynamic> subject) => _classText(
  subject['subject_name'] ?? subject['name'] ?? subject['title'],
  fallback: 'Subject',
);

String _subjectCode(Map<String, dynamic> subject) =>
    _classText(subject['subject_code'] ?? subject['code'], fallback: 'No code');

String _subjectSearchText(Map<String, dynamic> subject) => [
  _subjectName(subject),
  _subjectCode(subject),
  subject['subject_type'],
  subject['department_name'],
  subject['department'],
].map(_classText).join(' ').toLowerCase();

Color _subjectAccent(Map<String, dynamic> subject) {
  final color = _classText(subject['subject_color']);
  if (color.isNotEmpty) return _hexColor(color);
  final name = _subjectName(subject).toLowerCase();
  if (name.contains('math')) return const Color(0xFF22C55E);
  if (name.contains('evs') || name.contains('science')) {
    return const Color(0xFFF59E0B);
  }
  if (name.contains('hindi') || name.contains('language')) {
    return const Color(0xFF8B5CF6);
  }
  if (name.contains('art')) return const Color(0xFFEC4899);
  if (name.contains('physical') || name.contains('sport')) {
    return const Color(0xFF14B8A6);
  }
  if (name.contains('computer')) return const Color(0xFFEAB308);
  if (name.contains('music')) return const Color(0xFFA855F7);
  return _CreateClassSetupPageState._primary;
}

IconData _subjectIcon(Map<String, dynamic> subject) {
  final name = _subjectName(subject).toLowerCase();
  if (name.contains('math')) return Icons.calculate_outlined;
  if (name.contains('evs') || name.contains('science')) {
    return Icons.eco_outlined;
  }
  if (name.contains('hindi') || name.contains('language')) {
    return Icons.translate_rounded;
  }
  if (name.contains('art')) return Icons.palette_outlined;
  if (name.contains('physical') || name.contains('sport')) {
    return Icons.directions_run_rounded;
  }
  if (name.contains('computer')) return Icons.desktop_windows_outlined;
  if (name.contains('music')) return Icons.music_note_rounded;
  return Icons.auto_stories_rounded;
}

Color _hexColor(String value) {
  final normalized = value.replaceAll('#', '').trim();
  if (normalized.length == 6) {
    final parsed = int.tryParse('FF$normalized', radix: 16);
    if (parsed != null) return Color(parsed);
  }
  if (normalized.length == 8) {
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed != null) return Color(parsed);
  }
  return _CreateClassSetupPageState._primary;
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

TextStyle get _sectionTitleStyle => GoogleFonts.dmSans(
  color: _CreateClassSetupPageState._ink,
  fontSize: 16,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

String _initialId(
  String preferred,
  Iterable<String> allowed, {
  String? fallback,
}) {
  final values = allowed
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
  final preferredValue = preferred.trim();
  if (preferredValue.isNotEmpty && values.contains(preferredValue)) {
    return preferredValue;
  }
  final fallbackValue = fallback?.trim() ?? '';
  if (fallbackValue.isNotEmpty && values.contains(fallbackValue)) {
    return fallbackValue;
  }
  return values.isEmpty ? '' : values.first;
}

bool _timeValid(String value) => RegExp(r'^\d{2}:\d{2}$').hasMatch(value);

int _minutesFromClock(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return 0;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  return hour * 60 + minute;
}

String _clockFromMinutes(int value) {
  final normalized = value % (24 * 60);
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String _displayClock(String value) {
  final minutes = _minutesFromClock(value);
  final hour24 = minutes ~/ 60;
  final minute = minutes % 60;
  final suffix = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $suffix';
}

String _timeRange(Map<String, dynamic> row) {
  final start = _classText(row['start_time']);
  final end = _classText(row['end_time']);
  if (start.isEmpty || end.isEmpty) return '--:--';
  return '$start - $end';
}

String _dayShortLabel(int day) {
  return switch (day) {
    1 => 'Mon',
    2 => 'Tue',
    3 => 'Wed',
    4 => 'Thu',
    5 => 'Fri',
    6 => 'Sat',
    7 => 'Sun',
    _ => 'Day',
  };
}

TextStyle get _feeSectionTitleStyle => GoogleFonts.dmSans(
  color: _CreateClassSetupPageState._ink,
  fontSize: 20,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

List<_FeeComponentDraft> _defaultFeeComponents() => [
  _FeeComponentDraft(
    name: 'Tuition Fee',
    amount: 12000,
    icon: Icons.school_outlined,
    color: const Color(0xFF16A34A),
    tone: const Color(0xFFEAFBF0),
  ),
  _FeeComponentDraft(
    name: 'Admission Fee',
    amount: 2000,
    icon: Icons.account_balance_outlined,
    color: const Color(0xFFF43F5E),
    tone: const Color(0xFFFFEAF1),
  ),
  _FeeComponentDraft(
    name: 'Annual Charges',
    amount: 1500,
    icon: Icons.local_activity_outlined,
    color: const Color(0xFFA855F7),
    tone: const Color(0xFFF3E8FF),
  ),
  _FeeComponentDraft(
    name: 'Smart Class Fee',
    amount: 1000,
    icon: Icons.smart_display_outlined,
    color: _CreateClassSetupPageState._primary,
    tone: const Color(0xFFEAF2FF),
  ),
];

_FeeComponentDraft _feeDraftFromBackend(Map<String, dynamic> row) {
  final category = _classMap(row['fee_category']);
  final name = _classText(
    category['category_name'] ??
        category['name'] ??
        row['category_name'] ??
        row['category'],
    fallback: 'Fee',
  );
  final frequency = _classText(
    category['frequency'] ?? row['frequency'],
    fallback: 'One Time',
  );
  return _FeeComponentDraft(
    localKey: _classText(row['id'], fallback: UniqueKey().toString()),
    structureId: _classText(row['id']),
    feeCategoryId: _classText(row['fee_category_id']),
    name: name,
    amount: _classNum(row['amount']),
    frequency: frequency,
    icon: _feeComponentIconForName(name),
    color: _feeComponentColorForName(name),
    tone: _feeComponentToneForName(name),
    dueDay: _classInt(row['due_day'], fallback: 10),
    lateFinePerDay: _classNum(row['late_fine_per_day']),
  );
}

String _defaultFeeStructureName(String academicYear) {
  final suffix = academicYear.trim();
  return suffix.isEmpty || suffix == '-'
      ? 'Primary Fee Structure'
      : 'Primary Fee Structure $suffix';
}

String _formatAmountInput(double amount) {
  if (amount == amount.roundToDouble()) return amount.round().toString();
  return amount.toStringAsFixed(2);
}

String _formatCurrency(num value) {
  final rounded = value.round().toString();
  final chars = rounded.split('').reversed.toList();
  final grouped = <String>[];
  for (var i = 0; i < chars.length; i++) {
    if (i > 0 && i % 3 == 0) grouped.add(',');
    grouped.add(chars[i]);
  }
  return '₹ ${grouped.reversed.join()}';
}

String _feeFrequencyPayload(String frequency) {
  final text = frequency.trim().toLowerCase().replaceAll('-', '_');
  if (text.contains('one')) return 'one_time';
  if (text.contains('year')) return 'yearly';
  if (text.contains('month')) return 'monthly';
  if (text.contains('term')) return 'term';
  return text.isEmpty ? 'one_time' : text.replaceAll(' ', '_');
}

String _feeFrequencyLabel(String frequency) {
  final payload = _feeFrequencyPayload(frequency);
  return switch (payload) {
    'one_time' => 'One Time',
    'yearly' => 'Yearly',
    'monthly' => 'Monthly',
    'term' => 'Term',
    _ => frequency.trim().isEmpty ? 'One Time' : frequency.trim(),
  };
}

IconData _feeComponentIconForName(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('tuition')) return Icons.school_outlined;
  if (lower.contains('admission')) return Icons.account_balance_outlined;
  if (lower.contains('annual')) return Icons.local_activity_outlined;
  if (lower.contains('smart') || lower.contains('class')) {
    return Icons.smart_display_outlined;
  }
  if (lower.contains('transport')) return Icons.directions_bus_outlined;
  if (lower.contains('book')) return Icons.menu_book_outlined;
  return Icons.receipt_long_outlined;
}

Color _feeComponentColorForName(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('tuition')) return const Color(0xFF16A34A);
  if (lower.contains('admission')) return const Color(0xFFF43F5E);
  if (lower.contains('annual')) return const Color(0xFFA855F7);
  if (lower.contains('smart') || lower.contains('class')) {
    return _CreateClassSetupPageState._primary;
  }
  if (lower.contains('transport')) return const Color(0xFFF59E0B);
  if (lower.contains('book')) return const Color(0xFF0EA5E9);
  return _CreateClassSetupPageState._primary;
}

Color _feeComponentToneForName(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('tuition')) return const Color(0xFFEAFBF0);
  if (lower.contains('admission')) return const Color(0xFFFFEAF1);
  if (lower.contains('annual')) return const Color(0xFFF3E8FF);
  if (lower.contains('transport')) return const Color(0xFFFFF7E8);
  if (lower.contains('book')) return const Color(0xFFEAF8FF);
  return const Color(0xFFEAF2FF);
}

class _EditClassSheet extends StatefulWidget {
  final Map<String, dynamic> row;
  final List<AcademicYearModel> academicYears;
  final List<StaffModel> staff;
  final Future<bool> Function({
    required String sectionId,
    required String gradeId,
    required String gradeName,
    required int? gradeNumber,
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
  final _gradeName = TextEditingController();
  final _gradeNumber = TextEditingController();
  final _section = TextEditingController();
  final _capacity = TextEditingController();
  String _academicYearId = '';
  String _teacherId = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _gradeName.text = _classText(
      widget.row['grade_name'],
      fallback: _classText(widget.row['class_name']),
    );
    final gradeNumber = _classInt(widget.row['grade_number']);
    if (gradeNumber > 0) _gradeNumber.text = '$gradeNumber';
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
              Text('Edit Class', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Update the details used across roster, attendance, timetable, and fees.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64727E),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _gradeName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Class name'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Class name is required'
                    : null,
              ),
              const SizedBox(height: 12),
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final displayOrder = TextFormField(
                    controller: _gradeNumber,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Display order',
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return null;
                      return (int.tryParse(text) ?? 0) <= 0
                          ? 'Enter a positive order'
                          : null;
                    },
                  );
                  final capacity = TextFormField(
                    controller: _capacity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Capacity'),
                    validator: (value) =>
                        (int.tryParse((value ?? '').trim()) ?? 0) <= 0
                        ? 'Capacity is required'
                        : null,
                  );
                  if (constraints.maxWidth < 420) {
                    return Column(
                      children: [
                        displayOrder,
                        const SizedBox(height: 12),
                        capacity,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: displayOrder),
                      const SizedBox(width: 12),
                      Expanded(child: capacity),
                    ],
                  );
                },
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
      gradeName: _gradeName.text.trim(),
      gradeNumber: int.tryParse(_gradeNumber.text.trim()),
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
