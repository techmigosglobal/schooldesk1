import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../services/backend_api_client.dart';

class EventsCalendarScreen extends StatefulWidget {
  const EventsCalendarScreen({super.key});

  @override
  State<EventsCalendarScreen> createState() => _EventsCalendarScreenState();
}

class _EventsCalendarScreenState extends State<EventsCalendarScreen>
    with SingleTickerProviderStateMixin {
  int _selectedDrawerIndex = 10;
  late TabController _tabController;
  int _selectedMonth = 4;
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _holidays = [];
  String _academicYearId = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final years = await BackendApiClient.instance.getAcademicYears();
      final currentYears = years.where((y) => y.isCurrent).toList();
      final academicYearId = currentYears.isNotEmpty
          ? currentYears.first.id
          : (years.isNotEmpty ? years.first.id : '');
      final events = await BackendApiClient.instance.getEvents(
        academicYearId: academicYearId.isEmpty ? null : academicYearId,
      );
      if (!mounted) return;
      setState(() {
        _academicYearId = academicYearId;
        _events = events.map(_eventFromApi).toList();
        _holidays = _events.where((e) => e['holiday'] == true).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _eventFromApi(Map<String, dynamic> event) {
    final start = DateTime.tryParse((event['start_datetime'] ?? '').toString());
    final end = DateTime.tryParse((event['end_datetime'] ?? '').toString());
    final dateLabel = start == null
        ? ''
        : '${start.day} ${_monthName(start.month)} ${start.year}';
    final timeLabel = start == null
        ? 'TBD'
        : '${_twoDigits(start.hour)}:${_twoDigits(start.minute)}'
              '${end == null ? '' : ' - ${_twoDigits(end.hour)}:${_twoDigits(end.minute)}'}';
    return {
      'id': event['id'] ?? '',
      'title': event['event_title'] ?? '',
      'type': event['event_type'] ?? 'event',
      'date': dateLabel,
      'day': start?.day ?? '',
      'month': start?.month ?? _selectedMonth,
      'status': 'scheduled',
      'holiday': event['is_holiday'] == true,
      'location': event['location'] ?? '',
      'venue': event['location'] ?? '',
      'time': timeLabel,
      'description': event['description'] ?? event['event_title'] ?? '',
      'name': event['event_title'] ?? '',
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _monthEvents =>
      _events.where((e) => e['month'] == _selectedMonth).toList();

  @override
  Widget build(BuildContext context) {
    final drawer = PrincipalDrawer(
      selectedIndex: _selectedDrawerIndex,
      onDestinationSelected: (i) => setState(() => _selectedDrawerIndex = i),
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Calendar',
        subtitle: 'Plan calendars, events, and holidays for the school year',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Calendar',
      subtitle: 'Plan calendars, events, and holidays for the school year',
      drawer: drawer,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DashboardFabWidget(role: DashboardRole.principal),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: _openAddEventPage,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Event'),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Calendar'),
          Tab(text: 'Events'),
          Tab(text: 'Holidays'),
        ],
      ),
      body: MediaQuery.of(context).size.width >= 840
          ? _buildTabletLayout(context)
          : _buildPhoneLayout(context),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return TabBarView(
      controller: _tabController,
      children: [_buildCalendarTab(), _buildEventsTab(), _buildHolidaysTab()],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return TabBarView(
      controller: _tabController,
      children: [_buildCalendarTab(), _buildEventsTab(), _buildHolidaysTab()],
    );
  }

  Widget _buildCalendarTab() {
    final months = [
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
    return Column(
      children: [
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(12, (i) {
                final m = i + 1;
                final selected = _selectedMonth == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMonth = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        months[i],
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppTheme.muted,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        Expanded(
          child: _monthEvents.isEmpty
              ? const Center(child: Text('No events this month'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _monthEvents.length,
                  itemBuilder: (_, i) => _buildEventCard(_monthEvents[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildEventsTab() {
    final upcoming = _events.where((e) => e['status'] != 'completed').toList();
    return upcoming.isEmpty
        ? Center(
            child: Text(
              'No upcoming events',
              style: GoogleFonts.dmSans(color: AppTheme.muted),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: upcoming.length,
            itemBuilder: (ctx, i) => _buildEventCard(upcoming[i]),
          );
  }

  Widget _buildHolidaysTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _holidays.length,
      itemBuilder: (ctx, i) {
        final h = _holidays[i];
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h['name'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      h['date'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  h['type'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppTheme.muted,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppTheme.error,
                ),
                onPressed: () async {
                  await _deleteEvent(h);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> e) {
    final typeColors = {
      'Event': AppTheme.primary,
      'Meeting': AppTheme.info,
      'Exam': AppTheme.error,
      'Academic': AppTheme.warning,
      'Holiday': AppTheme.success,
      'Health': Colors.teal,
      'Staff': Colors.purple,
      'National': AppTheme.primary,
      'Cultural': Colors.orange,
      'Sports': Colors.green,
    };
    final color = typeColors[e['type']] ?? AppTheme.muted;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  e['day'].toString(),
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  e['month'].toString(),
                  style: GoogleFonts.dmSans(fontSize: 10, color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e['title'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        e['type'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  e['description'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      e['time'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                    if ((e['venue'] as String).isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          e['venue'] as String,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppTheme.error,
            ),
            onPressed: () async {
              await _deleteEvent(e);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openAddEventPage() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AddEventPage(
          academicYearId: _academicYearId,
          initialMonth: _selectedMonth,
        ),
      ),
    );
    if (!mounted || added != true) return;
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Event added'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    final id = '${event['id'] ?? ''}';
    if (id.isEmpty) return;
    try {
      await BackendApiClient.instance.deleteRaw('/events/$id');
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event removed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event remove failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

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
}

class _AddEventPage extends StatefulWidget {
  final String academicYearId;
  final int initialMonth;

  const _AddEventPage({
    required this.academicYearId,
    required this.initialMonth,
  });

  @override
  State<_AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<_AddEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  String _type = 'Event';
  int _day = 1;
  late int _month;
  bool _saving = false;
  String? _error;

  static const _eventTypes = [
    'Event',
    'Meeting',
    'Exam',
    'Academic',
    'Holiday',
    'Health',
    'Staff',
    'National',
    'Cultural',
    'Sports',
  ];

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _venueCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (widget.academicYearId.isEmpty) {
      setState(() => _error = 'Create an academic year first');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final year = DateTime.now().year;
      final timeParts = _parseEventTime(_timeCtrl.text);
      final start = DateTime(year, _month, _day, timeParts.$1, timeParts.$2);
      await BackendApiClient.instance.createEvent(
        academicYearId: widget.academicYearId,
        title: _titleCtrl.text.trim(),
        eventType: _type,
        start: start,
        end: start.add(const Duration(hours: 1)),
        location: _venueCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        isHoliday: _type == 'Holiday',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Event save failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Event')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Event Title'),
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Title required'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _day,
                      decoration: const InputDecoration(labelText: 'Day'),
                      items: List.generate(
                        31,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('${i + 1}'),
                        ),
                      ),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _day = value ?? _day),
                      validator: (_) {
                        final maxDay = DateTime(
                          DateTime.now().year,
                          _month + 1,
                          0,
                        ).day;
                        return _day > maxDay ? 'Invalid for month' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _month,
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(_monthNameFor(i + 1)),
                        ),
                      ),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _month = value ?? _month),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _eventTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _timeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Time',
                  hintText: '09:00 or 2:30 PM',
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return null;
                  final match = RegExp(
                    r'^\d{1,2}(?::\d{2})?\s*(AM|PM)?$',
                    caseSensitive: false,
                  ).hasMatch(trimmed);
                  return match ? null : 'Enter a valid time';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _venueCtrl,
                decoration: const InputDecoration(labelText: 'Venue'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppTheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : 'Add Event'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _monthNameFor(int month) {
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
    return months[month - 1];
  }

  static (int, int) _parseEventTime(String value) {
    final match = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return (9, 0);
    var hour = int.tryParse(match.group(1) ?? '') ?? 9;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final meridiem = (match.group(3) ?? '').toUpperCase();
    if (meridiem == 'PM' && hour < 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    return (hour.clamp(0, 23), minute.clamp(0, 59));
  }
}
