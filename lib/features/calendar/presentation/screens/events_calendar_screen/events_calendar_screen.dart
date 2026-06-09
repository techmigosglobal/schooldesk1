import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';
import 'package:schooldesk1/core/widgets/principal_directory_ui.dart';

enum _EventFilter {
  month,
  all,
  today,
  upcoming,
  holidays,
  approvals,
  cancelled,
}

class EventsCalendarScreen extends StatefulWidget {
  const EventsCalendarScreen({super.key});

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
  _EventFilter _filter = _EventFilter.month;

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
      setState(() {
        _academicYears = years;
        _selectedAcademicYearId = selectedYearId;
        _events = events;
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
    final role = BackendApiClient.instance.currentRoleName
        ?.trim()
        .toLowerCase();
    return role == null ||
        role.isEmpty ||
        role == 'admin' ||
        role == 'principal';
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

  int get _selectedMonthCount =>
      _events.where((event) => event.overlapsMonth(_selectedMonth)).length;

  int get _todayCount {
    final now = DateTime.now();
    return _events
        .where((event) => DateUtils.isSameDay(event.start, now))
        .length;
  }

  int get _upcomingCount {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return _events
        .where(
          (event) => !event.start.isBefore(startOfToday) && !event.isCancelled,
        )
        .length;
  }

  int get _holidayCount => _events.where((event) => event.isHoliday).length;

  int get _approvalCount =>
      _events.where((event) => event.needsApproval).length;

  Future<void> _openCreateEvent() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _EventFormPage(
          academicYears: _academicYears,
          selectedAcademicYearId: _selectedAcademicYearId,
          initialMonth: _selectedMonth,
        ),
      ),
    );
    if (saved == true) {
      await _loadData();
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
    final saved = await Navigator.of(context).push<bool>(
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
    if (saved == true) {
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
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
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
          backgroundColor: AppTheme.error,
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
          backgroundColor: AppTheme.error,
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
    final visible = _visibleEvents;
    return PrincipalDirectoryScaffold(
      title: 'Events Directory',
      subtitle:
          'Live school calendar for events, holidays, PTMs, and approvals',
      loading: _loading,
      error: _error,
      onRefresh: _loadData,
      onAdd: _canManageEvents ? _openCreateEvent : null,
      addTooltip: 'Create event',
      addIcon: Icons.event_available_rounded,
      isEmpty: !_loading && _error == null && visible.isEmpty,
      emptyState: EmptyStateWidget(
        icon: Icons.event_busy_rounded,
        title: 'No events found',
        description: _events.isEmpty
            ? 'Create the first event for the selected academic year.'
            : 'Adjust search, month, or status filters to see more events.',
      ),
      filters: _buildFilters(),
      slivers: [
        SliverToBoxAdapter(
          child: PrincipalDirectoryMetricStrip(
            metrics: [
              PrincipalDirectoryMetric(
                label: _monthName(_selectedMonth),
                value: '$_selectedMonthCount',
                icon: Icons.calendar_month_rounded,
                color: principalDirectoryAccent,
                tone: const Color(0xFFEAF4FF),
              ),
              PrincipalDirectoryMetric(
                label: 'Today',
                value: '$_todayCount',
                icon: Icons.today_rounded,
                color: Colors.teal,
                tone: const Color(0xFFE4FAF6),
              ),
              PrincipalDirectoryMetric(
                label: 'Upcoming',
                value: '$_upcomingCount',
                icon: Icons.upcoming_rounded,
                color: Colors.indigo,
                tone: const Color(0xFFEAF0FF),
              ),
              PrincipalDirectoryMetric(
                label: 'Holidays',
                value: '$_holidayCount',
                icon: Icons.celebration_rounded,
                color: Colors.green,
                tone: const Color(0xFFEAFBF0),
              ),
              PrincipalDirectoryMetric(
                label: 'Approvals',
                value: '$_approvalCount',
                icon: Icons.fact_check_rounded,
                color: Colors.orange,
                tone: const Color(0xFFFFF4E5),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 96),
          sliver: SliverList.separated(
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _EventDirectoryCard(
              event: visible[index],
              onTap: () => _openDetails(visible[index]),
              canManage: _canManageEvents,
              onAction: (action) => _handleEventAction(action, visible[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrincipalDirectorySearchBox(
            hint: 'Search event, venue, audience...',
            onChanged: (value) => setState(() => _query = value),
          ),
          if (_academicYears.length > 1) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
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
                if (value == null || value == _selectedAcademicYearId) return;
                setState(() => _selectedAcademicYearId = value);
                await _loadData();
              },
            ),
          ],
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in _EventFilter.values) ...[
                  PrincipalDirectoryChip(
                    label: _filterLabel(filter),
                    selected: _filter == filter,
                    icon: _filterIcon(filter),
                    onTap: () => setState(() => _filter = filter),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
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
          ),
        ],
      ),
    );
  }

  String _filterLabel(_EventFilter filter) {
    return switch (filter) {
      _EventFilter.month => 'Month',
      _EventFilter.all => 'All',
      _EventFilter.today => 'Today',
      _EventFilter.upcoming => 'Upcoming',
      _EventFilter.holidays => 'Holidays',
      _EventFilter.approvals => 'Needs approval',
      _EventFilter.cancelled => 'Cancelled',
    };
  }

  IconData _filterIcon(_EventFilter filter) {
    return switch (filter) {
      _EventFilter.month => Icons.calendar_month_rounded,
      _EventFilter.all => Icons.all_inclusive_rounded,
      _EventFilter.today => Icons.today_rounded,
      _EventFilter.upcoming => Icons.upcoming_rounded,
      _EventFilter.holidays => Icons.celebration_rounded,
      _EventFilter.approvals => Icons.fact_check_rounded,
      _EventFilter.cancelled => Icons.event_busy_rounded,
    };
  }
}

class _EventDirectoryCard extends StatelessWidget {
  final _PrincipalEvent event;
  final VoidCallback onTap;
  final bool canManage;
  final Future<bool> Function(String action) onAction;

  const _EventDirectoryCard({
    required this.event,
    required this.onTap,
    required this.canManage,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return PrincipalDirectoryCard(
      icon: event.icon,
      title: event.title,
      subtitle: event.description.isEmpty
          ? '${event.dateLabel} | ${event.timeLabel}'
          : event.description,
      status: event.statusLabel,
      statusColor: event.statusColor,
      onTap: onTap,
      chips: [
        PrincipalInfoPill(icon: Icons.event_rounded, label: event.dateLabel),
        PrincipalInfoPill(
          icon: Icons.access_time_rounded,
          label: event.timeLabel,
        ),
        PrincipalInfoPill(
          icon: Icons.location_on_outlined,
          label: event.venue.isEmpty ? 'Venue TBD' : event.venue,
        ),
        PrincipalInfoPill(icon: Icons.groups_rounded, label: event.audience),
      ],
      trailing: canManage
          ? PopupMenuButton<String>(
              tooltip: 'Event options',
              onSelected: (value) async => onAction(value),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'view', child: Text('View details')),
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
              ],
            )
          : const Icon(Icons.chevron_right_rounded),
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
          final saved = await Navigator.of(context).push<bool>(
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
          if (saved == true && context.mounted) Navigator.pop(context, true);
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

class _EventFormPage extends StatefulWidget {
  final List<AcademicYearModel> academicYears;
  final String selectedAcademicYearId;
  final int initialMonth;
  final _PrincipalEvent? event;

  const _EventFormPage({
    required this.academicYears,
    required this.selectedAcademicYearId,
    required this.initialMonth,
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
    final fallbackDate = DateTime(now.year, widget.initialMonth, 1);
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
        await BackendApiClient.instance.createRaw('/events', payload);
      } else {
        await BackendApiClient.instance.updateRaw('/events/$eventId', payload);
      }
      if (mounted) Navigator.pop(context, true);
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
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    label: 'Start date',
                    value: _formatDate(_startDate),
                    icon: Icons.event_rounded,
                    onTap: _saving ? null : _pickStartDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerTile(
                    label: 'End date',
                    value: _formatDate(_endDate),
                    icon: Icons.event_available_rounded,
                    onTap: _saving ? null : _pickEndDate,
                  ),
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
              Row(
                children: [
                  Expanded(
                    child: _PickerTile(
                      label: 'Start time',
                      value: _formatTimeOfDay(_startTime),
                      icon: Icons.schedule_rounded,
                      onTap: _saving ? null : () => _pickTime(start: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickerTile(
                      label: 'End time',
                      value: _formatTimeOfDay(_endTime),
                      icon: Icons.schedule_send_rounded,
                      onTap: _saving ? null : () => _pickTime(start: false),
                    ),
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
                  color: AppTheme.error,
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
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDCE8F5)),
          color: const Color(0xFFF8FBFE),
        ),
        child: Row(
          children: [
            Icon(icon, color: principalDirectoryAccent, size: 20),
            const SizedBox(width: 8),
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
      'cancelled' => AppTheme.error,
      'pending' || 'pending_approval' || 'draft' => Colors.orange,
      _ => principalDirectoryAccent,
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
  return DateTime.tryParse(text);
}

DateTime? _parseDateAndTime(Object? date, Object? time) {
  final dateText = _clean(date);
  if (dateText.isEmpty) return null;
  final timeText = _clean(time, fallback: '00:00:00');
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
