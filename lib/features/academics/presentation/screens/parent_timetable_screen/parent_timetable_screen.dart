import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_child_selector.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class ParentTimetableScreen extends StatefulWidget {
  const ParentTimetableScreen({super.key});

  @override
  State<ParentTimetableScreen> createState() => _ParentTimetableScreenState();
}

class _ParentTimetableScreenState extends State<ParentTimetableScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = ParentNav.timetable;
  int _activeChildIndex = 0;

  List<String> _children = [];
  List<String> _childIds = [];
  List<Map<String, dynamic>> _childRows = [];
  List<dynamic> _allSlots = [];
  bool _loading = true;
  int _selectedDay = 1; // 1 = Monday, 2 = Tuesday, etc.

  // Monotonically increasing token. Each _loadChildTimetable call captures the
  // current token; if it no longer matches when the await returns, the result
  // belongs to a stale load and is discarded.
  int _loadToken = 0;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    // Set selected day to current day of week (Monday-Saturday)
    final weekday = DateTime.now().weekday;
    if (weekday >= 1 && weekday <= 6) {
      _selectedDay = weekday;
    } else {
      _selectedDay = 1;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final childrenResponse = await BackendApiClient.instance.getMyStudents();
      final childLabels = childrenResponse.map((c) {
        final first = (c['first_name'] ?? '').toString();
        final last = (c['last_name'] ?? '').toString();
        final name = [first, last].where((e) => e.isNotEmpty).join(' ').trim();
        final grade = (c['grade_name'] ?? '').toString();
        final section = (c['section_name'] ?? '').toString();
        final classLabel = [
          grade,
          section,
        ].where((e) => e.isNotEmpty).join('-');
        return classLabel.isEmpty ? name : '$name ($classLabel)';
      }).toList();
      final childIds = childrenResponse
          .map((c) => (c['id'] ?? c['student_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();
      final selectedIndex = await ParentChildSelectionService.indexFor(
        childrenResponse,
        fallback: _activeChildIndex,
      );
      setState(() {
        _children = childLabels;
        _childIds = childIds;
        _childRows = childrenResponse
            .map((child) => Map<String, dynamic>.from(child))
            .toList();
        _activeChildIndex = selectedIndex;
      });
      if (_children.isNotEmpty && _childIds.isNotEmpty) {
        await _loadChildTimetable(selectedIndex);
      } else {
        setState(() => _loading = false);
      }
    } on Object catch (e) {
      setState(() => _loading = false);
      _showErrorSnackBar('Failed to load child list: $e');
    }
  }

  Future<void> _loadChildTimetable(int childIndex) async {
    if (childIndex >= _childRows.length) return;
    // Capture a unique token for this load. If the user taps another child
    // before this await resolves, _loadToken will have been incremented and
    // the stale result is silently discarded.
    final token = ++_loadToken;
    setState(() => _loading = true);
    try {
      final child = _childRows[childIndex];
      final sectionId = _stringValue(
        child['current_section_id'] ?? child['section_id'],
      );
      final response = sectionId.isEmpty
          ? <Map<String, dynamic>>[]
          : await BackendApiClient.instance.getTimetableSlots(
              sectionId: sectionId,
            );
      if (!mounted || token != _loadToken) return; // stale load — discard
      setState(() {
        _allSlots = response;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() => _loading = false);
      _showErrorSnackBar('Failed to load child timetable: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<dynamic> get _daySlots {
    final filtered = _allSlots.where((slot) {
      final dow = _intValue(slot['day_of_week']);
      return dow == _selectedDay;
    }).toList();
    // Sort slots by period number or start time
    filtered.sort((a, b) {
      final pA = _intValue(a['period_number']);
      final pB = _intValue(b['period_number']);
      return pA.compareTo(pB);
    });
    return filtered;
  }

  int _intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  String _stringValue(dynamic value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final drawer = ParentDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );

    return SchoolDeskModuleScaffold(
      title: 'Class Timetable',
      subtitle: 'View child class periods and subject schedule',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () {
            if (_childIds.isNotEmpty) {
              _loadChildTimetable(_activeChildIndex);
            } else {
              _loadData();
            }
          },
          tooltip: 'Refresh schedule',
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChildSelector(),
                  const SizedBox(height: 16),
                  _buildDaySelector(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _daySlots.isEmpty
                        ? _buildEmptyState()
                        : _buildPeriodsList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildChildSelector() {
    if (_children.isEmpty) return const SizedBox.shrink();
    final children = List.generate(
      _children.length,
      (index) => {'id': _childIds[index], 'name': _children[index]},
    );
    return ParentChildSelector(
      children: children,
      selectedIndex: _activeChildIndex,
      onSelected: (index) {
        setState(() => _activeChildIndex = index);
        ParentChildSelectionService.saveIndex(children, index);
        _loadChildTimetable(index);
      },
    );
  }

  Widget _buildDaySelector() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.appTheme.surfaceVariant.withAlpha(100),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        children: List.generate(_days.length, (index) {
          final dayNum = index + 1;
          final isActive = _selectedDay == dayNum;
          final dayName = _days[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDay = dayNum),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF1A6B4A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1A6B4A).withAlpha(50),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  dayName.substring(0, 3),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive ? Colors.white : context.appTheme.muted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 48,
            color: context.appTheme.muted,
          ),
          const SizedBox(height: 12),
          Text(
            'No classes scheduled for ${_days[_selectedDay - 1]}',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.appTheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check other days or contact the school principal.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: context.appTheme.muted,
            ),
          ),
        ],
      ),
    );
  }

  // Color palette cycling for subject cards
  static const List<List<Color>> _subjectGradients = [
    [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
    [Color(0xFF0F766E), Color(0xFF14B8A6)],
    [Color(0xFF7C3AED), Color(0xFFA78BFA)],
    [Color(0xFFEA580C), Color(0xFFFB923C)],
    [Color(0xFF0284C7), Color(0xFF38BDF8)],
    [Color(0xFF15803D), Color(0xFF4ADE80)],
    [Color(0xFFB91C1C), Color(0xFFF87171)],
    [Color(0xFFB45309), Color(0xFFFBBF24)],
  ];

  Widget _buildPeriodsList() {
    return ListView.builder(
      itemCount: _daySlots.length,
      itemBuilder: (context, index) {
        final slot = _daySlots[index];
        final subjectMap = _mapValue(slot['subject']);
        final staffMap = _mapValue(slot['staff']);
        final roomMap = _mapValue(slot['room']);
        final subject = _stringValue(
          slot['subject_name'] ?? subjectMap['subject_name'],
          fallback: 'Regular Period',
        );
        final teacher = _stringValue(
          slot['staff_name'] ??
              '${staffMap['first_name'] ?? ''} ${staffMap['last_name'] ?? ''}',
          fallback: 'Unassigned',
        );
        final room = _stringValue(
          slot['room_number'] ?? roomMap['room_number'],
          fallback: '-',
        );
        final startTime = _stringValue(slot['start_time'], fallback: '-');
        final endTime = _stringValue(slot['end_time'], fallback: '-');
        final periodNum = _intValue(slot['period_number'], fallback: index + 1);
        final gradient = _subjectGradients[index % _subjectGradients.length];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: context.appTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.appTheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colored period number sidebar
                Container(
                  width: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'P$periodNum',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Period',
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
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
                                subject,
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.appTheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 12,
                                    color: context.appTheme.muted,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      teacher,
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
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: gradient[0].withAlpha(15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: gradient[0].withAlpha(40),
                                ),
                              ),
                              child: Text(
                                '$startTime – $endTime',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: gradient[0],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.room_rounded,
                                  size: 11,
                                  color: context.appTheme.muted,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Rm $room',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: context.appTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
