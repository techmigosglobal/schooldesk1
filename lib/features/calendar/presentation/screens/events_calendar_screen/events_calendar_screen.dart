import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/principal_directory_ui.dart';
import 'package:schooldesk1/core/widgets/teacher_navigation.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/routes/app_routes.dart';

enum _EventFilter {
  month,
  all,
  today,
  upcoming,
  holidays,
  approvals,
  cancelled,
}

enum _EventsDisplayMode { calendar, week }

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
  late DateTime _selectedWeekStart;
  _EventFilter _filter = _EventFilter.month;
  _EventsDisplayMode _displayMode = _EventsDisplayMode.calendar;

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
      final years = await BackendApiClient.instance.getAcademicYears();
      final selectedYearId = _selectedAcademicYearId.isNotEmpty
          ? _selectedAcademicYearId
          : _currentAcademicYearId(years);
      final rows = await BackendApiClient.instance.getEvents(
        academicYearId: selectedYearId.isEmpty ? null : selectedYearId,
      );
      final events = rows.map(_PrincipalEvent.fromApi).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      if (!mounted) return;
      // Derive the display year from the selected academic year's start date so
      // the calendar grid always renders the correct year (e.g. 2026 for a
      // 2026-2027 academic year), regardless of the current wall-clock year.
      int derivedYear = _selectedYear;
      for (final y in years) {
        if (y.id == selectedYearId) {
          final start = DateTime.tryParse(y.startDate);
          if (start != null) derivedYear = start.year;
          break;
        }
      }
      setState(() {
        _academicYears = years;
        _selectedAcademicYearId = selectedYearId;
        _events = events;
        _selectedYear = derivedYear;
        _loading = false;
      });
    } catch (error) {
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

  bool get _canManageEvents {
    if (widget.portal != SchoolCalendarPortal.principal) return false;
    final role = BackendApiClient.instance.currentRoleName
        ?.trim()
        .toLowerCase();
    return role == null || role.isEmpty || role == 'principal';
  }

  bool get _isPrincipalPortal =>
      widget.portal == SchoolCalendarPortal.principal;

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

      return switch (_filter) {
        _EventFilter.month => event.overlapsMonth(_selectedMonth),
        _EventFilter.all => true,
        _EventFilter.today => event.overlapsDate(today),
        _EventFilter.upcoming =>
          !event.start.isBefore(today) && !event.isCancelled,
        _EventFilter.holidays => event.isHoliday,
        _EventFilter.approvals => event.needsApproval,
        _EventFilter.cancelled => event.isCancelled,
      };
    }).toList();
    rows.sort((a, b) => a.start.compareTo(b.start));
    return rows;
  }

  int get _calendarYear {
    // Prefer the explicitly tracked year (set from the academic year start date
    // when data loads, or updated when the user navigates months).
    return _selectedYear;
  }

  List<_PrincipalEvent> _eventsForDay(DateTime day) {
    final query = _query.trim().toLowerCase();
    final rows = _events.where((event) {
      if (!event.overlapsDate(day)) return false;
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
        _filter = _EventFilter.month;
        _displayMode = _EventsDisplayMode.calendar;
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
          canManage: _canManageEvents,
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
        _filter = _EventFilter.month;
        _displayMode = _EventsDisplayMode.calendar;
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
    } catch (error) {
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
    } catch (error) {
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

  // ── School Calendar Seed ─────────────────────────────────────────────────

  Future<void> _seedSchoolCalendar() async {
    if (!_canManageEvents) return;

    // Require an academic year to be selected.
    if (_selectedAcademicYearId.isEmpty) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No academic year selected'),
          content: const Text(
            'Please create an academic year covering 2026–27 before loading the school calendar.\n\n'
            'Go to Academic Management → Add Academic Year.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final entries = _SchoolCalendarData.all;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load 2026–27 school calendar?'),
        content: Text(
          'This will create ${entries.length} school calendar entries '
          '(holidays, events & celebrations) for the selected academic year.\n\n'
          'Entries with the same title and date that already exist will be skipped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Load calendar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Build a set of existing (title+date) pairs to skip duplicates.
    final existing = _events
        .map((e) => '${e.title.toLowerCase()}|${_formatDate(e.start)}')
        .toSet();

    int done = 0;
    int skipped = 0;
    int failed = 0;
    final errors = <String>[];

    // Show a progress bottom-sheet.
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (_, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loading school calendar…',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: principalDirectoryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$done / ${entries.length} entries created'
                    '${skipped > 0 ? ' · $skipped skipped' : ''}'
                    '${failed > 0 ? ' · $failed failed' : ''}',
                    style: GoogleFonts.dmSans(
                      color: principalDirectoryMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: (done + skipped + failed) / entries.length,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Iterate and POST each entry.
    for (final entry in entries) {
      final key = '${entry.title.toLowerCase()}|${entry.startDate}';
      if (existing.contains(key)) {
        skipped++;
        continue;
      }
      try {
        final payload = {
          'academic_year_id': _selectedAcademicYearId,
          'event_name': entry.title,
          'event_type': entry.eventType,
          'description': entry.description,
          'start_date': entry.startDate,
          'end_date': entry.endDate,
          'start_time': '00:00:00',
          'end_time': '23:59:59',
          'venue': '',
          'audience_type': 'all',
          'status': 'scheduled',
          'is_holiday': entry.isHoliday,
        };
        await BackendApiClient.instance.createEventPayload(payload);
        existing.add(key);
        done++;
      } catch (err) {
        failed++;
        errors.add('${entry.title}: $err');
      }
    }

    // Dismiss the bottom-sheet.
    if (mounted) Navigator.of(context, rootNavigator: true).maybePop();

    // Refresh the event list.
    await _loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'School calendar loaded: $done added'
          '${skipped > 0 ? ', $skipped skipped' : ''}'
          '${failed > 0 ? ', $failed failed' : ''}.',
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        backgroundColor: failed > 0 ? context.appTheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPrincipalPortal) return _buildReadOnlyCalendar();

    return _buildPrincipalCalendar();
  }

  Widget _buildPrincipalCalendar() {
    return PrincipalDirectoryScaffold(
      title: 'School Calendar',
      subtitle:
          'Live school calendar for events, holidays, PTMs, and approvals',
      loading: _loading,
      error: _error,
      onRefresh: _loadData,
      onAdd: _canManageEvents ? _openCreateEvent : null,
      addTooltip: 'Create event',
      addIcon: Icons.event_available_rounded,
      secondaryActions: _canManageEvents
          ? [
              IconButton(
                tooltip: 'Approve event posts',
                icon: const Icon(Icons.fact_check_rounded),
                onPressed: () async {
                  final changed = await Navigator.pushNamed(
                    context,
                    AppRoutes.principalEventApprovals,
                  );
                  if (changed == true && mounted) await _loadData();
                },
              ),
              IconButton(
                tooltip: 'Load 2026–27 school calendar',
                icon: const Icon(Icons.download_for_offline_rounded),
                onPressed: _seedSchoolCalendar,
              ),
            ]
          : null,
      isEmpty: !_loading && _error == null && _visibleEvents.isEmpty,
      emptyState: _buildCalendarEmptyState(),
      filters: _buildFilters(),
      slivers: [
        if (_displayMode == _EventsDisplayMode.calendar)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 72),
            sliver: SliverToBoxAdapter(child: _buildCalendarMonth()),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 72),
            sliver: SliverToBoxAdapter(child: _buildWeekView()),
          ),
      ],
    );
  }

  Widget _buildReadOnlyCalendar() {
    return SchoolDeskModuleScaffold(
      title: 'School Calendar',
      subtitle: 'Holidays, events, PTMs, and school milestones',
      drawer: _schoolCalendarDrawer(),
      actions: [
        IconButton(
          tooltip: 'Refresh calendar',
          onPressed: _loading ? null : _loadData,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildFilters()),
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
                    title: 'Unable to load calendar',
                    description: _error!,
                  ),
                ),
              )
            else ...[
              if (_displayMode == _EventsDisplayMode.calendar)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 72),
                  sliver: SliverToBoxAdapter(child: _buildCalendarMonthReadOnly()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 72),
                  sliver: SliverToBoxAdapter(child: _buildWeekView()),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _schoolCalendarDrawer() {
    switch (widget.portal) {
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
      case SchoolCalendarPortal.principal:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCalendarMonthReadOnly() {
    return _EventCalendarMonth(
      month: _selectedMonth,
      year: _calendarYear,
      eventsForDay: _eventsForDay,
      onEventTap: _openDetails,
      onDayTap: (day, events) {
        if (events.isEmpty) return; // read-only: no create on tap
        if (events.length == 1) {
          _openDetails(events.first);
        } else {
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Theme.of(context).colorScheme.surface,
            builder: (sheetCtx) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '${events.length} events on ${day.day} ${_monthName(day.month)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: events.length,
                        itemBuilder: (ctx, i) {
                          final ev = events[i];
                          return ListTile(
                            title: Text(ev.title,
                                style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w600)),
                            subtitle:
                                Text(ev.typeLabel, style: GoogleFonts.dmSans()),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                size: 20),
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              _openDetails(ev);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }
      },
      onPrevMonth: () {
        setState(() {
          if (_selectedMonth == 1) {
            _selectedMonth = 12;
            _selectedYear--;
          } else {
            _selectedMonth--;
          }
        });
      },
      onNextMonth: () {
        setState(() {
          if (_selectedMonth == 12) {
            _selectedMonth = 1;
            _selectedYear++;
          } else {
            _selectedMonth++;
          }
        });
      },
    );
  }

  Widget _buildCalendarMonth() {
    return _EventCalendarMonth(
      month: _selectedMonth,
      year: _calendarYear,
      eventsForDay: _eventsForDay,
      onEventTap: _openDetails,
      onDayTap: (day, events) {
        if (events.isEmpty) {
          _openCreateEvent(initialDate: day);
        } else if (events.length == 1) {
          _openDetails(events.first);
        } else {
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Theme.of(context).colorScheme.surface,
            builder: (sheetCtx) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '${events.length} events on ${day.day} ${_monthName(day.month)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: events.length,
                        itemBuilder: (ctx, i) {
                          final ev = events[i];
                          return ListTile(
                            title: Text(ev.title,
                                style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w600)),
                            subtitle:
                                Text(ev.typeLabel, style: GoogleFonts.dmSans()),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                size: 20),
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              _openDetails(ev);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }
      },
      onPrevMonth: () {
        setState(() {
          if (_selectedMonth == 1) {
            _selectedMonth = 12;
            _selectedYear--;
          } else {
            _selectedMonth--;
          }
        });
      },
      onNextMonth: () {
        setState(() {
          if (_selectedMonth == 12) {
            _selectedMonth = 1;
            _selectedYear++;
          } else {
            _selectedMonth++;
          }
        });
      },
    );
  }

  Widget _buildWeekView() {
    final endOfWeek = _selectedWeekStart.add(const Duration(days: 6));

    return _EventCalendarWeek(
      startOfWeek: _selectedWeekStart,
      endOfWeek: endOfWeek,
      eventsForDay: _eventsForDay,
      onEventTap: _openDetails,
      onEmptyDayTap: (day) => _openCreateEvent(initialDate: day),
      onPrevWeek: () {
        setState(() {
          _selectedWeekStart = _selectedWeekStart.subtract(
            const Duration(days: 7),
          );
        });
      },
      onNextWeek: () {
        setState(() {
          _selectedWeekStart = _selectedWeekStart.add(const Duration(days: 7));
        });
      },
      onGoToToday: () {
        setState(() {
          final now = DateTime.now();
          _selectedWeekStart = now.subtract(Duration(days: now.weekday - 1));
        });
      },
    );
  }

  Widget _buildCalendarEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyStateWidget(
            icon: Icons.event_busy_rounded,
            title: _events.isEmpty
                ? 'No calendar entries yet'
                : 'No calendar entries match these filters',
            description: _events.isEmpty
                ? 'Create or load school calendar entries for this academic year.'
                : 'Use Reset filters to return to the full school calendar.',
          ),
          if (_events.isNotEmpty) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _resetCalendarFilters,
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text('Reset filters'),
            ),
          ],
        ],
      ),
    );
  }

  void _resetCalendarFilters() {
    setState(() {
      _query = '';
      _filter = _EventFilter.month;
      _displayMode = _EventsDisplayMode.calendar;
      _selectedMonth = DateTime.now().month;
    });
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
                  hint: 'Search event, venue, audience...',
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
                        hint: 'Search event, venue, audience...',
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
    return SegmentedButton<_EventsDisplayMode>(
      segments: const [
        ButtonSegment(
          value: _EventsDisplayMode.calendar,
          icon: Icon(Icons.calendar_month_rounded),
          label: Text('Month'),
        ),
        ButtonSegment(
          value: _EventsDisplayMode.week,
          icon: Icon(Icons.view_week_rounded),
          label: Text('Week'),
        ),
      ],
      selected: {_displayMode},
      onSelectionChanged: (value) {
        setState(() => _displayMode = value.first);
      },
    );
  }

  Widget _buildMonthStrip() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(12, (index) {
          final month = index + 1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PrincipalDirectoryChip(
              label: _monthName(month),
              selected: _selectedMonth == month,
              onTap: () => setState(() {
                _selectedMonth = month;
                _filter = _EventFilter.month;
              }),
            ),
          );
        }),
      ),
    );
  }
}

