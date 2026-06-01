import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';

class ParentCalendarScreen extends StatefulWidget {
  const ParentCalendarScreen({super.key});

  @override
  State<ParentCalendarScreen> createState() => _ParentCalendarScreenState();
}

class _ParentCalendarScreenState extends State<ParentCalendarScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 8;
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _holidays = [];
  List<Map<String, dynamic>> _examDates = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final ptms = await api.getRawList('/parent-teacher-meetings');
      final exams = await api.getExams();
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
              .where((event) => event['is_holiday'] != true)
              .map(_eventCalendarRow),
          ...ptms.map(_ptmCalendarRow),
        ]..sort(_sortByDate);
        _holidays = [
          ...events
              .where((event) => event['is_holiday'] == true)
              .map(_holidayFromEvent),
          ...holidayRows.map(_holidayCalendarRow),
        ]..sort(_sortByDate);
        _examDates = exams.map(_examCalendarRow).toList()..sort(_sortByDate);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
        _events = [];
        _holidays = [];
        _examDates = [];
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
      subtitle: 'See school events, holidays, and exam milestones',
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
          Tab(text: 'Exams'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildEventsTab(),
                _buildHolidaysTab(),
                _buildExamsTab(),
              ],
            ),
    );
  }

  Widget _buildEventsTab() {
    return _tabList(
      rows: _events,
      emptyTitle: 'No events',
      emptyMessage: 'School events and PTM slots will appear here.',
      itemBuilder: _eventCard,
    );
  }

  Widget _buildHolidaysTab() {
    return _tabList(
      rows: _holidays,
      emptyTitle: 'No holidays',
      emptyMessage: 'Published school holidays will appear here.',
      itemBuilder: _holidayCard,
    );
  }

  Widget _buildExamsTab() {
    return _tabList(
      rows: _examDates,
      emptyTitle: 'No exams',
      emptyMessage: 'Published exam milestones will appear here.',
      itemBuilder: _examCard,
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
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dateBlock(event, color),
          const SizedBox(width: 12),
          Expanded(
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _typeBadge(event['type'] as String, color),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${event['day']} | ${event['time']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.muted,
                  ),
                ),
                if ((event['venue'] as String).isNotEmpty)
                  Text(
                    'Venue: ${event['venue']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _holidayCard(Map<String, dynamic> holiday) {
    final type = holiday['type'] as String;
    final typeColor = switch (type.toLowerCase()) {
      'national' => AppTheme.error,
      'state' => AppTheme.warning,
      _ => AppTheme.primary,
    };
    final typeBg = switch (type.toLowerCase()) {
      'national' => AppTheme.errorContainer,
      'state' => AppTheme.warningContainer,
      _ => AppTheme.primaryContainer,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: typeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.celebration_rounded, color: typeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday['name'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${holiday['day']}, ${holiday['date']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          _typeBadge(type, typeColor, bg: typeBg),
        ],
      ),
    );
  }

  Widget _examCard(Map<String, dynamic> exam) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.infoContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.quiz_rounded,
              color: AppTheme.info,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam['exam'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${exam['date']} | ${exam['time']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _typeBadge(exam['status'] as String, AppTheme.info),
        ],
      ),
    );
  }

  Widget _dateBlock(Map<String, dynamic> row, Color color) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            row['dateDay'] as String,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            row['dateMonth'] as String,
            style: GoogleFonts.dmSans(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String label, Color color, {Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
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

  Map<String, dynamic> _ptmCalendarRow(Map<String, dynamic> meeting) {
    final event = _map(meeting['event']);
    final slotDate =
        _dateTime(meeting['slot_date']) ?? _dateTime(event['start_datetime']);
    final eventTitle = _text(
      event['event_title'],
      fallback: 'Parent-Teacher Meeting',
    );
    final slotTime = _text(meeting['slot_time']);
    // Backend integration: PTM venue should come from the event/meeting API.
    // Leave it empty until a real location is published.
    return {
      'title': eventTitle,
      'type': 'PTM',
      'time': slotTime.isEmpty ? _timeRange(slotDate, null) : slotTime,
      'venue': _text(event['location']),
      'dateSort': slotDate,
      'dateDay': _dayNumber(slotDate),
      'dateMonth': _monthShort(slotDate),
      'day': _weekday(slotDate),
      'color': const Color(0xFF1B4F72),
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

  Map<String, dynamic> _examCalendarRow(ExamModel exam) {
    final start = _dateTime(exam.startDate);
    final end = _dateTime(exam.endDate);
    final range = end == null || _sameDay(start, end)
        ? _fullDate(start)
        : '${_fullDate(start)} - ${_fullDate(end)}';
    return {
      'exam': exam.examName,
      'date': range,
      'time': 'Published window',
      'status': exam.isPublished ? 'Published' : 'Planned',
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

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  DateTime? _dateTime(dynamic value) {
    final raw = _text(value);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _eventType(dynamic value) {
    final raw = _text(value, fallback: 'event').toLowerCase();
    if (raw.contains('ptm') || raw.contains('parent')) return 'PTM';
    if (raw.contains('exam') || raw.contains('test')) return 'Exam';
    if (raw.contains('holiday')) return 'School';
    return _title(raw);
  }

  Color _eventColor(String type) {
    switch (type.toLowerCase()) {
      case 'ptm':
        return const Color(0xFF1B4F72);
      case 'exam':
        return AppTheme.info;
      case 'school':
        return AppTheme.primary;
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
