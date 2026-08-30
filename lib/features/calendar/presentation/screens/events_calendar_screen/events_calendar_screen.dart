import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/principal_directory_ui.dart';
import 'package:schooldesk1/core/widgets/teacher_navigation.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

enum _EventFilter {
  month,
  all,
  today,
  upcoming,
  holidays,
  approvals,
  cancelled,
}

enum _EventsDisplayMode { month, week, agenda }

enum _CalendarRecordKind { event, holiday, generatedHoliday }

enum SchoolCalendarPortal { principal, teacher, parent }

class EventsCalendarScreen extends StatefulWidget {
  final SchoolCalendarPortal portal;

  const EventsCalendarScreen({
    super.key,
    this.portal = SchoolCalendarPortal.principal,
  });

  @override
  State<EventsCalendarScreen> createState() => _EventsCalendarScreenState();
}

class _EventsCalendarScreenState extends State<EventsCalendarScreen> {
  List<_PrincipalEvent> _events = [];
  List<AcademicYearModel> _academicYears = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _selectedAcademicYearId = '';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  late DateTime _selectedWeekStart;
  _EventFilter _filter = _EventFilter.month;
  _EventsDisplayMode _displayMode = _EventsDisplayMode.month;
  String? _activeLegendFilter;
  bool _hideGeneratedHolidays = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedWeekStart = now.subtract(Duration(days: now.weekday - 1));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final years = await api.getAcademicYears();
      final selectedYearId = _selectedAcademicYearId.isNotEmpty
          ? _selectedAcademicYearId
          : _currentAcademicYearId(years);
      final results = await Future.wait<List<Map<String, dynamic>>>([
        api.getEvents(
          academicYearId: selectedYearId.isEmpty ? null : selectedYearId,
        ),
        api
            .getHolidays(
              academicYearId: selectedYearId.isEmpty ? null : selectedYearId,
            )
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);
      final rows = results[0];
      final holidayRows = results[1];
      Map<String, dynamic> preferences = const {};
      try {
        preferences = await api.getCalendarPreferences();
      } on Object catch (_) {
        // Calendar preferences are optional. A temporary preference failure
        // must not hide the actual event and holiday data.
      }
      final storedHolidays = holidayRows
          .map(_PrincipalEvent.fromHoliday)
          .whereType<_PrincipalEvent>()
          .toList();
      final generatedHolidays = preferences['hide_generated_holidays'] != true
          ? _getBuiltInHolidays(selectedYearId, years)
                .where(
                  (generated) => !storedHolidays.any(
                    (holiday) => holiday.overlapsDate(generated.start),
                  ),
                )
                .toList()
          : const <_PrincipalEvent>[];
      final events = [
        ...rows
            .where((row) => _clean(row['event_type']).toLowerCase() != 'ptm')
            .map(_PrincipalEvent.fromApi),
        ...storedHolidays,
        ...generatedHolidays,
      ]..sort((a, b) => a.start.compareTo(b.start));
      if (!mounted) return;
      // Derive the display year from the selected academic year's start date so
      // the calendar grid always renders the correct year (e.g. 2026 for a
      // 2026-2027 academic year), regardless of the current wall-clock year.
      int derivedYear = _selectedYear;
      DateTime? rangeStart;
      DateTime? rangeEnd;
      for (final y in years) {
        if (y.id == selectedYearId) {
          final start = DateTime.tryParse(y.startDate);
          final end = DateTime.tryParse(y.endDate);
          if (start != null) derivedYear = start.year;
          rangeStart = start;
          rangeEnd = end;
          break;
        }
      }
      final effectiveSelectedDate = _normalizeSelectedDate(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      setState(() {
        _academicYears = years;
        _selectedAcademicYearId = selectedYearId;
        _events = events;
        _hideGeneratedHolidays = preferences['hide_generated_holidays'] == true;
        _selectedYear = derivedYear;
        _selectedMonth = effectiveSelectedDate.month;
        _selectedDate = effectiveSelectedDate;
        _focusedDay = effectiveSelectedDate;
        _selectedWeekStart = _startOfWeek(effectiveSelectedDate);
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  String _currentAcademicYearId(List<AcademicYearModel> years) {
    final current = years.where((year) => year.isCurrent).toList();
    if (current.isNotEmpty) return current.first.id;
    return years.isNotEmpty ? years.first.id : '';
  }

  List<_PrincipalEvent> _getBuiltInHolidays(
    String academicYearId,
    List<AcademicYearModel> academicYears,
  ) {
    AcademicYearModel? selectedYear;
    for (final year in academicYears) {
      if (year.id == academicYearId) {
        selectedYear = year;
        break;
      }
    }
    final rangeStart = DateTime.tryParse(selectedYear?.startDate ?? '');
    final rangeEnd = DateTime.tryParse(selectedYear?.endDate ?? '');
    final firstYear = rangeStart?.year ?? DateTime.now().year;
    final lastYear = rangeEnd?.year ?? firstYear;
    final holidays = <(DateTime, String)>[];
    for (var year = firstYear; year <= lastYear; year++) {
      holidays.addAll([
        (DateTime(year, 1, 26), 'Republic Day'),
        (DateTime(year, 8, 15), 'Independence Day'),
        (DateTime(year, 10, 2), 'Gandhi Jayanti'),
        (DateTime(year, 12, 25), 'Christmas'),
      ]);
    }

    return holidays
        .where((holiday) {
          final date = holiday.$1;
          if (rangeStart != null && date.isBefore(rangeStart)) return false;
          if (rangeEnd != null && date.isAfter(rangeEnd)) return false;
          return true;
        })
        .map((h) {
          return _PrincipalEvent(
            id: 'builtin_${h.$1.millisecondsSinceEpoch}',
            academicYearId: academicYearId,
            title: h.$2,
            type: 'festival',
            status: 'scheduled',
            description: 'National holiday / Festival',
            venue: 'All',
            audienceValue: 'all',
            isHoliday: true,
            start: h.$1,
            end: h.$1.add(const Duration(hours: 23, minutes: 59)),
            recordKind: _CalendarRecordKind.generatedHoliday,
          );
        })
        .toList();
  }

  bool get _canManageEvents {
    if (widget.portal != SchoolCalendarPortal.principal) return false;
    final role = BackendApiClient.instance.currentRoleName
        ?.trim()
        .toLowerCase();
    return role == null ||
        role.isEmpty ||
        role == 'principal' ||
        role == 'coordinator';
  }

  bool get _isPrincipal {
    return BackendApiClient.instance.currentRoleName?.trim().toLowerCase() ==
        'principal';
  }

  AcademicYearModel? get _selectedAcademicYear {
    for (final year in _academicYears) {
      if (year.id == _selectedAcademicYearId) return year;
    }
    return null;
  }

  List<_PrincipalEvent> get _visibleEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final query = _query.trim().toLowerCase();
    final rows = _events.where((event) {
      final matchesSearch =
          query.isEmpty ||
          [
            event.title,
            event.type,
            event.status,
            event.venue,
            event.audience,
            event.description,
          ].join(' ').toLowerCase().contains(query);
      if (!matchesSearch) return false;

      if (_activeLegendFilter != null) {
        if (_activeLegendFilter == 'Holiday' && !event.isHoliday) return false;
        if (_activeLegendFilter == 'Festival' &&
            event.type != 'festival' &&
            event.type != 'cultural') {
          return false;
        }
        if (_activeLegendFilter == 'Academic' && !event.isAcademicEntry) {
          return false;
        }
        if (_activeLegendFilter == 'Approval' && !event.needsApproval) {
          return false;
        }
      }

      final matchesTimeFilter = switch (_filter) {
        _EventFilter.month => event.overlapsMonth(_selectedMonth),
        _EventFilter.all => true,
        _EventFilter.today => event.overlapsDate(today),
        _EventFilter.upcoming =>
          !event.start.isBefore(today) && !event.isCancelled,
        _EventFilter.holidays => event.isHoliday,
        _EventFilter.approvals => event.needsApproval,
        _EventFilter.cancelled => event.isCancelled,
      };
      if (!matchesTimeFilter) return false;
      return true;
    }).toList();
    rows.sort((a, b) => a.start.compareTo(b.start));
    return rows;
  }

  int get _calendarYear {
    return _monthDateForAcademicYear(_selectedMonth).year;
  }

  List<_PrincipalEvent> _eventsForDay(DateTime day) {
    final query = _query.trim().toLowerCase();
    final rows = _events.where((event) {
      if (!event.overlapsDate(day)) return false;

      if (_activeLegendFilter != null) {
        if (_activeLegendFilter == 'Holiday' && !event.isHoliday) return false;
        if (_activeLegendFilter == 'Festival' &&
            event.type != 'festival' &&
            event.type != 'cultural') {
          return false;
        }
        if (_activeLegendFilter == 'Academic' && !event.isAcademicEntry) {
          return false;
        }
        if (_activeLegendFilter == 'Approval' && !event.needsApproval) {
          return false;
        }
      }

      if (query.isEmpty) return true;
      return [
        event.title,
        event.type,
        event.status,
        event.venue,
        event.audience,
        event.description,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
    rows.sort((a, b) => a.start.compareTo(b.start));
    return rows;
  }

  List<_PrincipalEvent> get _selectedDayEvents => _eventsForDay(_selectedDate);

  DateTime _startOfWeek(DateTime day) => DateTime(
    day.year,
    day.month,
    day.day,
  ).subtract(Duration(days: day.weekday - 1));

  DateTime _normalizeSelectedDate({DateTime? rangeStart, DateTime? rangeEnd}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    if (rangeStart != null && rangeEnd != null) {
      final normalizedStart = DateTime(
        rangeStart.year,
        rangeStart.month,
        rangeStart.day,
      );
      final normalizedEnd = DateTime(
        rangeEnd.year,
        rangeEnd.month,
        rangeEnd.day,
      );
      if (today.isBefore(normalizedStart)) return normalizedStart;
      if (today.isAfter(normalizedEnd)) {
        return current.isBefore(normalizedStart)
            ? normalizedStart
            : normalizedEnd;
      }
      return today;
    }
    return today;
  }

  DateTime _monthDateForAcademicYear(int month) {
    final year = _selectedAcademicYear;
    final start = DateTime.tryParse(year?.startDate ?? '');
    final end = DateTime.tryParse(year?.endDate ?? '');
    if (start == null || end == null) {
      return DateTime(_selectedYear, month, 1);
    }
    final startMonth = start.month;
    final targetYear = month >= startMonth ? start.year : end.year;
    return DateTime(targetYear, month, 1);
  }

  DateTime get _calendarFirstDay {
    final year = _selectedAcademicYear;
    final start = DateTime.tryParse(year?.startDate ?? '');
    return start != null
        ? DateTime(start.year, start.month, start.day)
        : DateTime(_calendarYear - 1, 1, 1);
  }

  DateTime get _calendarLastDay {
    final year = _selectedAcademicYear;
    final end = DateTime.tryParse(year?.endDate ?? '');
    return end != null
        ? DateTime(end.year, end.month, end.day)
        : DateTime(_calendarYear + 1, 12, 31);
  }

  void _selectDay(DateTime selected, DateTime focused) {
    setState(() {
      _selectedDate = DateTime(selected.year, selected.month, selected.day);
      _focusedDay = DateTime(focused.year, focused.month, focused.day);
      _selectedMonth = focused.month;
      _selectedYear = focused.year;
      _selectedWeekStart = _startOfWeek(selected);
      if (_filter == _EventFilter.today) _filter = _EventFilter.month;
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selectDay(today, today);
  }

  Future<void> _showDayEventsSheet(
    DateTime day,
    List<_PrincipalEvent> events,
  ) async {
    if (events.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DateFormat('EEEE, d MMMM y').format(day),
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: principalDirectoryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${events.length} ${events.length == 1 ? 'event' : 'events'}',
                  style: GoogleFonts.dmSans(
                    color: principalDirectoryMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final event = events[index];
                      return _SelectedDayEventCard(
                        event: event,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _openDetails(event);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCreateEvent({DateTime? initialDate}) async {
    final saved = await Navigator.of(context).push<_EventFormResult>(
      MaterialPageRoute(
        builder: (_) => _EventFormPage(
          academicYears: _academicYears,
          selectedAcademicYearId: _selectedAcademicYearId,
          initialMonth: _selectedMonth,
          initialDate: initialDate,
        ),
      ),
    );
    if (saved != null) {
      setState(() {
        _selectedAcademicYearId = saved.academicYearId.isEmpty
            ? _selectedAcademicYearId
            : saved.academicYearId;
        _selectedMonth = saved.startDate.month;
        _selectedYear = saved.startDate.year;
        _selectedDate = DateTime(
          saved.startDate.year,
          saved.startDate.month,
          saved.startDate.day,
        );
        _focusedDay = _selectedDate;
        _selectedWeekStart = _startOfWeek(_selectedDate);
        _filter = _EventFilter.month;
        _displayMode = _EventsDisplayMode.month;
      });
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event created and calendar refreshed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openDetails(_PrincipalEvent event) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _EventDetailPage(
          event: event,
          academicYears: _academicYears,
          selectedAcademicYearId: _selectedAcademicYearId,
          canManage: _canManageEvents && event.isEventRecord,
          onAction: (action) => _handleEventAction(action, event),
        ),
      ),
    );
    if (changed == true) {
      await _loadData();
    }
  }

  Future<void> _openEditEvent(_PrincipalEvent event) async {
    final saved = await Navigator.of(context).push<_EventFormResult>(
      MaterialPageRoute(
        builder: (_) => _EventFormPage(
          academicYears: _academicYears,
          selectedAcademicYearId: event.academicYearId.isEmpty
              ? _selectedAcademicYearId
              : event.academicYearId,
          initialMonth: event.start.month,
          event: event,
        ),
      ),
    );
    if (saved != null) {
      setState(() {
        _selectedAcademicYearId = saved.academicYearId.isEmpty
            ? _selectedAcademicYearId
            : saved.academicYearId;
        _selectedMonth = saved.startDate.month;
        _selectedYear = saved.startDate.year;
        _selectedDate = DateTime(
          saved.startDate.year,
          saved.startDate.month,
          saved.startDate.day,
        );
        _focusedDay = _selectedDate;
        _selectedWeekStart = _startOfWeek(_selectedDate);
        _filter = _EventFilter.month;
        _displayMode = _EventsDisplayMode.month;
      });
      await _loadData();
    }
  }

  Future<bool> _confirmDelete(_PrincipalEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove event?'),
        content: Text(
          'This will remove "${event.title}" from the school calendar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.appTheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _confirmCalendarReset() async {
    final controller = TextEditingController();
    var canReset = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reset school calendar?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This removes all manually created events for this school. School posts and academic years are not affected. Generated holidays will stay hidden until you add fresh calendar entries.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Type RESET to confirm',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setDialogState(
                  () => canReset = value.trim().toUpperCase() == 'RESET',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: canReset
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: context.appTheme.error,
              ),
              child: const Text('Reset calendar'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;
    try {
      final result = await BackendApiClient.instance.resetSchoolCalendar();
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Calendar reset: ${result['events_deleted'] ?? 0} events removed.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to reset calendar: $error'),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _deleteEvent(_PrincipalEvent event) async {
    if (event.id.isEmpty) return false;
    final confirmed = await _confirmDelete(event);
    if (!confirmed) return false;
    try {
      await BackendApiClient.instance.deleteRaw('/events/${event.id}');
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${event.title} removed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    } on Object catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to remove event: $error'),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  Future<bool> _setEventStatus(_PrincipalEvent event, String status) async {
    if (event.id.isEmpty) return false;
    try {
      await BackendApiClient.instance.updateRaw('/events/${event.id}', {
        'status': status,
      });
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${event.title} marked ${_titleCase(status)}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    } on Object catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update event: $error'),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  Future<bool> _handleEventAction(String action, _PrincipalEvent event) async {
    switch (action) {
      case 'view':
        await _openDetails(event);
        return false;
      case 'edit':
        await _openEditEvent(event);
        return false;
      case 'approve':
        final changed = await _setEventStatus(event, 'approved');
        if (changed) await _loadData();
        return changed;
      case 'cancel':
        final changed = await _setEventStatus(event, 'cancelled');
        if (changed) await _loadData();
        return changed;
      case 'delete':
        final removed = await _deleteEvent(event);
        if (removed) await _loadData();
        return removed;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return _buildSharedCalendar();
  }

  Widget _buildSharedCalendar() {
    final compact = MediaQuery.sizeOf(context).width < 520;
    return SchoolDeskModuleScaffold(
      title: 'Academic Calendar',
      subtitle: _canManageEvents
          ? 'Create and manage school events, holidays, and milestones'
          : 'School events, holidays, and milestones',
      drawer: _schoolCalendarDrawer(),
      actions: _isPrincipal
          ? [
              IconButton(
                tooltip: 'Reset school calendar',
                onPressed: _loading ? null : _confirmCalendarReset,
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ]
          : const [],
      floatingActionButton: _canManageEvents
          ? compact
                ? FloatingActionButton(
                    onPressed: () =>
                        _openCreateEvent(initialDate: _selectedDate),
                    tooltip: 'Create event',
                    child: const Icon(Icons.add_rounded),
                  )
                : FloatingActionButton.extended(
                    onPressed: () =>
                        _openCreateEvent(initialDate: _selectedDate),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create event'),
                  )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildCalendarSummary()),
            SliverToBoxAdapter(child: _buildFilters()),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EmptyStateWidget(
                        icon: Icons.cloud_off_rounded,
                        title: 'Unable to load calendar',
                        description: _error!,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (_displayMode == _EventsDisplayMode.agenda)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, compact ? 136 : 88),
                  sliver: SliverToBoxAdapter(child: _buildAgendaView()),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, compact ? 136 : 88),
                  sliver: SliverToBoxAdapter(child: _buildCalendarView()),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _schoolCalendarDrawer() {
    switch (widget.portal) {
      case SchoolCalendarPortal.principal:
        return PrincipalDrawer(
          selectedIndex: PrincipalNav.calendar,
          onDestinationSelected: (_) {},
        );
      case SchoolCalendarPortal.teacher:
        return TeacherDrawer(
          selectedIndex: TeacherNav.calendar,
          onDestinationSelected: (_) {},
        );
      case SchoolCalendarPortal.parent:
        return ParentDrawer(
          selectedIndex: ParentNav.calendar,
          onDestinationSelected: (_) {},
        );
    }
  }

  Widget _buildCalendarSummary() {
    final today = DateTime.now();
    final upcoming = _events
        .where(
          (event) =>
              !event.isCancelled &&
              !event.start.isBefore(
                DateTime(today.year, today.month, today.day),
              ),
        )
        .length;
    final holidays = _events.where((event) => event.isHoliday).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [context.appTheme.primary, context.appTheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: context.appTheme.primary.withAlpha(55),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              color: context.appTheme.onPrimary,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat(
                      'MMMM y',
                    ).format(_monthDateForAcademicYear(_selectedMonth)),
                    style: GoogleFonts.dmSans(
                      color: context.appTheme.onPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$upcoming upcoming  •  ${_hideGeneratedHolidays ? 'custom holidays only' : '$holidays holidays'}',
                    style: GoogleFonts.dmSans(
                      color: context.appTheme.onPrimary.withAlpha(220),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _goToToday,
              style: TextButton.styleFrom(
                foregroundColor: context.appTheme.primary,
                backgroundColor: context.appTheme.onPrimary,
              ),
              child: const Text('Today'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    final focusedDay = _displayMode == _EventsDisplayMode.week
        ? _selectedWeekStart
        : _focusedDay;
    final monthEventCount = _visibleEvents
        .where((event) => event.overlapsMonth(_selectedMonth))
        .length;
    return _CalendarPanel(
      title: DateFormat(
        'MMMM y',
      ).format(_monthDateForAcademicYear(_selectedMonth)),
      monthEventCount: monthEventCount,
      selectedDate: _selectedDate,
      focusedDay: focusedDay,
      firstDay: _calendarFirstDay,
      lastDay: _calendarLastDay,
      format: _displayMode == _EventsDisplayMode.week
          ? CalendarFormat.week
          : CalendarFormat.month,
      eventsForDay: _eventsForDay,
      onDaySelected: _selectDay,
      onToday: _goToToday,
      onOpenAgenda: () {
        setState(() => _displayMode = _EventsDisplayMode.agenda);
      },
      onIndicatorTap: _showDayEventsSheet,
      selectedDayContent: _buildSelectedDayAgenda(),
    );
  }

  Widget _buildAgendaView() {
    final events = _visibleEvents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AgendaSummaryCard(
          title: DateFormat(
            'MMMM y',
          ).format(_monthDateForAcademicYear(_selectedMonth)),
          subtitle: events.isEmpty
              ? 'No entries match the current search and filters.'
              : '${events.length} ${events.length == 1 ? 'entry' : 'entries'} in this view',
          onToday: _goToToday,
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          _buildSelectedDayEmptyState(
            title: 'No calendar entries found',
            message: 'Try another month or reset the active category filter.',
            showCreate: false,
          )
        else
          ...events.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SelectedDayEventCard(
                event: event,
                showDate: true,
                onTap: () => _openDetails(event),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedDayAgenda() {
    final events = _selectedDayEvents;
    final showInlineCreate =
        _canManageEvents && MediaQuery.sizeOf(context).width >= 520;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Selected: ${DateFormat('EEEE, d MMMM y').format(_selectedDate)}',
          style: GoogleFonts.dmSans(
            color: principalDirectoryText,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${events.length} ${events.length == 1 ? 'event' : 'events'}',
          style: GoogleFonts.dmSans(
            color: principalDirectoryMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          _buildSelectedDayEmptyState(
            title: 'No events scheduled',
            message: _canManageEvents
                ? showInlineCreate
                      ? 'Add the first event for this day, or choose another date.'
                      : 'Use the + button to add the first event for this day, or choose another date.'
                : 'Choose another date or check back when the school adds an event.',
            showCreate: showInlineCreate,
          )
        else
          ...events.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SelectedDayEventCard(
                event: event,
                onTap: () => _openDetails(event),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedDayEmptyState({
    required String title,
    required String message,
    required bool showCreate,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              color: principalDirectoryText,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          if (showCreate) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openCreateEvent(initialDate: _selectedDate),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create event'),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            message,
            style: GoogleFonts.dmSans(
              color: principalDirectoryMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final yearField = _academicYears.length > 1
              ? DropdownButtonFormField<String>(
                  initialValue: _selectedAcademicYearId.isEmpty
                      ? null
                      : _selectedAcademicYearId,
                  decoration: const InputDecoration(
                    labelText: 'Academic year',
                    prefixIcon: Icon(Icons.school_rounded),
                  ),
                  items: _academicYears
                      .map(
                        (year) => DropdownMenuItem(
                          value: year.id,
                          child: Text(year.yearLabel),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null || value == _selectedAcademicYearId) {
                      return;
                    }
                    setState(() => _selectedAcademicYearId = value);
                    await _loadData();
                  },
                )
              : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (yearField == null || constraints.maxWidth < 640) ...[
                PrincipalDirectorySearchBox(
                  hint: 'Search event, holiday, venue, audience...',
                  onChanged: (value) => setState(() => _query = value),
                ),
                if (yearField != null) ...[
                  const SizedBox(height: 10),
                  yearField,
                ],
              ] else
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: PrincipalDirectorySearchBox(
                        hint: 'Search event, holiday, venue, audience...',
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: yearField),
                  ],
                ),
              const SizedBox(height: 10),
              _buildDisplayModeSelector(),
              const SizedBox(height: 8),
              _buildMonthStrip(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDisplayModeSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        return SegmentedButton<_EventsDisplayMode>(
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: compact
                ? const VisualDensity(horizontal: -2, vertical: -1)
                : VisualDensity.standard,
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? principalDirectoryAccent
                  : Colors.white;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? Colors.white
                  : principalDirectoryText;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              return BorderSide(
                color: states.contains(WidgetState.selected)
                    ? principalDirectoryAccent
                    : const Color(0xFFD5E4F1),
              );
            }),
          ),
          segments: [
            const ButtonSegment(
              value: _EventsDisplayMode.month,
              icon: Icon(Icons.calendar_month_rounded),
              label: Text('Month'),
            ),
            const ButtonSegment(
              value: _EventsDisplayMode.week,
              icon: Icon(Icons.view_week_rounded),
              label: Text('Week'),
            ),
            const ButtonSegment(
              value: _EventsDisplayMode.agenda,
              icon: Icon(Icons.view_agenda_rounded),
              label: Text('Agenda'),
            ),
          ],
          selected: {_displayMode},
          onSelectionChanged: (value) {
            setState(() => _displayMode = value.first);
          },
        );
      },
    );
  }

  Widget _buildMonthStrip() {
    final startMonth = _selectedAcademicYear == null
        ? 1
        : (DateTime.tryParse(_selectedAcademicYear!.startDate)?.month ?? 1);
    final months = [
      ...List.generate(12 - startMonth + 1, (index) => startMonth + index),
      ...List.generate(startMonth - 1, (index) => index + 1),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: months.map((month) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PrincipalDirectoryChip(
              label: _monthName(month),
              selected: _selectedMonth == month,
              onTap: () => setState(() {
                final target = _monthDateForAcademicYear(month);
                _selectedMonth = month;
                _selectedYear = target.year;
                _selectedDate = DateTime(
                  target.year,
                  target.month,
                  _selectedDate.day.clamp(
                    1,
                    DateUtils.getDaysInMonth(target.year, target.month),
                  ),
                );
                _focusedDay = _selectedDate;
                _selectedWeekStart = _startOfWeek(_selectedDate);
                _filter = _EventFilter.month;
              }),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  final String title;
  final int monthEventCount;
  final DateTime selectedDate;
  final DateTime focusedDay;
  final DateTime firstDay;
  final DateTime lastDay;
  final CalendarFormat format;
  final List<_PrincipalEvent> Function(DateTime day) eventsForDay;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final VoidCallback onToday;
  final VoidCallback onOpenAgenda;
  final Future<void> Function(DateTime day, List<_PrincipalEvent> events)
  onIndicatorTap;
  final Widget selectedDayContent;

  const _CalendarPanel({
    required this.title,
    required this.monthEventCount,
    required this.selectedDate,
    required this.focusedDay,
    required this.firstDay,
    required this.lastDay,
    required this.format,
    required this.eventsForDay,
    required this.onDaySelected,
    required this.onToday,
    required this.onOpenAgenda,
    required this.onIndicatorTap,
    required this.selectedDayContent,
  });

  @override
  Widget build(BuildContext context) {
    final smallScreen = MediaQuery.sizeOf(context).width < 380;
    return Container(
      padding: EdgeInsets.all(smallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE8F4)),
        boxShadow: [
          BoxShadow(
            color: context.appTheme.onSurface.withAlpha(10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      color: principalDirectoryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: onOpenAgenda,
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            monthEventCount == 0
                                ? '0 calendar entries'
                                : '$monthEventCount calendar entries',
                            style: GoogleFonts.dmSans(
                              color: principalDirectoryMuted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: principalDirectoryMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Semantics(
                button: true,
                label: 'Go to today',
                child: Tooltip(
                  message: 'Go to today',
                  child: OutlinedButton.icon(
                    onPressed: onToday,
                    icon: const Icon(Icons.today_rounded),
                    label: const Text('Today'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TableCalendar<_PrincipalEvent>(
            firstDay: firstDay,
            lastDay: lastDay,
            focusedDay: focusedDay,
            headerVisible: false,
            daysOfWeekHeight: 30,
            calendarFormat: format,
            availableGestures: AvailableGestures.horizontalSwipe,
            selectedDayPredicate: (day) => isSameDay(day, selectedDate),
            eventLoader: eventsForDay,
            rowHeight: format == CalendarFormat.month
                ? (smallScreen ? 52 : 68)
                : (smallScreen ? 76 : 88),
            onDaySelected: onDaySelected,
            onPageChanged: (focused) => onDaySelected(
              isSameDay(selectedDate, focused) ? selectedDate : focused,
              focused,
            ),
            calendarBuilders: CalendarBuilders<_PrincipalEvent>(
              dowBuilder: (context, day) => Center(
                child: Text(
                  DateFormat('EEE').format(day),
                  style: GoogleFonts.dmSans(
                    color: day.weekday >= DateTime.saturday
                        ? const Color(0xFF9A5A3A)
                        : principalDirectoryMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              defaultBuilder: (context, day, focusedDay) => _CalendarDateCell(
                day: day,
                events: eventsForDay(day),
                isWeekend: day.weekday >= DateTime.saturday,
                onTap: () => onDaySelected(day, focusedDay),
                onIndicatorTap: () => onIndicatorTap(day, eventsForDay(day)),
              ),
              todayBuilder: (context, day, focusedDay) => _CalendarDateCell(
                day: day,
                events: eventsForDay(day),
                isToday: true,
                isWeekend: day.weekday >= DateTime.saturday,
                onTap: () => onDaySelected(day, focusedDay),
                onIndicatorTap: () => onIndicatorTap(day, eventsForDay(day)),
              ),
              selectedBuilder: (context, day, focusedDay) => _CalendarDateCell(
                day: day,
                events: eventsForDay(day),
                isSelected: true,
                isToday: isSameDay(day, DateTime.now()),
                isWeekend: day.weekday >= DateTime.saturday,
                onTap: () => onDaySelected(day, focusedDay),
                onIndicatorTap: () => onIndicatorTap(day, eventsForDay(day)),
              ),
              outsideBuilder: (context, day, focusedDay) => _CalendarDateCell(
                day: day,
                events: eventsForDay(day),
                isOutsideMonth: true,
                isWeekend: day.weekday >= DateTime.saturday,
                onTap: () => onDaySelected(day, focusedDay),
                onIndicatorTap: () => onIndicatorTap(day, eventsForDay(day)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          selectedDayContent,
        ],
      ),
    );
  }
}

class _CalendarDateCell extends StatelessWidget {
  final DateTime day;
  final List<_PrincipalEvent> events;
  final bool isSelected;
  final bool isToday;
  final bool isWeekend;
  final bool isOutsideMonth;
  final VoidCallback onTap;
  final VoidCallback onIndicatorTap;

  const _CalendarDateCell({
    required this.day,
    required this.events,
    required this.onTap,
    required this.onIndicatorTap,
    this.isSelected = false,
    this.isToday = false,
    this.isWeekend = false,
    this.isOutsideMonth = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = events.isNotEmpty
        ? events.first.typeColor
        : principalDirectoryAccent;
    final background = isSelected
        ? primary.withAlpha(72)
        : isToday
        ? const Color(0xFFEAF4FF)
        : isWeekend
        ? const Color(0xFFFFF8F1)
        : const Color(0xFFF9FBFE);
    final border = isSelected
        ? primary
        : isToday
        ? principalDirectoryAccent
        : isWeekend
        ? const Color(0xFFF3D6BB)
        : const Color(0xFFE4ECF5);
    final textColor = isOutsideMonth
        ? principalDirectoryMuted.withAlpha(150)
        : isSelected || isToday
        ? principalDirectoryText
        : isWeekend
        ? const Color(0xFF8B4C2F)
        : principalDirectoryText;

    return Semantics(
      button: true,
      label:
          '${DateFormat('EEEE d MMMM').format(day)}. ${events.length} ${events.length == 1 ? 'event' : 'events'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: isSelected ? 1.5 : 1),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primary.withAlpha(38),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: GoogleFonts.dmSans(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (events.length > 1)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _EventCountBadge(count: events.length),
                  ),
                if (events.isNotEmpty)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Wrap(
                        spacing: 3,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final event in events.take(3))
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withAlpha(220)
                                    : event.typeColor,
                                shape: BoxShape.circle,
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
      ),
    );
  }
}

class _EventCountBadge extends StatelessWidget {
  final int count;

  const _EventCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: principalDirectoryText,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.dmSans(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SelectedDayEventCard extends StatelessWidget {
  final _PrincipalEvent event;
  final VoidCallback onTap;
  final bool showDate;

  const _SelectedDayEventCard({
    required this.event,
    required this.onTap,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: event.calendarTone,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: event.typeColor.withAlpha(50)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: event.typeColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(event.calendarIcon, color: event.typeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: GoogleFonts.dmSans(
                        color: principalDirectoryText,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      showDate
                          ? '${DateFormat('EEE, d MMM').format(event.start)} · ${event.typeLabel} · ${event.timeLabel}'
                          : '${event.typeLabel} · ${event.timeLabel}',
                      style: GoogleFonts.dmSans(
                        color: principalDirectoryMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (event.venue.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.venue,
                        style: GoogleFonts.dmSans(
                          color: principalDirectoryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (event.audience.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        event.audience,
                        style: GoogleFonts.dmSans(
                          color: principalDirectoryMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: principalDirectoryMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgendaSummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onToday;

  const _AgendaSummaryCard({
    required this.title,
    required this.subtitle,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE8F4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: principalDirectoryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    color: principalDirectoryMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: onToday, child: const Text('Today')),
        ],
      ),
    );
  }
}

class _EventDetailPage extends StatelessWidget {
  final _PrincipalEvent event;
  final List<AcademicYearModel> academicYears;
  final String selectedAcademicYearId;
  final bool canManage;
  final Future<bool> Function(String action) onAction;

  const _EventDetailPage({
    required this.event,
    required this.academicYears,
    required this.selectedAcademicYearId,
    required this.canManage,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return PrincipalDetailPage(
      title: 'Event Details',
      menuItems: canManage
          ? [
              const PopupMenuItem(value: 'edit', child: Text('Edit event')),
              if (event.needsApproval)
                const PopupMenuItem(
                  value: 'approve',
                  child: Text('Approve event'),
                ),
              if (!event.isCancelled)
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancel event'),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Remove record'),
              ),
            ]
          : const [],
      onMenuSelected: (value) async {
        if (value == 'edit') {
          final saved = await Navigator.of(context).push<_EventFormResult>(
            MaterialPageRoute(
              builder: (_) => _EventFormPage(
                academicYears: academicYears,
                selectedAcademicYearId: event.academicYearId.isEmpty
                    ? selectedAcademicYearId
                    : event.academicYearId,
                initialMonth: event.start.month,
                event: event,
              ),
            ),
          );
          if (saved != null && context.mounted) Navigator.pop(context, true);
          return;
        }
        if (value == 'approve' || value == 'cancel' || value == 'delete') {
          final changed = await onAction(value);
          if (changed && context.mounted) Navigator.pop(context, true);
        }
      },
      children: [
        PrincipalDetailCard(
          title: event.title,
          trailing: PrincipalStatusPill(
            label: event.statusLabel,
            color: event.statusColor,
          ),
          children: [
            PrincipalDetailRow(label: 'Type', value: event.typeLabel),
            PrincipalDetailRow(label: 'Date', value: event.dateLabel),
            PrincipalDetailRow(label: 'Time', value: event.timeLabel),
            PrincipalDetailRow(
              label: 'Venue',
              value: event.venue.isEmpty ? 'Venue TBD' : event.venue,
            ),
            PrincipalDetailRow(label: 'Audience', value: event.audience),
            PrincipalDetailRow(
              label: 'Holiday',
              value: event.isHoliday ? 'Yes' : 'No',
            ),
            PrincipalDetailRow(
              label: 'Record',
              value: event.isStoredHoliday
                  ? 'Official holiday calendar'
                  : event.isGeneratedHoliday
                  ? 'Generated holiday'
                  : 'School event',
            ),
          ],
        ),
        PrincipalDetailCard(
          title: 'Description',
          children: [
            Text(
              event.description.isEmpty
                  ? 'No description added.'
                  : event.description,
              style: GoogleFonts.dmSans(
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: principalDirectoryText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EventFormResult {
  final DateTime startDate;
  final String academicYearId;

  const _EventFormResult({
    required this.startDate,
    required this.academicYearId,
  });
}

class _EventFormPage extends StatefulWidget {
  final List<AcademicYearModel> academicYears;
  final String selectedAcademicYearId;
  final int initialMonth;
  final DateTime? initialDate;
  final _PrincipalEvent? event;

  const _EventFormPage({
    required this.academicYears,
    required this.selectedAcademicYearId,
    required this.initialMonth,
    this.initialDate,
    this.event,
  });

  @override
  State<_EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<_EventFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  String _academicYearId = '';
  String _type = 'event';
  String _status = 'scheduled';
  String _audience = 'all';
  bool _isHoliday = false;
  bool _saving = false;
  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  String? _error;

  static const _types = [
    'event',
    'meeting',
    'academic',
    'exam',
    'sports',
    'cultural',
    'staff',
    'health',
  ];

  static const _statuses = [
    'draft',
    'scheduled',
    'pending_approval',
    'approved',
    'completed',
    'cancelled',
  ];

  static const _audiences = ['all', 'students', 'parents', 'staff', 'teachers'];

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final now = DateTime.now();
    final fallbackDate =
        widget.initialDate ?? DateTime(now.year, widget.initialMonth, 1);
    _academicYearId =
        event?.academicYearId ??
        (widget.selectedAcademicYearId.isNotEmpty
            ? widget.selectedAcademicYearId
            : (widget.academicYears.isNotEmpty
                  ? widget.academicYears.first.id
                  : ''));
    _titleController.text = event?.title ?? '';
    _descriptionController.text = event?.description ?? '';
    _venueController.text = event?.venue ?? '';
    _type = event?.type ?? 'event';
    _status = event?.status ?? 'scheduled';
    _audience = event?.audienceValue ?? 'all';
    _isHoliday = event?.isHoliday ?? false;
    if (_isHoliday) _type = 'event';
    if (!_types.contains(_type)) _type = 'event';
    if (_status == 'pending') _status = 'pending_approval';
    if (!_statuses.contains(_status)) _status = 'scheduled';
    if (!_audiences.contains(_audience)) _audience = 'all';
    _startDate = event?.start ?? fallbackDate;
    _endDate = event?.end ?? fallbackDate;
    _startTime = _timeFromDate(event?.start) ?? _startTime;
    _endTime = _timeFromDate(event?.end) ?? _endTime;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_academicYearId.isEmpty) {
      setState(() => _error = 'Create an academic year before adding events.');
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      setState(() => _error = 'End date cannot be before start date.');
      return;
    }
    final startDateTime = _combinedDateTime(_startDate, _effectiveStartTime);
    final endDateTime = _combinedDateTime(_endDate, _effectiveEndTime);
    if (!endDateTime.isAfter(startDateTime)) {
      setState(() => _error = 'End time must be after start time.');
      return;
    }
    final yearError = _academicYearRangeError();
    if (yearError != null) {
      setState(() => _error = yearError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = {
        'academic_year_id': _academicYearId,
        'event_title': _titleController.text.trim(),
        'event_type': _isHoliday ? 'holiday' : _type,
        'description': _descriptionController.text.trim(),
        'start_datetime': _formatRfc3339(startDateTime),
        'end_datetime': _formatRfc3339(endDateTime),
        'start_date': _formatDate(_startDate),
        'end_date': _formatDate(_endDate),
        'start_time': _formatTime(_effectiveStartTime),
        'end_time': _formatTime(_effectiveEndTime),
        'location': _venueController.text.trim(),
        'venue': _venueController.text.trim(),
        'audience_type': _audience,
        'status': _status,
        if (_isHoliday) 'is_holiday': true,
      };
      final eventId = widget.event?.id ?? '';
      if (eventId.isEmpty) {
        await BackendApiClient.instance.createEventPayload(payload);
      } else {
        await BackendApiClient.instance.updateRaw('/events/$eventId', payload);
      }
      if (mounted) {
        Navigator.pop(
          context,
          _EventFormResult(
            startDate: _startDate,
            academicYearId: _academicYearId,
          ),
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Event save failed: $error';
      });
    }
  }

  TimeOfDay get _effectiveStartTime =>
      _isHoliday ? const TimeOfDay(hour: 0, minute: 0) : _startTime;

  TimeOfDay get _effectiveEndTime =>
      _isHoliday ? const TimeOfDay(hour: 23, minute: 59) : _endTime;

  DateTime _combinedDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String? _academicYearRangeError() {
    AcademicYearModel? year;
    for (final item in widget.academicYears) {
      if (item.id == _academicYearId) {
        year = item;
        break;
      }
    }
    if (year == null) return null;
    final start = DateTime.tryParse(year.startDate);
    final end = DateTime.tryParse(year.endDate);
    if (start == null || end == null) return null;
    final normalizedStart = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    final normalizedEnd = DateTime(_endDate.year, _endDate.month, _endDate.day);
    if (normalizedStart.isBefore(
          DateTime(start.year, start.month, start.day),
        ) ||
        normalizedEnd.isAfter(DateTime(end.year, end.month, end.day))) {
      return 'Event dates must stay inside ${year.yearLabel}.';
    }
    return null;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate.isBefore(_startDate)) _endDate = picked;
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.event != null;
    return PrincipalInputPage(
      title: editing ? 'Edit Event' : 'Create Event',
      icon: Icons.event_available_rounded,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Event title',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),
            if (widget.academicYears.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _academicYearId.isEmpty ? null : _academicYearId,
                decoration: const InputDecoration(
                  labelText: 'Academic year',
                  prefixIcon: Icon(Icons.school_rounded),
                ),
                items: widget.academicYears
                    .map(
                      (year) => DropdownMenuItem(
                        value: year.id,
                        child: Text(year.yearLabel),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _academicYearId = value ?? ''),
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Academic year is required' : null,
              ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Event type',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: _types
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(_titleCase(type)),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 14),
            _ResponsivePickerGrid(
              children: [
                _PickerTile(
                  label: 'Start date',
                  value: _formatDate(_startDate),
                  icon: Icons.event_rounded,
                  onTap: _saving ? null : _pickStartDate,
                ),
                _PickerTile(
                  label: 'End date',
                  value: _formatDate(_endDate),
                  icon: Icons.event_available_rounded,
                  onTap: _saving ? null : _pickEndDate,
                ),
              ],
            ),
            if (_isHoliday) ...[
              const SizedBox(height: 14),
              const _CalendarNotice(
                icon: Icons.celebration_rounded,
                title: 'Legacy holiday record',
                message:
                    'This older holiday is retained for compatibility. New holidays are stored separately in the holiday calendar.',
              ),
            ] else ...[
              const SizedBox(height: 14),
              _ResponsivePickerGrid(
                children: [
                  _PickerTile(
                    label: 'Start time',
                    value: _formatTimeOfDay(_startTime),
                    icon: Icons.schedule_rounded,
                    onTap: _saving ? null : () => _pickTime(start: true),
                  ),
                  _PickerTile(
                    label: 'End time',
                    value: _formatTimeOfDay(_endTime),
                    icon: Icons.schedule_send_rounded,
                    onTap: _saving ? null : () => _pickTime(start: false),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _venueController,
              decoration: const InputDecoration(
                labelText: 'Venue',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _audience,
              decoration: const InputDecoration(
                labelText: 'Audience',
                prefixIcon: Icon(Icons.groups_rounded),
              ),
              items: _audiences
                  .map(
                    (audience) => DropdownMenuItem(
                      value: audience,
                      child: Text(_titleCase(audience)),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _audience = value ?? _audience),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.verified_rounded),
              ),
              items: _statuses
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(_titleCase(status.replaceAll('_', ' '))),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: GoogleFonts.dmSans(
                  color: context.appTheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _saving
                    ? 'Saving...'
                    : editing
                    ? 'Save Event'
                    : 'Create Event',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsivePickerGrid extends StatelessWidget {
  final List<Widget> children;

  const _ResponsivePickerGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                children[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDCE8F5)),
          color: const Color(0xFFF8FBFE),
        ),
        child: Row(
          children: [
            Icon(icon, color: principalDirectoryAccent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: principalDirectoryMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: principalDirectoryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
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

class _CalendarNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _CalendarNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: principalDirectoryAccent.withAlpha(42)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: principalDirectoryAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: principalDirectoryText,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts.dmSans(
                    color: principalDirectoryMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    height: 1.25,
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

class _PrincipalEvent {
  final String id;
  final String academicYearId;
  final String title;
  final String type;
  final String status;
  final String description;
  final String venue;
  final String audienceValue;
  final bool isHoliday;
  final DateTime start;
  final DateTime end;
  final _CalendarRecordKind recordKind;

  const _PrincipalEvent({
    required this.id,
    required this.academicYearId,
    required this.title,
    required this.type,
    required this.status,
    required this.description,
    required this.venue,
    required this.audienceValue,
    required this.isHoliday,
    required this.start,
    required this.end,
    this.recordKind = _CalendarRecordKind.event,
  });

  factory _PrincipalEvent.fromApi(Map<String, dynamic> row) {
    final start = _eventDateTime(row, true) ?? DateTime.now();
    final end =
        _eventDateTime(row, false) ?? start.add(const Duration(hours: 1));
    final type = _clean(row['event_type'], fallback: 'event').toLowerCase();
    final status = _clean(row['status'], fallback: 'scheduled').toLowerCase();
    return _PrincipalEvent(
      id: _clean(row['id'] ?? row['event_id']),
      academicYearId: _clean(row['academic_year_id']),
      title: _clean(row['event_title'] ?? row['event_name'], fallback: 'Event'),
      type: type,
      status: status,
      description: _clean(row['description']),
      venue: _clean(row['venue'] ?? row['location']),
      audienceValue: _clean(
        row['audience_type'] ?? row['audience'],
        fallback: 'all',
      ).toLowerCase(),
      isHoliday:
          row['is_holiday'] == true ||
          row['holiday'] == true ||
          type == 'holiday',
      start: start,
      end: end,
    );
  }

  static _PrincipalEvent? fromHoliday(Map<String, dynamic> row) {
    final from = DateTime.tryParse(_clean(row['from_date']));
    final to = DateTime.tryParse(
      _clean(row['to_date']).isEmpty
          ? _clean(row['from_date'])
          : _clean(row['to_date']),
    );
    if (from == null || to == null) return null;
    final start = DateTime(from.year, from.month, from.day);
    final endDate = DateTime(to.year, to.month, to.day);
    return _PrincipalEvent(
      id: 'holiday_${_clean(row['id'])}',
      academicYearId: _clean(row['academic_year_id']),
      title: _clean(row['holiday_name'], fallback: 'Holiday'),
      type: 'holiday',
      status: 'scheduled',
      description: _clean(row['type'], fallback: 'Official school holiday'),
      venue: 'School holiday',
      audienceValue: 'all',
      isHoliday: true,
      start: start,
      end: DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59),
      recordKind: _CalendarRecordKind.holiday,
    );
  }

  bool get isEventRecord => recordKind == _CalendarRecordKind.event;

  bool get isStoredHoliday => recordKind == _CalendarRecordKind.holiday;

  bool get isGeneratedHoliday =>
      recordKind == _CalendarRecordKind.generatedHoliday;

  bool get needsApproval =>
      status == 'pending' || status == 'pending_approval' || status == 'draft';

  bool get isCancelled => status == 'cancelled';

  bool get isAcademicEntry => type == 'academic' || type == 'exam';

  bool get isHolidayOrFestival =>
      isHoliday || type == 'cultural' || type == 'festival';

  bool get isGeneralEvent => !isHoliday && !isAcademicEntry && !needsApproval;

  bool overlapsMonth(int month) {
    var cursor = DateTime(start.year, start.month, 1);
    final last = DateTime(end.year, end.month, 1);
    while (!cursor.isAfter(last)) {
      if (cursor.month == month) return true;
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return false;
  }

  bool overlapsDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return start.isBefore(dayEnd) && end.isAfter(dayStart);
  }

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));

  String get typeLabel => _titleCase(type.replaceAll('_', ' '));

  String get audience => _titleCase(audienceValue.replaceAll('_', ' '));

  String get dateLabel {
    if (_formatDate(start) == _formatDate(end)) {
      return '${start.day} ${_monthName(start.month)} ${start.year}';
    }
    return '${start.day} ${_monthName(start.month)} - ${end.day} ${_monthName(end.month)}';
  }

  String get timeLabel {
    if (isHoliday) return 'All day';
    return '${_formatTimeOfDay(TimeOfDay.fromDateTime(start))} - ${_formatTimeOfDay(TimeOfDay.fromDateTime(end))}';
  }

  IconData get icon {
    if (isHoliday) return Icons.celebration_rounded;
    return switch (type) {
      'meeting' => Icons.groups_2_rounded,
      'exam' => Icons.assignment_rounded,
      'academic' => Icons.school_rounded,
      'sports' => Icons.sports_soccer_rounded,
      'cultural' => Icons.theater_comedy_rounded,
      'staff' => Icons.badge_rounded,
      'health' => Icons.health_and_safety_rounded,
      _ => Icons.event_rounded,
    };
  }

  IconData get calendarIcon {
    if (needsApproval) return Icons.verified_rounded;
    if (isHoliday) return Icons.beach_access_rounded;
    return switch (type) {
      'cultural' || 'festival' => Icons.celebration_rounded,
      'academic' || 'exam' => Icons.edit_note_rounded,
      'meeting' => Icons.groups_2_rounded,
      _ => Icons.campaign_rounded,
    };
  }

  Color get statusColor {
    return switch (status) {
      'approved' || 'scheduled' => Colors.green,
      'completed' => Colors.indigo,
      'cancelled' => Colors.red,
      'pending' || 'pending_approval' || 'draft' => Colors.orange,
      _ => principalDirectoryAccent,
    };
  }

  Color get typeColor {
    if (isHoliday) return const Color(0xFFD14343);
    if (needsApproval) return const Color(0xFF16A34A);
    return switch (type) {
      'meeting' => const Color(0xFF0F766E),
      'academic' || 'exam' => const Color(0xFF2563EB),
      'cultural' || 'festival' => const Color(0xFFF59E0B),
      'sports' => const Color(0xFF16A34A),
      'staff' => const Color(0xFF4F46E5),
      'health' => const Color(0xFF0E9384),
      _ => principalDirectoryAccent,
    };
  }

  Color get calendarTone {
    if (isHoliday) return const Color(0xFFFFF1F2);
    return switch (type) {
      'exam' => const Color(0xFFFFF4E5),
      'academic' => const Color(0xFFEAF4FF),
      'sports' => const Color(0xFFE9F9EF),
      'cultural' => const Color(0xFFF3ECFF),
      'meeting' => const Color(0xFFEAF0FF),
      'health' => const Color(0xFFE7FAF6),
      _ => const Color(0xFFF7FBFF),
    };
  }
}

String _clean(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty || text == 'null') return fallback;
  return text;
}

DateTime? _parseDateTime(Object? value) {
  final text = _clean(value);
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

DateTime? _eventDateTime(Map<String, dynamic> row, bool start) {
  final dateKey = start ? 'start_date' : 'end_date';
  final timeKey = start ? 'start_time' : 'end_time';
  final dateTimeKey = start ? 'start_datetime' : 'end_datetime';
  final dateText = _clean(row[dateKey]).isEmpty
      ? _clean(row['start_date'])
      : _clean(row[dateKey]);
  final date = DateTime.tryParse(dateText);
  final time = _timeFromText(_clean(row[timeKey]));
  if (date != null) {
    if (time != null) {
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }
    final parsed = DateTime.tryParse(_clean(row[dateTimeKey]));
    if (parsed != null) {
      final local = parsed.isUtc ? parsed.toLocal() : parsed;
      return DateTime(
        date.year,
        date.month,
        date.day,
        local.hour,
        local.minute,
      );
    }
    return start ? date : DateTime(date.year, date.month, date.day, 23, 59);
  }
  return _parseDateTime(row[dateTimeKey]);
}

TimeOfDay? _timeFromDate(DateTime? date) {
  if (date == null) return null;
  return TimeOfDay(hour: date.hour, minute: date.minute);
}

TimeOfDay? _timeFromText(String raw) {
  final parts = raw.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour < 0 || hour > 23) return null;
  if (minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute:00';
}

String _formatRfc3339(DateTime date) => date.toIso8601String();

String _formatTimeOfDay(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _titleCase(String value) {
  return value
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}