class _EventCalendarMonth extends StatelessWidget {
  final int month;
  final int year;
  final List<_PrincipalEvent> Function(DateTime day) eventsForDay;
  final ValueChanged<_PrincipalEvent> onEventTap;
  final void Function(DateTime day, List<_PrincipalEvent> events)? onDayTap;
  final VoidCallback? onPrevMonth;
  final VoidCallback? onNextMonth;

  const _EventCalendarMonth({
    required this.month,
    required this.year,
    required this.eventsForDay,
    required this.onEventTap,
    this.onDayTap,
    this.onPrevMonth,
    this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month);
    final leadingBlankDays = firstDay.weekday - 1;
    final dayCount = DateUtils.getDaysInMonth(year, month);
    final totalCells = ((leadingBlankDays + dayCount + 6) ~/ 7) * 7;
    var monthEventCount = 0;

    final cells = List<Widget>.generate(totalCells, (index) {
      final dayNumber = index - leadingBlankDays + 1;
      if (dayNumber < 1 || dayNumber > dayCount) {
        return const _EventCalendarDayCell(outsideMonth: true, events: []);
      }
      final day = DateTime(year, month, dayNumber);
      final events = eventsForDay(day);
      monthEventCount += events.length;
      return _EventCalendarDayCell(
        day: day,
        events: events,
        onTap: () => onDayTap?.call(day, events),
      );
    });

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8F4)),
        boxShadow: [
          BoxShadow(
            color: context.appTheme.onSurface.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (onPrevMonth != null)
                IconButton(
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left_rounded, size: 24),
                  onPressed: onPrevMonth,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFEAF4FF),
                    foregroundColor: principalDirectoryAccent,
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: principalDirectoryAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_monthName(month)} $year',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: principalDirectoryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      monthEventCount == 0
                          ? 'Calendar'
                          : '$monthEventCount calendar entries',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: principalDirectoryMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onNextMonth != null)
                IconButton(
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right_rounded, size: 24),
                  onPressed: onNextMonth,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFEAF4FF),
                    foregroundColor: principalDirectoryAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              _CalendarWeekLabel('Mon'),
              _CalendarWeekLabel('Tue'),
              _CalendarWeekLabel('Wed'),
              _CalendarWeekLabel('Thu'),
              _CalendarWeekLabel('Fri'),
              _CalendarWeekLabel('Sat'),
              _CalendarWeekLabel('Sun'),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              return GridView.count(
                crossAxisCount: 7,
                mainAxisSpacing: compact ? 4 : 6,
                crossAxisSpacing: compact ? 4 : 6,
                childAspectRatio: compact ? 1.0 : 1.15,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: cells,
              );
            },
          ),
          if (monthEventCount == 0) ...[
            const SizedBox(height: 14),
            const _CalendarNotice(
              icon: Icons.event_available_rounded,
              title: 'No events scheduled',
              message: 'Use the create event button to add one for this month.',
            ),
          ],
        ],
      ),
    );
  }
}

