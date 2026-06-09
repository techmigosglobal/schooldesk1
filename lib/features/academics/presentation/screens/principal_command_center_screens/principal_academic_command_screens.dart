// ignore_for_file: unused_element, unused_element_parameter, unused_field

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/operations_workspace.dart';
import 'package:schooldesk1/core/widgets/principal_directory_ui.dart';
import 'package:schooldesk1/routes/app_routes.dart';

import 'principal_exam_review_screen.dart';

enum _TimetableHomeMode { classes, teachers, rooms }

enum _TimetableDetailMode {
  home,
  classDay,
  classWeek,
  dayDetails,
  teacher,
  room,
}

enum _PrincipalCommandKind { timetable, exams, results }

class PrincipalTimetableScreen extends StatefulWidget {
  const PrincipalTimetableScreen({super.key});

  @override
  State<PrincipalTimetableScreen> createState() =>
      _PrincipalTimetableScreenState();
}

class _PrincipalTimetableScreenState extends State<PrincipalTimetableScreen> {
  static const _days = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  bool _loading = true;
  String? _error;
  String _search = '';
  int _selectedDay = DateTime.now().weekday.clamp(1, 6).toInt();
  int _filterDay = 0;
  _TimetableHomeMode _homeMode = _TimetableHomeMode.classes;
  _TimetableDetailMode _detailMode = _TimetableDetailMode.home;
  Map<String, dynamic> _data = {};
  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedTeacher;
  Map<String, dynamic>? _selectedRoom;
  Map<String, dynamic>? _selectedPeriod;
  bool _routeArgsRead = false;
  String _requestedSectionId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgsRead) return;
    _routeArgsRead = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final sectionId = _text(args['section_id'] ?? args['sectionId']);
      if (sectionId.isNotEmpty) {
        _requestedSectionId = sectionId;
        _homeMode = _TimetableHomeMode.classes;
        _detailMode = _TimetableDetailMode.classDay;
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await BackendApiClient.instance
          .getPrincipalTimetableOverview();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _reconcileSelection();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load timetable from backend. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: principalDirectoryBackground,
      bottomNavigationBar: const PrincipalShellBottomBar(),
      body: SafeArea(
        child: RefreshIndicator(
          color: principalDirectoryAccent,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: OpsEmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Timetable unavailable',
                        message: _error!,
                        actionLabel: 'Retry',
                        onAction: _load,
                      ),
                    ),
                  ),
                )
              else
                ..._buildContentSlivers(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = switch (_detailMode) {
      _TimetableDetailMode.classDay => 'Class Timetable',
      _TimetableDetailMode.classWeek => 'Full Week Timetable',
      _TimetableDetailMode.dayDetails => '${_dayLabel(_selectedDay)} Schedule',
      _TimetableDetailMode.teacher => 'Teacher Timetable',
      _TimetableDetailMode.room => 'Room Timetable',
      _TimetableDetailMode.home => 'Timetable',
    };
    final subtitle = switch (_detailMode) {
      _TimetableDetailMode.classDay => _text(
        _selectedClass?['class_name'],
        fallback: 'Class schedule',
      ),
      _TimetableDetailMode.classWeek => _text(
        _selectedClass?['class_name'],
        fallback: 'Class schedule',
      ),
      _TimetableDetailMode.dayDetails => _text(
        _selectedClass?['class_name'],
        fallback: 'Day schedule',
      ),
      _TimetableDetailMode.teacher => _text(
        _selectedTeacher?['teacher_name'],
        fallback: 'Teacher schedule',
      ),
      _TimetableDetailMode.room => _text(
        _selectedRoom?['room_name'],
        fallback: 'Room schedule',
      ),
      _TimetableDetailMode.home => 'View and explore live timetables',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: _detailMode == _TimetableDetailMode.home ? 'Menu' : 'Back',
            onPressed: _goBack,
            icon: Icon(
              _detailMode == _TimetableDetailMode.home
                  ? Icons.menu_rounded
                  : Icons.arrow_back_ios_new_rounded,
              size: 20,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: principalDirectoryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: principalDirectoryMuted,
                  ),
                ),
              ],
            ),
          ),
          if (_detailMode == _TimetableDetailMode.home)
            IconButton.filledTonal(
              tooltip: 'Filter timetable',
              onPressed: _openFilterSheet,
              icon: const Icon(Icons.tune_rounded, size: 20),
            )
          else
            IconButton.filledTonal(
              tooltip: _detailMode == _TimetableDetailMode.dayDetails
                  ? 'Share schedule'
                  : 'Refresh timetable',
              onPressed: _detailMode == _TimetableDetailMode.dayDetails
                  ? _shareDaySummary
                  : _load,
              icon: Icon(
                _detailMode == _TimetableDetailMode.dayDetails
                    ? Icons.ios_share_rounded
                    : Icons.calendar_month_rounded,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildContentSlivers() {
    final body = switch (_detailMode) {
      _TimetableDetailMode.classDay => _buildClassDayView(),
      _TimetableDetailMode.classWeek => _buildClassWeekView(),
      _TimetableDetailMode.dayDetails => _buildDayDetailsView(),
      _TimetableDetailMode.teacher => _buildTeacherDetailView(),
      _TimetableDetailMode.room => _buildRoomDetailView(),
      _TimetableDetailMode.home => _buildHomeView(),
    };
    return [
      SliverToBoxAdapter(child: _buildMetrics()),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
        sliver: SliverToBoxAdapter(child: body),
      ),
    ];
  }

  Widget _buildMetrics() {
    final summary = _map(_data['summary']);
    return PrincipalDirectoryMetricStrip(
      metrics: [
        PrincipalDirectoryMetric(
          label: 'Slots',
          value: '${_int(summary['total_slots'])}',
          icon: Icons.event_note_rounded,
          color: AppTheme.primary,
          tone: AppTheme.primaryContainer,
        ),
        PrincipalDirectoryMetric(
          label: 'Classes',
          value: '${_int(summary['classes_covered'])}',
          icon: Icons.groups_2_outlined,
          color: AppTheme.secondary,
          tone: AppTheme.secondaryContainer,
        ),
        PrincipalDirectoryMetric(
          label: 'Teachers',
          value: '${_int(summary['teachers_scheduled'])}',
          icon: Icons.badge_outlined,
          color: Colors.deepPurple,
          tone: const Color(0xFFF0E7FF),
        ),
        PrincipalDirectoryMetric(
          label: 'Conflicts',
          value: '${_int(summary['conflict_alerts'])}',
          icon: Icons.warning_amber_rounded,
          color: _int(summary['conflict_alerts']) == 0
              ? AppTheme.success
              : AppTheme.warning,
          tone: _int(summary['conflict_alerts']) == 0
              ? AppTheme.successContainer
              : AppTheme.warningContainer,
        ),
      ],
    );
  }

  Widget _buildHomeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildModeTabs(),
        const SizedBox(height: 14),
        _buildSearchBox(),
        const SizedBox(height: 18),
        switch (_homeMode) {
          _TimetableHomeMode.classes => _buildClassList(),
          _TimetableHomeMode.teachers => _buildTeacherList(),
          _TimetableHomeMode.rooms => _buildRoomList(),
        },
        const SizedBox(height: 16),
        _buildOwnershipNotice(),
      ],
    );
  }

  Widget _buildModeTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE8F5)),
      ),
      child: Row(
        children: [
          _modeTab(
            mode: _TimetableHomeMode.classes,
            icon: Icons.groups_2_outlined,
            label: 'Class',
          ),
          _modeTab(
            mode: _TimetableHomeMode.teachers,
            icon: Icons.person_pin_outlined,
            label: 'Teacher',
          ),
          _modeTab(
            mode: _TimetableHomeMode.rooms,
            icon: Icons.meeting_room_outlined,
            label: 'Room',
          ),
        ],
      ),
    );
  }

  Widget _modeTab({
    required _TimetableHomeMode mode,
    required IconData icon,
    required String label,
  }) {
    final selected = _homeMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _homeMode = mode;
          _search = '';
        }),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? principalDirectoryAccent : Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : principalDirectoryMuted,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$label Timetable',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : principalDirectoryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    final hint = switch (_homeMode) {
      _TimetableHomeMode.classes => 'Search class or section',
      _TimetableHomeMode.teachers => 'Search teacher',
      _TimetableHomeMode.rooms => 'Search room',
    };
    return PrincipalDirectorySearchBox(
      hint: hint,
      onChanged: (value) => setState(() => _search = value),
    );
  }

  Widget _buildClassList() {
    final rows = _classRows.where(_matchesSearch).toList();
    if (rows.isEmpty) return _homeEmptyState('No class timetables found');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _listSectionTitle('Classes'),
        const SizedBox(height: 10),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PrincipalDirectoryCard(
              icon: Icons.groups_2_outlined,
              title: _text(row['class_name'], fallback: 'Class'),
              subtitle: '${_int(row['slot_count'])} Periods / Week',
              status: _int(row['slot_count']) > 0 ? 'Active' : 'Pending',
              statusColor: _int(row['slot_count']) > 0
                  ? AppTheme.success
                  : AppTheme.warning,
              chips: [
                PrincipalInfoPill(
                  icon: Icons.co_present_outlined,
                  label: _text(
                    row['class_teacher'],
                    fallback: 'Class teacher pending',
                  ),
                ),
                PrincipalInfoPill(
                  icon: Icons.person_pin_outlined,
                  label: '${_int(row['teacher_count'])} teachers',
                ),
                PrincipalInfoPill(
                  icon: Icons.menu_book_outlined,
                  label: '${_int(row['subject_count'])} subjects',
                ),
              ],
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openClass(row),
            ),
          ),
      ],
    );
  }

  Widget _buildTeacherList() {
    final rows = _teacherRows.where(_matchesSearch).toList();
    if (rows.isEmpty) return _homeEmptyState('No teacher timetables found');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _listSectionTitle('Teachers'),
        const SizedBox(height: 10),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PrincipalDirectoryCard(
              icon: Icons.person_pin_outlined,
              title: _text(row['teacher_name'], fallback: 'Teacher'),
              subtitle: _teacherDepartment(row),
              status: _text(row['workload_state'], fallback: 'Scheduled'),
              statusColor: _statusColor(_text(row['workload_state'])),
              chips: [
                PrincipalInfoPill(
                  icon: Icons.event_note_outlined,
                  label: '${_int(row['periods'])} Periods / Week',
                ),
                PrincipalInfoPill(
                  icon: Icons.groups_2_outlined,
                  label: '${_int(row['classes'])} classes',
                ),
                PrincipalInfoPill(
                  icon: Icons.menu_book_outlined,
                  label: '${_int(row['subjects'])} subjects',
                ),
              ],
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openTeacher(row),
            ),
          ),
      ],
    );
  }

  Widget _buildRoomList() {
    final rows = _roomRows.where(_matchesSearch).toList();
    if (rows.isEmpty) return _homeEmptyState('No room timetables found');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _listSectionTitle('Rooms'),
        const SizedBox(height: 10),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PrincipalDirectoryCard(
              icon: _bool(row['is_lab_room'])
                  ? Icons.science_outlined
                  : Icons.meeting_room_outlined,
              title: _text(row['room_name'], fallback: 'Room'),
              subtitle: _roomCapacityLabel(row),
              status: _int(row['conflicts']) == 0 ? 'Clear' : 'Conflict',
              statusColor: _int(row['conflicts']) == 0
                  ? AppTheme.success
                  : AppTheme.warning,
              chips: [
                PrincipalInfoPill(
                  icon: Icons.event_note_outlined,
                  label: '${_int(row['periods'])} periods',
                ),
                PrincipalInfoPill(
                  icon: Icons.groups_2_outlined,
                  label: '${_int(row['classes'])} classes',
                ),
                PrincipalInfoPill(
                  icon: Icons.warning_amber_rounded,
                  label: '${_int(row['conflicts'])} conflicts',
                ),
              ],
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openRoom(row),
            ),
          ),
      ],
    );
  }

  Widget _listSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w900,
        color: principalDirectoryText,
      ),
    );
  }

  Widget _homeEmptyState(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
      decoration: _panelDecoration(),
      child: OpsEmptyState(
        icon: Icons.calendar_view_week_outlined,
        title: title,
        message: 'Only live backend timetable rows are shown here.',
      ),
    );
  }

  Widget _buildClassDayView() {
    final row = _selectedClass;
    if (row == null) return _buildHomeView();
    final periods = _periodsForClass(_text(row['section_id']), _selectedDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildClassSummary(row),
        const SizedBox(height: 14),
        _buildDayChips(),
        const SizedBox(height: 14),
        periods.isEmpty
            ? _buildClassEmptyState(row)
            : _buildSchedulePanel(
                title: '${_dayLabel(_selectedDay)} Schedule',
                rows: periods,
                onRowTap: _openDayDetails,
                columns: const [
                  'Time',
                  'Period',
                  'Subject',
                  'Teacher',
                  'Room',
                  'Action',
                ],
              ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () =>
              setState(() => _detailMode = _TimetableDetailMode.classWeek),
          icon: const Icon(Icons.calendar_view_week_rounded),
          label: const Text('View Full Week'),
        ),
        const SizedBox(height: 10),
        _buildOwnershipNotice(compact: true),
      ],
    );
  }

  Widget _buildClassWeekView() {
    final row = _selectedClass;
    if (row == null) return _buildHomeView();
    final sectionId = _text(row['section_id']);
    final periods = _periodsForClass(sectionId, null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildClassSummary(row),
        const SizedBox(height: 14),
        _buildDayChips(),
        const SizedBox(height: 14),
        periods.isEmpty ? _buildClassEmptyState(row) : _buildWeekGrid(periods),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _exportWeekPdf,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Export PDF'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openLegendSheet,
                icon: const Icon(Icons.sell_outlined),
                label: const Text('Legend'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () =>
              setState(() => _detailMode = _TimetableDetailMode.classDay),
          icon: const Icon(Icons.calendar_today_outlined),
          label: const Text('View Day Schedule'),
        ),
      ],
    );
  }

  Widget _buildDayDetailsView() {
    final classRow = _selectedClass;
    final period = _selectedPeriod;
    if (classRow == null) return _buildHomeView();
    final periods = _periodsForClass(
      _text(classRow['section_id']),
      _selectedDay,
    );
    final teachingPeriods = periods.where((row) => !_isBreak(row)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _panelDecoration(),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.successContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dayLabel(_selectedDay),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: principalDirectoryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _dayTimeRange(periods),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: principalDirectoryMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const PrincipalStatusPill(
                label: 'Active',
                color: AppTheme.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _panelDecoration(),
          child: Column(
            children: [
              _metadataRow(
                Icons.school_outlined,
                'Academic Year',
                _text(
                  classRow['academic_year'] ?? classRow['academic_year_id'],
                  fallback: 'Current academic year',
                ),
              ),
              _metadataRow(
                Icons.groups_2_outlined,
                'Class / Section',
                _text(classRow['class_name'], fallback: 'Class'),
              ),
              _metadataRow(
                Icons.event_note_outlined,
                'Total Periods',
                '${teachingPeriods.length}',
              ),
              _metadataRow(
                Icons.schedule_outlined,
                'Total Duration',
                _dayDurationLabel(periods),
              ),
              _metadataRow(
                Icons.free_breakfast_outlined,
                'Breaks',
                _breaksLabel(periods),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        periods.isEmpty
            ? _buildClassEmptyState(classRow)
            : _buildSchedulePanel(
                title: 'Today\'s Timetable',
                rows: periods,
                columns: const ['Period', 'Time', 'Subject', 'Teacher', 'Room'],
              ),
        if (period != null && !_isBreak(period)) ...[
          const SizedBox(height: 14),
          PrincipalDirectoryCard(
            icon: Icons.menu_book_outlined,
            title: _subjectName(period),
            subtitle: _slotTime(period),
            status: 'Selected Period',
            statusColor: AppTheme.primary,
            chips: [
              PrincipalInfoPill(
                icon: Icons.person_pin_outlined,
                label: _teacherName(period),
              ),
              PrincipalInfoPill(
                icon: Icons.meeting_room_outlined,
                label: _roomName(period),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _goToClassesHub,
          icon: const Icon(Icons.account_tree_outlined),
          label: const Text('Go to Classes Hub'),
        ),
        const SizedBox(height: 8),
        Text(
          'Make changes from Classes Hub > Step 3 (Timetable)',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: principalDirectoryMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherDetailView() {
    final row = _selectedTeacher;
    if (row == null) return _buildHomeView();
    final periods = _availabilityRows(
      _periodsForTeacher(_text(row['staff_id']), _selectedDay),
      _selectedDay,
      freeLabel: 'Free Period',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrincipalDirectoryCard(
          icon: Icons.person_pin_outlined,
          title: _text(row['teacher_name'], fallback: 'Teacher'),
          subtitle: _teacherDepartment(row),
          status: _text(row['workload_state'], fallback: 'Scheduled'),
          statusColor: _statusColor(_text(row['workload_state'])),
          chips: [
            PrincipalInfoPill(
              icon: Icons.event_note_outlined,
              label: 'Total Periods: ${_int(row['periods'])}',
            ),
            PrincipalInfoPill(
              icon: Icons.free_breakfast_outlined,
              label:
                  'Free Periods: ${_freePeriodsFor(_text(row['staff_id']), 'staff')}',
            ),
            PrincipalInfoPill(
              icon: Icons.groups_2_outlined,
              label: 'Classes: ${_int(row['classes'])}',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDayChips(),
        const SizedBox(height: 14),
        periods.isEmpty
            ? _detailEmptyState(
                'No teacher schedule for ${_dayLabel(_selectedDay)}',
              )
            : _buildSchedulePanel(
                title: '${_dayLabel(_selectedDay)} Teacher Schedule',
                rows: periods,
                onRowTap: _openPeriodClassDay,
                columns: const ['Time', 'Period', 'Class', 'Subject', 'Room'],
              ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _openTeacherWeekPreview,
          icon: const Icon(Icons.calendar_view_week_rounded),
          label: const Text('View Full Week Schedule'),
        ),
      ],
    );
  }

  Widget _buildRoomDetailView() {
    final row = _selectedRoom;
    if (row == null) return _buildHomeView();
    final periods = _availabilityRows(
      _periodsForRoom(_text(row['room_id']), _selectedDay),
      _selectedDay,
      freeLabel: 'Room Free',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrincipalDirectoryCard(
          icon: _bool(row['is_lab_room'])
              ? Icons.science_outlined
              : Icons.meeting_room_outlined,
          title: _text(row['room_name'], fallback: 'Room'),
          subtitle: _roomCapacityLabel(row),
          status: _int(row['conflicts']) == 0 ? 'Clear' : 'Conflict',
          statusColor: _int(row['conflicts']) == 0
              ? AppTheme.success
              : AppTheme.warning,
          chips: [
            PrincipalInfoPill(
              icon: Icons.event_note_outlined,
              label: '${_int(row['periods'])} periods',
            ),
            PrincipalInfoPill(
              icon: Icons.groups_2_outlined,
              label: '${_int(row['classes'])} classes',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDayChips(),
        const SizedBox(height: 14),
        periods.isEmpty
            ? _detailEmptyState(
                'No room schedule for ${_dayLabel(_selectedDay)}',
              )
            : _buildSchedulePanel(
                title: '${_dayLabel(_selectedDay)} Room Schedule',
                rows: periods,
                onRowTap: _openPeriodClassDay,
                columns: const [
                  'Time',
                  'Period',
                  'Class',
                  'Subject',
                  'Teacher',
                ],
              ),
      ],
    );
  }

  Widget _buildClassSummary(Map<String, dynamic> row) {
    return PrincipalDirectoryCard(
      icon: Icons.groups_2_outlined,
      title: _text(row['class_name'], fallback: 'Class'),
      subtitle: _text(
        row['supervision_note'],
        fallback: '${_int(row['slot_count'])} periods / week',
      ),
      status: _int(row['slot_count']) > 0 ? 'Active' : 'Pending',
      statusColor: _int(row['slot_count']) > 0
          ? AppTheme.success
          : AppTheme.warning,
      chips: [
        PrincipalInfoPill(
          icon: Icons.event_note_outlined,
          label: '${_int(row['slot_count'])} periods',
        ),
        PrincipalInfoPill(
          icon: Icons.person_pin_outlined,
          label: '${_int(row['teacher_count'])} teachers',
        ),
      ],
    );
  }

  Widget _buildDayChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = index + 1;
          final selected = day == _selectedDay;
          return PrincipalDirectoryChip(
            label: _days[index],
            selected: selected,
            icon: Icons.calendar_today_outlined,
            onTap: () => setState(() {
              _selectedDay = day;
              _filterDay = day;
            }),
          );
        },
      ),
    );
  }

  Widget _buildSchedulePanel({
    required String title,
    required List<Map<String, dynamic>> rows,
    required List<String> columns,
    ValueChanged<Map<String, dynamic>>? onRowTap,
  }) {
    final sorted = [...rows]..sort(_slotSort);
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: principalDirectoryText,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = constraints.maxWidth < 650
                  ? 650.0
                  : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      _scheduleHeader(columns),
                      for (final row in sorted)
                        _scheduleRow(row, columns, onTap: onRowTap),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _scheduleHeader(List<String> columns) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: const Color(0xFFF8FBFF),
      child: Row(
        children: [
          for (final column in columns)
            Expanded(
              flex: _scheduleColumnFlex(column),
              child: Text(
                column,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: principalDirectoryMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _scheduleRow(
    Map<String, dynamic> row,
    List<String> columns, {
    ValueChanged<Map<String, dynamic>>? onTap,
  }) {
    final subject = _subjectName(row);
    final isBreak = _isBreak(row);
    final isFree = _isFree(row);
    final values = <String, String>{
      'Time': _slotTime(row),
      'Period': isBreak || isFree
          ? '-'
          : '${_int(row['period_number'] ?? row['period'])}',
      'Subject': subject,
      'Teacher': isBreak || isFree ? '-' : _teacherName(row),
      'Room': isBreak || isFree ? '-' : _roomName(row),
      'Class': isFree
          ? 'Available'
          : _text(row['class_name'], fallback: 'Class'),
    };
    final rowContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isBreak
            ? AppTheme.warningContainer.withAlpha(120)
            : isFree
            ? AppTheme.successContainer.withAlpha(120)
            : Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE7EEF6))),
      ),
      child: Row(
        children: [
          for (final column in columns)
            Expanded(
              flex: _scheduleColumnFlex(column),
              child: Align(
                alignment: Alignment.centerLeft,
                child: column == 'Action'
                    ? _slotActionButton(row, isBreak: isBreak || isFree)
                    : column == 'Subject'
                    ? _subjectBadge(subject, isBreak: isBreak, isFree: isFree)
                    : Text(
                        values[column] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: column == 'Period'
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: principalDirectoryText,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
    if (onTap == null || isBreak || isFree) return rowContent;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: () => onTap(row), child: rowContent),
    );
  }

  int _scheduleColumnFlex(String column) {
    if (column == 'Time') return 2;
    if (column == 'Action') return 1;
    return 1;
  }

  Widget _slotActionButton(Map<String, dynamic> row, {required bool isBreak}) {
    final id = _text(row['id'] ?? row['slot_id']);
    if (isBreak || id.isEmpty) {
      return Text(
        '-',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: principalDirectoryMuted,
        ),
      );
    }
    return Tooltip(
      message: 'Edit period',
      child: IconButton.filledTonal(
        visualDensity: VisualDensity.compact,
        onPressed: () => _openEditPeriodForm(row),
        icon: const Icon(Icons.edit_calendar_outlined, size: 18),
      ),
    );
  }

  Widget _buildWeekGrid(List<Map<String, dynamic>> periods) {
    final maxPeriod = periods
        .map((row) => _int(row['period_number'] ?? row['period']))
        .fold<int>(0, (max, value) => value > max ? value : max)
        .clamp(1, 10)
        .toInt();
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 720,
          child: Column(
            children: [
              Row(
                children: [
                  _weekCell('Time / Period', header: true, flex: 2),
                  for (final day in _days) _weekCell(day, header: true),
                ],
              ),
              for (var period = 1; period <= maxPeriod; period++)
                Row(
                  children: [
                    _weekCell(_periodTimeLabel(periods, period), flex: 2),
                    for (var day = 1; day <= _days.length; day++)
                      _weekCell(
                        _weekSubject(periods, day, period),
                        onTap: _weekCellTap(periods, day, period),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weekCell(
    String label, {
    bool header = false,
    int flex = 1,
    VoidCallback? onTap,
  }) {
    final empty = label.trim().isEmpty;
    final cell = Container(
      height: header ? 40 : 46,
      margin: const EdgeInsets.all(3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: header
            ? const Color(0xFFF8FBFF)
            : empty
            ? Colors.white
            : _subjectTone(label),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2EAF2)),
      ),
      child: Text(
        empty ? '-' : label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: empty ? principalDirectoryMuted : principalDirectoryText,
        ),
      ),
    );
    return Expanded(
      flex: flex,
      child: onTap == null
          ? cell
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onTap,
                child: cell,
              ),
            ),
    );
  }

  Widget _subjectBadge(
    String label, {
    required bool isBreak,
    bool isFree = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isBreak
            ? AppTheme.warningContainer
            : isFree
            ? AppTheme.successContainer
            : _subjectTone(label),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: isBreak
              ? AppTheme.warning
              : isFree
              ? AppTheme.success
              : AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildClassEmptyState(Map<String, dynamic> row) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          OpsEmptyState(
            icon: Icons.calendar_month_outlined,
            title:
                'No timetable generated yet for ${_text(row['class_name'], fallback: 'this class')}',
            message:
                'Generate timetable from Classes Hub > Step 3 (Timetable).',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _goToClassesHub,
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('Go to Classes Hub'),
          ),
        ],
      ),
    );
  }

  Widget _detailEmptyState(String title) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
      child: OpsEmptyState(
        icon: Icons.event_busy_outlined,
        title: title,
        message: 'No matching saved backend periods were found.',
      ),
    );
  }

  Widget _buildOwnershipNotice({bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer.withAlpha(150),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withAlpha(45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Edit generated class periods from the Action column, or use Classes Hub > Step 3 to regenerate the timetable.',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: principalDirectoryText,
                height: 1.35,
              ),
            ),
          ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _goToClassesHub,
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    var mode = _homeMode;
    var academicYearId = _text(_selectedClass?['academic_year_id']);
    var day = _filterDay;
    var classId = _text(_selectedClass?['section_id']);
    var staffId = _text(_selectedTeacher?['staff_id']);
    var roomId = _text(_selectedRoom?['room_id']);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final classRows = academicYearId.isEmpty
                ? _classRows
                : _classRows
                      .where(
                        (row) =>
                            _text(row['academic_year_id']) == academicYearId,
                      )
                      .toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  18 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filter Timetable',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue:
                          _academicYearOptions.any(
                            (item) => item.value == academicYearId,
                          )
                          ? academicYearId
                          : '',
                      decoration: const InputDecoration(
                        labelText: 'Academic Year',
                      ),
                      items: _academicYearOptions,
                      onChanged: (value) => setSheetState(() {
                        academicYearId = value ?? '';
                        if (academicYearId.isNotEmpty &&
                            !_classRows.any(
                              (row) =>
                                  _text(row['section_id']) == classId &&
                                  _text(row['academic_year_id']) ==
                                      academicYearId,
                            )) {
                          classId = '';
                        }
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<_TimetableHomeMode>(
                      initialValue: mode,
                      decoration: const InputDecoration(labelText: 'View'),
                      items: const [
                        DropdownMenuItem(
                          value: _TimetableHomeMode.classes,
                          child: Text('Class Timetable'),
                        ),
                        DropdownMenuItem(
                          value: _TimetableHomeMode.teachers,
                          child: Text('Teacher Timetable'),
                        ),
                        DropdownMenuItem(
                          value: _TimetableHomeMode.rooms,
                          child: Text('Room Timetable'),
                        ),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => mode = value ?? mode),
                    ),
                    const SizedBox(height: 12),
                    _filterDropdown(
                      label: 'Class / Section',
                      allLabel: 'All Classes',
                      value: classId,
                      rows: classRows,
                      idKey: 'section_id',
                      labelKey: 'class_name',
                      onChanged: (value) =>
                          setSheetState(() => classId = value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    _filterDropdown(
                      label: 'Teacher',
                      allLabel: 'All Teachers',
                      value: staffId,
                      rows: _teacherRows,
                      idKey: 'staff_id',
                      labelKey: 'teacher_name',
                      onChanged: (value) =>
                          setSheetState(() => staffId = value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    _filterDropdown(
                      label: 'Room',
                      allLabel: 'All Rooms',
                      value: roomId,
                      rows: _roomRows,
                      idKey: 'room_id',
                      labelKey: 'room_name',
                      onChanged: (value) =>
                          setSheetState(() => roomId = value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: day,
                      decoration: const InputDecoration(labelText: 'Day'),
                      items: [
                        const DropdownMenuItem(
                          value: 0,
                          child: Text('All Days'),
                        ),
                        for (var i = 0; i < _days.length; i++)
                          DropdownMenuItem(
                            value: i + 1,
                            child: Text(_dayLabel(i + 1)),
                          ),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => day = value ?? day),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                mode = _TimetableHomeMode.classes;
                                academicYearId = '';
                                day = 0;
                                classId = '';
                                staffId = '';
                                roomId = '';
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _homeMode = mode;
                                _filterDay = day;
                                if (day > 0) _selectedDay = day;
                                _search = '';
                                _selectedPeriod = null;
                                if (mode == _TimetableHomeMode.classes &&
                                    classId.isNotEmpty) {
                                  _selectedClass = _findRow(
                                    _classRows,
                                    'section_id',
                                    classId,
                                  );
                                  _detailMode = day == 0
                                      ? _TimetableDetailMode.classWeek
                                      : _TimetableDetailMode.classDay;
                                } else if (mode ==
                                        _TimetableHomeMode.teachers &&
                                    staffId.isNotEmpty) {
                                  _selectedTeacher = _findRow(
                                    _teacherRows,
                                    'staff_id',
                                    staffId,
                                  );
                                  _detailMode = _TimetableDetailMode.teacher;
                                } else if (mode == _TimetableHomeMode.rooms &&
                                    roomId.isNotEmpty) {
                                  _selectedRoom = _findRow(
                                    _roomRows,
                                    'room_id',
                                    roomId,
                                  );
                                  _detailMode = _TimetableDetailMode.room;
                                } else {
                                  _detailMode = _TimetableDetailMode.home;
                                }
                              });
                              Navigator.pop(sheetContext);
                            },
                            child: const Text('Apply Filter'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterDropdown({
    required String label,
    required String allLabel,
    required String? value,
    required List<Map<String, dynamic>> rows,
    required String idKey,
    required String labelKey,
    required ValueChanged<String?> onChanged,
  }) {
    final items = [
      DropdownMenuItem<String>(value: '', child: Text(allLabel)),
      ...rows
          .where((row) => _text(row[idKey]).isNotEmpty)
          .map(
            (row) => DropdownMenuItem<String>(
              value: _text(row[idKey]),
              child: Text(_text(row[labelKey], fallback: _text(row[idKey]))),
            ),
          ),
    ];
    return DropdownButtonFormField<String>(
      initialValue: items.any((item) => item.value == value) ? value : '',
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
    );
  }

  void _openClass(Map<String, dynamic> row) {
    setState(() {
      _homeMode = _TimetableHomeMode.classes;
      _selectedClass = row;
      _selectedPeriod = null;
      _detailMode = _TimetableDetailMode.classDay;
    });
  }

  void _openTeacher(Map<String, dynamic> row) {
    setState(() {
      _homeMode = _TimetableHomeMode.teachers;
      _selectedTeacher = row;
      _selectedPeriod = null;
      _detailMode = _TimetableDetailMode.teacher;
    });
  }

  void _openRoom(Map<String, dynamic> row) {
    setState(() {
      _homeMode = _TimetableHomeMode.rooms;
      _selectedRoom = row;
      _selectedPeriod = null;
      _detailMode = _TimetableDetailMode.room;
    });
  }

  void _openDayDetails(Map<String, dynamic> row) {
    setState(() {
      _selectedPeriod = row;
      _selectedDay = _int(row['day_of_week']).clamp(1, 6).toInt();
      _filterDay = _selectedDay;
      _detailMode = _TimetableDetailMode.dayDetails;
    });
  }

  void _openPeriodClassDay(Map<String, dynamic> row) {
    if (_isBreak(row) || _isFree(row)) return;
    final classRow = _findRow(
      _classRows,
      'section_id',
      _text(row['section_id']),
    );
    if (classRow == null) return;
    setState(() {
      _homeMode = _TimetableHomeMode.classes;
      _selectedClass = classRow;
      _selectedPeriod = row;
      _selectedDay = _int(row['day_of_week']).clamp(1, 6).toInt();
      _filterDay = _selectedDay;
      _detailMode = _TimetableDetailMode.dayDetails;
    });
  }

  void _goBack() {
    if (_detailMode == _TimetableDetailMode.classWeek ||
        _detailMode == _TimetableDetailMode.dayDetails) {
      setState(() => _detailMode = _TimetableDetailMode.classDay);
      return;
    }
    if (_detailMode != _TimetableDetailMode.home) {
      setState(() => _detailMode = _TimetableDetailMode.home);
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _goToClassesHub() {
    Navigator.of(context).pushNamed(
      AppRoutes.principalClasses,
      arguments: {
        'class_hub_action': 'timetable',
        'action': 'timetable',
        'selectedStep': 'timetable',
        'section_id': _text(_selectedClass?['section_id']),
        'sectionId': _text(_selectedClass?['section_id']),
        'classId': _text(_selectedClass?['grade_id']),
        'academicYearId': _text(_selectedClass?['academic_year_id']),
        'source': 'principal_timetable',
      },
    );
  }

  Future<void> _openEditPeriodForm(Map<String, dynamic> period) async {
    final id = _text(period['id'] ?? period['slot_id']);
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to edit this timetable period. Slot id missing.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            8,
            18,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: _TimetableSlotInputForm(
              period: period,
              onSubmit: (payload) async {
                await BackendApiClient.instance.updateRaw(
                  '/timetable/slots/$id',
                  payload,
                );
              },
            ),
          ),
        ),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  void _reconcileSelection() {
    if (_requestedSectionId.isNotEmpty) {
      final requested = _findRow(_classRows, 'section_id', _requestedSectionId);
      if (requested != null) {
        _selectedClass = requested;
        _homeMode = _TimetableHomeMode.classes;
        _detailMode = _TimetableDetailMode.classDay;
        _requestedSectionId = '';
      } else if (_selectedClass == null) {
        _detailMode = _TimetableDetailMode.home;
      }
    }
    final classId = _text(_selectedClass?['section_id']);
    if (classId.isNotEmpty) {
      _selectedClass = _findRow(_classRows, 'section_id', classId);
    }
    final staffId = _text(_selectedTeacher?['staff_id']);
    if (staffId.isNotEmpty) {
      _selectedTeacher = _findRow(_teacherRows, 'staff_id', staffId);
    }
    final roomId = _text(_selectedRoom?['room_id']);
    if (roomId.isNotEmpty) {
      _selectedRoom = _findRow(_roomRows, 'room_id', roomId);
    }
  }

  bool _matchesSearch(Map<String, dynamic> row) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return true;
    return row.values.any(
      (value) => _text(value).toLowerCase().contains(query),
    );
  }

  List<Map<String, dynamic>> _periodsForClass(String sectionId, int? day) {
    return _periodRows.where((row) {
      return _text(row['section_id']) == sectionId &&
          (day == null || _int(row['day_of_week']) == day);
    }).toList();
  }

  List<Map<String, dynamic>> _periodsForTeacher(String staffId, int? day) {
    return _periodRows.where((row) {
      return _text(row['staff_id']) == staffId &&
          (day == null || _int(row['day_of_week']) == day);
    }).toList();
  }

  List<Map<String, dynamic>> _periodsForRoom(String roomId, int? day) {
    return _periodRows.where((row) {
      return _text(row['room_id']) == roomId &&
          (day == null || _int(row['day_of_week']) == day);
    }).toList();
  }

  List<Map<String, dynamic>> _availabilityRows(
    List<Map<String, dynamic>> occupied,
    int day, {
    required String freeLabel,
  }) {
    final maxPeriod = _maxPeriodForDay(day);
    if (maxPeriod <= 0) return occupied;
    final references = <int, Map<String, dynamic>>{};
    for (final row in _periodRows) {
      if (_int(row['day_of_week']) != day) continue;
      final period = _int(row['period_number'] ?? row['period']);
      if (period > 0) references.putIfAbsent(period, () => row);
    }
    final occupiedByPeriod = <int, List<Map<String, dynamic>>>{};
    for (final row in occupied) {
      final period = _int(row['period_number'] ?? row['period']);
      if (period <= 0) continue;
      occupiedByPeriod.putIfAbsent(period, () => []).add(row);
    }
    final rows = <Map<String, dynamic>>[];
    for (var period = 1; period <= maxPeriod; period++) {
      final matches = occupiedByPeriod[period] ?? const [];
      if (matches.isNotEmpty) {
        rows.addAll(matches);
        continue;
      }
      final reference = references[period];
      if (reference != null && _isBreak(reference)) {
        rows.add({
          ...reference,
          'id': '',
          'slot_id': '',
          'class_name': _subjectName(reference),
        });
        continue;
      }
      rows.add({
        'day_of_week': day,
        'period_number': period,
        'period': period,
        'start_time': _text(reference?['start_time']),
        'end_time': _text(reference?['end_time']),
        'subject': freeLabel,
        'subject_name': freeLabel,
        'slot_type': 'free',
        'class_name': freeLabel,
      });
    }
    return rows;
  }

  List<Map<String, dynamic>> get _periodRows {
    final rows = _list(_views['periods']);
    rows.sort(_slotSort);
    return rows;
  }

  List<Map<String, dynamic>> get _classRows => _list(_views['class_wise']);

  List<Map<String, dynamic>> get _teacherRows => _list(_views['teacher_wise']);

  List<Map<String, dynamic>> get _roomRows => _list(_views['room_wise']);

  Map<String, dynamic> get _views => _map(_data['views']);

  List<DropdownMenuItem<String>> get _academicYearOptions {
    final seen = <String>{};
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('Current academic year')),
    ];
    for (final row in [..._classRows, ..._periodRows]) {
      final id = _text(row['academic_year_id']);
      if (id.isEmpty || !seen.add(id)) continue;
      items.add(
        DropdownMenuItem<String>(
          value: id,
          child: Text(_text(row['academic_year'], fallback: id)),
        ),
      );
    }
    return items;
  }

  static Map<String, dynamic>? _findRow(
    List<Map<String, dynamic>> rows,
    String key,
    String value,
  ) {
    for (final row in rows) {
      if (_text(row[key]) == value) return row;
    }
    return null;
  }

  static int _slotSort(Map<String, dynamic> a, Map<String, dynamic> b) {
    final day = _int(a['day_of_week']).compareTo(_int(b['day_of_week']));
    if (day != 0) return day;
    return _int(
      a['period_number'] ?? a['period'],
    ).compareTo(_int(b['period_number'] ?? b['period']));
  }

  String _subjectName(Map<String, dynamic> row) {
    final breakLabel = _breakLabelFromSlotType(row);
    if (breakLabel.isNotEmpty) return breakLabel;
    return _text(row['subject_name'] ?? row['subject'], fallback: 'Subject');
  }

  String _teacherName(Map<String, dynamic> row) =>
      _text(row['teacher_name'] ?? row['teacher'], fallback: 'Teacher pending');

  String _roomName(Map<String, dynamic> row) =>
      _text(row['room'], fallback: _text(row['room_id'], fallback: '-'));

  String _teacherDepartment(Map<String, dynamic> row) {
    final department = _text(row['department_name'] ?? row['department']);
    final designation = _text(row['designation']);
    if (department.isEmpty && designation.isEmpty) {
      return 'Department not assigned';
    }
    if (department.isNotEmpty && designation.isNotEmpty) {
      return '$department - $designation';
    }
    return department.isNotEmpty ? department : designation;
  }

  String _roomCapacityLabel(Map<String, dynamic> row) {
    final capacity = _int(row['capacity'] ?? row['room_capacity']);
    final type = _text(row['room_type']);
    if (capacity <= 0) {
      return type.isEmpty ? 'Capacity not set' : type;
    }
    return type.isEmpty ? 'Capacity: $capacity' : '$type - Capacity: $capacity';
  }

  Widget _metadataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: principalDirectoryMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: principalDirectoryMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: principalDirectoryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _slotTime(Map<String, dynamic> row) {
    final start = _text(row['start_time']);
    final end = _text(row['end_time']);
    if (start.isEmpty && end.isEmpty) return 'Time pending';
    if (end.isEmpty) return start;
    return '$start - $end';
  }

  String _dayLabel(int day) {
    const full = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return full[(day - 1).clamp(0, full.length - 1)];
  }

  String _periodTimeLabel(List<Map<String, dynamic>> rows, int period) {
    for (final row in rows) {
      if (_int(row['period_number'] ?? row['period']) == period) {
        final time = _slotTime(row);
        return time == 'Time pending' ? 'Period $period' : time;
      }
    }
    return 'Period $period';
  }

  String _dayTimeRange(List<Map<String, dynamic>> rows) {
    final sorted =
        rows.where((row) => _slotTime(row) != 'Time pending').toList()
          ..sort(_slotSort);
    if (sorted.isEmpty) return 'Time pending';
    final start = _text(sorted.first['start_time']);
    final end = _text(sorted.last['end_time']);
    if (start.isEmpty && end.isEmpty) return 'Time pending';
    if (end.isEmpty) return start;
    return '$start - $end';
  }

  String _dayDurationLabel(List<Map<String, dynamic>> rows) {
    final sorted =
        rows.where((row) => _slotTime(row) != 'Time pending').toList()
          ..sort(_slotSort);
    if (sorted.isEmpty) return 'Duration pending';
    final start = _clockMinutes(_text(sorted.first['start_time']));
    final end = _clockMinutes(_text(sorted.last['end_time']));
    if (start == null || end == null || end <= start) return 'Duration pending';
    return _durationLabel(end - start);
  }

  String _breaksLabel(List<Map<String, dynamic>> rows) {
    final breakRows = rows.where(_isBreak).toList();
    final minutes = breakRows.fold<int>(0, (total, row) {
      final start = _clockMinutes(_text(row['start_time']));
      final end = _clockMinutes(_text(row['end_time']));
      if (start == null || end == null || end <= start) return total;
      return total + end - start;
    });
    if (minutes <= 0) return '${breakRows.length}';
    return '${breakRows.length} ($minutes Min)';
  }

  String _weekSubject(List<Map<String, dynamic>> rows, int day, int period) {
    for (final row in rows) {
      if (_int(row['day_of_week']) == day &&
          _int(row['period_number'] ?? row['period']) == period) {
        return _subjectAbbreviation(_subjectName(row));
      }
    }
    return '';
  }

  VoidCallback? _weekCellTap(
    List<Map<String, dynamic>> rows,
    int day,
    int period,
  ) {
    if (_detailMode != _TimetableDetailMode.classWeek) return null;
    for (final row in rows) {
      if (_int(row['day_of_week']) == day &&
          _int(row['period_number'] ?? row['period']) == period &&
          !_isBreak(row)) {
        return () => _openDayDetails(row);
      }
    }
    return null;
  }

  String _subjectAbbreviation(String subject) {
    final upper = subject.trim().toUpperCase();
    if (upper.isEmpty) return '';
    if (upper.contains('MATHEMAT')) return 'MATH';
    if (upper.contains('ENGLISH')) return 'EN';
    if (upper.contains('SCIENCE')) return 'SCI';
    if (upper.contains('PHYSICAL')) return 'PE';
    if (upper.contains('SOCIAL')) return 'ST';
    if (upper.contains('COMPUTER')) return 'CS';
    if (upper.contains('LUNCH')) return 'Lunch';
    if (upper.contains('BREAK')) return 'Break';
    return upper.length <= 5 ? upper : upper.substring(0, 5);
  }

  bool _isBreak(Map<String, dynamic> row) {
    final slotType = _text(row['slot_type']).toLowerCase();
    final subject = _subjectName(row).toLowerCase();
    return slotType.contains('break') ||
        subject.contains('break') ||
        subject.contains('lunch');
  }

  bool _isFree(Map<String, dynamic> row) {
    final slotType = _text(row['slot_type']).toLowerCase();
    final subject = _subjectName(row).toLowerCase();
    return slotType.contains('free') || subject.contains('free');
  }

  int _maxPeriodForDay(int day) {
    var maxPeriod = 0;
    for (final row in _periodRows) {
      if (_int(row['day_of_week']) != day) continue;
      final period = _int(row['period_number'] ?? row['period']);
      if (period > maxPeriod) maxPeriod = period;
    }
    return maxPeriod;
  }

  int _maxPeriodForWeek() {
    var maxPeriod = 0;
    for (final row in _periodRows) {
      final period = _int(row['period_number'] ?? row['period']);
      if (period > maxPeriod) maxPeriod = period;
    }
    return maxPeriod;
  }

  int _freePeriodsFor(String id, String key) {
    if (id.isEmpty) return 0;
    final idKey = key == 'room' ? 'room_id' : 'staff_id';
    final days = _periodRows
        .map((row) => _int(row['day_of_week']))
        .where((day) => day >= 1 && day <= 6)
        .toSet();
    final possible = days.length * _maxPeriodForWeek();
    if (possible <= 0) return 0;
    final occupied = _periodRows
        .where((row) => _text(row[idKey]) == id && !_isBreak(row))
        .length;
    return (possible - occupied).clamp(0, possible).toInt();
  }

  int? _clockMinutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  String _durationLabel(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours <= 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  Future<void> _openTeacherWeekPreview() async {
    final teacher = _selectedTeacher;
    if (teacher == null) return;
    final periods = _periodsForTeacher(_text(teacher['staff_id']), null);
    if (periods.isEmpty) {
      _showSnack('No weekly schedule found for this teacher.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Full Week Schedule',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.62,
                child: _buildWeekGrid(periods),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLegendSheet() async {
    final classRow = _selectedClass;
    if (classRow == null) return;
    final periods = _periodsForClass(_text(classRow['section_id']), null);
    final subjects = <String, String>{};
    for (final row in periods) {
      final subject = _subjectName(row);
      subjects.putIfAbsent(_subjectAbbreviation(subject), () => subject);
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Legend',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (subjects.isEmpty)
                const Text('No subject codes available.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in subjects.entries)
                      PrincipalInfoPill(
                        icon: Icons.sell_outlined,
                        label: '${entry.key} = ${entry.value}',
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportWeekPdf() async {
    final classRow = _selectedClass;
    if (classRow == null) return;
    final periods = _periodsForClass(_text(classRow['section_id']), null);
    if (periods.isEmpty) {
      _showSnack('No timetable data available to export.');
      return;
    }
    final bytes = await _weekPdfBytes(classRow, periods);
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          '${_safeFileSegment(_text(classRow['class_name'], fallback: 'class'))}-timetable.pdf',
    );
  }

  Future<void> _shareDaySummary() async {
    final classRow = _selectedClass;
    if (classRow == null) return;
    final periods = _periodsForClass(
      _text(classRow['section_id']),
      _selectedDay,
    );
    if (periods.isEmpty) {
      _showSnack('No day schedule available to share.');
      return;
    }
    final bytes = await _dayPdfBytes(classRow, periods);
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          '${_safeFileSegment(_text(classRow['class_name'], fallback: 'class'))}-${_dayLabel(_selectedDay).toLowerCase()}-schedule.pdf',
    );
  }

  Future<Uint8List> _weekPdfBytes(
    Map<String, dynamic> classRow,
    List<Map<String, dynamic>> periods,
  ) async {
    final pdf = pw.Document();
    final maxPeriod = periods
        .map((row) => _int(row['period_number'] ?? row['period']))
        .fold<int>(0, (max, value) => value > max ? value : max)
        .clamp(1, 10)
        .toInt();
    pdf.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text(
            'Full Week Timetable',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(_text(classRow['class_name'], fallback: 'Class')),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Time / Period', ..._days],
            data: [
              for (var period = 1; period <= maxPeriod; period++)
                [
                  _periodTimeLabel(periods, period),
                  for (var day = 1; day <= _days.length; day++)
                    _weekSubject(periods, day, period).isEmpty
                        ? '-'
                        : _weekSubject(periods, day, period),
                ],
            ],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  Future<Uint8List> _dayPdfBytes(
    Map<String, dynamic> classRow,
    List<Map<String, dynamic>> periods,
  ) async {
    final sorted = [...periods]..sort(_slotSort);
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text(
            '${_dayLabel(_selectedDay)} Schedule',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(_text(classRow['class_name'], fallback: 'Class')),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Period', 'Time', 'Subject', 'Teacher', 'Room'],
            data: [
              for (final row in sorted)
                [
                  _isBreak(row)
                      ? '-'
                      : '${_int(row['period_number'] ?? row['period'])}',
                  _slotTime(row),
                  _subjectName(row),
                  _isBreak(row) ? '-' : _teacherName(row),
                  _isBreak(row) ? '-' : _roomName(row),
                ],
            ],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  String _safeFileSegment(String value) {
    final cleaned = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty ? 'timetable' : cleaned;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _breakLabelFromSlotType(Map<String, dynamic> row) {
    final slotType = _text(row['slot_type']);
    if (!slotType.toLowerCase().startsWith('break')) return '';
    final parts = slotType.split(':');
    if (parts.length < 2) return 'Break';
    return parts.sublist(1).join(':').trim().isEmpty
        ? 'Break'
        : parts.sublist(1).join(':').trim();
  }

  bool _bool(Object? value) {
    if (value is bool) return value;
    return '${value ?? ''}'.toLowerCase() == 'true';
  }

  Color _subjectTone(String label) {
    final key = label.toUpperCase();
    if (key.contains('MATH')) return const Color(0xFFE0F7EA);
    if (key.contains('EN')) return AppTheme.primaryContainer;
    if (key.contains('SCI')) return const Color(0xFFE5FAFF);
    if (key.contains('HIN')) return const Color(0xFFF0E7FF);
    if (key.contains('ART')) return const Color(0xFFFFE7F0);
    if (key.contains('PE')) return const Color(0xFFE0FBF4);
    if (key.contains('BREAK') || key.contains('LUNCH')) {
      return AppTheme.warningContainer;
    }
    return const Color(0xFFF2F6FA);
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFDDE7F0)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF8AB2C8).withAlpha(34),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

class PrincipalExamsScreen extends StatelessWidget {
  const PrincipalExamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrincipalExamReviewScreen.examsHome();
  }
}

class PrincipalResultsScreen extends StatelessWidget {
  const PrincipalResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrincipalExamReviewScreen.results();
  }
}

class _PrincipalCommandScreen extends StatefulWidget {
  final _PrincipalCommandKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Future<bool> Function(BuildContext context)? onAddCreate;
  final Future<bool> Function(BuildContext context, Map<String, dynamic> row)?
  onEditEntry;
  final IconData addIcon;
  final String addTooltip;
  final Future<Map<String, dynamic>> Function() loadData;
  final List<Widget> Function(
    BuildContext context,
    Future<void> Function() refresh,
  )?
  quickActions;
  final Future<Map<String, dynamic>> Function({
    required String actionType,
    required String message,
    String title,
    String priority,
    String entityId,
    String dueDate,
  })
  saveAction;
  final List<_Metric> Function(Map<String, dynamic> data) metrics;
  final List<Widget> Function(
    Map<String, dynamic> data,
    void Function(_ActionSpec action) openAction,
  )
  content;

  const _PrincipalCommandScreen({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.onAddCreate,
    this.onEditEntry,
    this.addIcon = Icons.add_task_rounded,
    this.addTooltip = 'Create action',
    required this.loadData,
    this.quickActions,
    required this.saveAction,
    required this.metrics,
    required this.content,
  });

  @override
  State<_PrincipalCommandScreen> createState() =>
      _PrincipalCommandScreenState();
}

class _PrincipalCommandScreenState extends State<_PrincipalCommandScreen> {
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _search = '';
  String _selectedSection = 'All';
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.loadData();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load ${widget.title} from backend. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    final entries = _filteredEntries;
    final quickActions = widget.quickActions?.call(context, _load) ?? const [];
    return PrincipalDirectoryScaffold(
      title: _directoryTitle,
      subtitle: widget.subtitle,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      onAdd: _handleAdd,
      addIcon: widget.addIcon,
      addTooltip: widget.addTooltip,
      controller: _scrollController,
      filters: _buildFilters(),
      isEmpty: !_loading && _error == null && entries.isEmpty,
      emptyState: OpsEmptyState(
        icon: widget.icon,
        title: _emptyTitle,
        message: _emptyMessage,
      ),
      slivers: [
        if (_isTimetable || _isExams)
          SliverToBoxAdapter(
            child: _isTimetable
                ? const _TimetableWorkflowStrip()
                : const _ExamWorkflowStrip(),
          ),
        SliverToBoxAdapter(
          child: PrincipalDirectoryMetricStrip(
            metrics: [
              for (final metric in widget.metrics(_data))
                PrincipalDirectoryMetric(
                  label: metric.label,
                  value: metric.value,
                  icon: metric.icon,
                  color: metric.color,
                  tone: metric.color.withAlpha(22),
                ),
            ],
          ),
        ),
        if (quickActions.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: quickActions,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 96),
          sliver: SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: PrincipalDirectoryCard(
                  icon: entry.icon,
                  title: entry.title,
                  subtitle: entry.subtitle,
                  status: entry.status,
                  statusColor: _statusColor(entry.status),
                  chips: [
                    PrincipalInfoPill(
                      icon: Icons.folder_open_rounded,
                      label: entry.section,
                    ),
                    if (entry.date.isNotEmpty)
                      PrincipalInfoPill(
                        icon: Icons.calendar_today_outlined,
                        label: entry.date,
                      ),
                    if (entry.value.isNotEmpty)
                      PrincipalInfoPill(
                        icon: Icons.insights_outlined,
                        label: entry.value,
                      ),
                  ],
                  trailing: _entryMenu(entry),
                  onTap: () => _openEntryDetail(entry),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleAdd() async {
    final creator = widget.onAddCreate;
    if (creator != null) {
      final changed = await creator(context);
      if (changed) await _load();
      return;
    }
    await _openAction(
      _ActionSpec(
        actionType: _defaultActionType,
        title: widget.title,
        priority: 'normal',
        entityId: '',
        dueDate: '',
      ),
    );
  }

  String get _directoryTitle {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable => 'Timetable Review',
      _PrincipalCommandKind.exams => 'Exam Workflow',
      _PrincipalCommandKind.results => 'Results Directory',
    };
  }

  bool get _isTimetable => widget.kind == _PrincipalCommandKind.timetable;

  bool get _isExams => widget.kind == _PrincipalCommandKind.exams;

  bool get _allowsFollowUpActions => !_isTimetable;

  String get _emptyTitle {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable => 'No timetable periods yet',
      _PrincipalCommandKind.exams => 'No exams scheduled yet',
      _PrincipalCommandKind.results => 'No results rows',
    };
  }

  String get _emptyMessage {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable =>
        'Admin-created timetable periods will appear here for principal review.',
      _PrincipalCommandKind.exams =>
        'Create an exam schedule from the workflow, then monitor and evaluate it here.',
      _PrincipalCommandKind.results =>
        'Adjust search or wait for backend results data to arrive.',
    };
  }

  String get _searchHint {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable =>
        'Search class, subject, teacher, day...',
      _PrincipalCommandKind.exams => 'Search exam, class, subject, status...',
      _PrincipalCommandKind.results => 'Search results directory...',
    };
  }

  String get _defaultActionType {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable => 'schedule_review',
      _PrincipalCommandKind.exams => 'exam_readiness',
      _PrincipalCommandKind.results => 'improvement_plan',
    };
  }

  Widget _buildFilters() {
    final sections = ['All', ..._entries.map((entry) => entry.section).toSet()];
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
      child: Column(
        children: [
          PrincipalDirectorySearchBox(
            hint: _searchHint,
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                for (final section in sections)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PrincipalDirectoryChip(
                      label: section,
                      selected: _selectedSection == section,
                      icon: section == 'All'
                          ? Icons.all_inclusive_rounded
                          : Icons.folder_open_rounded,
                      onTap: () => setState(() => _selectedSection = section),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_CommandDirectoryEntry> get _filteredEntries {
    final query = _search.trim().toLowerCase();
    return _entries.where((entry) {
      final matchesSection =
          _selectedSection == 'All' || entry.section == _selectedSection;
      final matchesSearch =
          query.isEmpty || entry.searchText.contains(query.toLowerCase());
      return matchesSection && matchesSearch;
    }).toList();
  }

  List<_CommandDirectoryEntry> get _entries {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable => _timetableEntries(),
      _PrincipalCommandKind.exams => _examEntries(),
      _PrincipalCommandKind.results => _resultEntries(),
    };
  }

  List<_CommandDirectoryEntry> _timetableEntries() {
    final views = _map(_data['views']);
    return [
      ..._rowsToEntries(
        section: 'Periods',
        rows: _list(views['periods']),
        icon: Icons.schedule_outlined,
      ),
    ];
  }

  List<_CommandDirectoryEntry> _examEntries() {
    return [
      ..._rowsToEntries(
        section: 'Scheduled Exams',
        rows: _list(_data['exam_dashboard']),
        icon: Icons.assignment_outlined,
      ),
    ];
  }

  List<_CommandDirectoryEntry> _resultEntries() {
    final dashboard = _map(_data['result_dashboard']);
    final toppers = _map(_data['toppers']);
    final reports = _map(_data['reports']);
    return [
      ..._rowsToEntries(
        section: 'Performance',
        rows: _list(dashboard['class_performance']),
        icon: Icons.analytics_outlined,
      ),
      ..._rowsToEntries(
        section: 'Toppers',
        rows: _list(toppers['school_toppers']),
        icon: Icons.emoji_events_outlined,
      ),
      ..._rowsToEntries(
        section: 'Weak Students',
        rows: _list(_data['weak_students']),
        icon: Icons.warning_amber_rounded,
      ),
      ..._rowsToEntries(
        section: 'Exports',
        rows: _list(reports['export_options']),
        icon: Icons.file_download_outlined,
      ),
      ..._rowsToEntries(
        section: 'Actions',
        rows: _list(_data['actions']),
        icon: Icons.task_alt_outlined,
      ),
    ];
  }

  List<_CommandDirectoryEntry> _rowsToEntries({
    required String section,
    required List<Map<String, dynamic>> rows,
    required IconData icon,
  }) {
    return [
      for (final row in rows)
        _CommandDirectoryEntry(
          section: section,
          row: row,
          icon: icon,
          title: _rowTitle(row),
          subtitle: _rowSubtitle(row),
          status: _text(
            row['status'] ?? row['priority'] ?? row['state'],
            fallback: 'Live',
          ),
          date: _text(row['date'] ?? row['exam_date'] ?? row['start_date']),
          value: _text(
            row['value'] ??
                row['count'] ??
                row['percentage'] ??
                row['schedule_count'],
          ),
        ),
    ];
  }

  Widget _entryMenu(_CommandDirectoryEntry entry) {
    return PopupMenuButton<String>(
      tooltip: '${entry.title} options',
      onSelected: (value) async {
        switch (value) {
          case 'open':
            await _openEntryDetail(entry);
            break;
          case 'action':
            await _openAction(
              _ActionSpec(
                actionType: _defaultActionType,
                title: entry.title,
                priority: 'normal',
                entityId: _entityIdFor(entry),
                dueDate: '',
              ),
            );
            break;
          case 'edit':
            await _editEntry(entry);
            break;
          case 'delete':
            await _deleteEntry(entry);
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'open', child: Text('View details')),
        if (_allowsFollowUpActions)
          const PopupMenuItem(value: 'action', child: Text('Create follow-up')),
        if (_canEditEntry(entry))
          PopupMenuItem(value: 'edit', child: Text(_editMenuLabel)),
        if (_canDeleteEntry(entry))
          PopupMenuItem(value: 'delete', child: Text(_deleteMenuLabel)),
      ],
    );
  }

  Future<void> _openEntryDetail(_CommandDirectoryEntry entry) async {
    final scheduleRows = _examScheduleRows(entry);
    final fields = entry.row.entries
        .where((item) {
          final value = item.value;
          return item.key != 'schedule_details' &&
              value is! Iterable &&
              value is! Map &&
              _text(value).isNotEmpty;
        })
        .take(12)
        .toList();
    final canEdit = _canEditEntry(entry);
    final canDelete = _canDeleteEntry(entry);
    final hasActions = _allowsFollowUpActions || canEdit || canDelete;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (detailContext) => PrincipalDetailPage(
          title: entry.title,
          menuItems: [
            if (_allowsFollowUpActions)
              const PopupMenuItem(
                value: 'action',
                child: Text('Create follow-up'),
              ),
            if (canEdit)
              PopupMenuItem(value: 'edit', child: Text(_editMenuLabel)),
            if (canDelete)
              PopupMenuItem(value: 'delete', child: Text(_deleteMenuLabel)),
          ],
          onMenuSelected: (value) async {
            if (value == 'action') {
              Navigator.pop(detailContext);
              await _openAction(
                _ActionSpec(
                  actionType: _defaultActionType,
                  title: entry.title,
                  priority: 'normal',
                  entityId: _entityIdFor(entry),
                  dueDate: '',
                ),
              );
            } else if (value == 'edit') {
              Navigator.pop(detailContext);
              await _editEntry(entry);
            } else if (value == 'delete') {
              Navigator.pop(detailContext);
              await _deleteEntry(entry);
            }
          },
          children: [
            PrincipalDetailCard(
              title: entry.section,
              trailing: PrincipalStatusPill(
                label: entry.status,
                color: _statusColor(entry.status),
              ),
              children: [
                PrincipalDetailRow(label: 'Summary', value: entry.subtitle),
                if (entry.date.isNotEmpty)
                  PrincipalDetailRow(label: 'Date', value: entry.date),
                if (entry.value.isNotEmpty)
                  PrincipalDetailRow(label: 'Value', value: entry.value),
                for (final field in fields)
                  PrincipalDetailRow(
                    label: _labelize(field.key),
                    value: _text(field.value),
                  ),
              ],
            ),
            if (scheduleRows.isNotEmpty) _examScheduleDetailsCard(scheduleRows),
            if (hasActions)
              PrincipalDetailCard(
                title: 'Actions',
                children: [
                  if (_allowsFollowUpActions)
                    PrincipalActionTile(
                      icon: Icons.add_task_rounded,
                      title: 'Create follow-up',
                      subtitle: 'Save a principal action against this row',
                      onTap: () {
                        Navigator.pop(detailContext);
                        _openAction(
                          _ActionSpec(
                            actionType: _defaultActionType,
                            title: entry.title,
                            priority: 'normal',
                            entityId: _entityIdFor(entry),
                            dueDate: '',
                          ),
                        );
                      },
                    ),
                  if (canEdit)
                    PrincipalActionTile(
                      icon: Icons.edit_calendar_outlined,
                      title: _editMenuLabel,
                      subtitle:
                          'Change the class, teacher, subject, day, or time.',
                      onTap: () {
                        Navigator.pop(detailContext);
                        _editEntry(entry);
                      },
                    ),
                  if (canDelete)
                    PrincipalActionTile(
                      icon: Icons.delete_outline_rounded,
                      title: _deleteMenuLabel,
                      subtitle: _deleteDetailHelp,
                      color: AppTheme.error,
                      onTap: () {
                        Navigator.pop(detailContext);
                        _deleteEntry(entry);
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _examScheduleRows(_CommandDirectoryEntry entry) {
    if (!_isExams || entry.section != 'Scheduled Exams') {
      return const [];
    }
    return _list(entry.row['schedule_details']);
  }

  Widget _examScheduleDetailsCard(List<Map<String, dynamic>> schedules) {
    final children = <Widget>[];
    for (var index = 0; index < schedules.length; index += 1) {
      final schedule = schedules[index];
      if (index > 0) {
        children.add(const Divider(height: 24));
      }
      children.add(
        Text(
          _text(schedule['class_name'], fallback: 'Class'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: principalDirectoryText,
          ),
        ),
      );
      children.add(const SizedBox(height: 8));
      children.add(
        PrincipalDetailRow(
          label: 'Subject',
          value: _text(schedule['subject'], fallback: 'Subject'),
        ),
      );
      children.add(
        PrincipalDetailRow(
          label: 'Syllabus',
          value: _text(schedule['syllabus'], fallback: 'Not added'),
        ),
      );
      children.add(
        PrincipalDetailRow(
          label: 'Date & time',
          value:
              '${_text(schedule['exam_date'], fallback: 'Date not set')} | ${_text(schedule['time'], fallback: 'Time not set')}',
        ),
      );
      children.add(
        PrincipalDetailRow(
          label: 'Marks',
          value:
              'Max ${_int(schedule['max_marks'])} | Pass ${_int(schedule['pass_marks'])}',
        ),
      );
      final room = _text(schedule['room']);
      if (room.isNotEmpty && room != 'Not assigned') {
        children.add(PrincipalDetailRow(label: 'Room', value: room));
      }
    }
    return PrincipalDetailCard(title: 'Scheduled Papers', children: children);
  }

  bool _canDeleteEntry(_CommandDirectoryEntry entry) {
    if (_isTimetable) return false;
    return _deletePathFor(entry).isNotEmpty;
  }

  bool _canEditEntry(_CommandDirectoryEntry entry) {
    if (_isTimetable) return false;
    return widget.onEditEntry != null && _deletePathFor(entry).isNotEmpty;
  }

  String _deletePathFor(_CommandDirectoryEntry entry) {
    switch (widget.kind) {
      case _PrincipalCommandKind.timetable:
        return '';
      case _PrincipalCommandKind.exams:
        final id = _text(entry.row['exam_id'] ?? entry.row['id']);
        if (id.isEmpty) return '';
        final hasExamShape =
            entry.row.containsKey('exam_name') ||
            entry.row.containsKey('exam_type') ||
            entry.row.containsKey('start_date');
        if (!hasExamShape) return '';
        return '/exams/$id';
      case _PrincipalCommandKind.results:
        return '';
    }
  }

  String _entityIdFor(_CommandDirectoryEntry entry) {
    return _text(
      entry.row['id'] ??
          entry.row['slot_id'] ??
          entry.row['timetable_slot_id'] ??
          entry.row['exam_id'] ??
          entry.row['schedule_id'],
    );
  }

  String get _deleteMenuLabel {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable => 'Timetable review',
      _PrincipalCommandKind.exams => 'Delete exam',
      _PrincipalCommandKind.results => 'Delete',
    };
  }

  String get _editMenuLabel {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable => 'View timetable slot',
      _PrincipalCommandKind.exams => 'Edit exam',
      _PrincipalCommandKind.results => 'Edit',
    };
  }

  String get _deleteDetailHelp {
    return switch (widget.kind) {
      _PrincipalCommandKind.timetable =>
        'Timetable changes are handled from the Admin timetable module.',
      _PrincipalCommandKind.exams =>
        'Backend blocks deletion when schedules, marks, or report cards exist.',
      _PrincipalCommandKind.results =>
        'Deletion is not available for aggregated result rows.',
    };
  }

  Future<void> _deleteEntry(_CommandDirectoryEntry entry) async {
    final path = _deletePathFor(entry);
    if (path.isEmpty) {
      _showSnack(
        'This row is an aggregate view and cannot be deleted directly.',
      );
      return;
    }
    final confirmed = await _confirmDelete(
      title: _deleteMenuLabel,
      message: 'Delete ${entry.title}? $_deleteDetailHelp',
    );
    if (!confirmed) return;
    try {
      await BackendApiClient.instance.deleteRaw(path);
      await _load();
      _showSnack('${entry.title} deleted', success: true);
    } catch (error) {
      _showSnack('Unable to delete ${entry.title}: $error');
    }
  }

  Future<void> _editEntry(_CommandDirectoryEntry entry) async {
    final editor = widget.onEditEntry;
    if (editor == null) return;
    final changed = await editor(context, entry.row);
    if (changed) {
      await _load();
      _showSnack('${entry.title} updated', success: true);
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
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
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
      ),
    );
  }

  Future<void> _openAction(_ActionSpec action) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrincipalInputPage(
          title: 'Create Action',
          icon: Icons.add_task_rounded,
          child: _CommandActionForm(
            saving: _saving,
            onSubmit: (message) async {
              setState(() => _saving = true);
              try {
                await widget.saveAction(
                  actionType: action.actionType,
                  title: action.title,
                  message: message,
                  priority: action.priority,
                  entityId: action.entityId,
                  dueDate: action.dueDate,
                );
                return true;
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Unable to save action: $error'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
                return false;
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
          ),
        ),
      ),
    );
    if (result == true) await _load();
  }

  String _labelize(String key) {
    final label = key.replaceAll('_', ' ').trim();
    if (label.isEmpty) return 'Field';
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }
}

class _CommandDirectoryEntry {
  final String section;
  final Map<String, dynamic> row;
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final String date;
  final String value;

  const _CommandDirectoryEntry({
    required this.section,
    required this.row,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.date,
    required this.value,
  });

  String get searchText => [
    section,
    title,
    subtitle,
    status,
    date,
    value,
    row.values.map(_text).join(' '),
  ].join(' ').toLowerCase();
}

class _CommandActionForm extends StatefulWidget {
  final bool saving;
  final Future<bool> Function(String message) onSubmit;

  const _CommandActionForm({required this.saving, required this.onSubmit});

  @override
  State<_CommandActionForm> createState() => _CommandActionFormState();
}

class _CommandActionFormState extends State<_CommandActionForm> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          minLines: 5,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Action note',
            prefixIcon: Icon(Icons.rate_review_outlined),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(_saving ? 'Saving...' : 'Save action'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    setState(() => _saving = true);
    final ok = await widget.onSubmit(message);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }
}

class _TimetableWorkflowStrip extends StatelessWidget {
  const _TimetableWorkflowStrip();

  @override
  Widget build(BuildContext context) {
    return const _PrincipalWorkflowStrip(
      steps: [
        _WorkflowStep(
          icon: Icons.meeting_room_outlined,
          label: 'Pick class',
          helper: 'Choose section',
        ),
        _WorkflowStep(
          icon: Icons.calendar_today_outlined,
          label: 'Pick day',
          helper: 'Set weekday',
        ),
        _WorkflowStep(
          icon: Icons.menu_book_outlined,
          label: 'Assign subject',
          helper: 'Map teacher',
        ),
        _WorkflowStep(
          icon: Icons.schedule_outlined,
          label: 'Set time',
          helper: 'Save period',
        ),
      ],
    );
  }
}

class _ExamWorkflowStrip extends StatelessWidget {
  const _ExamWorkflowStrip();

  @override
  Widget build(BuildContext context) {
    return const _PrincipalWorkflowStrip(
      steps: [
        _WorkflowStep(
          icon: Icons.fact_check_outlined,
          label: 'Readiness',
          helper: 'Types and classes',
        ),
        _WorkflowStep(
          icon: Icons.event_available_outlined,
          label: 'Schedule',
          helper: 'Dates and subjects',
        ),
        _WorkflowStep(
          icon: Icons.monitor_heart_outlined,
          label: 'Monitor',
          helper: 'Live progress',
        ),
        _WorkflowStep(
          icon: Icons.edit_note_outlined,
          label: 'Evaluate',
          helper: 'Marks pending',
        ),
        _WorkflowStep(
          icon: Icons.publish_outlined,
          label: 'Publish',
          helper: 'Principal decision',
        ),
      ],
    );
  }
}

class _PrincipalWorkflowStrip extends StatelessWidget {
  final List<_WorkflowStep> steps;

  const _PrincipalWorkflowStrip({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDEAF2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7FA6BD).withAlpha(28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 430;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < steps.length; index++)
                  SizedBox(
                    width: compact
                        ? (constraints.maxWidth - 8) / 2
                        : (constraints.maxWidth - (8 * (steps.length - 1))) /
                              steps.length,
                    child: _WorkflowStepTile(
                      number: index + 1,
                      step: steps[index],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WorkflowStep {
  final IconData icon;
  final String label;
  final String helper;

  const _WorkflowStep({
    required this.icon,
    required this.label,
    required this.helper,
  });
}

class _WorkflowStepTile extends StatelessWidget {
  final int number;
  final _WorkflowStep step;

  const _WorkflowStepTile({required this.number, required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1EDF5)),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: principalDirectoryAccent.withAlpha(18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  step.icon,
                  color: principalDirectoryAccent,
                  size: 18,
                ),
              ),
              Positioned(
                right: -4,
                top: -5,
                child: Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: principalDirectoryAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: principalDirectoryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.helper,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: principalDirectoryMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
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

class _ExamInputForm extends StatefulWidget {
  final Map<String, dynamic>? exam;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  const _ExamInputForm({this.exam, required this.onSubmit});

  @override
  State<_ExamInputForm> createState() => _ExamInputFormState();
}

class _ExamInputFormState extends State<_ExamInputForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _startDate;
  late final TextEditingController _endDate;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _academicYearId = '';
  String _termId = '';
  String _examTypeId = '';
  Map<String, dynamic> _exam = {};

  List<AcademicYearModel> _academicYears = [];
  List<Map<String, dynamic>> _terms = [];
  List<Map<String, dynamic>> _examTypes = [];

  bool get _ready =>
      _academicYearId.isNotEmpty &&
      _termId.isNotEmpty &&
      _examTypeId.isNotEmpty &&
      _examTypes.isNotEmpty &&
      _terms.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _exam = Map<String, dynamic>.from(widget.exam ?? const {});
    _name = TextEditingController(
      text: _text(_exam['exam_name'] ?? _exam['name']),
    );
    _startDate = TextEditingController(
      text: _dateOnly(
        _exam['start_date'],
        fallback: _dateInput(DateTime.now()),
      ),
    );
    _endDate = TextEditingController(
      text: _dateOnly(_exam['end_date'], fallback: _dateInput(DateTime.now())),
    );
    _loadReferences();
  }

  @override
  void dispose() {
    _name.dispose();
    _startDate.dispose();
    _endDate.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final id = _text(_exam['exam_id'] ?? _exam['id']);
      if (id.isNotEmpty && _text(_exam['academic_year_id']).isEmpty) {
        _exam = await api.getRawMap('/exams/$id');
        _name.text = _text(_exam['exam_name'] ?? _exam['name']);
        _startDate.text = _dateOnly(
          _exam['start_date'],
          fallback: _dateInput(DateTime.now()),
        );
        _endDate.text = _dateOnly(
          _exam['end_date'],
          fallback: _dateInput(DateTime.now()),
        );
      }

      final years = await api.getAcademicYears();
      final examTypes = await api.getExamTypes();
      final yearId = _initialId(
        _text(_exam['academic_year_id']),
        years.map((year) => year.id),
        fallback: years.where((year) => year.isCurrent).firstOrNull?.id,
      );
      final terms = yearId.isEmpty
          ? <Map<String, dynamic>>[]
          : await api.getTerms(yearId);
      if (!mounted) return;
      setState(() {
        _academicYears = years;
        _examTypes = examTypes;
        _academicYearId = yearId;
        _terms = terms;
        _termId = _initialId(
          _text(_exam['term_id']),
          terms.map((term) => _text(term['id'])),
        );
        _examTypeId = _initialId(
          _text(_exam['exam_type_id']),
          examTypes.map((type) => _text(type['id'])),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load exam setup data. $error';
        _loading = false;
      });
    }
  }

  Future<void> _loadTermsForYear(String yearId) async {
    setState(() {
      _academicYearId = yearId;
      _termId = '';
      _terms = [];
    });
    if (yearId.isEmpty) return;
    try {
      final terms = await BackendApiClient.instance.getTerms(yearId);
      if (!mounted) return;
      setState(() {
        _terms = terms;
        _termId = _initialId('', terms.map((term) => _text(term['id'])));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load terms for academic year. $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return OpsEmptyState(
        icon: Icons.fact_check_outlined,
        title: 'Exam setup unavailable',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadReferences,
      );
    }
    if (!_ready) {
      return const OpsEmptyState(
        icon: Icons.rule_folder_outlined,
        title: 'Exam setup required',
        message:
            'Create academic years, terms, and exam types before creating exams.',
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Exam name',
              prefixIcon: Icon(Icons.fact_check_outlined),
            ),
            validator: (value) => _required(value, 'Enter exam name.'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _academicYearId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Academic year',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            items: _academicYears
                .map(
                  (year) => DropdownMenuItem(
                    value: year.id,
                    child: Text(year.yearLabel),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select academic year.'),
            onChanged: _saving
                ? null
                : (value) => _loadTermsForYear(value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('exam-term-$_academicYearId-$_termId'),
            initialValue: _termId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Term',
              prefixIcon: Icon(Icons.date_range_outlined),
            ),
            items: _terms
                .map(
                  (term) => DropdownMenuItem(
                    value: _text(term['id']),
                    child: Text(_termLabel(term)),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select term.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _termId = value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _examTypeId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Exam type',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: _examTypes
                .where((type) => _text(type['id']).isNotEmpty)
                .map(
                  (type) => DropdownMenuItem(
                    value: _text(type['id']),
                    child: Text(
                      _examTypeLabel(type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select exam type.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _examTypeId = value ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _startDate,
            enabled: !_saving,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'Start date',
              helperText: 'YYYY-MM-DD',
              prefixIcon: Icon(Icons.event_outlined),
            ),
            validator: _dateValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _endDate,
            enabled: !_saving,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'End date',
              helperText: 'YYYY-MM-DD',
              prefixIcon: Icon(Icons.event_available_outlined),
            ),
            validator: _dateValidator,
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
            label: Text(_saving ? 'Saving...' : 'Save exam'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final start = DateTime.parse(_startDate.text.trim());
    final end = DateTime.parse(_endDate.text.trim());
    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date cannot be before start date.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit({
        'academic_year_id': _academicYearId,
        'term_id': _termId,
        'exam_type_id': _examTypeId,
        'exam_name': _name.text.trim(),
        'start_date': _startDate.text.trim(),
        'end_date': _endDate.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save exam: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _dateInput(DateTime date) =>
      date.toIso8601String().split('T').first;

  static String _dateOnly(Object? value, {required String fallback}) {
    final parsed = DateTime.tryParse(_text(value));
    return parsed == null ? fallback : _dateInput(parsed);
  }

  static String _initialId(
    String preferred,
    Iterable<String> options, {
    String? fallback,
  }) {
    final values = options.where((value) => value.trim().isNotEmpty).toList();
    if (preferred.trim().isNotEmpty && values.contains(preferred)) {
      return preferred;
    }
    if (fallback != null &&
        fallback.trim().isNotEmpty &&
        values.contains(fallback)) {
      return fallback;
    }
    return values.isEmpty ? '' : values.first;
  }

  static String _termLabel(Map<String, dynamic> term) {
    return _text(
      term['term_name'] ?? term['name'] ?? term['label'],
      fallback: _text(term['id'], fallback: 'Term'),
    );
  }

  static String _examTypeLabel(Map<String, dynamic> type) {
    return _text(
      type['name'] ?? type['exam_type'] ?? type['label'],
      fallback: _text(type['id'], fallback: 'Exam type'),
    );
  }

  static String? _required(String? value, String message) {
    return (value ?? '').trim().isEmpty ? message : null;
  }

  static String? _dateValidator(String? value) {
    final text = (value ?? '').trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      return 'Use YYYY-MM-DD.';
    }
    return DateTime.tryParse(text) == null ? 'Enter a valid date.' : null;
  }
}

class _ExamTypeInputForm extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  const _ExamTypeInputForm({required this.onSubmit});

  @override
  State<_ExamTypeInputForm> createState() => _ExamTypeInputFormState();
}

class _ExamTypeInputFormState extends State<_ExamTypeInputForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _weightage = TextEditingController(text: '100');
  bool _isBoardExam = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _weightage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Exam type name',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            validator: (value) => _required(value, 'Enter exam type name.'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _weightage,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Weightage percent',
              prefixIcon: Icon(Icons.percent_outlined),
            ),
            validator: (value) {
              final parsed = double.tryParse((value ?? '').trim()) ?? -1;
              return parsed < 0 ? 'Enter zero or more.' : null;
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _isBoardExam,
            onChanged: _saving
                ? null
                : (value) => setState(() => _isBoardExam = value),
            title: const Text('Board exam'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save exam type'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit({
        'name': _name.text.trim(),
        'weightage_percent': double.tryParse(_weightage.text.trim()) ?? 0,
        'is_board_exam': _isBoardExam,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save exam type: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ExamScheduleInputForm extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  const _ExamScheduleInputForm({required this.onSubmit});

  @override
  State<_ExamScheduleInputForm> createState() => _ExamScheduleInputFormState();
}

class _ExamScheduleInputFormState extends State<_ExamScheduleInputForm> {
  final _formKey = GlobalKey<FormState>();
  final _date = TextEditingController(text: _dateInput(DateTime.now()));
  final _start = TextEditingController(text: '09:00');
  final _end = TextEditingController(text: '10:00');
  final _maxMarks = TextEditingController(text: '100');
  final _passMarks = TextEditingController(text: '35');
  final _syllabus = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _examId = '';
  String _gradeId = '';
  String _sectionId = '';
  String _subjectId = '';
  String _roomId = '';

  List<ExamModel> _exams = [];
  List<GradeModel> _grades = [];
  List<SectionModel> _sections = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _rooms = [];

  List<SectionModel> get _sectionOptions =>
      _sections.where((section) => section.gradeId == _gradeId).toList()
        ..sort((left, right) => left.sectionName.compareTo(right.sectionName));

  bool get _ready =>
      _examId.isNotEmpty &&
      _gradeId.isNotEmpty &&
      _sectionId.isNotEmpty &&
      _subjectId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  @override
  void dispose() {
    _date.dispose();
    _start.dispose();
    _end.dispose();
    _maxMarks.dispose();
    _passMarks.dispose();
    _syllabus.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait<Object>([
        api.getExams(),
        api.getGrades(),
        api.getSections(),
        api.getRawList('/subjects'),
        api.getRooms(),
      ]);
      if (!mounted) return;
      final exams = results[0] as List<ExamModel>;
      final grades = results[1] as List<GradeModel>;
      final sections = results[2] as List<SectionModel>;
      final subjects = results[3] as List<Map<String, dynamic>>;
      final rooms = results[4] as List<Map<String, dynamic>>;
      final gradeId = _initialId('', grades.map((grade) => grade.id));
      final gradeSections = sections.where((section) {
        return section.gradeId == gradeId;
      }).toList();
      setState(() {
        _exams = exams;
        _grades = grades;
        _sections = sections;
        _subjects = subjects;
        _rooms = rooms;
        _examId = _initialId('', exams.map((exam) => exam.id));
        _gradeId = gradeId;
        _sectionId = _initialId('', gradeSections.map((section) => section.id));
        _subjectId = _initialId(
          '',
          subjects.map((subject) => _text(subject['id'])),
        );
        _roomId = '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load exam schedule setup. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return OpsEmptyState(
        icon: Icons.event_note_outlined,
        title: 'Schedule setup unavailable',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadReferences,
      );
    }
    if (!_ready) {
      return const OpsEmptyState(
        icon: Icons.rule_folder_outlined,
        title: 'Schedule setup required',
        message: 'Create an exam, class, section, and subject first.',
      );
    }
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _examId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Exam'),
            items: _exams
                .map(
                  (exam) => DropdownMenuItem(
                    value: exam.id,
                    child: Text(
                      exam.examName.isEmpty ? exam.id : exam.examName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select exam.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _examId = value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _gradeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Class'),
            items: _grades
                .map(
                  (grade) => DropdownMenuItem(
                    value: grade.id,
                    child: Text(grade.gradeName),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select class.'),
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _gradeId = value ?? '';
                    _sectionId = _initialId(
                      '',
                      _sectionOptions.map((section) => section.id),
                    );
                  }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('exam-schedule-section-$_gradeId-$_sectionId'),
            initialValue: _sectionId.isEmpty ? null : _sectionId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Section'),
            items: _sectionOptions
                .map(
                  (section) => DropdownMenuItem(
                    value: section.id,
                    child: Text(_sectionLabel(section)),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select section.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _sectionId = value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _subjectId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Subject'),
            items: _subjects
                .where((subject) => _text(subject['id']).isNotEmpty)
                .map(
                  (subject) => DropdownMenuItem(
                    value: _text(subject['id']),
                    child: Text(
                      _subjectLabel(subject),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select subject.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _subjectId = value ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _syllabus,
            enabled: !_saving,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Syllabus / chapters',
              alignLabelWithHint: true,
            ),
            validator: (value) =>
                _required(value, 'Enter syllabus or chapters.'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _date,
            enabled: !_saving,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(labelText: 'Exam date'),
            validator: _dateValidator,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _start,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Start time'),
                  validator: _timeValidator,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _end,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'End time'),
                  validator: _timeValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('exam-schedule-room-$_roomId'),
            initialValue: _rooms.any((room) => _text(room['id']) == _roomId)
                ? _roomId
                : '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Room'),
            items: [
              const DropdownMenuItem(value: '', child: Text('No room')),
              for (final room in _rooms)
                DropdownMenuItem(
                  value: _text(room['id']),
                  child: Text(
                    _roomLabel(room),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _roomId = value ?? ''),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _maxMarks,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max marks'),
                  validator: _positiveIntValidator,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _passMarks,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pass marks'),
                  validator: _nonNegativeIntValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save schedule'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final maxMarks = int.parse(_maxMarks.text.trim());
    final passMarks = int.parse(_passMarks.text.trim());
    if (passMarks > maxMarks) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pass marks cannot exceed max marks.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit({
        'exam_id': _examId,
        'grade_id': _gradeId,
        'section_id': _sectionId,
        'subject_id': _subjectId,
        'exam_date': _date.text.trim(),
        'start_time': _start.text.trim(),
        'end_time': _end.text.trim(),
        'syllabus': _syllabus.text.trim(),
        'max_marks': maxMarks,
        'pass_marks': passMarks,
        'room_id': _roomId,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save exam schedule: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TimetableSlotInputForm extends StatefulWidget {
  final Map<String, dynamic>? period;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  const _TimetableSlotInputForm({this.period, required this.onSubmit});

  @override
  State<_TimetableSlotInputForm> createState() =>
      _TimetableSlotInputFormState();
}

class _TimetablePeriodOption {
  final int period;
  final String startTime;
  final String endTime;

  const _TimetablePeriodOption({
    required this.period,
    required this.startTime,
    required this.endTime,
  });

  String get label {
    final time = [
      startTime,
      endTime,
    ].where((value) => value.trim().isNotEmpty).join(' - ');
    return time.isEmpty ? 'P$period' : 'P$period - $time';
  }
}

class _TimetableSlotInputFormState extends State<_TimetableSlotInputForm> {
  static const _days = <int, String>{
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _sectionId = '';
  String _academicYearId = '';
  String _termId = '';
  String _subjectId = '';
  String _staffId = '';
  String _roomId = '';
  String _startTime = '09:00';
  String _endTime = '09:40';
  int _periodNumber = 1;
  int _day = DateTime.now().weekday;

  List<SectionModel> _sections = [];
  List<AcademicYearModel> _academicYears = [];
  List<Map<String, dynamic>> _terms = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _periodRows = [];
  List<StaffModel> _staff = [];

  bool get _ready =>
      _sectionId.isNotEmpty &&
      _academicYearId.isNotEmpty &&
      _termId.isNotEmpty &&
      _subjectId.isNotEmpty &&
      _staffId.isNotEmpty &&
      _periodNumber > 0 &&
      _startTime.isNotEmpty &&
      _endTime.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final period = widget.period ?? const <String, dynamic>{};
    _periodNumber = _int(period['period_number'] ?? period['period']);
    if (_periodNumber <= 0) _periodNumber = 1;
    _startTime = _text(period['start_time'], fallback: '09:00');
    _endTime = _text(period['end_time'], fallback: '09:40');
    _roomId = _text(period['room_id']);
    final day = _int(period['day_of_week']);
    if (day >= 1 && day <= 7) _day = day;
    _loadReferences();
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final years = await api.getAcademicYears();
      final results = await Future.wait<Object>([
        api.getSections(),
        api.getStaff(page: 1, pageSize: 300, status: 'active'),
        api.getRawList('/subjects'),
        api.getRooms(),
      ]);
      final preferredYear = _text(widget.period?['academic_year_id']);
      final yearId = _initialId(
        preferredYear,
        years.map((year) => year.id),
        fallback: years.where((year) => year.isCurrent).firstOrNull?.id,
      );
      final terms = yearId.isEmpty
          ? <Map<String, dynamic>>[]
          : await api.getTerms(yearId);
      if (!mounted) return;
      final sections = results[0] as List<SectionModel>;
      final staff = (results[1] as PaginatedList<StaffModel>).data;
      final subjects = results[2] as List<Map<String, dynamic>>;
      final rooms = results[3] as List<Map<String, dynamic>>;
      final sectionId = _initialId(
        _text(widget.period?['section_id']),
        sections.map((section) => section.id),
      );
      final termId = _initialId(
        _text(widget.period?['term_id']),
        terms.map((term) => _text(term['id'])),
      );
      final periodRows = sectionId.isEmpty || yearId.isEmpty
          ? <Map<String, dynamic>>[]
          : await api.getTimetableSlots(
              sectionId: sectionId,
              academicYearId: yearId,
            );
      if (!mounted) return;
      setState(() {
        _academicYears = years;
        _sections = sections;
        _staff = staff;
        _subjects = subjects;
        _rooms = rooms;
        _academicYearId = yearId;
        _terms = terms;
        _termId = termId;
        _sectionId = sectionId;
        _subjectId = _initialId(
          _text(widget.period?['subject_id']),
          subjects.map((subject) => _text(subject['id'])),
        );
        _staffId = _initialId(
          _text(widget.period?['staff_id']),
          staff.map((item) => item.id),
        );
        final roomIds = rooms.map((room) => _text(room['id'])).toSet();
        _roomId = roomIds.contains(_roomId) ? _roomId : '';
        _periodRows = periodRows;
        _syncPeriodTime();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load timetable setup data. $error';
        _loading = false;
      });
    }
  }

  Future<void> _loadTermsForYear(String yearId) async {
    setState(() {
      _academicYearId = yearId;
      _termId = '';
      _terms = [];
      _periodRows = [];
    });
    if (yearId.isEmpty) return;
    try {
      final terms = await BackendApiClient.instance.getTerms(yearId);
      final periodRows = _sectionId.isEmpty
          ? <Map<String, dynamic>>[]
          : await BackendApiClient.instance.getTimetableSlots(
              sectionId: _sectionId,
              academicYearId: yearId,
            );
      if (!mounted) return;
      setState(() {
        _terms = terms;
        _termId = _initialId('', terms.map((term) => _text(term['id'])));
        _periodRows = periodRows;
        _syncPeriodTime();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load terms for academic year. $error');
    }
  }

  Future<void> _loadPeriodsForSection(String sectionId) async {
    setState(() {
      _sectionId = sectionId;
      _periodRows = [];
    });
    if (sectionId.isEmpty || _academicYearId.isEmpty) return;
    try {
      final rows = await BackendApiClient.instance.getTimetableSlots(
        sectionId: sectionId,
        academicYearId: _academicYearId,
      );
      if (!mounted) return;
      setState(() {
        _periodRows = rows;
        _syncPeriodTime();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load timetable periods. $error');
    }
  }

  List<MapEntry<int, String>> get _dayEntries {
    final days = _periodRows
        .map((row) => _int(row['day_of_week']))
        .where((day) => day >= 1 && day <= 7)
        .toSet();
    days.add(_day);
    final entries = _days.entries
        .where((entry) => days.isEmpty || days.contains(entry.key))
        .toList();
    return entries.isEmpty ? _days.entries.toList() : entries;
  }

  List<_TimetablePeriodOption> get _periodOptions {
    final matchingTerm = _periodRows.where((row) {
      final termId = _text(row['term_id']);
      return (_termId.isEmpty || termId.isEmpty || termId == _termId) &&
          !_isBreakSlot(row);
    }).toList();
    final matchingDay = matchingTerm
        .where((row) => _int(row['day_of_week']) == _day)
        .toList();
    final source = matchingDay.isEmpty ? matchingTerm : matchingDay;
    final byPeriod = <int, _TimetablePeriodOption>{};
    for (final row in source) {
      final period = _int(row['period_number'] ?? row['period']);
      if (period <= 0 || byPeriod.containsKey(period)) continue;
      byPeriod[period] = _TimetablePeriodOption(
        period: period,
        startTime: _text(row['start_time']),
        endTime: _text(row['end_time']),
      );
    }
    byPeriod.putIfAbsent(
      _periodNumber,
      () => _TimetablePeriodOption(
        period: _periodNumber,
        startTime: _startTime,
        endTime: _endTime,
      ),
    );
    final rows = byPeriod.values.toList()
      ..sort((a, b) => a.period.compareTo(b.period));
    return rows;
  }

  void _syncPeriodTime() {
    final options = _periodOptions;
    if (!options.any((option) => option.period == _periodNumber) &&
        options.isNotEmpty) {
      _periodNumber = options.first.period;
    }
    final selected = options
        .where((option) => option.period == _periodNumber)
        .firstOrNull;
    if (selected != null) {
      _startTime = selected.startTime;
      _endTime = selected.endTime;
    }
  }

  bool _isBreakSlot(Map<String, dynamic> row) {
    final slotType = _text(row['slot_type']).toLowerCase();
    return slotType.contains('break');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return OpsEmptyState(
        icon: Icons.calendar_view_week_outlined,
        title: 'Timetable setup unavailable',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadReferences,
      );
    }
    if (!_ready) {
      return const OpsEmptyState(
        icon: Icons.rule_folder_outlined,
        title: 'Setup data required',
        message:
            'Create classes, academic terms, subjects, and active staff before creating timetable periods.',
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit timetable slot',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: principalDirectoryText,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _academicYearId,
            decoration: const InputDecoration(labelText: 'Academic year'),
            items: _academicYears
                .map(
                  (year) => DropdownMenuItem(
                    value: year.id,
                    child: Text(year.yearLabel),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select academic year.'),
            onChanged: _saving
                ? null
                : (value) => _loadTermsForYear(value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('term-$_academicYearId-$_termId'),
            initialValue: _termId,
            decoration: const InputDecoration(labelText: 'Term'),
            items: _terms
                .map(
                  (term) => DropdownMenuItem(
                    value: _text(term['id']),
                    child: Text(_text(term['term_name'] ?? term['name'])),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select term.'),
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _termId = value ?? '';
                    _syncPeriodTime();
                  }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('section-$_sectionId'),
            initialValue: _sectionId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Class / section'),
            items: _sections
                .map(
                  (section) => DropdownMenuItem(
                    value: section.id,
                    child: Text(
                      _sectionLabel(section),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select class.'),
            onChanged: _saving
                ? null
                : (value) => _loadPeriodsForSection(value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('day-$_sectionId-$_day'),
            initialValue: _dayEntries.any((entry) => entry.key == _day)
                ? _day
                : _dayEntries.first.key,
            decoration: const InputDecoration(labelText: 'Day'),
            items: [
              for (final entry in _dayEntries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _day = value ?? _day;
                    _syncPeriodTime();
                  }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('period-$_sectionId-$_termId-$_day-$_periodNumber'),
            initialValue:
                _periodOptions.any((option) => option.period == _periodNumber)
                ? _periodNumber
                : _periodOptions.first.period,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Period / time'),
            items: [
              for (final option in _periodOptions)
                DropdownMenuItem(
                  value: option.period,
                  child: Text(option.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            validator: (value) =>
                value == null || value <= 0 ? 'Select period.' : null,
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _periodNumber = value ?? _periodNumber;
                    _syncPeriodTime();
                  }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _subjectId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Subject'),
            items: _subjects
                .map(
                  (subject) => DropdownMenuItem(
                    value: _text(subject['id']),
                    child: Text(
                      _subjectLabel(subject),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select subject.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _subjectId = value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _staffId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Teacher'),
            items: _staff
                .map(
                  (staff) => DropdownMenuItem(
                    value: staff.id,
                    child: Text(
                      _staffLabel(staff),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select teacher.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _staffId = value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('room-$_roomId'),
            initialValue: _rooms.any((room) => _text(room['id']) == _roomId)
                ? _roomId
                : '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Room'),
            items: [
              const DropdownMenuItem(value: '', child: Text('No room')),
              for (final room in _rooms)
                DropdownMenuItem(
                  value: _text(room['id']),
                  child: Text(
                    _roomLabel(room),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _roomId = value ?? ''),
          ),
          const SizedBox(height: 10),
          PrincipalInfoPill(
            icon: Icons.schedule_outlined,
            label: 'Selected time $_startTime - $_endTime',
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
            label: Text(_saving ? 'Saving...' : 'Save timetable period'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit({
        'section_id': _sectionId,
        'academic_year_id': _academicYearId,
        'term_id': _termId,
        'day_of_week': _day,
        'period_number': _periodNumber,
        'subject_id': _subjectId,
        'staff_id': _staffId,
        'room_id': _roomId,
        'start_time': _startTime,
        'end_time': _endTime,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save timetable period: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _initialId(
    String preferred,
    Iterable<String> options, {
    String? fallback,
  }) {
    final values = options.where((value) => value.trim().isNotEmpty).toList();
    if (preferred.trim().isNotEmpty && values.contains(preferred)) {
      return preferred;
    }
    if (fallback != null &&
        fallback.trim().isNotEmpty &&
        values.contains(fallback)) {
      return fallback;
    }
    return values.isEmpty ? '' : values.first;
  }

  static String _sectionLabel(SectionModel section) {
    final grade = section.gradeName.trim();
    final name = section.sectionName.trim();
    if (grade.isEmpty) return name.isEmpty ? section.id : name;
    return name.isEmpty ? grade : '$grade - $name';
  }

  static String _subjectLabel(Map<String, dynamic> subject) => _text(
    subject['subject_name'] ?? subject['name'] ?? subject['subject_code'],
    fallback: _text(subject['id']),
  );

  static String _staffLabel(StaffModel staff) {
    final name = staff.fullName.trim();
    if (name.isNotEmpty) return name;
    final email = (staff.email ?? '').trim();
    return email.isEmpty ? staff.id : email;
  }

  static String _roomLabel(Map<String, dynamic> room) {
    final number = _text(room['room_number'] ?? room['name']);
    final type = _text(room['room_type']);
    if (number.isEmpty) return _text(room['id'], fallback: 'Room');
    return type.isEmpty ? number : '$number - $type';
  }

  static String? _required(String? value, String message) {
    return (value ?? '').trim().isEmpty ? message : null;
  }
}

String _dateInput(DateTime date) => date.toIso8601String().split('T').first;

String _initialId(
  String preferred,
  Iterable<String> options, {
  String? fallback,
}) {
  final values = options.where((value) => value.trim().isNotEmpty).toList();
  if (preferred.trim().isNotEmpty && values.contains(preferred)) {
    return preferred;
  }
  if (fallback != null &&
      fallback.trim().isNotEmpty &&
      values.contains(fallback)) {
    return fallback;
  }
  return values.isEmpty ? '' : values.first;
}

String _sectionLabel(SectionModel section) {
  final grade = section.gradeName.trim();
  final name = section.sectionName.trim();
  if (grade.isEmpty) return name.isEmpty ? section.id : name;
  return name.isEmpty ? grade : '$grade - $name';
}

String _subjectLabel(Map<String, dynamic> subject) => _text(
  subject['subject_name'] ?? subject['name'] ?? subject['subject_code'],
  fallback: _text(subject['id']),
);

String _roomLabel(Map<String, dynamic> room) {
  final number = _text(room['room_number'] ?? room['name']);
  final type = _text(room['room_type']);
  if (number.isEmpty) return _text(room['id'], fallback: 'Room');
  return type.isEmpty ? number : '$number - $type';
}

String? _required(String? value, String message) {
  return (value ?? '').trim().isEmpty ? message : null;
}

String? _dateValidator(String? value) {
  final text = (value ?? '').trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    return 'Use YYYY-MM-DD.';
  }
  return DateTime.tryParse(text) == null ? 'Enter a valid date.' : null;
}

String? _timeValidator(String? value) {
  final text = (value ?? '').trim();
  if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(text)) return 'Use HH:MM.';
  final hour = int.tryParse(text.substring(0, 2)) ?? -1;
  final minute = int.tryParse(text.substring(3, 5)) ?? -1;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return 'Enter a valid time.';
  }
  return null;
}

String? _positiveIntValidator(String? value) {
  final parsed = int.tryParse(value ?? '') ?? 0;
  return parsed <= 0 ? 'Enter a positive number.' : null;
}

String? _nonNegativeIntValidator(String? value) {
  final parsed = int.tryParse(value ?? '') ?? -1;
  return parsed < 0 ? 'Enter zero or a positive number.' : null;
}

Widget _rowsPanel(
  String title,
  String subtitle,
  List<Map<String, dynamic>> rows,
  IconData icon,
) {
  return OpsPanel(
    title: title,
    subtitle: subtitle,
    child: rows.isEmpty
        ? const Text('No backend rows to review.')
        : Column(
            children: [
              for (final row in rows.take(8))
                OpsListRow(
                  icon: icon,
                  title: _rowTitle(row),
                  subtitle: _rowSubtitle(row),
                  trailing: OpsStatusPill(
                    label: _text(
                      row['status'] ?? row['priority'] ?? row['state'],
                      fallback: 'Live',
                    ),
                    color: _statusColor(
                      _text(row['status'] ?? row['priority'] ?? row['state']),
                    ),
                  ),
                ),
            ],
          ),
  );
}

Widget _actionsPanel({
  required String title,
  required String subtitle,
  required List<Map<String, dynamic>> rows,
  required void Function(_ActionSpec action) openAction,
  required String actionType,
}) {
  return OpsPanel(
    title: title,
    subtitle: subtitle,
    trailing: FilledButton.icon(
      onPressed: () => openAction(
        _ActionSpec(
          actionType: actionType,
          title: title,
          priority: 'normal',
          entityId: '',
          dueDate: '',
        ),
      ),
      icon: const Icon(Icons.add_task_rounded),
      label: const Text('Create action'),
    ),
    child: rows.isEmpty
        ? const Text('No recent principal actions.')
        : Column(
            children: [
              for (final row in rows.take(8))
                OpsListRow(
                  icon: Icons.task_alt_outlined,
                  title: _text(
                    row['title'] ?? row['action_type'],
                    fallback: 'Principal action',
                  ),
                  subtitle: _text(row['message'], fallback: 'No message saved'),
                  trailing: OpsStatusPill(
                    label: _text(row['status'], fallback: 'Open'),
                    color: _statusColor(_text(row['status'])),
                  ),
                ),
            ],
          ),
  );
}

List<Map<String, dynamic>> _optionRows(Map<String, dynamic> controls) {
  return [
    {
      'label': 'Exam types',
      'value': _list(controls['exam_types']).length,
      'status': 'ready',
    },
    {
      'label': 'Grades',
      'value': _list(controls['grades']).length,
      'status': 'ready',
    },
    {
      'label': 'Subjects',
      'value': _list(controls['subjects']).length,
      'status': 'ready',
    },
    {
      'label': 'Rooms',
      'value': _list(controls['rooms']).length,
      'status': 'ready',
    },
    {
      'label': 'Assign invigilators',
      'value': _list(controls['staff']).length,
      'status': 'ready',
    },
  ];
}

String _rowTitle(Map<String, dynamic> row) {
  return _text(
    row['title'] ??
        row['label'] ??
        row['class_name'] ??
        row['teacher_name'] ??
        row['subject_name'] ??
        row['room_name'] ??
        row['exam_name'] ??
        row['student_name'] ??
        row['name'],
    fallback: 'Backend row',
  );
}

String _rowSubtitle(Map<String, dynamic> row) {
  final parts = <String>[
    _text(row['subtitle']),
    _text(row['description']),
    _text(row['class_names']),
    _text(row['subject_names']),
    if (_int(row['schedule_count']) > 0)
      '${_int(row['schedule_count'])} papers',
    _text(row['date'] ?? row['exam_date']),
    _text(row['subject_name']),
    _text(row['teacher_name']),
    _text(row['class_name']),
    _text(row['value']),
  ]..removeWhere((part) => part.isEmpty);
  return parts.isEmpty ? 'Live backend row' : parts.take(3).join(' | ');
}

Color _statusColor(String status) {
  final lower = status.toLowerCase();
  if (lower.contains('complete') ||
      lower.contains('published') ||
      lower.contains('ready')) {
    return Colors.green;
  }
  if (lower.contains('high') ||
      lower.contains('delayed') ||
      lower.contains('conflict')) {
    return Colors.red;
  }
  if (lower.contains('pending') ||
      lower.contains('open') ||
      lower.contains('normal')) {
    return Colors.orange;
  }
  return Colors.indigo;
}

class _Metric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Metric(this.label, this.value, this.icon, this.color);
}

class _ActionSpec {
  final String actionType;
  final String title;
  final String priority;
  final String entityId;
  final String dueDate;

  const _ActionSpec({
    required this.actionType,
    this.title = '',
    this.priority = 'normal',
    this.entityId = '',
    this.dueDate = '',
  });
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _list(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : [];

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

String _text(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? fallback : text;
}
