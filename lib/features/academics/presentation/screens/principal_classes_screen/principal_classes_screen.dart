import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/bulk_csv_import_service.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/widgets/principal_directory_ui.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/widgets/desktop_master_detail_layout.dart';

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
  bool _routeArgsRead = false;
  String _pendingHubAction = '';
  String _pendingHubSectionId = '';
  String _pendingHubGradeId = '';

  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _classes = [];
  List<AcademicYearModel> _academicYears = [];
  List<StaffModel> _staff = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _gradeSubjects = [];
  List<Map<String, dynamic>> _staffSubjects = [];
  List<Map<String, dynamic>> _events = [];
  int _unreadNotifications = 0;
  NotificationService? _notificationService;
  String _lastNotificationSignal = '';

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(_bindFeeNotifications());
  }

  @override
  void dispose() {
    _notificationService?.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  Future<void> _bindFeeNotifications() async {
    final service = await NotificationService.getInstance();
    if (!mounted) return;
    _notificationService = service;
    _lastNotificationSignal = service.notifications.isEmpty
        ? ''
        : service.notifications.first.id;
    service.addListener(_onNotificationsChanged);
  }

  void _onNotificationsChanged() {
    final service = _notificationService;
    if (!mounted || service == null || service.notifications.isEmpty) return;
    final latest = service.notifications.first;
    if (latest.id == _lastNotificationSignal) return;
    _lastNotificationSignal = latest.id;
    final isFeeUpdate =
        latest.referenceType == 'fee' ||
        latest.category.contains('fee') ||
        latest.title.toLowerCase().contains('fee payment');
    if (isFeeUpdate) unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgsRead) return;
    _routeArgsRead = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;
    _pendingHubAction = _text(
      args['class_hub_action'] ??
          args['action'] ??
          args['selectedStep'] ??
          args['setup'],
    );
    _pendingHubSectionId = _text(
      args['section_id'] ?? args['sectionId'] ?? args['classId'],
    );
    _pendingHubGradeId = _text(args['grade_id'] ?? args['gradeId']);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait<Object>([
        api.getPrincipalClassesOverview(forceRefresh: true),
        api.getAcademicYears(forceRefresh: true),
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
      _openPendingHubAction();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load Classes Hub from backend. $error';
        _loading = false;
      });
    }
  }

  void _openPendingHubAction() {
    final action = _pendingHubAction.trim();
    if (action.isEmpty || _classes.isEmpty) return;
    final sectionId = _pendingHubSectionId;
    final gradeId = _pendingHubGradeId;
    _pendingHubAction = '';
    _pendingHubSectionId = '';
    _pendingHubGradeId = '';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final row = _classRowForRoute(sectionId: sectionId, gradeId: gradeId);
      if (row == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Open a class first to continue this setup.'),
            backgroundColor: context.appTheme.warning,
          ),
        );
        return;
      }
      setState(() => _selectedSectionId = _text(row['section_id']));
      switch (action) {
        case 'subjects':
        case 'subject_setup':
          await _openSubjectSetup(row);
          break;
        case 'fees':
        case 'fee_setup':
          _openFeesModule(row);
          break;
        case 'attendance':
          _openRoute(AppRoutes.principalAttendance, row);
          break;
        default:
          await _openClassDetail(row);
      }
    });
  }

  Map<String, dynamic>? _classRowForRoute({
    required String sectionId,
    required String gradeId,
  }) {
    if (sectionId.isNotEmpty) {
      for (final row in _classes) {
        if (_text(row['section_id']) == sectionId) return row;
      }
    }
    if (gradeId.isNotEmpty) {
      for (final row in _classes) {
        if (_text(row['grade_id']) == gradeId) return row;
      }
    }
    return _classes.isEmpty ? null : _classes.first;
  }

  Future<List<Map<String, dynamic>>> _loadOptionalRows(
    Future<List<Map<String, dynamic>>> request,
  ) async {
    try {
      return await request;
    } on Object catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(
      _legacyNavigationContract.isNotEmpty && _legacyScreenLabels.length == 5,
    );
    final isDesktop = DesktopBreakpoints.isDesktopWidth(
      MediaQuery.sizeOf(context).width,
    );
    if (isDesktop) {
      return _buildDesktopLayout();
    }
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
                        onUpload: _importClassesCsv,
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
                        onClassesTap: () =>
                            setState(() => _capacityFilter = 'All'),
                        onIssuesTap: () =>
                            setState(() => _capacityFilter = 'Issues'),
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
                        onFees: () => rows.isEmpty
                            ? Navigator.pushNamed(
                                context,
                                AppRoutes.feeMonitoring,
                              )
                            : _openFeesModule(rows.first),
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
    setState(() => _saving = true);
    try {
      final academicYears = await BackendApiClient.instance.getAcademicYears(
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() => _academicYears = academicYears);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to refresh academic years: $error'),
          backgroundColor: context.appTheme.error,
        ),
      );
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }

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
          existingClasses: _classes,
        ),
      ),
    );
    if (result == true) await _load();
  }

  Future<void> _importClassesCsv() async {
    final imported = await BulkCsvImportService.importCsv(
      context,
      BulkCsvImportTarget.classes,
    );
    if (imported && mounted) await _load();
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
    required String coTeacherId,
    required String roomNumber,
    required String roomType,
    required int roomCapacity,
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
        coTeacherId: coTeacherId,
        roomNumber: roomNumber,
        roomType: roomType,
        roomCapacity: roomCapacity,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Class created'),
            backgroundColor: context.appTheme.success,
          ),
        );
      }

      return created;
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to create class: $error'),
            backgroundColor: context.appTheme.error,
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
    required String coTeacherId,
    required String roomNumber,
    required String roomType,
    required int roomCapacity,
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
        coTeacherId: coTeacherId,
        roomNumber: roomNumber,
        roomType: roomType,
        roomCapacity: roomCapacity,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Class updated'),
            backgroundColor: context.appTheme.success,
          ),
        );
      }
      return true;
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to update class: $error'),
            backgroundColor: context.appTheme.error,
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
            style: FilledButton.styleFrom(
              backgroundColor: context.appTheme.error,
            ),
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
          backgroundColor: context.appTheme.success,
        ),
      );
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to remove $className: $error'),
          backgroundColor: context.appTheme.error,
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
          academicYears: _academicYears,
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
      case 'subjects':
        await _openSubjectSetup(row);
        break;
      case 'note':
        await _openInstructionSheet(row);
        break;
    }
  }

  Future<void> _openSubjectSetup(Map<String, dynamic> row) async {
    setState(() => _selectedSectionId = _text(row['section_id']));
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AssignSubjectsSetupPage(
          classRow: row,
          setupPayload: const {},
          academicYears: _academicYears,
          initialSubjects: _subjects,
          initialGradeSubjects: _gradeSubjects,
          initialStaffSubjects: _staffSubjects,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openFeesModule(Map<String, dynamic> row) async {
    setState(() => _selectedSectionId = _text(row['section_id']));
    await Navigator.pushNamed(
      context,
      AppRoutes.feeMonitoring,
      arguments: {
        'grade_id': _text(row['grade_id']),
        'section_id': _text(row['section_id']),
        'source': 'class_hub',
      },
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _openInstructionSheet(Map<String, dynamic> row) async {
    setState(() => _selectedSectionId = _text(row['section_id']));
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
                try {
                  await BackendApiClient.instance
                      .createPrincipalClassInstruction(
                        sectionId: _text(row['section_id']),
                        title: 'Class observation',
                        message: message,
                        type: 'observation',
                        priority: 'normal',
                      );
                  if (context.mounted) Navigator.pop(context, true);
                } on Object catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to save observation: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
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
        'grade_id': _text(row['grade_id']),
        'gradeId': _text(row['grade_id']),
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
        // Require capacity > 0 so classes without a set capacity limit are
        // not erroneously treated as "Healthy" (capacity==0 is unknown, not OK).
        'Healthy' => issues == 0 && capacity > 0 && students < capacity,
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
          .where(
            (item) =>
                _text(item['grade_id']) == gradeId &&
                _text(item['section_id']) == sectionId,
          )
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
    if (readAt.isNotEmpty || isRead == 'true' || isRead == '1') return false;
    final role =
        '${notification['role'] ?? notification['target_role'] ?? 'all'}'
            .trim()
            .toLowerCase();
    return role == 'all' || role == 'principal';
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

  Widget _buildDesktopLayout() {
    final rows = _filteredClasses;
    final showAddFab = !_loading && _error == null && rows.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F8FF),
      floatingActionButton: showAddFab
          ? FloatingActionButton(
              heroTag: 'classes-directory-add-class-desktop',
              onPressed: _openClassForm,
              tooltip: 'Add class',
              backgroundColor: const Color(0xFF1478F2),
              foregroundColor: Colors.white,
              elevation: 10,
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, size: 30),
            )
          : null,
      body: SafeArea(
        child: DesktopMasterDetailLayout(
          master: Container(
            color: Colors.white,
            child: Column(
              children: [
                _ClassesDirectoryHeader(
                  unreadNotifications: _unreadNotifications,
                  onMenu: _showDirectoryMenu,
                  onUpload: _importClassesCsv,
                  onNotifications: () => Navigator.pushNamed(
                    context,
                    AppRoutes.notificationCenter,
                    arguments: 'principal',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: _ClassesDirectorySearchField(
                    onChanged: (value) => setState(() => _search = value),
                    onFilter: _showClassFilterSheet,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  child: _ClassesDirectoryMetricStrip(
                    classes: _int(
                      _summary['total_classes'],
                      fallback: _classes.length,
                    ),
                    students: _int(_summary['total_students']),
                    attendance: _num(_summary['average_attendance']),
                    issues: _int(_summary['classes_with_issues']),
                    onClassesTap: () => setState(() => _capacityFilter = 'All'),
                    onIssuesTap: () =>
                        setState(() => _capacityFilter = 'Issues'),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? _ClassesDirectoryErrorCard(
                          message: _error!,
                          onRetry: _load,
                        )
                      : rows.isEmpty
                      ? _ClassesDirectoryEmptyCard(onAdd: _openClassForm)
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: const Color(0xFF1478F2),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: rows.length,
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              final isSelected =
                                  _selectedSectionId ==
                                  _text(row['section_id']);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedSectionId = _text(
                                        row['section_id'],
                                      );
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: isSelected
                                          ? Border.all(
                                              color: const Color(0xFF1478F2),
                                              width: 2,
                                            )
                                          : Border.all(
                                              color: Colors.transparent,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: _ClassesDirectoryClassCard(
                                      row: row,
                                      subjects: _subjectsForClass(row),
                                      healthLabel: _healthLabel(row),
                                      healthColor: _healthColor(row),
                                      onTap: () {
                                        setState(() {
                                          _selectedSectionId = _text(
                                            row['section_id'],
                                          );
                                        });
                                      },
                                      onAction: (action) =>
                                          _handleClassAction(action, row),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
          detail: _buildDesktopDetailPane(),
        ),
      ),
    );
  }

  Widget _buildDesktopDetailPane() {
    final row = _selectedClassRow;
    if (row == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.class_outlined, size: 48, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text(
              'Select a class to view details',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
            ),
          ],
        ),
      );
    }

    final subjects = _subjectsForClass(row);
    final healthLabel = _healthLabel(row);
    final healthColor = _healthColor(row);

    return Scaffold(
      backgroundColor: const Color(0xFFEFF8FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEFF8FD),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          _text(row['class_name'], fallback: 'Class Detail'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Class',
            onPressed: () => _openEditClassForm(row),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Remove Class',
            onPressed: () => _deleteClass(row),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Basic Info
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: healthColor.withAlpha(24),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          healthLabel,
                          style: TextStyle(
                            color: healthColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Room: ${_text(row['room_number'], fallback: 'N/A')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailRow(
                          label: 'Students / Capacity',
                          value:
                              '${_int(row['student_count'])} / ${_int(row['capacity'])}',
                        ),
                      ),
                      Expanded(
                        child: _DetailRow(
                          label: 'Academic Year',
                          value: _text(row['academic_year_name']),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailRow(
                          label: 'Class Teacher',
                          value: _text(
                            row['class_teacher_name'],
                            fallback: 'Not assigned',
                          ),
                        ),
                      ),
                      Expanded(
                        child: _DetailRow(
                          label: 'Co-Teacher',
                          value: _text(
                            row['co_teacher_name'],
                            fallback: 'Not assigned',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Class Subjects
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Subjects & Tutors',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _openSubjectSetup(row),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add/Assign'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (subjects.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        'No subjects assigned to this class yet.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ...subjects.map((sub) {
                      final subName = _text(sub['subject_name']);
                      final teacherName = _teacherForSubject(row, sub);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.blue,
                        ),
                        title: Text(subName),
                        subtitle: Text(
                          teacherName.isEmpty
                              ? 'No teacher assigned'
                              : teacherName,
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Observation Action Card
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Classroom Action Menu',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            _openRoute(AppRoutes.studentOversight, row),
                        icon: const Icon(Icons.groups_rounded, size: 16),
                        label: const Text('Students List'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _openRoute(AppRoutes.principalAttendance, row),
                        icon: const Icon(Icons.fact_check_rounded, size: 16),
                        label: const Text('Attendance'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openFeesModule(row),
                        icon: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 16,
                        ),
                        label: const Text('Fees Monitoring'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openInstructionSheet(row),
                        icon: const Icon(Icons.rate_review_rounded, size: 16),
                        label: const Text('Add Observation'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? get _selectedClassRow {
    if (_selectedSectionId.isEmpty) return null;
    return _classes.firstWhere(
      (row) => _text(row['section_id']) == _selectedSectionId,
      orElse: () => _classes.first,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

const Color _classesDirectoryBg = principalDirectoryBackground;
const Color _classesDirectoryInk = principalDirectoryText;
const Color _classesDirectoryMuted = principalDirectoryMuted;
const Color _classesDirectoryBlue = principalDirectoryAccent;

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
      ? 12.0
      : width < 430
      ? 16.0
      : 18.0;
  return EdgeInsets.fromLTRB(horizontal, 10, horizontal, 28);
}

class _ClassesDirectoryHeader extends StatelessWidget {
  final int unreadNotifications;
  final VoidCallback onMenu;
  final VoidCallback onUpload;
  final VoidCallback onNotifications;

  const _ClassesDirectoryHeader({
    required this.unreadNotifications,
    required this.onMenu,
    required this.onUpload,
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
                      ? 17
                      : compact
                      ? 18
                      : 20,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: compact ? 8 : 14),
        _ClassesHeaderIconButton(
          tooltip: 'Upload classes CSV',
          icon: Icons.upload_file_rounded,
          onTap: onUpload,
        ),
        SizedBox(width: compact ? 8 : 10),
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
              : 44,
          height: tiny
              ? 40
              : compact
              ? 44
              : 44,
          child: Icon(
            icon,
            color: _classesDirectoryInk,
            size: tiny
                ? 21
                : compact
                ? 22
                : 23,
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
    final tiny = _classesTiny(context);
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 48 : 52),
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 5),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD5E2F1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF86A5C7).withAlpha(24),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(width: tiny ? 8 : (compact ? 12 : 16)),
          Icon(
            Icons.search_rounded,
            color: _classesDirectoryMuted,
            size: tiny ? 20 : (compact ? 21 : 23),
          ),
          SizedBox(width: tiny ? 6 : (compact ? 7 : 10)),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              maxLines: 1,
              style: GoogleFonts.dmSans(
                color: _classesDirectoryInk,
                fontSize: tiny ? 13 : (compact ? 14 : 15),
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                hintText: tiny
                    ? 'Search'
                    : (compact ? 'Search class' : 'Search class, teacher'),
                hintMaxLines: 1,
                hintStyle: GoogleFonts.dmSans(
                  color: _classesDirectoryMuted,
                  fontSize: tiny ? 12 : (compact ? 13 : 14),
                  fontWeight: FontWeight.w500,
                  letterSpacing: tiny ? -0.2 : 0,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: tiny ? 10 : (compact ? 12 : 14),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Filter classes',
            onPressed: onFilter,
            constraints: BoxConstraints(
              minWidth: tiny ? 32 : 40,
              minHeight: tiny ? 32 : 40,
            ),
            padding: tiny ? EdgeInsets.zero : const EdgeInsets.all(8.0),
            icon: Icon(
              Icons.tune_rounded,
              size: tiny ? 20 : (compact ? 21 : 23),
            ),
            color: _classesDirectoryMuted,
          ),
          SizedBox(width: tiny ? 4 : (compact ? 4 : 8)),
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
  final VoidCallback? onClassesTap;
  final VoidCallback? onIssuesTap;

  const _ClassesDirectoryMetricStrip({
    required this.classes,
    required this.students,
    required this.attendance,
    required this.issues,
    this.onClassesTap,
    this.onIssuesTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _classesPanelDecoration(radius: 8),
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
                  onTap: onClassesTap,
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
                  onTap: onClassesTap,
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
                  onTap: onIssuesTap,
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
  final VoidCallback? onTap;

  const _ClassesMetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.tone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _classesCompact(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: color.withAlpha(20),
        highlightColor: color.withAlpha(10),
        child: Ink(
          decoration: BoxDecoration(
            color: context.appTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(35)),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 82 : 86),
            padding: EdgeInsets.fromLTRB(
              compact ? 9 : 12,
              compact ? 9 : 12,
              compact ? 8 : 10,
              compact ? 9 : 12,
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: compact ? 20 : 22),
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
                        fontSize: compact ? 18 : 20,
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
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
              size: compact ? 22 : 24,
            ),
            SizedBox(width: compact ? 10 : 12),
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
                      fontSize: compact ? 13 : 14,
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
                      fontSize: compact ? 11.5 : 12,
                      fontWeight: FontWeight.w700,
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
            minimumSize: Size(compact ? 104 : 116, 40),
            foregroundColor: _classesDirectoryBlue,
            side: const BorderSide(color: Color(0xFFD5E5F7)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: GoogleFonts.dmSans(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          child: const Text('View calendar'),
        );

        return Container(
          padding: EdgeInsets.fromLTRB(14, 12, compact ? 12 : 14, 12),
          decoration: BoxDecoration(
            color: context.appTheme.surface.withAlpha(225),
            borderRadius: BorderRadius.circular(8),
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
        ? context.appTheme.surface
        : _CreateClassSetupPageState._ink;
    return Container(
      width: 118,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active
              ? _CreateClassSetupPageState._primary
              : _CreateClassSetupPageState._line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: complete
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : Text(
                      '$number',
                      style: GoogleFonts.dmSans(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: active
                    ? _CreateClassSetupPageState._primary
                    : _CreateClassSetupPageState._ink,
                fontSize: 10.5,
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
    final dueFees = _classNum(row['fees_due_amount']);
    final pendingProofAmount = _classNum(
      row['fees_pending_verification_amount'],
    );
    final pendingProofStudents = _classInt(
      row['fees_pending_verification_students'],
    );
    final compact = _classesCompact(context);
    return Material(
      color: context.appTheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: _classesPanelDecoration(radius: 8),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ClassesIconTile(
                    icon: Icons.meeting_room_outlined,
                    color: _classesDirectoryBlue,
                    tone: const Color(0xFFEAF3FF),
                    size: compact ? 42 : 46,
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
                            fontSize: compact ? 15 : 16,
                            fontWeight: FontWeight.w900,
                            height: 1.18,
                            letterSpacing: 0,
                          ),
                        ),
                        if (healthLabel != 'Healthy') ...[
                          const SizedBox(height: 5),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _ClassesStatusPill(
                              label: healthLabel,
                              color: healthColor,
                            ),
                          ),
                        ],
                        const SizedBox(height: 5),
                        Text(
                          '${_classText(row['class_teacher'], fallback: 'Teacher pending')}  •  $students/$capacity students',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: _classesDirectoryMuted,
                            fontSize: compact ? 11.5 : 12,
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
                      size: compact ? 21 : 22,
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
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'subjects',
                        child: Text('Setup subjects'),
                      ),
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
                  color: context.appTheme.surface,
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
                        value: row['today_attendance_pct'] == null
                            ? '—'
                            : '${_classNum(row['today_attendance_pct']).toStringAsFixed(0)}%',
                        label: 'Attendance',
                      ),
                      _ClassesClassMetric(
                        icon: Icons.currency_rupee_rounded,
                        color: const Color(0xFFF97316),
                        value: _formatCurrencyCompact(dueFees),
                        label: 'Total Dues',
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
              if (pendingProofAmount > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.hourglass_top_rounded,
                      size: 16,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_formatCurrencyCompact(pendingProofAmount)} proof pending review for $pendingProofStudents student${pendingProofStudents == 1 ? '' : 's'}',
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFF92400E),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
    return Container(width: 1, height: 48, color: const Color(0xFFDDE8F6));
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
          fontSize: compact ? 11 : 12,
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
      padding: EdgeInsets.fromLTRB(12, compact ? 12 : 14, 12, 12),
      decoration: _classesPanelDecoration(radius: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.dmSans(
              color: _classesDirectoryInk,
              fontSize: compact ? 15 : 16,
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
                  : 6;
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
          constraints: BoxConstraints(minHeight: compact ? 68 : 76),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 5,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: context.appTheme.surface,
            borderRadius: BorderRadius.circular(8),
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
                child: Icon(icon, color: color, size: compact ? 19 : 21),
              ),
              SizedBox(height: compact ? 6 : 8),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: _classesDirectoryInk,
                  fontSize: compact ? 10 : 11.5,
                  fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.all(14),
      decoration: _classesPanelDecoration(radius: 8),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: context.appTheme.error,
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: _classesDirectoryMuted,
              fontSize: 12.5,
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
      padding: const EdgeInsets.all(16),
      decoration: _classesPanelDecoration(radius: 8),
      child: Column(
        children: [
          const _ClassesIconTile(
            icon: Icons.meeting_room_outlined,
            color: _classesDirectoryBlue,
            tone: Color(0xFFEAF3FF),
            size: 50,
          ),
          const SizedBox(height: 12),
          Text(
            'No classes found',
            style: GoogleFonts.dmSans(
              color: _classesDirectoryInk,
              fontSize: 16,
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
              fontSize: 12.5,
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
            color: context.appTheme.surface,
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
                label: 'Alerts',
                icon: Icons.notifications_none_rounded,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.notificationCenter,
                  arguments: 'principal',
                ),
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
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        decoration: BoxDecoration(
          color: context.appTheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: context.appTheme.onSurface.withAlpha(30),
              blurRadius: 14,
              offset: const Offset(0, 6),
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
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            for (final action in actions)
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  dense: true,
                  minVerticalPadding: 8,
                  leading: Icon(
                    action.icon,
                    color: action.selected
                        ? _classesDirectoryBlue
                        : _classesDirectoryMuted,
                    size: 21,
                  ),
                  title: Text(
                    action.label,
                    style: GoogleFonts.dmSans(
                      color: _classesDirectoryInk,
                      fontSize: 13.5,
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
  final List<AcademicYearModel> academicYears;

  const _ClassDetailPage({
    required this.row,
    required this.subjects,
    required this.healthLabel,
    required this.healthColor,
    required this.teacherForSubject,
    required this.academicYears,
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
              PopupMenuDivider(),
              PopupMenuItem(value: 'subjects', child: Text('Setup subjects')),
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
              children: [
                _ClassMetricGrid(row: row),
                _ClassIssueBreakdown(items: _classIssueBreakdown(row)),
                const SizedBox(height: 18),
                _ClassDetailRow(
                  label: 'Class Teacher',
                  value: _classText(
                    row['class_teacher'],
                    fallback: 'Teacher pending',
                  ),
                ),
                _ClassDetailRow(
                  label: 'Co-Teacher',
                  value: _classText(
                    row['co_teacher'],
                    fallback: 'Not assigned',
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
                  value: _resolveAcademicYearLabel(row['academic_year_id']),
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
                  icon: Icons.menu_book_outlined,
                  title: 'Setup subjects',
                  subtitle: 'Assign subjects and teachers for this class',
                  onTap: () => Navigator.pop(context, 'subjects'),
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
                  color: context.appTheme.error,
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

  String _resolveAcademicYearLabel(Object? academicYearId) {
    final id = _classText(academicYearId);
    if (id.isEmpty) return '-';
    for (final year in academicYears) {
      if (year.id == id) return year.yearLabel;
    }
    return id;
  }
}

class _ClassMetricGrid extends StatelessWidget {
  final Map<String, dynamic> row;

  const _ClassMetricGrid({required this.row});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final twoColumns = constraints.maxWidth >= 340;
        final columns = twoColumns ? 2 : 1;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: tileWidth,
              child: _ClassMetricTile(
                icon: Icons.groups_outlined,
                label: 'Students',
                value:
                    '${_classInt(row['total_students'])}/${_classInt(row['capacity'])}',
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _ClassMetricTile(
                icon: Icons.fact_check_outlined,
                label: 'Today Attendance',
                value:
                    '${_classNum(row['today_attendance_pct']).toStringAsFixed(0)}%',
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _ClassMetricTile(
                icon: Icons.warning_amber_rounded,
                label: 'Pending Issues',
                value: '${_classInt(row['pending_issues'])}',
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _ClassMetricTile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Fee Due',
                value:
                    '₹${_classNum(row['fees_due_amount']).toStringAsFixed(0)}',
              ),
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
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF64727E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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

List<_ClassIssueItem> _classIssueBreakdown(Map<String, dynamic> row) {
  final teacherPending = _classText(row['class_teacher_id']).isEmpty;
  final studentsCount = _classInt(
    row['student_count'] ?? row['total_students'],
  );
  final capacity = _classInt(row['capacity']);
  final feeDueStudents = _classInt(row['fees_due_students']);
  final feeDueAmount = _classNum(row['fees_due_amount']);
  final pendingFeeProofStudents = _classInt(
    row['fees_pending_verification_students'],
  );
  final pendingFeeProofAmount = _classNum(
    row['fees_pending_verification_amount'],
  );

  final practicePending = _classInt(row['homework_pending']);
  final disciplineNotes = _classInt(row['discipline_issues']);
  final openComplaints = _classInt(row['complaints_open']);

  return [
    if (teacherPending)
      const _ClassIssueItem(
        icon: Icons.person_off_outlined,
        label: 'Teacher pending',
        value: 'Missing',
        note: 'Class teacher not assigned',
        color: Color(0xFFF59E0B),
      ),
    if (studentsCount == 0)
      const _ClassIssueItem(
        icon: Icons.group_off_outlined,
        label: 'No students',
        value: 'Empty',
        note: 'No students enrolled',
        color: Color(0xFFDC2626),
      ),
    if (capacity > 0 && studentsCount > capacity)
      _ClassIssueItem(
        icon: Icons.error_outline_rounded,
        label: 'Over capacity',
        value: '$studentsCount/$capacity',
        note: 'Students exceed capacity',
        color: const Color(0xFFDC2626),
      ),
    if (feeDueStudents > 0 || feeDueAmount > 0)
      _ClassIssueItem(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Total Dues',
        value: _formatCurrencyCompact(feeDueAmount),
        note: '$feeDueStudents student${feeDueStudents == 1 ? '' : 's'}',
        color: const Color(0xFFDC2626),
      ),
    if (pendingFeeProofStudents > 0 || pendingFeeProofAmount > 0)
      _ClassIssueItem(
        icon: Icons.hourglass_top_rounded,
        label: 'Proof pending',
        value: _formatCurrencyCompact(pendingFeeProofAmount),
        note:
            '$pendingFeeProofStudents student${pendingFeeProofStudents == 1 ? '' : 's'} awaiting verification',
        color: const Color(0xFFD97706),
      ),
    if (practicePending > 0)
      _ClassIssueItem(
        icon: Icons.assignment_late_outlined,
        label: 'Practice pending',
        value: '$practicePending',
        note: 'Diary follow-up needed',
        color: const Color(0xFFF59E0B),
      ),
    if (disciplineNotes > 0)
      _ClassIssueItem(
        icon: Icons.report_problem_outlined,
        label: 'Discipline notes',
        value: '$disciplineNotes',
        note: 'Needs principal review',
        color: const Color(0xFF7C3AED),
      ),
    if (openComplaints > 0)
      _ClassIssueItem(
        icon: Icons.mark_unread_chat_alt_outlined,
        label: 'Open complaints',
        value: '$openComplaints',
        note: 'Parent or student issue',
        color: const Color(0xFF0891B2),
      ),
  ];
}

class _ClassIssueItem {
  final IconData icon;
  final String label;
  final String value;
  final String note;
  final Color color;

  const _ClassIssueItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    required this.color,
  });
}

class _ClassIssueBreakdown extends StatelessWidget {
  final List<_ClassIssueItem> items;

  const _ClassIssueBreakdown({required this.items});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E4EA)),
      ),
      child: items.isEmpty
          ? Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF0F9F6E),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No pending class issues',
                    style: textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF20313B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Issue breakdown',
                  style: textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF20313B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < items.length; index++) ...[
                  _ClassIssueLine(item: items[index]),
                  if (index != items.length - 1)
                    const Divider(height: 14, color: Color(0xFFE4EEF3)),
                ],
              ],
            ),
    );
  }
}

class _ClassIssueLine extends StatelessWidget {
  final _ClassIssueItem item;

  const _ClassIssueLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(item.icon, color: item.color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF20313B),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                item.note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF64727E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          item.value,
          style: textTheme.titleMedium?.copyWith(
            color: item.color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ClassDetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ClassDetailCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final phone = _classesPhone(context);
    return Container(
      padding: EdgeInsets.all(phone ? 12 : 14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
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
                  style: GoogleFonts.dmSans(
                    color: _classesDirectoryInk,
                    fontSize: phone ? 14.5 : 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
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
            style: GoogleFonts.dmSans(
              color: const Color(0xFF64727E),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          );
          final valueWidget = Text(
            value,
            style: GoogleFonts.dmSans(
              color: _classesDirectoryInk,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
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
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: tint.withAlpha(26),
          child: Icon(icon, color: tint, size: 20),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: _classesDirectoryInk,
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
            color: _classesDirectoryMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: 0,
          ),
        ),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: onTap,
      ),
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

String _staffDisplayName(List<StaffModel> staff, String staffId) {
  final cleanId = staffId.trim();
  if (cleanId.isEmpty) return '';
  for (final member in staff) {
    if (member.id == cleanId) {
      final name = member.fullName.trim();
      return name.isNotEmpty ? name : member.staffCode;
    }
  }
  return '';
}

class _CreateClassSetupPage extends StatefulWidget {
  final List<AcademicYearModel> academicYears;
  final List<StaffModel> staff;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> gradeSubjects;
  final List<Map<String, dynamic>> staffSubjects;
  final List<Map<String, dynamic>>? existingClasses;
  final bool saving;
  final Future<Map<String, dynamic>?> Function({
    required String academicYearId,
    required String sectionName,
    required int capacity,
    required String gradeId,
    required String gradeName,
    required int? gradeNumber,
    required String classTeacherId,
    required String coTeacherId,
    required String roomNumber,
    required String roomType,
    required int roomCapacity,
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
    this.existingClasses = const [],
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
  final _roomNumber = TextEditingController();
  final _roomType = TextEditingController(text: 'classroom');
  String _academicYearId = '';
  String _teacherId = '';
  bool _saving = false;
  bool _submitted = false; // synchronous re-entry guard
  List<Map<String, dynamic>> get _existing => widget.existingClasses ?? [];
  String _coTeacherId = "";

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
    _roomNumber.dispose();
    _roomType.dispose();
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
                                const SizedBox(height: 14),
                                _ClassSetupSelectField(
                                  label: 'Co-Teacher',
                                  value: _coTeacherId,
                                  hint: 'Choose co-teacher (optional)',
                                  icon: Icons.person_add_outlined,
                                  iconColor: const Color(0xFF7C3AED),
                                  iconTone: const Color(0xFFF4ECFF),
                                  enabled: !_busy,
                                  items: [
                                    const DropdownMenuItem(
                                      value: '',
                                      child: Text('Not assigned'),
                                    ),
                                    ...widget.staff.map(
                                      (staff) => DropdownMenuItem(
                                        value: staff.id,
                                        child: Text(staff.fullName),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _coTeacherId = value),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _ClassSetupTwoColumnRow(
                              children: [
                                _ClassSetupInputField(
                                  label: 'Room Number',
                                  controller: _roomNumber,
                                  hint: 'Optional room number',
                                  icon: Icons.meeting_room_outlined,
                                  iconColor: const Color(0xFF0891B2),
                                  iconTone: const Color(0xFFE6FAFD),
                                  enabled: !_busy,
                                  validator: (_) => null,
                                ),
                                _ClassSetupInputField(
                                  label: 'Room Type',
                                  controller: _roomType,
                                  hint: 'classroom',
                                  icon: Icons.apartment_outlined,
                                  iconColor: const Color(0xFF475569),
                                  iconTone: const Color(0xFFF1F5F9),
                                  enabled: !_busy,
                                  validator: (_) => null,
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
                            const SizedBox(height: 32),
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
    if (_submitted) return; // prevent double-tap / re-entry
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      // Pre-submit check: warn about similar existing classes
      final gradeName = _gradeName.text.trim();
      final sectionName = _section.text.trim();
      final duplicate = _existing.any((row) {
        final existingGrade = (row['grade_name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final existingSection = (row['section_name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        return existingGrade == gradeName.toLowerCase() &&
            existingSection == sectionName.toLowerCase();
      });
      if (duplicate && mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Class already exists'),
            content: const Text(
              'A class named "\$gradeName - \$sectionName" already exists. Do you want to create another one?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create anyway'),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          _submitted = false;
          return;
        }
      }

      _submitted = true;
      setState(() => _saving = true);
      final created = await widget.onSubmit(
        academicYearId: _academicYearId,
        sectionName: _section.text.trim(),
        capacity: int.tryParse(_capacity.text.trim()) ?? 40,
        gradeId: '',
        gradeName: _gradeName.text.trim(),
        gradeNumber: _gradeOrderValue(),
        coTeacherId: _coTeacherId,
        classTeacherId: _teacherId,
        roomNumber: _roomNumber.text.trim(),
        roomType: _roomType.text.trim(),
        roomCapacity: int.tryParse(_capacity.text.trim()) ?? 40,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _submitted = false;
      });
      if (created != null && context.mounted) {
        Navigator.of(context).pushReplacement<bool, bool>(
          MaterialPageRoute(
            builder: (_) => _AssignSubjectsSetupPage(
              classRow: _createdClassRow(created),
              setupPayload: created,
              academicYears: widget.academicYears,
              initialSubjects: widget.subjects,
              initialGradeSubjects: widget.gradeSubjects,
              initialStaffSubjects: widget.staffSubjects,
            ),
          ),
          result: true,
        );
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _submitted = false;
        });
      }
      rethrow;
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
      'co_teacher_id': _classText(
        section['co_teacher_id'],
        fallback: _coTeacherId,
      ),
      'class_teacher': _staffDisplayName(widget.staff, _teacherId),
      'co_teacher': _staffDisplayName(widget.staff, _coTeacherId),
      'room_id': _classText(section['room_id']),
      'room_number': _classText(
        section['room_number'] ?? _classMap(section['room'])['room_number'],
        fallback: _roomNumber.text.trim(),
      ),
      'room_type': _classText(
        section['room_type'] ?? _classMap(section['room'])['room_type'],
        fallback: _roomType.text.trim(),
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
      padding: EdgeInsets.fromLTRB(phone ? 12 : 18, 10, phone ? 12 : 18, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: _CreateClassSetupPageState._ink,
            iconSize: tiny ? 20 : 22,
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
                        ? 17
                        : phone
                        ? 18
                        : 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Add a new class to your school',
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.dmSans(
                    color: _CreateClassSetupPageState._muted,
                    fontSize: tiny
                        ? 11
                        : phone
                        ? 11.5
                        : 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (!tiny) ...[
            const SizedBox(width: 10),
            Container(
              width: phone ? 40 : 44,
              height: phone ? 40 : 44,
              decoration: BoxDecoration(
                color: context.appTheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB7CEE5).withAlpha(70),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.maps_home_work_rounded,
                color: _CreateClassSetupPageState._primary,
                size: phone ? 21 : 23,
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
      padding: EdgeInsets.all(phone ? 14 : 18),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(phone ? 10 : 12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9DB9D2).withAlpha(45),
            blurRadius: 14,
            offset: const Offset(0, 5),
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
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: _CreateClassSetupPageState._primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.maps_home_work_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter class details to start the setup flow.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: _CreateClassSetupPageState._muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
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

class _ClassSetupStepRail extends StatelessWidget {
  final int activeIndex;

  const _ClassSetupStepRail({required this.activeIndex});

  static const _steps = [
    'Classes setup',
    'Subjects creation and assigning teachers',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _steps.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final active = index == activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: active
                  ? _CreateClassSetupPageState._primary
                  : const Color(0xFFF3F7FC),
              borderRadius: BorderRadius.circular(999),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _steps[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: active ? Colors.white : const Color(0xFF64748B),
                    fontSize: 10.5,
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
              fontSize: 13.5,
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
        const SizedBox(height: 7),
        child,
      ],
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
      height: phone ? 48 : 52,
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
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.appTheme.surface,
                ),
              )
            : const Icon(Icons.save_rounded, size: 21),
        label: Text(
          saving ? 'Saving...' : 'Save & Continue',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: phone ? 14.5 : 15.5,
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
  fontSize: 14.5,
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
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    filled: true,
    fillColor: Colors.white,
    prefixIcon: Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconTone,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 54, minHeight: 54),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
        width: 1.4,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFEF4444)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.4),
    ),
  );
}

class _AssignSubjectsSetupPage extends StatefulWidget {
  final Map<String, dynamic> classRow;
  final Map<String, dynamic> setupPayload;
  final List<AcademicYearModel> academicYears;
  final List<Map<String, dynamic>> initialSubjects;
  final List<Map<String, dynamic>> initialGradeSubjects;
  final List<Map<String, dynamic>> initialStaffSubjects;

  const _AssignSubjectsSetupPage({
    required this.classRow,
    required this.setupPayload,
    required this.academicYears,
    required this.initialSubjects,
    required this.initialGradeSubjects,
    required this.initialStaffSubjects,
  });

  @override
  State<_AssignSubjectsSetupPage> createState() =>
      _AssignSubjectsSetupPageState();
}

class _AssignSubjectsSetupPageState extends State<_AssignSubjectsSetupPage> {
  static const _classHubSetupTruth =
      'Class Hub setup is the source of truth for per-class subjects and fees';

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
          queryParameters: {
            'grade_id': _gradeId,
            'section_id': _sectionId,
            'page_size': 500,
          },
        ),
        BackendApiClient.instance.getRawList(
          '/staff-subjects',
          queryParameters: {
            'grade_id': _gradeId,
            'section_id': _sectionId,
            'page_size': 500,
          },
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _subjects = results[0];
        _gradeSubjects = results[1];
        _staffSubjects = results[2];
        _loading = false;
      });
    } on Object catch (error) {
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
          .where((row) => _isClassGradeSubject(row))
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

  bool _isClassGradeSubject(Map<String, dynamic> row) {
    return _classText(row['grade_id']) == _gradeId &&
        _classText(row['section_id']) == _sectionId;
  }

  Map<String, dynamic> _gradeSubjectFor(String subjectId) {
    return _gradeSubjects.firstWhere(
      (row) =>
          _isClassGradeSubject(row) &&
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
        ),
      ),
    );
    if (changed == true) {
      await _load();
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
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to remove subject: $error'),
          backgroundColor: context.appTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editSubject(Map<String, dynamic> subject) async {
    if (_saving) return;
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSubjectSetupSheet(subject: subject),
    );
    if (updated == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final subjectId = _subjectId(subject);
      await BackendApiClient.instance.updateRaw(
        '/subjects/$subjectId',
        updated,
      );
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update subject: $error'),
          backgroundColor: context.appTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteSubjectEverywhere(Map<String, dynamic> subject) async {
    final subjectId = _subjectId(subject);
    if (subjectId.isEmpty || _saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete subject?'),
        content: Text(
          'This first removes ${_subjectName(subject)} from $_className, then deletes the subject if the backend has no linked marks, attendance, or reports.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _removeSubject(subject);
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.deleteRaw('/subjects/$subjectId');
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Removed from this class, but subject could not be deleted globally: $error',
          ),
          backgroundColor: context.appTheme.warning,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(_classHubSetupTruth.isNotEmpty);
    final subjects = _mappedSubjects;
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            const _SetupFlowHeader(
              title: 'Assign Subjects',
              subtitle:
                  'Add class subjects. Class teacher and co-teacher teach these subjects.',
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
                                          busy: _saving,
                                          onEdit: () => _editSubject(subject),
                                          onRemove: () =>
                                              _removeSubject(subject),
                                          onDelete: () =>
                                              _deleteSubjectEverywhere(subject),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  const _SubjectSetupTip(),
                                  const SizedBox(height: 20),
                                  _SetupPrimaryButton(
                                    label: 'Save',
                                    icon: Icons.save_rounded,
                                    saving: _saving,
                                    onPressed: _saving
                                        ? null
                                        : () => Navigator.of(context).pop(true),
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

  String _academicYearLabel() {
    for (final year in widget.academicYears) {
      if (year.id == _academicYearId) return year.yearLabel;
    }
    return _academicYearId.isEmpty ? '-' : _academicYearId;
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
  final List<String> _deletedStructureIds = [];

  bool _loading = true;
  bool _saving = false;
  bool _useExisting = false;
  bool _reviewingExisting = false;
  int _stage = 0;
  String? _error;
  List<Map<String, dynamic>> _existingStructures = [];
  List<Map<String, dynamic>> _feeCategories = [];

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
      final results = await Future.wait<List<Map<String, dynamic>>>([
        _academicYearId.isEmpty || _gradeId.isEmpty
            ? Future.value(<Map<String, dynamic>>[])
            : BackendApiClient.instance.getFeeStructures(
                academicYearId: _academicYearId,
                gradeId: _gradeId,
                sectionId: _sectionId,
              ),
        BackendApiClient.instance.getFeeCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _existingStructures = results[0];
        _feeCategories = results[1];
        _loading = false;
      });
    } on Object catch (error) {
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
            backgroundColor: context.appTheme.error,
          ),
        );
        return;
      }
      setState(() {
        _reviewingExisting = true;
        _deletedStructureIds.clear();
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
      _deletedStructureIds.clear();
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

  Future<void> _saveFeeStructures() async {
    if (_saving) return;
    if (_sectionId.isEmpty || _gradeId.isEmpty || _academicYearId.isEmpty) {
      _showFeeError('Class, grade, and academic year are required.');
      return;
    }
    setState(() => _saving = true);
    try {
      final structureIdsToSync = <String>{};
      for (final structureId in _deletedStructureIds) {
        await BackendApiClient.instance.deleteFeeStructure(
          structureId,
          removePending: true,
        );
      }
      for (final component in _components) {
        final categoryId = await _ensureFeeCategory(component);
        if (component.structureId.isEmpty) {
          final created = await BackendApiClient.instance.createFeeStructure(
            academicYearId: _academicYearId,
            gradeId: _gradeId,
            sectionId: _sectionId,
            feeCategoryId: categoryId,
            amount: component.amount,
            dueDay: component.dueDay,
            lateFinePerDay: component.lateFinePerDay,
            installmentCount: _installmentCountFor(component),
          );
          final createdId = _classText(created['id']);
          if (createdId.isNotEmpty) structureIdsToSync.add(createdId);
        } else {
          await BackendApiClient.instance.updateFeeStructure(
            component.structureId,
            academicYearId: _academicYearId,
            gradeId: _gradeId,
            sectionId: _sectionId,
            feeCategoryId: categoryId,
            amount: component.amount,
            dueDay: component.dueDay,
            lateFinePerDay: component.lateFinePerDay,
            installmentCount: _installmentCountFor(component),
          );
          structureIdsToSync.add(component.structureId);
        }
      }
      for (final structureId in structureIdsToSync) {
        await BackendApiClient.instance.applyFeeInvoiceSync(
          structureId,
          includePartiallyPaid: true,
        );
      }
      if (!mounted) return;
      setState(() {
        _deletedStructureIds.clear();
        _stage = 3;
      });
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      _showFeeError('Unable to save fee structures: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String> _ensureFeeCategory(_FeeComponentDraft component) async {
    final name = component.name;
    final frequency = component.frequencyPayload;
    if (component.feeCategoryId.isNotEmpty) return component.feeCategoryId;
    for (final category in _feeCategories) {
      final categoryName = _classText(
        category['category_name'] ?? category['name'],
      ).toLowerCase();
      final categoryFrequency = _feeFrequencyPayload(
        _classText(category['frequency']),
      );
      if (categoryName == name.toLowerCase() &&
          categoryFrequency == frequency) {
        return _classText(category['id']);
      }
    }
    final created = await BackendApiClient.instance.createFeeCategory(
      categoryName: name,
      frequency: frequency,
    );
    _feeCategories.add(created);
    return _classText(created['id']);
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
      if (component.structureId.isNotEmpty) {
        _deletedStructureIds.add(component.structureId);
      }
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
      SnackBar(content: Text(message), backgroundColor: context.appTheme.error),
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
        const _FeeSetupProgressIndicator(activeIndex: 2),
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
              'Class Hub setup is the source of truth. Saved fee structures appear in the Fees dashboard automatically.',
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
                  onFrequencyChanged: (value) =>
                      setState(() => component.frequency = value),
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
        _FeeTotalsCard(
          termTotal: _termTotal,
          oneTimeTotal: _oneTimeTotal,
          yearlyTotal: _yearlyTotal,
        ),
        const SizedBox(height: 20),
        _SetupPrimaryButton(
          label: 'Save Fee Structures',
          icon: Icons.check_box_rounded,
          saving: _saving,
          onPressed: _saving ? null : _saveFeeStructures,
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
          termTotal: _termTotal,
          oneTimeTotal: _oneTimeTotal,
          yearlyTotal: _yearlyTotal,
        ),
        const SizedBox(height: 20),
        const _FeeInfoPanel(
          message:
              'Student fee accounts are assigned automatically from these fee structures.',
        ),
        const SizedBox(height: 20),
        _SetupPrimaryButton(
          label: 'Back to Class Hub',
          icon: Icons.grid_view_rounded,
          saving: false,
          onPressed: () => Navigator.pop(context, true),
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

  double get _termTotal => _components
      .where((component) => component.frequencyPayload == 'term')
      .fold<double>(0, (sum, component) => sum + component.amount);

  double get _yearlyTotal => _components
      .where((component) => component.frequencyPayload == 'yearly')
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

  const _AddSelectSubjectSetupPage({
    required this.classRow,
    required this.mappedSubjectIds,
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
  String _addingSubjectId = '';
  List<Map<String, dynamic>> _subjects = [];

  String get _gradeId => _classText(widget.classRow['grade_id']);
  String get _sectionId => _classText(widget.classRow['section_id']);
  String get _academicYearId => _classText(widget.classRow['academic_year_id']);

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
    } on Object catch (error) {
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
      final matchesSearch =
          query.isEmpty || _subjectSearchText(subject).contains(query);
      return matchesSearch;
    }).toList();
    rows.sort(
      (left, right) =>
          _subjectName(left).toLowerCase().compareTo(_subjectName(right)),
    );
    return rows;
  }

  Future<void> _addSubject(Map<String, dynamic> subject) async {
    final subjectId = _subjectId(subject);
    if (subjectId.isEmpty || _addingSubjectId.isNotEmpty) return;
    setState(() => _addingSubjectId = subjectId);
    try {
      await BackendApiClient.instance.savePrincipalSubjectMapping(
        subjectId: subjectId,
        academicYearId: _academicYearId,
        gradeId: _gradeId,
        sectionId: _sectionId,
        periodsPerWeek: 0,
        isPrimary: true,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _addingSubjectId = '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to add subject: $error'),
          backgroundColor: context.appTheme.error,
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
                              TextField(
                                onChanged: (value) =>
                                    setState(() => _query = value),
                                decoration: _plainSearchDecoration(
                                  'Search subject by name or code',
                                ),
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
  String _subjectColor = '#1E63F3';
  bool _saving = false;
  String? _error;

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
  String get _academicYearId => _classText(widget.classRow['academic_year_id']);

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
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
        'subject_color': _subjectColor,
      });
      final subjectId = _subjectId(subject);
      if (subjectId.isEmpty) {
        throw Exception('Subject was created but no subject id was returned.');
      }
      await BackendApiClient.instance.savePrincipalSubjectMapping(
        subjectId: subjectId,
        academicYearId: _academicYearId,
        gradeId: _gradeId,
        sectionId: _sectionId,
        periodsPerWeek: 0,
        isPrimary: true,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on Object catch (error) {
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
                                  _SubjectColorPicker(
                                    selected: _subjectColor,
                                    colors: _colors,
                                    enabled: !_saving,
                                    onChanged: (value) =>
                                        setState(() => _subjectColor = value),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
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

class _SetupSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const _SetupSectionHeader({
    required this.title,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heading = Text(
          title,
          style: _sectionTitleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
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

class _SetupPanelTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SetupPanelTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _CreateClassSetupPageState._primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: _CreateClassSetupPageState._primary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeeSetupProgressIndicator extends StatelessWidget {
  final int activeIndex;

  const _FeeSetupProgressIndicator({required this.activeIndex});

  static const _steps = ['Class', 'Subjects', 'Fees', 'Review'];

  @override
  Widget build(BuildContext context) {
    if (_classesPhone(context)) {
      return SizedBox(
        height: 62,
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
                  width: 30,
                  height: 30,
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
                            size: 16,
                          )
                        : Text(
                            '${i + 1}',
                            style: GoogleFonts.dmSans(
                              color: i == activeIndex
                                  ? Colors.white
                                  : const Color(0xFF475569),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: i == activeIndex
                        ? _CreateClassSetupPageState._primary
                        : _CreateClassSetupPageState._ink,
                    fontSize: 10,
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
                        fontSize: 15,
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
          const SizedBox(height: 14),
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
      color: context.appTheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? _CreateClassSetupPageState._primary
                  : _CreateClassSetupPageState._line,
              width: selected ? 1.4 : 1,
            ),
            color: selected
                ? const Color(0xFFF4F8FF)
                : context.appTheme.surface,
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
              const SizedBox(width: 12),
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
                        fontSize: 14,
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
                        fontSize: 12,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF7FF),
        borderRadius: BorderRadius.circular(8),
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
                fontSize: 12,
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
  final ValueChanged<String> onFrequencyChanged;
  final VoidCallback onDelete;

  const _FeeComponentEditRow({
    super.key,
    required this.index,
    required this.component,
    required this.enabled,
    required this.onFrequencyChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
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
                color: context.appTheme.error,
              ),
            ],
          );
          final amount = _FeeAmountField(
            component: component,
            enabled: enabled,
          );
          final frequency = _FeeFrequencySelector(
            value: component.frequencyLabel,
            enabled: enabled,
            onChanged: onFrequencyChanged,
          );
          if (constraints.maxWidth < 540) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 8),
                frequency,
                const SizedBox(height: 8),
                amount,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: header),
              const SizedBox(width: 12),
              SizedBox(width: 132, child: frequency),
              const SizedBox(width: 12),
              SizedBox(width: 148, child: amount),
            ],
          );
        },
      ),
    );
  }
}

class _FeeFrequencySelector extends StatelessWidget {
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _FeeFrequencySelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const options = ['Term', 'One Time', 'Yearly', 'Monthly'];
    final label = _feeFrequencyLabel(value);
    final current = options.contains(label) ? label : 'Term';
    return DropdownButtonFormField<String>(
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FBFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _CreateClassSetupPageState._line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _CreateClassSetupPageState._line),
        ),
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: enabled ? (value) => onChanged(value ?? 'Term') : null,
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
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _FeeSummaryText(label: 'Name', value: structureName),
          const SizedBox(height: 12),
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
                  children: [values[0], const SizedBox(height: 12), values[1]],
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
            fontSize: 11.5,
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
            fontSize: phone ? 13 : 13.5,
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
  final double termTotal;
  final double oneTimeTotal;
  final double yearlyTotal;

  const _FeeTotalsCard({
    required this.termTotal,
    required this.oneTimeTotal,
    required this.yearlyTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E7FF)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final oneTime = _FeeTotalValue(
            label: 'One Time',
            value: _formatCurrency(oneTimeTotal),
          );
          final term = _FeeTotalValue(
            label: 'Term',
            value: _formatCurrency(termTotal),
          );
          final yearly = _FeeTotalValue(
            label: 'Yearly',
            value: _formatCurrency(yearlyTotal),
          );
          if (constraints.maxWidth < 340) {
            return Column(
              children: [
                term,
                const SizedBox(height: 12),
                Container(height: 1, color: const Color(0xFFD8E7FF)),
                const SizedBox(height: 12),
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
              Expanded(child: term),
              Container(width: 1, height: 44, color: const Color(0xFFD8E7FF)),
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
            fontSize: 11.5,
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
            fontSize: 16,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFAF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCFEEDB)),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFF20B565),
            child: Icon(Icons.check_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            'Fee Structure Assigned!',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: _CreateClassSetupPageState._ink,
              fontSize: 16,
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
              fontSize: 12.5,
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
  final double termTotal;
  final double oneTimeTotal;
  final double yearlyTotal;

  const _FeeAssignmentDetailsCard({
    required this.academicYear,
    required this.className,
    required this.structureName,
    required this.totalComponents,
    required this.termTotal,
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
          const SizedBox(height: 14),
          _FeeSummaryText(label: 'Academic Year', value: academicYear),
          const SizedBox(height: 12),
          _FeeSummaryText(label: 'Class / Section', value: className),
          const SizedBox(height: 12),
          _FeeSummaryText(label: 'Fee Structure', value: structureName),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final values = [
                _FeeSummaryText(
                  label: 'Total Components',
                  value: '$totalComponents',
                ),
                _FeeSummaryText(
                  label: 'Term Total',
                  value: _formatCurrency(termTotal),
                ),
              ];
              if (constraints.maxWidth < 330) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [values[0], const SizedBox(height: 12), values[1]],
                );
              }
              return Row(
                children: [for (final value in values) Expanded(child: value)],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final values = [
                _FeeSummaryText(
                  label: 'One Time Total',
                  value: _formatCurrency(oneTimeTotal),
                ),
                _FeeSummaryText(
                  label: 'Yearly Total',
                  value: _formatCurrency(yearlyTotal),
                ),
              ];
              if (constraints.maxWidth < 330) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [values[0], const SizedBox(height: 12), values[1]],
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

class _FeeComponentIcon extends StatelessWidget {
  final _FeeComponentDraft component;

  const _FeeComponentIcon({required this.component});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: component.tone,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(component.icon, color: component.color, size: 20),
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
  String _frequency = 'Term';

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
            _FeeFrequencySelector(
              value: _frequency,
              enabled: true,
              onChanged: (value) => setState(() => _frequency = value),
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
                    frequency: _frequency,
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
  String frequency;
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
    this.frequency = 'Term',
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
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
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
      padding: EdgeInsets.fromLTRB(phone ? 12 : 18, 10, phone ? 12 : 18, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: _CreateClassSetupPageState._ink,
            iconSize: tiny ? 20 : 22,
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
                        ? 17.5
                        : 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.dmSans(
                    color: _CreateClassSetupPageState._muted,
                    fontSize: tiny
                        ? 11
                        : phone
                        ? 11.5
                        : 12,
                    fontWeight: FontWeight.w700,
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
              width: phone ? 40 : 44,
              height: phone ? 40 : 44,
              decoration: BoxDecoration(
                color: context.appTheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB7CEE5).withAlpha(60),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: _CreateClassSetupPageState._primary,
                size: phone ? 20 : 22,
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
      padding: EdgeInsets.all(phone ? 12 : 14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9DB9D2).withAlpha(38),
            blurRadius: 12,
            offset: const Offset(0, 5),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: phone ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: _CreateClassSetupPageState._ink,
            fontSize: phone ? 13 : 14,
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
              fontSize: 15,
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
              fontSize: 11,
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
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onDelete;

  const _AssignedSubjectTile({
    required this.subject,
    required this.busy,
    required this.onEdit,
    required this.onRemove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _CreateClassSetupPageState._line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _SubjectIconBadge(subject: subject),
                const SizedBox(width: 12),
                Expanded(child: _SubjectNameCode(subject: subject)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Subject actions',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'remove') onRemove();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit subject details')),
              PopupMenuItem(value: 'remove', child: Text('Remove subject')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete subject globally'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditSubjectSetupSheet extends StatefulWidget {
  final Map<String, dynamic> subject;

  const _EditSubjectSetupSheet({required this.subject});

  @override
  State<_EditSubjectSetupSheet> createState() => _EditSubjectSetupSheetState();
}

class _EditSubjectSetupSheetState extends State<_EditSubjectSetupSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late String _subjectColor;

  static const _colors = _CreateSubjectSetupPageState._colors;

  @override
  void initState() {
    super.initState();
    final subject = widget.subject;
    _nameController = TextEditingController(text: _subjectName(subject));
    _codeController = TextEditingController(text: _subjectCode(subject));
    _subjectColor = _classText(subject['subject_color'], fallback: '#1E63F3');
    if (!_colors.contains(_subjectColor)) _subjectColor = '#1E63F3';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, {
      'subject_name': _nameController.text.trim(),
      'subject_code': _codeController.text.trim(),
      'subject_color': _subjectColor,
    });
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetPanel(
      title: 'Edit subject details',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ClassSetupInputField(
              label: 'Subject Name',
              required: true,
              controller: _nameController,
              hint: 'Enter subject name',
              icon: Icons.edit_outlined,
              iconColor: const Color(0xFF1E63F3),
              iconTone: const Color(0xFFEAF2FF),
              enabled: true,
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  _classText(value).isEmpty ? 'Subject name is required' : null,
            ),
            const SizedBox(height: 14),
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
                  enabled: true,
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) =>
                      _classText(value).isEmpty ? 'Code is required' : null,
                ),
                _SubjectColorPicker(
                  selected: _subjectColor,
                  colors: _colors,
                  enabled: true,
                  onChanged: (value) => setState(() => _subjectColor = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 6),
            _SetupPrimaryButton(
              label: 'Save Subject',
              icon: Icons.save_rounded,
              saving: false,
              onPressed: _submit,
            ),
          ],
        ),
      ),
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
              'Class teacher and co-teacher teach these subjects.\nYou can edit or add more later from class settings.',
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
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Enter subject details to add to your curriculum.',
                    style: GoogleFonts.dmSans(
                      color: _CreateClassSetupPageState._muted,
                      fontSize: 12,
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

class _SetupIconCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? tone;

  const _SetupIconCircle({required this.icon, required this.color, this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: tone ?? color, shape: BoxShape.circle),
      child: Icon(icon, color: tone == null ? Colors.white : color, size: 22),
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
      height: phone ? 48 : 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: saving
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.appTheme.surface,
                ),
              )
            : Icon(icon, size: 21),
        label: Text(
          saving ? 'Saving...' : label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: phone ? 14.5 : 15.5,
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
          Icon(Icons.error_outline_rounded, color: context.appTheme.error),
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

TextStyle get _sectionTitleStyle => GoogleFonts.dmSans(
  color: _CreateClassSetupPageState._ink,
  fontSize: 16,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

TextStyle get _feeSectionTitleStyle => GoogleFonts.dmSans(
  color: _CreateClassSetupPageState._ink,
  fontSize: 16,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

List<_FeeComponentDraft> _defaultFeeComponents() => [
  _FeeComponentDraft(
    name: 'Tuition Fee',
    amount: 12000,
    frequency: 'Term',
    icon: Icons.school_outlined,
    color: const Color(0xFF16A34A),
    tone: const Color(0xFFEAFBF0),
  ),
  _FeeComponentDraft(
    name: 'Admission Fee',
    amount: 2000,
    frequency: 'One Time',
    icon: Icons.account_balance_outlined,
    color: const Color(0xFFF43F5E),
    tone: const Color(0xFFFFEAF1),
  ),
  _FeeComponentDraft(
    name: 'Annual Charges',
    amount: 1500,
    frequency: 'Yearly',
    icon: Icons.local_activity_outlined,
    color: const Color(0xFFA855F7),
    tone: const Color(0xFFF3E8FF),
  ),
  _FeeComponentDraft(
    name: 'Smart Class Fee',
    amount: 1000,
    frequency: 'Term',
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
    fallback: 'Term',
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
  return text.isEmpty ? 'term' : text.replaceAll(' ', '_');
}

String _feeFrequencyLabel(String frequency) {
  final payload = _feeFrequencyPayload(frequency);
  return switch (payload) {
    'one_time' => 'One Time',
    'yearly' => 'Yearly',
    'monthly' => 'Monthly',
    'term' => 'Term',
    _ => frequency.trim().isEmpty ? 'Term' : frequency.trim(),
  };
}

int _installmentCountFor(_FeeComponentDraft component) {
  return switch (component.frequencyPayload) {
    'monthly' => 12,
    'yearly' => 1,
    'one_time' => 1,
    _ => 3,
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
    required String coTeacherId,
    required String roomNumber,
    required String roomType,
    required int roomCapacity,
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
  final _roomNumber = TextEditingController();
  final _roomType = TextEditingController(text: 'classroom');
  String _academicYearId = '';
  String _teacherId = '';
  bool _saving = false;
  String _coTeacherId = "";

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
    final coTeacherId = _classText(widget.row['co_teacher_id']);
    final coTeacherIds = widget.staff.map((staff) => staff.id).toSet();
    _coTeacherId = coTeacherIds.contains(coTeacherId) ? coTeacherId : '';
    _roomNumber.text = _classText(widget.row['room_number']);
    final roomType = _classText(widget.row['room_type']);
    if (roomType.isNotEmpty) _roomType.text = roomType;
  }

  @override
  void dispose() {
    _gradeName.dispose();
    _gradeNumber.dispose();
    _section.dispose();
    _capacity.dispose();
    _roomNumber.dispose();
    _roomType.dispose();
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _coTeacherId.isEmpty ? '' : _coTeacherId,
                decoration: const InputDecoration(labelText: 'Co-teacher'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Unassigned')),
                  ...widget.staff.map(
                    (staff) => DropdownMenuItem(
                      value: staff.id,
                      child: Text(staff.fullName),
                    ),
                  ),
                ],
                onChanged: (value) => _coTeacherId = value ?? '',
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final roomNumber = TextFormField(
                    controller: _roomNumber,
                    decoration: const InputDecoration(
                      labelText: 'Room number',
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                    ),
                  );
                  final roomType = TextFormField(
                    controller: _roomType,
                    decoration: const InputDecoration(
                      labelText: 'Room type',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                  );
                  if (constraints.maxWidth < 420) {
                    return Column(
                      children: [
                        roomNumber,
                        const SizedBox(height: 12),
                        roomType,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: roomNumber),
                      const SizedBox(width: 12),
                      Expanded(child: roomType),
                    ],
                  );
                },
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
      coTeacherId: _coTeacherId,
      roomNumber: _roomNumber.text.trim(),
      roomType: _roomType.text.trim(),
      roomCapacity: int.tryParse(_capacity.text.trim()) ?? 40,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok && context.mounted) Navigator.pop(context, true);
  }
}
