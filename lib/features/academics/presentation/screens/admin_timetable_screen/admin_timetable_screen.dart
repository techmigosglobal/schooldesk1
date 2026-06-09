import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/bulk_csv_import_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/operations_workspace.dart';
import 'package:schooldesk1/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_form_screens.dart';
import 'package:schooldesk1/routes/app_routes.dart';

enum _AdminTimetableHomeMode { classes, teachers, rooms }

enum _AdminTimetableDetailMode {
  home,
  classDay,
  classWeek,
  dayDetails,
  teacher,
  room,
}

class AdminTimetableScreen extends StatefulWidget {
  const AdminTimetableScreen({super.key});

  @override
  State<AdminTimetableScreen> createState() => _AdminTimetableScreenState();
}

class _AdminTimetableScreenState extends State<AdminTimetableScreen> {
  static const _dayShortLabels = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];
  static const _dayFullLabels = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _loading = true;
  String? _error;
  String _search = '';
  String _selectedSectionId = '';
  String _selectedStaffId = '';
  String _selectedRoomId = '';
  int _selectedDay = DateTime.now().weekday.clamp(1, 6).toInt();
  int _filterDay = 0;
  _AdminTimetableHomeMode _homeMode = _AdminTimetableHomeMode.classes;
  _AdminTimetableDetailMode _detailMode = _AdminTimetableDetailMode.home;
  Map<String, dynamic>? _selectedPeriod;

  List<Map<String, dynamic>> _slots = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _terms = [];
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _substitutions = [];
  List<SectionModel> _sections = [];
  List<StaffModel> _staff = [];
  List<AcademicYearModel> _academicYears = [];

  @override
  void initState() {
    super.initState();
    _loadBackendTimetable();
  }

  Future<void> _loadBackendTimetable() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final academicYears = await api.getAcademicYears();
      final currentYear = _currentAcademicYearFrom(academicYears);
      final terms = currentYear == null
          ? <Map<String, dynamic>>[]
          : await api.getTerms(currentYear.id);
      final results = await Future.wait<Object>([
        api.getTimetableSlots(),
        api.getSubstitutions(),
        api.getSections(),
        api.getStaff(page: 1, pageSize: 300, status: 'active'),
        api.getRawList('/subjects'),
        api.getRooms(),
      ]);
      final sections = results[2] as List<SectionModel>;
      final staff = (results[3] as PaginatedList<StaffModel>).data;
      if (!mounted) return;
      setState(() {
        _academicYears = academicYears;
        _terms = terms;
        _slots = (results[0] as List<Map<String, dynamic>>)..sort(_slotSort);
        _substitutions = results[1] as List<Map<String, dynamic>>;
        _sections = sections;
        _staff = staff;
        _subjects = results[4] as List<Map<String, dynamic>>;
        _rooms = results[5] as List<Map<String, dynamic>>;
        _reconcileSelections();
        _loading = false;
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
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF3F8FC),
      drawer: AdminDrawer(selectedIndex: 5, onDestinationSelected: (_) {}),
      bottomNavigationBar: const _AdminTimetableBottomBar(),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0877D8),
          onRefresh: _loadBackendTimetable,
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
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: OpsEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Timetable unavailable',
                      message: _error!,
                      actionLabel: 'Retry',
                      onAction: _loadBackendTimetable,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 92),
                  sliver: SliverToBoxAdapter(child: _buildActiveView()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = switch (_detailMode) {
      _AdminTimetableDetailMode.classDay => 'Class Timetable',
      _AdminTimetableDetailMode.classWeek => 'Full Week Timetable',
      _AdminTimetableDetailMode.dayDetails =>
        '${_dayLabel(_selectedDay)} Schedule',
      _AdminTimetableDetailMode.teacher => _selectedTeacherName,
      _AdminTimetableDetailMode.room => 'Room $_selectedRoomName',
      _AdminTimetableDetailMode.home => 'Timetable',
    };
    final subtitle = switch (_detailMode) {
      _AdminTimetableDetailMode.classDay ||
      _AdminTimetableDetailMode.classWeek ||
      _AdminTimetableDetailMode.dayDetails =>
        '$_selectedClassLabel - ${_currentAcademicYear?.yearLabel ?? 'Current year'}',
      _AdminTimetableDetailMode.teacher => _selectedTeacherDepartment,
      _AdminTimetableDetailMode.room => _selectedRoomCapacityLabel,
      _AdminTimetableDetailMode.home => 'View and explore timetables',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: _detailMode == _AdminTimetableDetailMode.home
                ? 'Menu'
                : 'Back',
            onPressed: _detailMode == _AdminTimetableDetailMode.home
                ? () => _scaffoldKey.currentState?.openDrawer()
                : _goBack,
            icon: Icon(
              _detailMode == _AdminTimetableDetailMode.home
                  ? Icons.menu_rounded
                  : Icons.arrow_back_ios_new_rounded,
              size: 21,
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
                    color: const Color(0xFF172B3A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF667989),
                  ),
                ),
              ],
            ),
          ),
          if (_detailMode == _AdminTimetableDetailMode.home)
            IconButton.filledTonal(
              tooltip: 'Filter timetable',
              onPressed: _openFilterSheet,
              icon: const Icon(Icons.tune_rounded, size: 20),
            )
          else if (_detailMode == _AdminTimetableDetailMode.dayDetails)
            IconButton.filledTonal(
              tooltip: 'Share schedule',
              onPressed: _shareDaySummary,
              icon: const Icon(Icons.ios_share_rounded, size: 20),
            )
          else
            IconButton.filledTonal(
              tooltip: 'Refresh timetable',
              onPressed: _loadBackendTimetable,
              icon: const Icon(Icons.calendar_month_rounded, size: 20),
            ),
          PopupMenuButton<String>(
            tooltip: 'Admin timetable tools',
            onSelected: _handleAdminTool,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'generate',
                child: Text('Generate Timetable'),
              ),
              PopupMenuItem(
                value: 'import',
                child: Text('Generate from class CSV'),
              ),
              PopupMenuItem(value: 'add', child: Text('Add single period')),
              PopupMenuItem(
                value: 'substitute',
                child: Text('Add substitution'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveView() {
    return switch (_detailMode) {
      _AdminTimetableDetailMode.classDay => _buildClassDayView(),
      _AdminTimetableDetailMode.classWeek => _buildClassWeekView(),
      _AdminTimetableDetailMode.dayDetails => _buildDayDetailsView(),
      _AdminTimetableDetailMode.teacher => _buildTeacherDetailView(),
      _AdminTimetableDetailMode.room => _buildRoomDetailView(),
      _AdminTimetableDetailMode.home => _buildHomeView(),
    };
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
          _AdminTimetableHomeMode.classes => _buildClassList(),
          _AdminTimetableHomeMode.teachers => _buildTeacherList(),
          _AdminTimetableHomeMode.rooms => _buildRoomList(),
        },
        const SizedBox(height: 14),
        _buildInfoCard(),
        const SizedBox(height: 12),
        _buildAdminActionStrip(),
      ],
    );
  }

  Widget _buildModeTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: _softDecoration(),
      child: Row(
        children: [
          _modeTab(
            _AdminTimetableHomeMode.classes,
            Icons.groups_2_outlined,
            'Class Timetable',
          ),
          _modeTab(
            _AdminTimetableHomeMode.teachers,
            Icons.person_pin_outlined,
            'Teacher Timetable',
          ),
          _modeTab(
            _AdminTimetableHomeMode.rooms,
            Icons.meeting_room_outlined,
            'Room Timetable',
          ),
        ],
      ),
    );
  }

  Widget _modeTab(_AdminTimetableHomeMode mode, IconData icon, String label) {
    final selected = _homeMode == mode;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() {
          _homeMode = mode;
          _search = '';
          _detailMode = _AdminTimetableDetailMode.home;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0877D8) : Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : const Color(0xFF667989),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : const Color(0xFF172B3A),
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
      _AdminTimetableHomeMode.classes => 'Search class or section',
      _AdminTimetableHomeMode.teachers => 'Search teacher',
      _AdminTimetableHomeMode.rooms => 'Search room',
    };
    return Container(
      decoration: _softDecoration(),
      child: TextField(
        onChanged: (value) => setState(() => _search = value),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildClassList() {
    final rows = _classRows.where(_matchesSearch).toList();
    if (rows.isEmpty) return _emptyPanel('No class timetables found');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Classes'),
        const SizedBox(height: 10),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TimetableCard(
              icon: Icons.groups_2_outlined,
              title: _text(row['class_name'], fallback: 'Class'),
              subtitle:
                  '${_int(row['slot_count'])} Periods / Week - Class teacher: ${_text(row['class_teacher'], fallback: 'Pending')}',
              status: _int(row['slot_count']) > 0 ? 'Active' : 'Pending',
              statusColor: _int(row['slot_count']) > 0
                  ? AppTheme.success
                  : AppTheme.warning,
              chips: [
                _MiniPill(
                  icon: Icons.co_present_outlined,
                  label: _text(
                    row['class_teacher'],
                    fallback: 'Class teacher pending',
                  ),
                ),
                _MiniPill(
                  icon: Icons.meeting_room_outlined,
                  label:
                      'Class room: ${_text(row['room_name'], fallback: _capacityLabel(row))}',
                ),
              ],
              onTap: () => _openClass(row),
            ),
          ),
      ],
    );
  }

  Widget _buildTeacherList() {
    final rows = _teacherRows.where(_matchesSearch).toList();
    if (rows.isEmpty) return _emptyPanel('No teacher timetables found');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Teachers'),
        const SizedBox(height: 10),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TimetableCard(
              icon: Icons.person_pin_outlined,
              title: _text(row['teacher_name'], fallback: 'Teacher'),
              subtitle: _text(
                row['department_name'],
                fallback: 'Department not assigned',
              ),
              status: '${_int(row['periods'])} / Week',
              statusColor: AppTheme.primary,
              chips: [
                _MiniPill(
                  icon: Icons.groups_2_outlined,
                  label: '${_int(row['classes'])} classes',
                ),
                _MiniPill(
                  icon: Icons.menu_book_outlined,
                  label: '${_int(row['subjects'])} subjects',
                ),
              ],
              onTap: () => _openTeacher(row),
            ),
          ),
      ],
    );
  }

  Widget _buildRoomList() {
    final rows = _roomRows.where(_matchesSearch).toList();
    if (rows.isEmpty) return _emptyPanel('No room timetables found');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Rooms'),
        const SizedBox(height: 10),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TimetableCard(
              icon: _bool(row['is_lab_room'])
                  ? Icons.science_outlined
                  : Icons.meeting_room_outlined,
              title: _text(row['room_name'], fallback: 'Room'),
              subtitle: _capacityLabel(row),
              status: _int(row['conflicts']) == 0 ? 'Clear' : 'Conflict',
              statusColor: _int(row['conflicts']) == 0
                  ? AppTheme.success
                  : AppTheme.warning,
              chips: [
                _MiniPill(
                  icon: Icons.event_note_outlined,
                  label: '${_int(row['periods'])} periods',
                ),
                _MiniPill(
                  icon: Icons.groups_2_outlined,
                  label: '${_int(row['classes'])} classes',
                ),
              ],
              onTap: () => _openRoom(row),
            ),
          ),
      ],
    );
  }

  Widget _buildClassDayView() {
    final classRow = _selectedClassRow;
    if (classRow == null) return _buildHomeView();
    final periods = _periodsForClass(_selectedSectionId, _selectedDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _classSummaryCard(classRow),
        const SizedBox(height: 14),
        _buildDayChips(),
        const SizedBox(height: 14),
        periods.isEmpty
            ? _classEmptyState(classRow)
            : _schedulePanel(
                title: '${_dayLabel(_selectedDay)} Schedule',
                rows: periods,
                columns: const ['Time', 'Period', 'Subject', 'Teacher', 'Room'],
                onRowTap: _openDayDetails,
              ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () =>
              setState(() => _detailMode = _AdminTimetableDetailMode.classWeek),
          icon: const Icon(Icons.calendar_view_week_rounded),
          label: const Text('View Full Week'),
        ),
        const SizedBox(height: 10),
        _buildAdminActionStrip(compact: true),
      ],
    );
  }

  Widget _buildClassWeekView() {
    final classRow = _selectedClassRow;
    if (classRow == null) return _buildHomeView();
    final periods = _periodsForClass(_selectedSectionId, null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _classSummaryCard(classRow),
        const SizedBox(height: 14),
        _buildDayChips(),
        const SizedBox(height: 14),
        periods.isEmpty ? _classEmptyState(classRow) : _weekGrid(periods),
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
      ],
    );
  }

  Widget _buildDayDetailsView() {
    final classRow = _selectedClassRow;
    if (classRow == null) return _buildHomeView();
    final periods = _periodsForClass(_selectedSectionId, _selectedDay);
    final teachingPeriods = periods.where((row) => !_isBreakSlot(row)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dateSummaryCard(periods),
        const SizedBox(height: 14),
        _metadataPanel([
          (
            Icons.school_outlined,
            'Academic Year',
            _currentAcademicYear?.yearLabel ?? 'Current academic year',
          ),
          (Icons.groups_2_outlined, 'Class / Section', _selectedClassLabel),
          (
            Icons.event_note_outlined,
            'Total Periods',
            '${teachingPeriods.length}',
          ),
          (
            Icons.schedule_outlined,
            'Total Duration',
            _dayDurationLabel(periods),
          ),
          (Icons.free_breakfast_outlined, 'Breaks', _breaksLabel(periods)),
        ]),
        const SizedBox(height: 14),
        periods.isEmpty
            ? _classEmptyState(classRow)
            : _schedulePanel(
                title: 'Today\'s Timetable',
                rows: periods,
                columns: const ['Period', 'Time', 'Subject', 'Teacher', 'Room'],
              ),
        if (_selectedPeriod != null && !_isBreakSlot(_selectedPeriod!)) ...[
          const SizedBox(height: 14),
          _adminSelectedPeriodTools(_selectedPeriod!),
        ],
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _openGenerateTimetableForm,
          icon: const Icon(Icons.account_tree_outlined),
          label: const Text('Go to Classes Hub'),
        ),
        const SizedBox(height: 8),
        Text(
          'Make timetable changes from Classes Hub > Step 3 (Timetable) or Admin timetable tools.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF667989),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherDetailView() {
    final row = _selectedTeacherRow;
    if (row == null) return _buildHomeView();
    final periods = _availabilityRows(
      _periodsForTeacher(_selectedStaffId, _selectedDay),
      _selectedDay,
      freeLabel: 'Free Period',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimetableCard(
          icon: Icons.person_pin_outlined,
          title: _text(row['teacher_name'], fallback: 'Teacher'),
          subtitle: _text(
            row['department_name'],
            fallback: 'Department not assigned',
          ),
          status: _text(row['workload_state'], fallback: 'Scheduled'),
          statusColor: _statusColor(_text(row['workload_state'])),
          chips: [
            _MiniPill(
              icon: Icons.event_note_outlined,
              label: 'Total Periods: ${_int(row['periods'])}',
            ),
            _MiniPill(
              icon: Icons.free_breakfast_outlined,
              label:
                  'Free Periods: ${_freePeriodsFor(_selectedStaffId, 'staff')}',
            ),
            _MiniPill(
              icon: Icons.groups_2_outlined,
              label: 'Classes: ${_int(row['classes'])}',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDayChips(),
        const SizedBox(height: 14),
        _schedulePanel(
          title: '${_dayLabel(_selectedDay)} Teacher Schedule',
          rows: periods,
          columns: const ['Time', 'Period', 'Class', 'Subject', 'Room'],
          onRowTap: _openPeriodClassDay,
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
    final row = _selectedRoomRow;
    if (row == null) return _buildHomeView();
    final periods = _availabilityRows(
      _periodsForRoom(_selectedRoomId, _selectedDay),
      _selectedDay,
      freeLabel: 'Room Free',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimetableCard(
          icon: _bool(row['is_lab_room'])
              ? Icons.science_outlined
              : Icons.meeting_room_outlined,
          title: 'Room ${_text(row['room_name'], fallback: 'Room')}',
          subtitle: _capacityLabel(row),
          status: _int(row['conflicts']) == 0 ? 'Clear' : 'Conflict',
          statusColor: _int(row['conflicts']) == 0
              ? AppTheme.success
              : AppTheme.warning,
          chips: [
            _MiniPill(
              icon: Icons.event_note_outlined,
              label: '${_int(row['periods'])} periods',
            ),
            _MiniPill(
              icon: Icons.groups_2_outlined,
              label: '${_int(row['classes'])} classes',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDayChips(),
        const SizedBox(height: 14),
        _schedulePanel(
          title: '${_dayLabel(_selectedDay)} Room Schedule',
          rows: periods,
          columns: const ['Time', 'Class', 'Subject', 'Teacher'],
          onRowTap: _openPeriodClassDay,
        ),
      ],
    );
  }

  Widget _classSummaryCard(Map<String, dynamic> row) {
    return _TimetableCard(
      icon: Icons.groups_2_outlined,
      title: _selectedClassLabel,
      subtitle: _text(row['class_teacher'], fallback: 'Class Teacher pending'),
      status: _int(row['slot_count']) > 0 ? 'Active' : 'Pending',
      statusColor: _int(row['slot_count']) > 0
          ? AppTheme.success
          : AppTheme.warning,
      chips: [
        _MiniPill(
          icon: Icons.person_pin_outlined,
          label:
              'Class Teacher: ${_text(row['class_teacher'], fallback: 'Not assigned')}',
        ),
        _MiniPill(
          icon: Icons.event_note_outlined,
          label: 'Total Periods / Week: ${_int(row['slot_count'])}',
        ),
      ],
    );
  }

  Widget _dateSummaryCard(List<Map<String, dynamic>> periods) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _softDecoration(),
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF172B3A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _dayTimeRange(periods),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF667989),
                  ),
                ),
              ],
            ),
          ),
          const _StatusPill(label: 'Active', color: AppTheme.success),
        ],
      ),
    );
  }

  Widget _metadataPanel(List<(IconData, String, String)> rows) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _softDecoration(),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(row.$1, size: 18, color: const Color(0xFF667989)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF667989),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      row.$3,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF172B3A),
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

  Widget _adminSelectedPeriodTools(Map<String, dynamic> period) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _softDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Single Period Modification',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF172B3A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openEditPeriodForm(period),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Edit period'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Delete period',
                onPressed: () => _deletePeriod(period),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _schedulePanel({
    required String title,
    required List<Map<String, dynamic>> rows,
    required List<String> columns,
    ValueChanged<Map<String, dynamic>>? onRowTap,
  }) {
    final sorted = [...rows]..sort(_slotSort);
    return Container(
      decoration: _softDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF172B3A),
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
      color: const Color(0xFFF8FBFF),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          for (final column in columns)
            Expanded(
              flex: column == 'Time' ? 2 : 1,
              child: Text(
                column,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF667989),
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
    final isBreak = _isBreakSlot(row);
    final isFree = _isFree(row);
    final values = <String, String>{
      'Time': _slotTime(row),
      'Period': isBreak || isFree ? '-' : '${_int(row['period_number'])}',
      'Subject': _subjectName(row),
      'Teacher': isBreak || isFree ? '-' : _staffName(row),
      'Room': isBreak || isFree ? '-' : _roomName(row),
      'Class': isFree ? 'Available' : _slotClassName(row),
    };
    final content = Container(
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
              flex: column == 'Time' ? 2 : 1,
              child: column == 'Subject'
                  ? _subjectBadge(
                      values[column] ?? '',
                      isBreak: isBreak,
                      isFree: isFree,
                    )
                  : Text(
                      values[column] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: column == 'Period'
                            ? FontWeight.w900
                            : FontWeight.w700,
                        color: const Color(0xFF172B3A),
                      ),
                    ),
            ),
        ],
      ),
    );
    if (onTap == null || isBreak || isFree) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: () => onTap(row), child: content),
    );
  }

  Widget _weekGrid(List<Map<String, dynamic>> periods) {
    final maxPeriod = periods
        .map((row) => _int(row['period_number']))
        .fold<int>(0, (max, value) => value > max ? value : max)
        .clamp(1, 10)
        .toInt();
    return Container(
      decoration: _softDecoration(),
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
                  for (final day in _dayShortLabels)
                    _weekCell(day, header: true),
                ],
              ),
              for (var period = 1; period <= maxPeriod; period++)
                Row(
                  children: [
                    _weekCell(_periodTimeLabel(periods, period), flex: 2),
                    for (var day = 1; day <= _dayShortLabels.length; day++)
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
          color: empty ? const Color(0xFF667989) : const Color(0xFF172B3A),
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

  Widget _buildDayChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _dayShortLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = index + 1;
          return _ChoiceChipButton(
            label: _dayShortLabels[index],
            selected: day == _selectedDay,
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

  Widget _classEmptyState(Map<String, dynamic> classRow) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _softDecoration(),
      child: Column(
        children: [
          OpsEmptyState(
            icon: Icons.calendar_month_outlined,
            title: 'No timetable generated yet',
            message:
                'for ${_text(classRow['class_name'], fallback: 'this class')}. Generate timetable from Classes Hub.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openGenerateTimetableForm,
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('Go to Classes Hub'),
          ),
          const SizedBox(height: 8),
          Text(
            'Classes Hub > Step 3 (Timetable)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF667989),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyPanel(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
      decoration: _softDecoration(),
      child: OpsEmptyState(
        icon: Icons.calendar_view_week_outlined,
        title: title,
        message: 'Only live backend timetable rows are shown here.',
      ),
    );
  }

  Widget _buildInfoCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _openGenerateTimetableForm,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F3FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFB8D8FF)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF0877D8)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'To make changes to the timetable, go to Classes Hub > Step 3 (Timetable).',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF172B3A),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActionStrip({bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: _softDecoration(),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _ActionChipButton(
            icon: Icons.auto_awesome_rounded,
            label: 'Generate Timetable',
            onTap: _openGenerateTimetableForm,
          ),
          _ActionChipButton(
            icon: Icons.add_rounded,
            label: 'Single Period',
            onTap: _openAddPeriodForm,
          ),
          _ActionChipButton(
            icon: Icons.upload_file_rounded,
            label: 'Generate from class CSV',
            onTap: _importTimetableCsv,
          ),
          _ActionChipButton(
            icon: Icons.swap_horiz_rounded,
            label: 'Substitution',
            onTap: _openSubstitutionForm,
          ),
          _MiniPill(
            icon: Icons.swap_calls_rounded,
            label: '${_substitutions.length} substitutions',
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w900,
        color: const Color(0xFF172B3A),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    var mode = _homeMode;
    var day = _filterDay;
    var sectionId = _selectedSectionId;
    var staffId = _selectedStaffId;
    var roomId = _selectedRoomId;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  18 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SingleChildScrollView(
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
                        initialValue: _currentAcademicYear?.id ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Academic Year',
                        ),
                        items: [
                          DropdownMenuItem(
                            value: _currentAcademicYear?.id ?? '',
                            child: Text(
                              _currentAcademicYear?.yearLabel ??
                                  'Current academic year',
                            ),
                          ),
                        ],
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<_AdminTimetableHomeMode>(
                        initialValue: mode,
                        decoration: const InputDecoration(labelText: 'View'),
                        items: const [
                          DropdownMenuItem(
                            value: _AdminTimetableHomeMode.classes,
                            child: Text('Class Timetable'),
                          ),
                          DropdownMenuItem(
                            value: _AdminTimetableHomeMode.teachers,
                            child: Text('Teacher Timetable'),
                          ),
                          DropdownMenuItem(
                            value: _AdminTimetableHomeMode.rooms,
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
                        value: sectionId,
                        items: _classRows,
                        idKey: 'section_id',
                        labelKey: 'class_name',
                        onChanged: (value) =>
                            setSheetState(() => sectionId = value ?? ''),
                      ),
                      const SizedBox(height: 12),
                      _filterDropdown(
                        label: 'Teacher',
                        allLabel: 'All Teachers',
                        value: staffId,
                        items: _teacherRows,
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
                        items: _roomRows,
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
                          for (var i = 0; i < _dayFullLabels.length; i++)
                            DropdownMenuItem(
                              value: i + 1,
                              child: Text(_dayFullLabels[i]),
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
                              onPressed: () => setSheetState(() {
                                mode = _AdminTimetableHomeMode.classes;
                                day = 0;
                                sectionId = '';
                                staffId = '';
                                roomId = '';
                              }),
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
                                  _selectedPeriod = null;
                                  if (mode == _AdminTimetableHomeMode.classes &&
                                      sectionId.isNotEmpty) {
                                    _selectedSectionId = sectionId;
                                    _detailMode = day == 0
                                        ? _AdminTimetableDetailMode.classWeek
                                        : _AdminTimetableDetailMode.classDay;
                                  } else if (mode ==
                                          _AdminTimetableHomeMode.teachers &&
                                      staffId.isNotEmpty) {
                                    _selectedStaffId = staffId;
                                    _detailMode =
                                        _AdminTimetableDetailMode.teacher;
                                  } else if (mode ==
                                          _AdminTimetableHomeMode.rooms &&
                                      roomId.isNotEmpty) {
                                    _selectedRoomId = roomId;
                                    _detailMode =
                                        _AdminTimetableDetailMode.room;
                                  } else {
                                    _detailMode =
                                        _AdminTimetableDetailMode.home;
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
    required String value,
    required List<Map<String, dynamic>> items,
    required String idKey,
    required String labelKey,
    required ValueChanged<String?> onChanged,
  }) {
    final menuItems = [
      DropdownMenuItem<String>(value: '', child: Text(allLabel)),
      for (final item in items)
        if (_text(item[idKey]).isNotEmpty)
          DropdownMenuItem<String>(
            value: _text(item[idKey]),
            child: Text(_text(item[labelKey], fallback: _text(item[idKey]))),
          ),
    ];
    return DropdownButtonFormField<String>(
      initialValue: menuItems.any((item) => item.value == value) ? value : '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: menuItems,
      onChanged: onChanged,
    );
  }

  void _handleAdminTool(String value) {
    switch (value) {
      case 'generate':
        _openGenerateTimetableForm();
      case 'import':
        _importTimetableCsv();
      case 'add':
        _openAddPeriodForm();
      case 'substitute':
        _openSubstitutionForm();
    }
  }

  void _openClass(Map<String, dynamic> row) {
    setState(() {
      _homeMode = _AdminTimetableHomeMode.classes;
      _selectedSectionId = _text(row['section_id']);
      _selectedPeriod = null;
      _detailMode = _AdminTimetableDetailMode.classDay;
    });
  }

  void _openTeacher(Map<String, dynamic> row) {
    setState(() {
      _homeMode = _AdminTimetableHomeMode.teachers;
      _selectedStaffId = _text(row['staff_id']);
      _selectedPeriod = null;
      _detailMode = _AdminTimetableDetailMode.teacher;
    });
  }

  void _openRoom(Map<String, dynamic> row) {
    setState(() {
      _homeMode = _AdminTimetableHomeMode.rooms;
      _selectedRoomId = _text(row['room_id']);
      _selectedPeriod = null;
      _detailMode = _AdminTimetableDetailMode.room;
    });
  }

  void _openDayDetails(Map<String, dynamic> period) {
    setState(() {
      _selectedPeriod = period;
      _selectedSectionId = _text(
        period['section_id'],
        fallback: _selectedSectionId,
      );
      _selectedDay = _int(period['day_of_week']).clamp(1, 6).toInt();
      _filterDay = _selectedDay;
      _detailMode = _AdminTimetableDetailMode.dayDetails;
    });
  }

  void _openPeriodClassDay(Map<String, dynamic> period) {
    if (_isBreakSlot(period) || _isFree(period)) return;
    _openDayDetails(period);
  }

  void _goBack() {
    if (_detailMode == _AdminTimetableDetailMode.classWeek ||
        _detailMode == _AdminTimetableDetailMode.dayDetails) {
      setState(() => _detailMode = _AdminTimetableDetailMode.classDay);
      return;
    }
    if (_detailMode != _AdminTimetableDetailMode.home) {
      setState(() => _detailMode = _AdminTimetableDetailMode.home);
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _openGenerateTimetableForm() async {
    if (_selectedSection == null) {
      _showSnack('Select a class before generating timetable.');
      return;
    }
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminTimetableGenerationForm,
      arguments: AdminTimetableGenerationFormArgs(
        classLabel: _selectedClassLabel,
        section: _selectedSection,
        academicYear: _currentAcademicYear,
        termId: _currentTermId,
        dayLabel: _dayLabel(_selectedDay),
        dayNumber: _selectedDay,
      ),
    );
    await _handleTimetableResult(result);
  }

  Future<void> _importTimetableCsv() async {
    final imported = await BulkCsvImportService.importCsv(
      context,
      BulkCsvImportTarget.classTimetables,
    );
    if (imported && mounted) await _loadBackendTimetable();
  }

  Future<void> _openAddPeriodForm() async {
    if (_selectedSection == null) {
      _showSnack('Select a class before adding a period.');
      return;
    }
    final periods = _periodsForClass(_selectedSectionId, _selectedDay);
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminTimetablePeriodForm,
      arguments: AdminTimetablePeriodFormArgs(
        classLabel: _selectedClassLabel,
        section: _selectedSection,
        academicYear: _currentAcademicYear,
        termId: _currentTermId,
        dayLabel: _dayLabel(_selectedDay),
        dayNumber: _selectedDay,
        nextPeriodNumber: periods.length + 1,
        subjects: _subjects,
        staff: _staff,
        rooms: _rooms,
      ),
    );
    await _handleTimetableResult(result);
  }

  Future<void> _openEditPeriodForm(Map<String, dynamic> period) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminTimetablePeriodForm,
      arguments: AdminTimetablePeriodFormArgs(
        classLabel: _selectedClassLabel,
        section: _selectedSection,
        academicYear: _currentAcademicYear,
        termId: _currentTermId,
        dayLabel: _dayLabel(_selectedDay),
        dayNumber: _selectedDay,
        nextPeriodNumber: _int(period['period_number']),
        subjects: _subjects,
        staff: _staff,
        rooms: _rooms,
        period: period,
      ),
    );
    await _handleTimetableResult(result);
  }

  Future<void> _openSubstitutionForm({Map<String, dynamic>? period}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminTimetableSubstitutionForm,
      arguments: AdminTimetableSubstitutionFormArgs(
        classLabel: _selectedClassLabel,
        dayLabel: _dayLabel(_selectedDay),
        periods: _periodsForClass(_selectedSectionId, _selectedDay),
        staff: _staff,
        initialPeriod: period,
      ),
    );
    await _handleTimetableResult(result);
  }

  Future<void> _handleTimetableResult(Object? result) async {
    if (!mounted || result is! AdminTimetableFormResult) return;
    await _loadBackendTimetable();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _deletePeriod(Map<String, dynamic> period) async {
    final id = _text(period['id']);
    if (id.isEmpty) return;
    try {
      await BackendApiClient.instance.deleteRaw('/timetable/slots/$id');
      await _loadBackendTimetable();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Timetable period deleted'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete timetable period: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _openTeacherWeekPreview() async {
    final row = _selectedTeacherRow;
    if (row == null) return;
    final periods = _periodsForTeacher(_selectedStaffId, null);
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
                child: _weekGrid(periods),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLegendSheet() async {
    final periods = _periodsForClass(_selectedSectionId, null);
    final subjects = <String, String>{};
    for (final period in periods) {
      final subject = _subjectName(period);
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
                      _MiniPill(
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
    final periods = _periodsForClass(_selectedSectionId, null);
    if (periods.isEmpty) {
      _showSnack('No timetable data available to export.');
      return;
    }
    final bytes = await _weekPdfBytes(periods);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${_safeFileSegment(_selectedClassLabel)}-timetable.pdf',
    );
  }

  Future<void> _shareDaySummary() async {
    final periods = _periodsForClass(_selectedSectionId, _selectedDay);
    if (periods.isEmpty) {
      _showSnack('No day schedule available to share.');
      return;
    }
    final bytes = await _dayPdfBytes(periods);
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          '${_safeFileSegment(_selectedClassLabel)}-${_dayLabel(_selectedDay).toLowerCase()}-schedule.pdf',
    );
  }

  Future<Uint8List> _weekPdfBytes(List<Map<String, dynamic>> periods) async {
    final pdf = pw.Document();
    final maxPeriod = periods
        .map((row) => _int(row['period_number']))
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
          pw.Text(_selectedClassLabel),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Time / Period', ..._dayShortLabels],
            data: [
              for (var period = 1; period <= maxPeriod; period++)
                [
                  _periodTimeLabel(periods, period),
                  for (var day = 1; day <= _dayShortLabels.length; day++)
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

  Future<Uint8List> _dayPdfBytes(List<Map<String, dynamic>> periods) async {
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
          pw.Text(_selectedClassLabel),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Period', 'Time', 'Subject', 'Teacher', 'Room'],
            data: [
              for (final row in sorted)
                [
                  _isBreakSlot(row) ? '-' : '${_int(row['period_number'])}',
                  _slotTime(row),
                  _subjectName(row),
                  _isBreakSlot(row) ? '-' : _staffName(row),
                  _isBreakSlot(row) ? '-' : _roomName(row),
                ],
            ],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  List<Map<String, dynamic>> get _classRows {
    return [
      for (final section in _sections)
        {
          'section_id': section.id,
          'grade_id': section.gradeId,
          'academic_year_id': section.academicYearId,
          'class_name': _sectionLabel(section),
          'class_teacher': section.classTeacherName,
          'room_name': section.roomNumber,
          'capacity': section.capacity,
          'slot_count': _periodsForClass(section.id, null).length,
          'teacher_count': _distinctCount(
            _periodsForClass(section.id, null),
            'staff_id',
          ),
          'subject_count': _distinctCount(
            _periodsForClass(section.id, null),
            'subject_id',
          ),
        },
    ];
  }

  List<Map<String, dynamic>> get _teacherRows {
    final rows = <Map<String, dynamic>>[];
    for (final staff in _staff) {
      final periods = _slots
          .where((slot) => _text(slot['staff_id']) == staff.id)
          .toList();
      if (periods.isEmpty && _search.trim().isEmpty) continue;
      rows.add({
        'staff_id': staff.id,
        'teacher_name': _staffLabel(staff),
        'department_name': (staff.departmentName ?? '').trim(),
        'periods': periods.length,
        'classes': _distinctCount(periods, 'section_id'),
        'subjects': _distinctCount(periods, 'subject_id'),
        'workload_state': _workloadState(periods.length),
      });
    }
    rows.sort((a, b) => _int(b['periods']).compareTo(_int(a['periods'])));
    return rows;
  }

  List<Map<String, dynamic>> get _roomRows {
    final roomIds = <String>{};
    final rows = <Map<String, dynamic>>[];
    for (final room in _rooms) {
      final id = _text(room['id']);
      if (id.isEmpty || !roomIds.add(id)) continue;
      final periods = _slots
          .where((slot) => _text(slot['room_id']) == id)
          .toList();
      rows.add({
        'room_id': id,
        'room_name': _roomLabel(room),
        'room_type': _text(room['room_type'] ?? room['type']),
        'capacity': _int(room['capacity']),
        'periods': periods.length,
        'classes': _distinctCount(periods, 'section_id'),
        'conflicts': _roomConflictCount(periods),
        'is_lab_room': _roomIsLab(room),
      });
    }
    for (final slot in _slots) {
      final id = _text(slot['room_id']);
      if (id.isEmpty || !roomIds.add(id)) continue;
      final periods = _slots
          .where((row) => _text(row['room_id']) == id)
          .toList();
      rows.add({
        'room_id': id,
        'room_name': _roomName(slot),
        'capacity': _int(slot['room_capacity']),
        'periods': periods.length,
        'classes': _distinctCount(periods, 'section_id'),
        'conflicts': _roomConflictCount(periods),
        'is_lab_room': _roomName(slot).toLowerCase().contains('lab'),
      });
    }
    rows.sort((a, b) => _text(a['room_name']).compareTo(_text(b['room_name'])));
    return rows;
  }

  List<Map<String, dynamic>> _periodsForClass(String sectionId, int? day) {
    return _slots.where((slot) {
      return _text(slot['section_id']) == sectionId &&
          (day == null || _int(slot['day_of_week']) == day);
    }).toList();
  }

  List<Map<String, dynamic>> _periodsForTeacher(String staffId, int? day) {
    return _slots.where((slot) {
      return _text(slot['staff_id']) == staffId &&
          (day == null || _int(slot['day_of_week']) == day);
    }).toList();
  }

  List<Map<String, dynamic>> _periodsForRoom(String roomId, int? day) {
    return _slots.where((slot) {
      return _text(slot['room_id']) == roomId &&
          (day == null || _int(slot['day_of_week']) == day);
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
    for (final slot in _slots) {
      if (_int(slot['day_of_week']) != day) continue;
      final period = _int(slot['period_number']);
      if (period > 0) references.putIfAbsent(period, () => slot);
    }
    final occupiedByPeriod = <int, List<Map<String, dynamic>>>{};
    for (final slot in occupied) {
      final period = _int(slot['period_number']);
      if (period > 0) occupiedByPeriod.putIfAbsent(period, () => []).add(slot);
    }
    final rows = <Map<String, dynamic>>[];
    for (var period = 1; period <= maxPeriod; period++) {
      final matches = occupiedByPeriod[period] ?? const [];
      if (matches.isNotEmpty) {
        rows.addAll(matches);
        continue;
      }
      final reference = references[period];
      if (reference != null && _isBreakSlot(reference)) {
        rows.add({
          ...reference,
          'id': '',
          'class_name': _subjectName(reference),
        });
        continue;
      }
      rows.add({
        'day_of_week': day,
        'period_number': period,
        'start_time': _text(reference?['start_time']),
        'end_time': _text(reference?['end_time']),
        'subject_name': freeLabel,
        'slot_type': 'free',
        'class_name': freeLabel,
      });
    }
    return rows;
  }

  bool _matchesSearch(Map<String, dynamic> row) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return true;
    return row.values.any(
      (value) => _text(value).toLowerCase().contains(query),
    );
  }

  void _reconcileSelections() {
    if (_selectedSectionId.isEmpty && _sections.isNotEmpty) {
      _selectedSectionId = _sections.first.id;
    }
    if (!_sections.any((section) => section.id == _selectedSectionId)) {
      _selectedSectionId = _sections.isEmpty ? '' : _sections.first.id;
    }
    if (_selectedStaffId.isEmpty && _teacherRows.isNotEmpty) {
      _selectedStaffId = _text(_teacherRows.first['staff_id']);
    }
    if (_selectedRoomId.isEmpty && _roomRows.isNotEmpty) {
      _selectedRoomId = _text(_roomRows.first['room_id']);
    }
  }

  Map<String, dynamic>? get _selectedClassRow {
    for (final row in _classRows) {
      if (_text(row['section_id']) == _selectedSectionId) return row;
    }
    return null;
  }

  Map<String, dynamic>? get _selectedTeacherRow {
    for (final row in _teacherRows) {
      if (_text(row['staff_id']) == _selectedStaffId) return row;
    }
    return null;
  }

  Map<String, dynamic>? get _selectedRoomRow {
    for (final row in _roomRows) {
      if (_text(row['room_id']) == _selectedRoomId) return row;
    }
    return null;
  }

  SectionModel? get _selectedSection {
    for (final section in _sections) {
      if (section.id == _selectedSectionId) return section;
    }
    return null;
  }

  AcademicYearModel? get _currentAcademicYear =>
      _currentAcademicYearFrom(_academicYears);

  AcademicYearModel? _currentAcademicYearFrom(List<AcademicYearModel> years) {
    for (final year in years) {
      if (year.isCurrent) return year;
    }
    return years.isEmpty ? null : years.first;
  }

  String get _currentTermId => _terms.isEmpty ? '' : _text(_terms.first['id']);

  String get _selectedClassLabel => _sectionLabel(_selectedSection);

  String get _selectedTeacherName => _text(
    _selectedTeacherRow?['teacher_name'],
    fallback: 'Teacher Timetable',
  );

  String get _selectedTeacherDepartment => _text(
    _selectedTeacherRow?['department_name'],
    fallback: 'Department not assigned',
  );

  String get _selectedRoomName =>
      _text(_selectedRoomRow?['room_name'], fallback: 'Room');

  String get _selectedRoomCapacityLabel =>
      _capacityLabel(_selectedRoomRow ?? const {});

  String _sectionLabel(SectionModel? section) {
    if (section == null) return 'No class selected';
    final grade = section.gradeName.trim();
    final name = section.sectionName.trim();
    if (grade.isEmpty && name.isEmpty) return section.id;
    if (grade.isEmpty) return 'Section $name';
    if (name.isEmpty) return grade;
    return '$grade - $name';
  }

  String _slotClassName(Map<String, dynamic> slot) {
    final direct = _text(slot['class_name']);
    if (direct.isNotEmpty) return direct;
    for (final section in _sections) {
      if (section.id == _text(slot['section_id'])) {
        return _sectionLabel(section);
      }
    }
    return 'Class';
  }

  String _subjectName(Map<String, dynamic> slot) {
    final breakLabel = _breakLabelFromSlotType(slot);
    if (breakLabel.isNotEmpty) return breakLabel;
    final subject = slot['subject'];
    if (subject is Map) {
      return _text(
        subject['subject_name'] ?? subject['name'],
        fallback: 'Subject',
      );
    }
    return _text(
      slot['subject_name'] ?? slot['subject_id'],
      fallback: 'Subject',
    );
  }

  String _staffName(Map<String, dynamic> slot) {
    if (_isBreakSlot(slot)) return '-';
    final staff = slot['staff'];
    if (staff is Map) {
      final name = _text(staff['name']);
      if (name.isNotEmpty) return name;
      final fullName =
          '${_text(staff['first_name'])} ${_text(staff['last_name'])}'.trim();
      if (fullName.isNotEmpty) return fullName;
    }
    for (final item in _staff) {
      if (item.id == _text(slot['staff_id'])) return _staffLabel(item);
    }
    return _text(
      slot['staff_name'] ?? slot['teacher_name'] ?? slot['staff_id'],
      fallback: 'Teacher pending',
    );
  }

  String _staffLabel(StaffModel staff) {
    final name = staff.fullName.trim();
    if (name.isNotEmpty) return name;
    final email = (staff.email ?? '').trim();
    return email.isEmpty ? staff.id : email;
  }

  String _roomName(Map<String, dynamic> slot) {
    if (_isBreakSlot(slot)) return '-';
    final room = slot['room'];
    if (room is Map) {
      final name = _text(room['room_number'] ?? room['name']);
      if (name.isNotEmpty) return name;
    }
    return _text(
      slot['room_name'] ?? slot['room'] ?? slot['room_id'],
      fallback: 'Room pending',
    );
  }

  String _roomLabel(Map<String, dynamic> room) {
    final name = _text(room['room_number'] ?? room['name']);
    if (name.isNotEmpty) return name;
    return _text(room['id'], fallback: 'Room');
  }

  String _slotTime(Map<String, dynamic> slot) {
    final start = _text(slot['start_time']);
    final end = _text(slot['end_time']);
    if (start.isEmpty && end.isEmpty) return 'Time pending';
    if (end.isEmpty) return start;
    return '$start - $end';
  }

  String _dayLabel(int day) =>
      _dayFullLabels[(day - 1).clamp(0, _dayFullLabels.length - 1)];

  String _periodTimeLabel(List<Map<String, dynamic>> rows, int period) {
    for (final row in rows) {
      if (_int(row['period_number']) == period) {
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
    final breakRows = rows.where(_isBreakSlot).toList();
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
          _int(row['period_number']) == period) {
        return _subjectAbbreviation(_subjectName(row));
      }
    }
    return '';
  }

  String _subjectAbbreviation(String subject) {
    final upper = subject.trim().toUpperCase();
    if (upper.isEmpty) return '';
    if (upper.contains('MATHEMAT')) return 'MATH';
    if (upper.contains('ENGLISH')) return 'EN';
    if (upper.contains('SCIENCE')) return 'SCI';
    if (upper.contains('HINDI')) return 'HI';
    if (upper.contains('PHYSICAL')) return 'PE';
    if (upper.contains('SOCIAL')) return 'ST';
    if (upper.contains('ACTIVITY')) return 'ACT';
    if (upper.contains('LUNCH')) return 'Lunch';
    if (upper.contains('BREAK')) return 'Break';
    return upper.length <= 5 ? upper : upper.substring(0, 5);
  }

  VoidCallback? _weekCellTap(
    List<Map<String, dynamic>> rows,
    int day,
    int period,
  ) {
    if (_detailMode != _AdminTimetableDetailMode.classWeek) return null;
    for (final row in rows) {
      if (_int(row['day_of_week']) == day &&
          _int(row['period_number']) == period &&
          !_isBreakSlot(row)) {
        return () => _openDayDetails(row);
      }
    }
    return null;
  }

  bool _isBreakSlot(Map<String, dynamic> slot) {
    final slotType = _text(slot['slot_type']).toLowerCase();
    final subject = _subjectName(slot).toLowerCase();
    return slotType.contains('break') ||
        subject.contains('break') ||
        subject.contains('lunch');
  }

  bool _isFree(Map<String, dynamic> slot) {
    final slotType = _text(slot['slot_type']).toLowerCase();
    final subject = _subjectName(slot).toLowerCase();
    return slotType.contains('free') || subject.contains('free');
  }

  String _breakLabelFromSlotType(Map<String, dynamic> slot) {
    final slotType = _text(slot['slot_type']);
    if (!slotType.toLowerCase().startsWith('break')) return '';
    final parts = slotType.split(':');
    if (parts.length < 2) return 'Break';
    final label = parts.sublist(1).join(':').trim();
    return label.isEmpty ? 'Break' : label;
  }

  int _maxPeriodForDay(int day) {
    var maxPeriod = 0;
    for (final slot in _slots) {
      if (_int(slot['day_of_week']) != day) continue;
      final period = _int(slot['period_number']);
      if (period > maxPeriod) maxPeriod = period;
    }
    return maxPeriod;
  }

  int _maxPeriodForWeek() {
    var maxPeriod = 0;
    for (final slot in _slots) {
      final period = _int(slot['period_number']);
      if (period > maxPeriod) maxPeriod = period;
    }
    return maxPeriod;
  }

  int _freePeriodsFor(String id, String key) {
    if (id.isEmpty) return 0;
    final idKey = key == 'room' ? 'room_id' : 'staff_id';
    final days = _slots
        .map((slot) => _int(slot['day_of_week']))
        .where((day) => day >= 1 && day <= 6)
        .toSet();
    final possible = days.length * _maxPeriodForWeek();
    if (possible <= 0) return 0;
    final occupied = _slots
        .where((slot) => _text(slot[idKey]) == id && !_isBreakSlot(slot))
        .length;
    return (possible - occupied).clamp(0, possible).toInt();
  }

  int _distinctCount(List<Map<String, dynamic>> rows, String key) {
    return rows
        .map((row) => _text(row[key]))
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;
  }

  int _roomConflictCount(List<Map<String, dynamic>> rows) {
    final grouped = <String, int>{};
    var conflicts = 0;
    for (final row in rows) {
      final key = '${_int(row['day_of_week'])}|${_int(row['period_number'])}';
      grouped[key] = (grouped[key] ?? 0) + 1;
    }
    for (final count in grouped.values) {
      if (count > 1) conflicts += count - 1;
    }
    return conflicts;
  }

  bool _roomIsLab(Map<String, dynamic> row) {
    final text =
        '${_text(row['room_number'] ?? row['name'])} ${_text(row['room_type'] ?? row['type'])}'
            .toLowerCase();
    return text.contains('lab') ||
        text.contains('science') ||
        text.contains('computer');
  }

  String _capacityLabel(Map<String, dynamic> row) {
    final capacity = _int(row['capacity'] ?? row['room_capacity']);
    final type = _text(row['room_type']);
    if (capacity <= 0) return type.isEmpty ? 'Capacity not set' : type;
    return type.isEmpty ? 'Capacity: $capacity' : '$type - Capacity: $capacity';
  }

  String _workloadState(int periods) {
    if (periods > 32) return 'Excess workload';
    if (periods >= 24) return 'Full workload';
    if (periods == 0) return 'No periods';
    return 'Balanced';
  }

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('excess') || lower.contains('conflict')) {
      return AppTheme.warning;
    }
    if (lower.contains('pending') || lower.contains('no period')) {
      return AppTheme.warning;
    }
    return AppTheme.success;
  }

  Color _subjectTone(String label) {
    final key = label.toUpperCase();
    if (key.contains('MATH')) return const Color(0xFFE0F7EA);
    if (key.contains('EN')) return const Color(0xFFE3F0FF);
    if (key.contains('SCI')) return const Color(0xFFE5FAFF);
    if (key.contains('HI')) return const Color(0xFFF0E7FF);
    if (key.contains('ART')) return const Color(0xFFFFE7F0);
    if (key.contains('PE')) return const Color(0xFFE0FBF4);
    if (key.contains('BREAK') || key.contains('LUNCH')) {
      return AppTheme.warningContainer;
    }
    return const Color(0xFFF2F6FA);
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

  BoxDecoration _softDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFDDE7F0)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF7FA6BD).withAlpha(34),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static int _slotSort(Map<String, dynamic> a, Map<String, dynamic> b) {
    final day = _int(a['day_of_week']).compareTo(_int(b['day_of_week']));
    if (day != 0) return day;
    return _int(a['period_number']).compareTo(_int(b['period_number']));
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    return '${value ?? ''}'.toLowerCase() == 'true';
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }
}

class _TimetableCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final List<Widget> chips;
  final VoidCallback? onTap;

  const _TimetableCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    this.chips = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDDE7F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7FA6BD).withAlpha(36),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF0877D8).withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF0877D8), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF172B3A),
                                ),
                          ),
                        ),
                        _StatusPill(label: status, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF667989),
                      ),
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: chips),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF667989)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDCE8F5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF667989)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF667989),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _ChoiceChipButton({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected ? const Color(0xFF0877D8) : Colors.white;
    final foreground = selected ? Colors.white : const Color(0xFF172B3A);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF0877D8) : const Color(0xFFD8E4EA),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

class _AdminTimetableBottomBar extends StatelessWidget {
  const _AdminTimetableBottomBar();

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    return SchoolDeskBottomNavigationBar(
      items: [
        SchoolDeskBottomNavItem(
          label: 'Home',
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          selected: currentRoute == AppRoutes.adminDashboard,
          onTap: () => Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.adminDashboard, (_) => false),
        ),
        SchoolDeskBottomNavItem(
          label: 'Search',
          icon: Icons.search_rounded,
          activeIcon: Icons.manage_search_rounded,
          selected: currentRoute == AppRoutes.globalSearch,
          onTap: () => Navigator.of(
            context,
          ).pushNamed(AppRoutes.globalSearch, arguments: 'admin'),
        ),
        SchoolDeskBottomNavItem(
          label: 'Inbox',
          icon: Icons.mail_outline_rounded,
          activeIcon: Icons.mail_rounded,
          selected: currentRoute == AppRoutes.adminCommunication,
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.adminCommunication),
        ),
        SchoolDeskBottomNavItem(
          label: 'Profile',
          icon: Icons.account_circle_outlined,
          activeIcon: Icons.account_circle_rounded,
          selected: currentRoute == AppRoutes.profileScreen,
          onTap: () => Navigator.of(
            context,
          ).pushNamed(AppRoutes.profileScreen, arguments: 'admin'),
        ),
      ],
    );
  }
}