class _CalendarWeekLabel extends StatelessWidget {
  final String label;

  const _CalendarWeekLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            color: principalDirectoryMuted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _EventCalendarDayCell extends StatelessWidget {
  final DateTime? day;
  final List<_PrincipalEvent> events;
  final VoidCallback? onTap;
  final bool outsideMonth;

  const _EventCalendarDayCell({
    required this.events,
    this.day,
    this.onTap,
    this.outsideMonth = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outsideMonth || day == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: context.appTheme.surface.withAlpha(100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEAF1F7)),
        ),
      );
    }
    final now = DateTime.now();
    final actualDay = day!;
    final isToday = DateUtils.isSameDay(actualDay, now);
    final hasEvents = events.isNotEmpty;
    final firstEvent = hasEvents ? events.first : null;
    final accent = firstEvent?.typeColor ?? principalDirectoryAccent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isToday
                ? const Color(0xFFEAF4FF)
                : hasEvents
                ? firstEvent!.calendarTone
                : const Color(0xFFF9FBFE),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isToday
                  ? principalDirectoryAccent.withAlpha(120)
                  : hasEvents
                  ? accent.withAlpha(110)
                  : const Color(0xFFE4ECF5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${actualDay.day}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: isToday
                            ? principalDirectoryAccent
                            : principalDirectoryText,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (events.length > 1)
                    Text(
                      '${events.length}',
                      style: GoogleFonts.dmSans(
                        color: principalDirectoryMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              if (firstEvent != null) ...[
                Text(
                  firstEvent.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: principalDirectoryText,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    for (final event in events.take(3)) ...[
                      // event preview dots
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: event.typeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
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
    'ptm',
    'academic',
    'exam',
    'holiday',
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
        'event_name': _titleController.text.trim(),
        'event_type': _isHoliday ? 'holiday' : _type,
        'description': _descriptionController.text.trim(),
        'start_date': _formatDate(_startDate),
        'end_date': _formatDate(_endDate),
        'start_time': _formatTime(_effectiveStartTime),
        'end_time': _formatTime(_effectiveEndTime),
        'venue': _venueController.text.trim(),
        'audience_type': _audience,
        'status': _status,
        'is_holiday': _isHoliday,
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
    } catch (error) {
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
                  : (value) => setState(() {
                      _type = value ?? _type;
                      _isHoliday = _type == 'holiday';
                    }),
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
                title: 'Holiday calendar entry',
                message:
                    'Holiday rows are saved as all-day events and also appear in parent calendars.',
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isHoliday,
              title: const Text('Mark as holiday'),
              subtitle: const Text('Show this event in holiday filters'),
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _isHoliday = value;
                      if (value) _type = 'holiday';
                    }),
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

class _EventCalendarWeek extends StatelessWidget {
  final DateTime startOfWeek;
  final DateTime endOfWeek;
  final List<_PrincipalEvent> Function(DateTime day) eventsForDay;
  final ValueChanged<_PrincipalEvent> onEventTap;
  final ValueChanged<DateTime>? onEmptyDayTap;
  final VoidCallback? onPrevWeek;
  final VoidCallback? onNextWeek;
  final VoidCallback? onGoToToday;

  const _EventCalendarWeek({
    required this.startOfWeek,
    required this.endOfWeek,
    required this.eventsForDay,
    required this.onEventTap,
    this.onEmptyDayTap,
    this.onPrevWeek,
    this.onNextWeek,
    this.onGoToToday,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8F4)),
        boxShadow: [
          BoxShadow(
            color: context.appTheme.onSurface.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (onPrevWeek != null)
                IconButton(
                  tooltip: 'Previous week',
                  icon: const Icon(Icons.chevron_left_rounded, size: 22),
                  onPressed: onPrevWeek,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFEAF4FF),
                    foregroundColor: principalDirectoryAccent,
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_monthName(startOfWeek.month)} ${startOfWeek.day} – ${_monthName(endOfWeek.month)} ${endOfWeek.day}, ${endOfWeek.year}',
                  style: GoogleFonts.dmSans(
                    color: principalDirectoryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (onGoToToday != null)
                TextButton(
                  onPressed: onGoToToday,
                  child: Text(
                    'Today',
                    style: GoogleFonts.dmSans(
                      color: principalDirectoryAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              if (onNextWeek != null)
                IconButton(
                  tooltip: 'Next week',
                  icon: const Icon(Icons.chevron_right_rounded, size: 22),
                  onPressed: onNextWeek,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFEAF4FF),
                    foregroundColor: principalDirectoryAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...days.map((day) {
            final events = eventsForDay(day);
            final isToday = DateUtils.isSameDay(day, now);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isToday
                    ? const Color(0xFFEAF4FF)
                    : context.appTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isToday
                      ? principalDirectoryAccent.withAlpha(120)
                      : const Color(0xFFE4ECF5),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Column(
                      children: [
                        Text(
                          _dayName(day.weekday),
                          style: GoogleFonts.dmSans(
                            color: principalDirectoryMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${day.day}',
                          style: GoogleFonts.dmSans(
                            color: isToday
                                ? principalDirectoryAccent
                                : principalDirectoryText,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: events.isEmpty
                        ? InkWell(
                            onTap: () => onEmptyDayTap?.call(day),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'No events',
                                style: GoogleFonts.dmSans(
                                  color: principalDirectoryMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: events.map((event) {
                              return InkWell(
                                onTap: () => onEventTap(event),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: event.typeColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          event.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.dmSans(
                                            color: principalDirectoryText,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (event.venue.isNotEmpty)
                                        Text(
                                          event.venue,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.dmSans(
                                            color: principalDirectoryMuted,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
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

String _dayName(int weekday) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[weekday - 1];
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
  });

  factory _PrincipalEvent.fromApi(Map<String, dynamic> row) {
    final start =
        _parseDateTime(row['start_datetime']) ??
        _parseDateAndTime(row['start_date'], row['start_time']) ??
        DateTime.now();
    final end =
        _parseDateTime(row['end_datetime']) ??
        _parseDateAndTime(
          row['end_date'] ?? row['start_date'],
          row['end_time'],
          endOfDay: true,
        ) ??
        start.add(const Duration(hours: 1));
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

  bool get needsApproval =>
      status == 'pending' || status == 'pending_approval' || status == 'draft';

  bool get isCancelled => status == 'cancelled';

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
      'ptm' => Icons.people_alt_rounded,
      'exam' => Icons.assignment_rounded,
      'academic' => Icons.school_rounded,
      'sports' => Icons.sports_soccer_rounded,
      'cultural' => Icons.theater_comedy_rounded,
      'staff' => Icons.badge_rounded,
      'health' => Icons.health_and_safety_rounded,
      _ => Icons.event_rounded,
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
    if (isHoliday) return Colors.red;
    return switch (type) {
      'meeting' => Colors.teal,
      'ptm' => const Color(0xFF1B4F72),
      'exam' => const Color(0xFFD35400),
      'academic' => const Color(0xFF2563EB),
      'sports' => const Color(0xFF16A34A),
      'cultural' => const Color(0xFF8E44AD),
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
      'ptm' || 'meeting' => const Color(0xFFEAF0FF),
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

DateTime? _parseDateAndTime(
  Object? date,
  Object? time, {
  bool endOfDay = false,
}) {
  final dateText = _clean(date);
  if (dateText.isEmpty) return null;
  final timeText = _clean(time, fallback: endOfDay ? '23:59:59' : '00:00:00');
  return DateTime.tryParse('${dateText.split('T').first}T$timeText');
}

TimeOfDay? _timeFromDate(DateTime? date) {
  if (date == null) return null;
  return TimeOfDay(hour: date.hour, minute: date.minute);
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

String _formatTimeOfDay(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _titleCase(String value) {
  if (value.trim().toLowerCase() == 'ptm') return 'PTM';
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

// ─────────────────────────────────────────────────────────────────────────────
// School Calendar 2026–27 – Seed Data
// ─────────────────────────────────────────────────────────────────────────────

class _SchoolCalendarEntry {
  const _SchoolCalendarEntry({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.eventType,
    required this.description,
    this.isHoliday = false,
    this.audienceType = 'all',
  });

  final String title;
  final String startDate; // ISO‑8601 date (YYYY‑MM‑DD)
  final String endDate;
  final String eventType; // 'holiday' | 'cultural' | 'academic' | 'sports' …
  final String description;
  final bool isHoliday;
  final String audienceType;
}

// ─────────────────────────────────────────────────────────────────────────────

abstract final class _SchoolCalendarData {
  // Holiday
  static _SchoolCalendarEntry _h(
    String title,
    String start, {
    String? end,
    String desc = '',
  }) => _SchoolCalendarEntry(
    title: title,
    startDate: start,
    endDate: end ?? start,
    eventType: 'holiday',
    description: desc.isEmpty ? title : desc,
    isHoliday: true,
    audienceType: 'all',
  );

  // Cultural / celebration
  static _SchoolCalendarEntry _c(
    String title,
    String start, {
    String? end,
    String desc = '',
    String type = 'cultural',
  }) => _SchoolCalendarEntry(
    title: title,
    startDate: start,
    endDate: end ?? start,
    eventType: type,
    description: desc.isEmpty ? title : desc,
    isHoliday: false,
    audienceType: 'all',
  );

  static final List<_SchoolCalendarEntry> all = [
    // ── June 2026 ──────────────────────────────────────────────────────────
    _h('Muharram', '2026-06-26', desc: 'Islamic New Year – public holiday'),

    // ── August 2026 ────────────────────────────────────────────────────────
    _h(
      'Bonalu Festival',
      '2026-08-10',
      desc: 'Bonalu Festival – Telangana public holiday',
    ),
    _h(
      'Independence Day',
      '2026-08-15',
      desc: 'India Independence Day – national holiday',
    ),
    _c(
      'Varalakshmi Vratam',
      '2026-08-21',
      desc: 'Varalakshmi Vratam celebration',
    ),
    _c('Onam', '2026-08-26', desc: 'Onam harvest festival'),
    _c(
      'Raksha Bandhan',
      '2026-08-28',
      desc: 'Raksha Bandhan – sibling bonding celebration',
    ),

    // ── September 2026 ─────────────────────────────────────────────────────
    _c(
      'Janmashtami',
      '2026-09-04',
      desc: 'Janmashtami – Krishna Jayanti celebration',
    ),
    _c(
      "Teacher's Day",
      '2026-09-05',
      desc: "Teacher's Day celebration – Dr Sarvepalli Radhakrishnan",
      type: 'academic',
    ),
    _h(
      "Milad-un-Nabi / Eid-e-Milad",
      '2026-09-14',
      desc: 'Prophet Muhammad\'s Birthday – public holiday',
    ),
    _c(
      'Vinayaka Chaturthi',
      '2026-09-16',
      desc: 'Ganesh Chaturthi – 10-day festival',
    ),
    _c(
      "Pitra Paksha / Mahalaya",
      '2026-10-01',
      desc: 'Mahalaya – beginning of Durga Puja period',
    ),

    // ── October 2026 ───────────────────────────────────────────────────────
    _h(
      'Gandhi Jayanti',
      '2026-10-02',
      desc: 'Gandhi Jayanti – national holiday',
    ),
    _c(
      'Navratri Begin',
      '2026-10-07',
      desc: 'Navratri festival begins – 9 days of celebration',
    ),
    _h(
      'Dussehra (Vijayadashami)',
      '2026-10-15',
      end: '2026-10-16',
      desc: 'Dussehra / Vijayadashami – public holiday',
    ),
    _c(
      'Navratri End',
      '2026-10-15',
      desc: 'Navratri concludes with Vijayadashami',
    ),

    // ── November 2026 ──────────────────────────────────────────────────────
    _h(
      'Diwali',
      '2026-11-08',
      end: '2026-11-10',
      desc: 'Diwali festival holidays',
    ),
    _c(
      'Bhai Dooj',
      '2026-11-10',
      desc: 'Bhai Dooj – sibling celebration after Diwali',
    ),
    _h(
      'Guru Nanak Jayanti',
      '2026-11-25',
      desc: 'Guru Nanak Jayanti – public holiday',
    ),
    _c(
      'Constitution Day',
      '2026-11-26',
      desc: 'Constitution Day of India',
      type: 'academic',
    ),

    // ── December 2026 ──────────────────────────────────────────────────────
    _c(
      'Christmas Week',
      '2026-12-21',
      end: '2026-12-31',
      desc: 'Winter holiday / Christmas break',
    ),
    _h('Christmas Day', '2026-12-25', desc: 'Christmas Day – public holiday'),

    // ── January 2027 ───────────────────────────────────────────────────────
    _c(
      'Winter Holiday',
      '2027-01-01',
      end: '2027-01-02',
      desc: 'New Year winter break continues',
    ),
    _h(
      'Makara Sankranti',
      '2027-01-14',
      end: '2027-01-16',
      desc: 'Makara Sankranti / Pongal – harvest festival holidays',
    ),
    _h('Pongal', '2027-01-15', desc: 'Pongal – Tamil harvest festival'),
    _h('Republic Day', '2027-01-26', desc: 'Republic Day – national holiday'),

    // ── February 2027 ──────────────────────────────────────────────────────
    _c(
      'Saraswati Puja',
      '2027-02-01',
      desc: 'Saraswati Puja – Vasant Panchami',
    ),
    _c(
      "Children's Science Congress",
      '2027-02-05',
      desc: "Children's Science Congress / Science Day",
      type: 'academic',
    ),
    _c(
      'Shivaji Jayanti',
      '2027-02-19',
      desc: 'Chhatrapati Shivaji Maharaj Jayanti',
    ),

    // ── March 2027 ─────────────────────────────────────────────────────────
    _h(
      'Maha Shivaratri',
      '2027-02-26',
      desc: 'Maha Shivaratri – public holiday',
    ),
    _c(
      'Holi',
      '2027-03-01',
      end: '2027-03-02',
      desc: 'Holi festival of colors',
    ),
    _h('Holi (main)', '2027-03-02', desc: 'Holi – public holiday'),
    _c(
      'Annual Day / Sports Day',
      '2027-03-15',
      desc: 'School Annual Day & Sports Day celebration',
      type: 'sports',
    ),

    // ── April 2027 ─────────────────────────────────────────────────────────
    _h('Good Friday', '2027-04-02', desc: 'Good Friday – public holiday'),
    _h('Ram Navami', '2027-04-06', desc: 'Ram Navami – public holiday'),
    _h(
      'Dr Ambedkar Jayanti',
      '2027-04-14',
      desc: 'Dr B R Ambedkar Jayanti – national holiday',
    ),
    _c('Vishu', '2027-04-14', desc: 'Vishu – Kerala New Year celebration'),
    _h(
      'Ugadi / Telugu New Year',
      '2027-04-14',
      desc: 'Ugadi / Telugu New Year – public holiday',
    ),
    _h('Eid-ul-Fitr', '2027-04-21', desc: 'Eid-ul-Fitr – public holiday'),

    // ── May 2027 ───────────────────────────────────────────────────────────
    _h(
      'Maharashtra Day / May Day',
      '2027-05-01',
      desc: 'Maharashtra Foundation Day & International Labour Day',
    ),
    _c(
      "Buddha Purnima",
      '2027-05-12',
      desc: 'Buddha Purnima / Vesak celebration',
    ),
    _c("Mother's Day", '2027-05-09', desc: "Mother's Day school celebration"),
    _c(
      'Farewell / Valedictory',
      '2027-05-15',
      desc: 'Farewell ceremony for graduating students',
      type: 'academic',
    ),
    _h(
      'Summer Vacation Begin',
      '2027-05-16',
      end: '2027-05-31',
      desc: 'Summer vacation begins',
    ),

    // ── June 2027 ──────────────────────────────────────────────────────────
    _h(
      'Summer Vacation End',
      '2027-06-01',
      end: '2027-06-14',
      desc: 'Summer vacation continues',
    ),
    _c(
      'New Academic Year Opening',
      '2027-06-15',
      desc: 'School reopens – new academic year 2027-28 begins',
      type: 'academic',
    ),

    // ── Academic Calendar Events (across the year) ─────────────────────────
    _c(
      'Orientation Day',
      '2026-06-17',
      desc: 'Student orientation & school opening day',
      type: 'academic',
    ),
    _c(
      'Unit Test 1',
      '2026-07-20',
      end: '2026-07-25',
      desc: 'First unit test across all classes',
      type: 'academic',
    ),
    _c(
      'PTM Round 1',
      '2026-08-08',
      desc: 'First Parent-Teacher Meeting of the year',
      type: 'academic',
    ),
    _c(
      'Half-Yearly Exams',
      '2026-09-21',
      end: '2026-09-30',
      desc: 'Mid-year (half-yearly) examinations',
      type: 'academic',
    ),
    _c(
      'Half-Yearly Results',
      '2026-10-10',
      desc: 'Half-yearly examination results declaration',
      type: 'academic',
    ),
    _c(
      'PTM Round 2',
      '2026-10-17',
      desc: 'Second Parent-Teacher Meeting',
      type: 'academic',
    ),
    _c(
      'Unit Test 2',
      '2026-11-16',
      end: '2026-11-21',
      desc: 'Second unit test across all classes',
      type: 'academic',
    ),
    _c(
      'PTM Round 3',
      '2026-12-05',
      desc: 'Third Parent-Teacher Meeting',
      type: 'academic',
    ),
    _c(
      'Unit Test 3',
      '2027-01-18',
      end: '2027-01-23',
      desc: 'Third unit test across all classes',
      type: 'academic',
    ),
    _c(
      'PTM Round 4',
      '2027-02-06',
      desc: 'Fourth Parent-Teacher Meeting',
      type: 'academic',
    ),
    _c(
      'Pre-Board Exams',
      '2027-02-10',
      end: '2027-02-22',
      desc: 'Pre-board / mock examinations for senior classes',
      type: 'academic',
    ),
    _c(
      'Annual Exams',
      '2027-03-01',
      end: '2027-03-20',
      desc: 'Annual / year-end examinations for all classes',
      type: 'academic',
    ),
    _c(
      'Annual Academic Review',
      '2027-04-01',
      desc: 'Annual academic year review and planning',
      type: 'academic',
    ),
    _c(
      'Final PTM',
      '2027-04-10',
      desc: 'Final Parent-Teacher Meeting',
      type: 'academic',
    ),

    // ── School Events / Celebrations ───────────────────────────────────────
    _c(
      'Diwali Celebrations',
      '2026-11-05',
      desc: 'School Diwali celebration & cultural programme',
    ),
    _c(
      'Christmas Celebrations',
      '2026-12-20',
      desc: 'School Christmas programme & carol singing',
    ),
    _c(
      'Talent Show',
      '2026-12-10',
      desc: 'Inter-class talent show & cultural festival',
      type: 'cultural',
    ),
    _c(
      'Republic Day Celebrations',
      '2027-01-26',
      desc: 'Republic Day flag hoisting & cultural programme',
    ),
    _c(
      'Environment Day',
      '2027-06-05',
      desc: 'World Environment Day – tree plantation drive',
      type: 'academic',
    ),
  ];
}
