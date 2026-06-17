import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/teacher_navigation.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class TeacherCalendarScreen extends StatefulWidget {
  const TeacherCalendarScreen({super.key});

  @override
  State<TeacherCalendarScreen> createState() => _TeacherCalendarScreenState();
}

class _TeacherCalendarScreenState extends State<TeacherCalendarScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 30;
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _holidays = [];
  List<Map<String, dynamic>> _celebrations = [];

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
      final allEvents = await api.getEvents();

      if (!mounted) return;
      setState(() {
        // Events tab — non-holiday, non-cultural entries
        _events = allEvents
            .where((e) =>
                e['is_holiday'] != true &&
                !_isCultural(e['event_type']))
            .map(_toCalendarRow)
            .toList()
          ..sort(_sortByDate);

        // Holidays tab — is_holiday flag or type == 'holiday'
        _holidays = allEvents
            .where((e) =>
                e['is_holiday'] == true ||
                (_clean(e['event_type']).toLowerCase() == 'holiday'))
            .map(_toHolidayRow)
            .toList()
          ..sort(_sortByDate);

        // Celebrations tab — cultural events
        _celebrations = allEvents
            .where((e) =>
                e['is_holiday'] != true &&
                _isCultural(e['event_type']))
            .map(_toCalendarRow)
            .toList()
          ..sort(_sortByDate);

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
        _celebrations = [];
      });
    }
  }

  bool _isCultural(dynamic type) {
    final t = _clean(type).toLowerCase();
    return t == 'cultural';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'School Calendar',
      subtitle: 'Holidays, events & celebrations for the academic year',
      drawer: TeacherDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.teacher,
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
          Tab(text: 'Celebrations'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTab(
                  rows: _events,
                  emptyTitle: 'No events',
                  emptyMessage: 'School events will appear here once published.',
                  itemBuilder: _eventCard,
                ),
                _buildTab(
                  rows: _holidays,
                  emptyTitle: 'No holidays',
                  emptyMessage:
                      'Published school holidays will appear here.',
                  itemBuilder: _holidayCard,
                ),
                _buildTab(
                  rows: _celebrations,
                  emptyTitle: 'No celebrations',
                  emptyMessage:
                      'Cultural celebrations will appear here once published.',
                  itemBuilder: _eventCard,
                ),
              ],
            ),
    );
  }

  Widget _buildTab({
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
            _buildError(),
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

  Widget _buildError() {
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

  Widget _eventCard(Map<String, dynamic> row) {
    final color = row['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dateBlock(row, color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row['title'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _typeBadge(row['type'] as String, color),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${row['day']} | ${row['time']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: context.appTheme.muted,
                  ),
                ),
                if ((row['venue'] as String).isNotEmpty)
                  Text(
                    'Venue: ${row['venue']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: context.appTheme.muted,
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
    final color = context.appTheme.error;
    final bg = context.appTheme.errorContainer;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.celebration_rounded, color: color, size: 22),
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
                    color: context.appTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          _typeBadge('Holiday', color, bg: bg),
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

  // ── Mapping helpers ────────────────────────────────────────────────────────

  Map<String, dynamic> _toCalendarRow(Map<String, dynamic> event) {
    final start = _dt(event['start_datetime'] ?? event['start_date']);
    final end = _dt(event['end_datetime'] ?? event['end_date']);
    final type = _resolveType(event['event_type']);
    final color = _typeColor(type);
    return {
      'title': _clean(event['event_title'] ?? event['event_name'],
          fallback: 'School Event'),
      'type': type,
      'time': _timeRange(start, end),
      'venue': _clean(event['venue'] ?? event['location']),
      'dateSort': start,
      'dateDay': start != null ? '${start.day}' : '-',
      'dateMonth': _monthShort(start),
      'day': _weekday(start),
      'color': color,
    };
  }

  Map<String, dynamic> _toHolidayRow(Map<String, dynamic> event) {
    final start = _dt(event['start_datetime'] ?? event['start_date']);
    return {
      'name': _clean(event['event_title'] ?? event['event_name'],
          fallback: 'Holiday'),
      'date': _fullDate(start),
      'day': _weekday(start),
      'dateSort': start,
    };
  }

  String _resolveType(dynamic raw) {
    final t = _clean(raw, fallback: 'event').toLowerCase();
    if (t.contains('cultural')) return 'Cultural';
    if (t.contains('academic')) return 'Academic';
    if (t.contains('sports')) return 'Sports';
    if (t.contains('health')) return 'Health';
    if (t.contains('meeting') || t.contains('ptm')) return 'PTM';
    if (t.contains('exam')) return 'Exam';
    return 'Event';
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'cultural':
        return const Color(0xFF8E44AD);
      case 'academic':
        return const Color(0xFF2980B9);
      case 'sports':
        return const Color(0xFF27AE60);
      case 'health':
        return const Color(0xFF16A085);
      case 'ptm':
        return const Color(0xFF1B4F72);
      case 'exam':
        return const Color(0xFFD35400);
      default:
        return const Color(0xFF1E8449);
    }
  }

  int _sortByDate(Map<String, dynamic> a, Map<String, dynamic> b) {
    final left = a['dateSort'];
    final right = b['dateSort'];
    if (left is DateTime && right is DateTime) return left.compareTo(right);
    if (left is DateTime) return -1;
    if (right is DateTime) return 1;
    return 0;
  }

  DateTime? _dt(dynamic value) {
    final text = _clean(value);
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  String _timeRange(DateTime? start, DateTime? end) {
    if (start == null) return 'All day';
    final startT = _time(start);
    if (end == null || _sameMinute(start, end)) return startT;
    return '$startT – ${_time(end)}';
  }

  String _time(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $suffix';
  }

  String _monthShort(DateTime? dt) {
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[dt.month - 1];
  }

  String _weekday(DateTime? dt) {
    if (dt == null) return '-';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }

  String _fullDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day} ${_monthShort(dt)} ${dt.year}';
  }

  bool _sameMinute(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

  String _clean(dynamic value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }
}
