import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/erp_module_scaffold.dart';

class TimetableManagementScreen extends StatefulWidget {
  const TimetableManagementScreen({super.key});

  @override
  State<TimetableManagementScreen> createState() =>
      _TimetableManagementScreenState();
}

class _TimetableManagementScreenState extends State<TimetableManagementScreen>
    with SingleTickerProviderStateMixin {
  int _selectedDrawerIndex = 4;
  late TabController _tabController;
  late String _selectedClass;
  String _selectedDay = 'Monday';
  bool _timetableApproved = false;

  List<String> _classes = [];
  final Map<String, SectionModel> _sectionsByClass = {};
  List<AcademicYearModel> _academicYears = [];
  List<Map<String, dynamic>> _terms = [];

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  final List<String> _subjects = [
    'Mathematics',
    'English',
    'Science',
    'Hindi',
    'Social Studies',
    'Computer Science',
    'Physical Education',
    'Art & Craft',
    'BREAK',
    'LUNCH',
  ];
  List<String> _teachers = [];

  Map<String, List<Map<String, dynamic>>> _timetable = {};
  List<Map<String, dynamic>> _substituteRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedClass = 'Unassigned';
    _loadData();
  }

  Future<void> _loadData() async {
    final api = BackendApiClient.instance;
    final slots = await api.getTimetableSlots();
    final substitutions = await api.getSubstitutions();
    final sections = await api.getSections();
    final staff = await api.getStaff(page: 1, pageSize: 100);
    final academicYears = await api.getAcademicYears();
    final currentYear = academicYears.isEmpty
        ? null
        : academicYears.firstWhere(
            (year) => year.isCurrent,
            orElse: () => academicYears.first,
          );
    final terms = currentYear == null
        ? <Map<String, dynamic>>[]
        : await api.getTerms(currentYear.id);
    final parsed = {for (final day in _days) day: <Map<String, dynamic>>[]};
    for (final slot in slots) {
      final day = _dayName(_intValue(slot['day_of_week'], fallback: 1));
      parsed.putIfAbsent(day, () => <Map<String, dynamic>>[]).add({
        'id': slot['id'],
        'section_id': slot['section_id'],
        'academic_year_id': slot['academic_year_id'],
        'term_id': slot['term_id'],
        'period': _intValue(slot['period_number'], fallback: 0),
        'subject': slot['subject']?['subject_name'] ?? slot['subject_id'] ?? '',
        'teacher': slot['staff'] == null
            ? slot['staff_id'] ?? ''
            : '${slot['staff']['first_name'] ?? ''} ${slot['staff']['last_name'] ?? ''}'
                  .trim(),
        'room': slot['room']?['room_number'] ?? slot['room_id'] ?? '',
        'time':
            '${slot['start_time'] ?? ''}${slot['end_time'] == null ? '' : ' - ${slot['end_time']}'}',
      });
    }
    final labels = _uniqueClassLabels(sections);
    if (!mounted) return;
    setState(() {
      _timetable = parsed;
      _substituteRequests = substitutions;
      _teachers = staff.data.map((t) => t.fullName).toList();
      _academicYears = academicYears;
      _terms = terms;
      _classes = labels;
      if (_classes.isNotEmpty && !_classes.contains(_selectedClass)) {
        _selectedClass = _classes.first;
      }
    });
  }

  String _sectionLabel(SectionModel section) {
    final grade = section.gradeName.trim();
    final sectionName = section.sectionName.trim();
    if (grade.isEmpty && sectionName.isEmpty) return section.id;
    if (grade.isEmpty) return 'Section $sectionName';
    if (sectionName.isEmpty) return grade;
    return '$grade - $sectionName';
  }

  List<String> _uniqueClassLabels(List<SectionModel> sections) {
    _sectionsByClass.clear();
    final nameCounts = <String, int>{};
    for (final section in sections) {
      final name = _sectionLabel(section);
      nameCounts[name] = (nameCounts[name] ?? 0) + 1;
    }

    final used = <String>{};
    return sections.map<String>((section) {
      final name = _sectionLabel(section);
      var label = name;
      if ((nameCounts[name] ?? 0) > 1) {
        final suffix = section.id.length > 8
            ? section.id.substring(0, 8)
            : section.id;
        label = '$name ($suffix)';
        var duplicateIndex = 2;
        while (used.contains(label)) {
          label = '$name ($suffix-$duplicateIndex)';
          duplicateIndex++;
        }
      }
      used.add(label);
      _sectionsByClass[label] = section;
      return label;
    }).toList();
  }

  SectionModel? get _selectedSection => _sectionsByClass[_selectedClass];

  AcademicYearModel? get _currentAcademicYear {
    if (_academicYears.isEmpty) return null;
    return _academicYears.firstWhere(
      (year) => year.isCurrent,
      orElse: () => _academicYears.first,
    );
  }

  String get _defaultTermId => _terms.isEmpty ? '' : '${_terms.first['id']}';

  int get _activeDayNumber => _days.indexOf(_selectedDay) + 1;

  List<Map<String, dynamic>> _periodsForSelectedClass() {
    final sectionId = _selectedSection?.id;
    final periods = List<Map<String, dynamic>>.from(
      _timetable[_selectedDay] ?? [],
    );
    if (sectionId == null || sectionId.isEmpty) return periods;
    return periods
        .where((period) => '${period['section_id'] ?? ''}' == sectionId)
        .toList();
  }

  String _dayName(int day) {
    if (day < 1 || day > _days.length) return _days.first;
    return _days[day - 1];
  }

  int _intValue(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  String _stringValue(dynamic value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? fallback : text;
  }

  String _staffLabel(dynamic value, {required String fallback}) {
    if (value is Map) {
      final firstName = _stringValue(value['first_name']);
      final lastName = _stringValue(value['last_name']);
      final fullName = '$firstName $lastName'.trim();
      if (fullName.isNotEmpty) return fullName;
      return _stringValue(value['name'], fallback: fallback);
    }
    return _stringValue(value, fallback: fallback);
  }

  String _substitutionDateLabel(dynamic value) {
    final text = _stringValue(value, fallback: 'Date not set');
    if (text.length >= 10) return text.substring(0, 10);
    return text;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Timetable Records',
      subtitle: 'Review admin-maintained schedules, substitutes, and alerts',
      drawer: PrincipalDrawer(
        selectedIndex: _selectedDrawerIndex,
        onDestinationSelected: (i) => setState(() => _selectedDrawerIndex = i),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      actions: [
        IconButton(
          tooltip: 'Generate suggestions',
          onPressed: _openTimetableSuggestionScreen,
          icon: const Icon(Icons.auto_awesome_outlined),
        ),
        if (!_timetableApproved)
          TextButton.icon(
            onPressed: () => _openTimetableAdviceScreen(),
            icon: const Icon(Icons.rate_review_outlined, size: 16),
            label: const Text('Raise Advice'),
          )
        else
          Chip(
            label: const Text('Advice raised'),
            backgroundColor: AppTheme.successContainer,
            labelStyle: GoogleFonts.dmSans(
              color: AppTheme.success,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'View Timetable'),
          Tab(text: 'Substitutes'),
          Tab(text: 'Alerts'),
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
      children: [
        _buildTimetableTab(),
        _buildSubstituteTab(),
        _buildAlertsTab(),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return _buildPhoneLayout(context);
  }

  Future<void> _openTimetableAdviceScreen() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _TimetableAdviceFormScreen(
          className: _selectedClass,
          day: _selectedDay,
          sectionId: _selectedSection?.id,
        ),
      ),
    );
    if (!mounted || sent != true) return;
    setState(() => _timetableApproved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Timetable advice sent to Admin'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _openTimetableSuggestionScreen() async {
    if (_selectedSection == null ||
        _currentAcademicYear == null ||
        _defaultTermId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Class and term setup are required first'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _TimetableSuggestionFormScreen(
          className: _selectedClass,
          day: _selectedDay,
          section: _selectedSection!,
          academicYear: _currentAcademicYear!,
          termId: _defaultTermId,
          dayOfWeek: _activeDayNumber,
        ),
      ),
    );
    if (!mounted || sent != true) return;
    setState(() => _timetableApproved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Timetable suggestions sent to Admin'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Widget _buildTimetableTab() {
    final periods = _periodsForSelectedClass();
    return Column(
      children: [
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildClassSelector(),
              const SizedBox(height: 10),
              _buildDaySelector(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final header = Text(
                '$_selectedClass — $_selectedDay',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_timetableApproved)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Approved',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppTheme.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _openTimetableSuggestionScreen,
                    icon: const Icon(Icons.auto_awesome_outlined, size: 14),
                    label: const Text('Suggest'),
                  ),
                  TextButton.icon(
                    onPressed: () => _openTimetableAdviceScreen(),
                    icon: const Icon(Icons.rate_review_outlined, size: 14),
                    label: const Text('Raise Advice'),
                  ),
                ],
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [header, const SizedBox(height: 6), actions],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: header),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            },
          ),
        ),
        Expanded(
          child: periods.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.calendar_view_week_outlined,
                  title: 'No timetable periods',
                  description:
                      'Backend timetable periods for the selected day will appear here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: periods.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _buildPeriodCard(periods[i], i),
                ),
        ),
      ],
    );
  }

  Widget _buildClassSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _classes.map((className) {
          final selected = _selectedClass == className;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: 'View timetable for $className',
              child: Semantics(
                button: true,
                selected: selected,
                label: '$className timetable',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: FilterChip(
                    label: Text(className, overflow: TextOverflow.ellipsis),
                    selected: selected,
                    selectedColor: AppTheme.primaryContainer,
                    backgroundColor: AppTheme.surfaceVariant,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(
                      color: selected ? AppTheme.primary : AppTheme.outline,
                    ),
                    checkmarkColor: AppTheme.primary,
                    labelStyle: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppTheme.primary : AppTheme.onSurface,
                    ),
                    onSelected: (_) => setState(() {
                      _selectedClass = className;
                      _timetableApproved = false;
                    }),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDaySelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _days.map((day) {
            final selected = _selectedDay == day;
            final label = compact ? day.substring(0, 3) : day;
            return Tooltip(
              message: 'View $day timetable',
              child: Semantics(
                button: true,
                selected: selected,
                label: '$day timetable',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 68,
                  ),
                  child: FilterChip(
                    label: Text(label, overflow: TextOverflow.ellipsis),
                    selected: selected,
                    selectedColor: AppTheme.primaryContainer,
                    backgroundColor: AppTheme.surfaceVariant,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(
                      color: selected ? AppTheme.primary : AppTheme.outline,
                    ),
                    checkmarkColor: AppTheme.primary,
                    labelStyle: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? AppTheme.primary : AppTheme.onSurface,
                    ),
                    onSelected: (_) => setState(() => _selectedDay = day),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPeriodCard(Map<String, dynamic> p, int index) {
    final isBreak = p['subject'] == 'BREAK' || p['subject'] == 'LUNCH';
    if (isBreak) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              p['subject'] == 'LUNCH'
                  ? Icons.lunch_dining_rounded
                  : Icons.coffee_rounded,
              size: 14,
              color: AppTheme.muted,
            ),
            const SizedBox(width: 8),
            Text(
              '${p['subject']} · ${p['time']}',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
            ),
          ],
        ),
      );
    }

    final colors = [
      AppTheme.primaryContainer,
      AppTheme.successContainer,
      AppTheme.warningContainer,
      AppTheme.infoContainer,
      AppTheme.secondaryContainer,
    ];
    final periodNum = (p['period'] is int)
        ? (p['period'] as int)
        : int.tryParse(p['period'].toString()) ?? (index + 1);
    final colorIndex = periodNum % colors.length;

    return GestureDetector(
      onTap: () => _openPeriodDetailScreen(p),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors[colorIndex],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'P$periodNum',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p['subject'] ?? '',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${p['teacher']} · ${p['room']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  p['time'] ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 2),
                const Icon(
                  Icons.visibility_outlined,
                  size: 14,
                  color: AppTheme.muted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPeriodDetailScreen(Map<String, dynamic> p) async {
    final guarded = _guardBackendDropdownValues(p);
    final raiseAdvice = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _TimetablePeriodDetailScreen(
          period: p,
          subject: guarded['subject'] ?? '',
          teacher: guarded['teacher'] ?? '',
        ),
      ),
    );
    if (!mounted || raiseAdvice != true) return;
    await _openTimetableAdviceScreen();
  }

  Widget _buildSubstituteTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Substitute Assignments',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openTimetableAdviceScreen(),
              icon: const Icon(Icons.rate_review_outlined, size: 16),
              label: const Text('Raise Advice'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._substituteRequests.asMap().entries.map(
          (e) => _buildSubstituteCard(e.value, e.key),
        ),
        if (_teachers.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Available Substitute Staff',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ..._teachers.map(
            (teacher) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildAvailableTeacherCard(
                teacher,
                'Backend staff record',
                'Availability verified by timetable service',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubstituteCard(Map<String, dynamic> s, int index) {
    final status = _stringValue(s['status']).toLowerCase();
    final isPending = status == 'pending';
    final originalStaff = _staffLabel(
      s['teacher'] ?? s['original_staff'] ?? s['original_staff_id'],
      fallback: 'Original staff unavailable',
    );
    final substituteStaff = _staffLabel(
      s['substitute'] ?? s['substitute_staff'] ?? s['substitute_staff_id'],
      fallback: isPending ? 'Unassigned' : 'Substitute unavailable',
    );
    final slot = s['timetable_slot'];
    final period = _stringValue(
      s['periods'] ??
          s['period_number'] ??
          (slot is Map ? slot['period_number'] : null),
      fallback: 'Period not set',
    );
    final date = _substitutionDateLabel(s['date']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending
              ? AppTheme.warning.withAlpha(100)
              : AppTheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  originalStaff,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPending
                      ? AppTheme.warningContainer
                      : AppTheme.successContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPending ? 'Unassigned' : 'Assigned',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPending ? AppTheme.warning : AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$date · $period',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 14,
                color: AppTheme.muted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Substitute: $substituteStaff',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openTimetableAdviceScreen(),
                icon: const Icon(Icons.rate_review_outlined, size: 14),
                label: const Text('Raise Advice'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailableTeacherCard(
    String name,
    String subject,
    String freeSlots,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.successContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.success.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.success.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                name.trim().isEmpty ? '?' : name.trim().substring(0, 1),
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$subject · $freeSlots',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openTimetableAdviceScreen(),
            child: Text(
              'Advise',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    final pendingSubstitutions = _substituteRequests
        .where((s) => '${s['status'] ?? ''}'.toLowerCase() == 'pending')
        .toList();
    if (pendingSubstitutions.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAlertCard(
            Icons.check_circle_outline_rounded,
            AppTheme.success,
            AppTheme.successContainer,
            'No Backend Timetable Alerts',
            'Timetable alerts from the backend will appear here.',
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: pendingSubstitutions
          .map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildAlertCard(
                Icons.person_off_outlined,
                AppTheme.warning,
                AppTheme.warningContainer,
                'Substitute Needed',
                '${request['teacher'] ?? request['original_staff_id'] ?? 'Staff'} · ${request['date'] ?? ''} · ${request['periods'] ?? request['period'] ?? ''}',
                showResolve: true,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAlertCard(
    IconData icon,
    Color color,
    Color bgColor,
    String title,
    String message, {
    bool showResolve = false,
    bool showApprove = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showResolve || showApprove) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (showResolve)
                  TextButton(
                    onPressed: () => _openTimetableAdviceScreen(),
                    child: Text(
                      'Raise Advice',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                if (showApprove)
                  TextButton(
                    onPressed: _openTimetableAdviceScreen,
                    child: Text(
                      'Raise Advice',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Map<String, String> _guardBackendDropdownValues(Map<String, dynamic> p) {
    var selectedSubject = '${p['subject'] ?? ''}';
    if (!_subjects.contains(selectedSubject)) selectedSubject = 'Mathematics';
    var selectedTeacher = '${p['teacher'] ?? ''}';
    if (!_teachers.contains(selectedTeacher)) selectedTeacher = '';
    return {'subject': selectedSubject, 'teacher': selectedTeacher};
  }
}

class _TimetableAdviceFormScreen extends StatefulWidget {
  final String className;
  final String day;
  final String? sectionId;

  const _TimetableAdviceFormScreen({
    required this.className,
    required this.day,
    required this.sectionId,
  });

  @override
  State<_TimetableAdviceFormScreen> createState() =>
      _TimetableAdviceFormScreenState();
}

class _TimetableAdviceFormScreenState
    extends State<_TimetableAdviceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'class_name': widget.className,
        'day': widget.day,
        'message': _messageCtrl.text.trim(),
        'status': 'open',
      };
      final sectionId = widget.sectionId?.trim();
      if (sectionId != null && sectionId.isNotEmpty) {
        payload['section_id'] = sectionId;
      }
      await BackendApiClient.instance.createRaw(
        '/principal/timetable-advice',
        payload,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Advice failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Raise Timetable Advice',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.surface,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _TimetableFormSection(
              title: 'Selected Timetable',
              children: [
                _TimetableReadOnlyValue(
                  label: 'Class / Section',
                  value: widget.className,
                ),
                _TimetableReadOnlyValue(label: 'Day', value: widget.day),
                _TimetableReadOnlyValue(
                  label: 'Section ID',
                  value: widget.sectionId?.isEmpty == false
                      ? widget.sectionId!
                      : 'Not available',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _TimetableFormSection(
              title: 'Advice Details',
              children: [
                TextFormField(
                  controller: _messageCtrl,
                  minLines: 5,
                  maxLines: 8,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Advice / request details',
                    hintText:
                        'Describe the schedule change or review needed by administrators.',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length < 8) {
                      return 'Enter the advice details.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: const Text('Send Advice'),
          ),
        ),
      ),
    );
  }
}

class _TimetableSuggestionFormScreen extends StatefulWidget {
  final String className;
  final String day;
  final SectionModel section;
  final AcademicYearModel academicYear;
  final String termId;
  final int dayOfWeek;

  const _TimetableSuggestionFormScreen({
    required this.className,
    required this.day,
    required this.section,
    required this.academicYear,
    required this.termId,
    required this.dayOfWeek,
  });

  @override
  State<_TimetableSuggestionFormScreen> createState() =>
      _TimetableSuggestionFormScreenState();
}

class _TimetableSuggestionFormScreenState
    extends State<_TimetableSuggestionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _periodCountCtrl = TextEditingController(text: '7');
  final _startCtrl = TextEditingController(text: '09:00');
  final _durationCtrl = TextEditingController(text: '40');
  final _gapCtrl = TextEditingController(text: '5');
  TimetableSuggestionResult? _preview;
  bool _previewing = false;
  bool _sending = false;

  @override
  void dispose() {
    _periodCountCtrl.dispose();
    _startCtrl.dispose();
    _durationCtrl.dispose();
    _gapCtrl.dispose();
    super.dispose();
  }

  Future<void> _previewSuggestions() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _previewing = true;
      _preview = null;
    });
    try {
      final preview = await BackendApiClient.instance.suggestTimetableSlots(
        sectionId: widget.section.id,
        academicYearId: widget.academicYear.id,
        termId: widget.termId,
        dayOfWeek: widget.dayOfWeek,
        periodCount: _positiveInt(_periodCountCtrl.text, 7),
        startTime: _startCtrl.text.trim(),
        periodDurationMinutes: _positiveInt(_durationCtrl.text, 40),
        gapMinutes: _nonNegativeInt(_gapCtrl.text, 5),
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _previewing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _previewing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Suggestion preview failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _sendAdvice() async {
    final preview = _preview;
    if (preview == null || !_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await BackendApiClient.instance.createRaw('/principal/timetable-advice', {
        'class_name': widget.className,
        'section_id': widget.section.id,
        'day': widget.day,
        'message': _suggestionAdviceMessage(preview),
        'status': 'open',
        'suggestions': preview.suggestions
            .map(
              (suggestion) => {
                ...suggestion.toSlotPayload(),
                'subject_name': suggestion.subjectName,
                'staff_name': suggestion.staffName,
                'warnings': suggestion.warnings,
                'blocking': suggestion.blocking,
              },
            )
            .toList(),
        'summary': preview.toSummaryPayload(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Suggestion advice failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  String _suggestionAdviceMessage(TimetableSuggestionResult preview) {
    final lines = preview.suggestions
        .map((suggestion) {
          final status = suggestion.blocking ? 'review needed' : 'ready';
          final warnings = suggestion.warnings.isEmpty
              ? ''
              : ' ${suggestion.warnings.join(' ')}';
          return 'P${suggestion.periodNumber}: ${suggestion.subjectName} with ${suggestion.staffName} (${suggestion.startTime}-${suggestion.endTime}) - $status.$warnings';
        })
        .join('\n');
    return 'Principal timetable suggestion for ${widget.className} on ${widget.day}.\n${preview.creatablePeriods} periods are ready and ${preview.blockedPeriods} need review.\n$lines';
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Suggest Timetable',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.surface,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _TimetableFormSection(
              title: 'Selected Timetable',
              children: [
                _TimetableReadOnlyValue(
                  label: 'Class / Section',
                  value: widget.className,
                ),
                _TimetableReadOnlyValue(label: 'Day', value: widget.day),
                _TimetableReadOnlyValue(
                  label: 'Academic Year',
                  value: widget.academicYear.yearLabel,
                ),
                _TimetableReadOnlyValue(label: 'Term ID', value: widget.termId),
                _TimetableReadOnlyValue(
                  label: 'Section ID',
                  value: widget.section.id,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _TimetableFormSection(
              title: 'Generation Parameters',
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 520;
                    final fields = [
                      _numberField(
                        controller: _periodCountCtrl,
                        label: 'Periods',
                        min: 1,
                        max: 12,
                      ),
                      _timeField(),
                      _numberField(
                        controller: _durationCtrl,
                        label: 'Minutes per period',
                        min: 1,
                        max: 180,
                      ),
                      _numberField(
                        controller: _gapCtrl,
                        label: 'Gap minutes',
                        min: 0,
                        max: 60,
                      ),
                    ];
                    if (!twoColumns) {
                      return Column(
                        children: fields
                            .map(
                              (field) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: field,
                              ),
                            )
                            .toList(),
                      );
                    }
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: fields[0]),
                            const SizedBox(width: 10),
                            Expanded(child: fields[1]),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: fields[2]),
                            const SizedBox(width: 10),
                            Expanded(child: fields[3]),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            _TimetableFormSection(
              title: 'Backend Preview',
              children: [_buildSuggestionPreview(preview)],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previewing || _sending
                      ? null
                      : _previewSuggestions,
                  icon: _previewing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Preview'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: preview == null || _sending || _previewing
                      ? null
                      : _sendAdvice,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Send Advice'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required int min,
    required int max,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final parsed = int.tryParse((value ?? '').trim());
        if (parsed == null || parsed < min || parsed > max) {
          return 'Use $min-$max';
        }
        return null;
      },
      onChanged: (_) => setState(() => _preview = null),
    );
  }

  Widget _timeField() {
    return TextFormField(
      controller: _startCtrl,
      keyboardType: TextInputType.datetime,
      decoration: const InputDecoration(
        labelText: 'Start time',
        hintText: '09:00',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        final match = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(text);
        if (!match) return 'Use HH:mm';
        return null;
      },
      onChanged: (_) => setState(() => _preview = null),
    );
  }

  Widget _buildSuggestionPreview(TimetableSuggestionResult? preview) {
    if (_previewing) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (preview == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Preview backend-generated suggestions before sending advice.',
          style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${preview.creatablePeriods} ready, ${preview.blockedPeriods} need review',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: preview.blockedPeriods == 0
                ? AppTheme.success
                : AppTheme.warning,
          ),
        ),
        const SizedBox(height: 8),
        ...preview.suggestions.map(_buildSuggestionRow),
      ],
    );
  }

  Widget _buildSuggestionRow(TimetableSuggestionModel suggestion) {
    final color = suggestion.blocking ? AppTheme.warning : AppTheme.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: suggestion.blocking
            ? AppTheme.warningContainer
            : AppTheme.successContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              'P${suggestion.periodNumber}',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.subjectName,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${suggestion.staffName} - ${suggestion.startTime} to ${suggestion.endTime}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (suggestion.warnings.isNotEmpty)
                  Text(
                    suggestion.warnings.join(' '),
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppTheme.warning,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _positiveInt(String value, int fallback) {
    final parsed = int.tryParse(value.trim()) ?? fallback;
    return parsed <= 0 ? fallback : parsed;
  }

  int _nonNegativeInt(String value, int fallback) {
    final parsed = int.tryParse(value.trim()) ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }
}

class _TimetablePeriodDetailScreen extends StatelessWidget {
  final Map<String, dynamic> period;
  final String subject;
  final String teacher;

  const _TimetablePeriodDetailScreen({
    required this.period,
    required this.subject,
    required this.teacher,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Period ${period['period'] ?? ''}',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _TimetableFormSection(
            title: 'Period Details',
            children: [
              _TimetableReadOnlyValue(label: 'Subject', value: subject),
              _TimetableReadOnlyValue(label: 'Teacher', value: teacher),
              _TimetableReadOnlyValue(
                label: 'Room',
                value: '${period['room'] ?? ''}'.trim().isEmpty
                    ? 'Not assigned'
                    : '${period['room']}',
              ),
              _TimetableReadOnlyValue(
                label: 'Time',
                value: '${period['time'] ?? ''}'.trim().isEmpty
                    ? 'Not set'
                    : '${period['time']}',
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Raise Advice'),
          ),
        ),
      ),
    );
  }
}

class _TimetableFormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _TimetableFormSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.muted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _TimetableReadOnlyValue extends StatelessWidget {
  final String label;
  final String value;

  const _TimetableReadOnlyValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
