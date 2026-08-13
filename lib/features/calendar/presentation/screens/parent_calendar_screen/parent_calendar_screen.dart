import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class ParentCalendarScreen extends StatefulWidget {
  const ParentCalendarScreen({super.key});

  @override
  State<ParentCalendarScreen> createState() => _ParentCalendarScreenState();
}

class _ParentCalendarScreenState extends State<ParentCalendarScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = ParentNav.calendar;
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _holidays = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCalendar();
  }

  Future<void> _loadCalendar({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = BackendApiClient.instance;
      final academicYears = await api.getAcademicYears();
      final events = await api.getEvents();
      final holidayRows = <Map<String, dynamic>>[];
      for (final year
          in academicYears.where((year) => year.isCurrent).take(1)) {
        final detail = await api.getRawMap('/academic-years/${year.id}');
        holidayRows.addAll(_asListMap(detail['holidays']));
      }
      if (!mounted) return;
      setState(() {
        _events = [
          ...events
              .where(
                (event) =>
                    event['is_holiday'] != true &&
                    _text(event['event_type']).toLowerCase() != 'ptm',
              )
              .map(_eventCalendarRow),
        ]..sort(_sortByDate);
        _holidays = [
          ...events
              .where((event) => event['is_holiday'] == true)
              .map(_holidayFromEvent),
          ...holidayRows.map(_holidayCalendarRow),
        ]..sort(_sortByDate);
        _loading = false;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
        _events = [];
        _holidays = [];
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Calendar',
      subtitle: 'See school events and holidays',
      drawer: ParentDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          tooltip: 'Refresh calendar',
          onPressed: _loading ? null : () => _loadCalendar(showSpinner: false),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Events'),
          Tab(text: 'Holidays'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildEventsTab(), _buildHolidaysTab()],
            ),
    );
  }

  Widget _buildEventsTab() {
    return _calendarTab(
      rows: _events,
      emptyTitle: 'No events',
      emptyMessage: 'Published school events will appear here.',
      itemBuilder: _eventCard,
    );
  }

  Widget _buildHolidaysTab() {
    return _calendarTab(
      rows: _holidays,
      emptyTitle: 'No holidays',
      emptyMessage: 'Published school holidays will appear here.',
      itemBuilder: _holidayCard,
    );
  }

  Widget _calendarTab({
    required List<Map<String, dynamic>> rows,
    required String emptyTitle,
    required String emptyMessage,
    required Widget Function(Map<String, dynamic>) itemBuilder,
  }) {
    final selectedRows = _selectedDay == null
        ? rows
        : rows
              .where(
                (row) => _sameDay(row['dateSort'] as DateTime?, _selectedDay),
              )
              .toList();
    final label = _selectedDay == null
        ? 'All published dates'
        : 'Items on ${_fullDate(_selectedDay)}';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TableCalendar<Map<String, dynamic>>(
            firstDay: DateTime(2020),
            lastDay: DateTime(2035, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => _sameDay(day, _selectedDay),
            eventLoader: (day) => rows
                .where((row) => _sameDay(row['dateSort'] as DateTime?, day))
                .toList(),
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) => _focusedDay = focusedDay,
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: context.appTheme.primary,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: context.appTheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: context.appTheme.primary.withAlpha(90),
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (_selectedDay != null)
                TextButton(
                  onPressed: () => setState(() => _selectedDay = null),
                  child: const Text('Show all'),
                ),
            ],
          ),
        ),
        Expanded(
          child: _tabList(
            rows: selectedRows,
            emptyTitle: _selectedDay == null ? emptyTitle : 'Nothing scheduled',
            emptyMessage: _selectedDay == null
                ? emptyMessage
                : 'There are no published items on this date.',
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }

  Widget _tabList({
    required List<Map<String, dynamic>> rows,
    required String emptyTitle,
    required String emptyMessage,
    required Widget Function(Map<String, dynamic>) itemBuilder,
  }) {
    return RefreshIndicator(
      onRefresh: () => _loadCalendar(showSpinner: false),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            _buildErrorState(),
            const SizedBox(height: 16),
          ],
          if (rows.isEmpty)
            SchoolDeskStatusPanel.empty(
              title: emptyTitle,
              message: emptyMessage,
            )
          else
            ...rows.map(itemBuilder),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appTheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appTheme.error.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: context.appTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error ?? 'Unable to load calendar',
              style: GoogleFonts.dmSans(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _loadCalendar,
            child: Text('Retry', style: GoogleFonts.dmSans(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _eventCard(Map<String, dynamic> event) {
    final color = event['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient date block
          Container(
            width: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withAlpha(200)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event['dateDay'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  event['dateMonth'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: Colors.white.withAlpha(220),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event['title'] as String,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _typeBadge(event['type'] as String, color),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: context.appTheme.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${event['day']} · ${event['time']}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: context.appTheme.muted,
                        ),
                      ),
                    ],
                  ),
                  if ((event['venue'] as String).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: context.appTheme.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event['venue'] as String,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: context.appTheme.muted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _holidayCard(Map<String, dynamic> holiday) {
    final type = holiday['type'] as String;
    final typeColor = switch (type.toLowerCase()) {
      'national' => const Color(0xFFDC2626),
      'state' => const Color(0xFFD97706),
      _ => const Color(0xFF1D4ED8),
    };
    final gradient = switch (type.toLowerCase()) {
      'national' => [const Color(0xFFDC2626), const Color(0xFFF87171)],
      'state' => [const Color(0xFFD97706), const Color(0xFFFBBF24)],
      _ => [const Color(0xFF1D4ED8), const Color(0xFF60A5FA)],
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: typeColor.withAlpha(45)),
        boxShadow: [
          BoxShadow(
            color: typeColor.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.celebration_rounded, color: Colors.white, size: 24),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          holiday['name'] as String,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${holiday['day']}, ${holiday['date']}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: context.appTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _typeBadge(type, typeColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(28), color.withAlpha(16)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(55)),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Map<String, dynamic> _eventCalendarRow(Map<String, dynamic> event) {
    final start = _dateTime(event['start_datetime']);
    final end = _dateTime(event['end_datetime']);
    final type = _eventType(event['event_type']);
    final color = _eventColor(type);
    return {
      'title': _text(event['event_title'], fallback: 'School event'),
      'type': type,
      'time': _timeRange(start, end),
      'venue': _text(event['location']),
      'dateSort': start,
      'dateDay': _dayNumber(start),
      'dateMonth': _monthShort(start),
      'day': _weekday(start),
      'color': color,
    };
  }

  Map<String, dynamic> _holidayFromEvent(Map<String, dynamic> event) {
    final start = _dateTime(event['start_datetime']);
    final type = _eventType(event['event_type']);
    return {
      'name': _text(event['event_title'], fallback: 'Holiday'),
      'date': _fullDate(start),
      'day': _weekday(start),
      'type': type == 'Event' ? 'School' : type,
      'dateSort': start,
    };
  }

  Map<String, dynamic> _holidayCalendarRow(Map<String, dynamic> holiday) {
    final start = _dateTime(holiday['from_date']);
    final end = _dateTime(holiday['to_date']);
    final range = end == null || _sameDay(start, end)
        ? _fullDate(start)
        : '${_fullDate(start)} - ${_fullDate(end)}';
    return {
      'name': _text(holiday['holiday_name'], fallback: 'Holiday'),
      'date': range,
      'day': _weekday(start),
      'type': _title(_text(holiday['type'], fallback: 'School')),
      'dateSort': start,
    };
  }

  int _sortByDate(Map<String, dynamic> a, Map<String, dynamic> b) {
    final left = a['dateSort'];
    final right = b['dateSort'];
    if (left is DateTime && right is DateTime) return left.compareTo(right);
    if (left is DateTime) return -1;
    if (right is DateTime) return 1;
    return 0;
  }

  List<Map<String, dynamic>> _asListMap(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  DateTime? _dateTime(dynamic value) {
    final raw = _text(value);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _eventType(dynamic value) {
    final raw = _text(value, fallback: 'event').toLowerCase();
    if (raw.contains('exam') || raw.contains('test')) return 'Exam';
    if (raw.contains('holiday')) return 'School';
    return _title(raw);
  }

  Color _eventColor(String type) {
    switch (type.toLowerCase()) {
      case 'exam':
        return context.appTheme.info;
      case 'school':
        return context.appTheme.primary;
      default:
        return const Color(0xFF1E8449);
    }
  }

  String _timeRange(DateTime? start, DateTime? end) {
    if (start == null) return '-';
    final startLabel = _time(start);
    if (end == null || _sameMinute(start, end)) return startLabel;
    return '$startLabel - ${_time(end)}';
  }

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _dayNumber(DateTime? value) => value == null ? '-' : '${value.day}';

  String _monthShort(DateTime? value) {
    if (value == null) return '';
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
    return months[value.month - 1];
  }

  String _weekday(DateTime? value) {
    if (value == null) return '-';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[value.weekday - 1];
  }

  String _fullDate(DateTime? value) {
    if (value == null) return '-';
    return '${value.day} ${_monthShort(value)} ${value.year}';
  }

  bool _sameDay(DateTime? a, DateTime? b) =>
      a != null &&
      b != null &&
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  bool _sameMinute(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

  String _text(dynamic value, {dynamic fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return '${fallback ?? ''}'.trim();
    return text;
  }

  String _title(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return raw;
    return raw[0].toUpperCase() + raw.substring(1);
  }
}
