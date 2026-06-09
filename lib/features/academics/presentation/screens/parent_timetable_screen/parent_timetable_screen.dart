import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';

class ParentTimetableScreen extends StatefulWidget {
  const ParentTimetableScreen({super.key});

  @override
  State<ParentTimetableScreen> createState() => _ParentTimetableScreenState();
}

class _ParentTimetableScreenState extends State<ParentTimetableScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 1; // Academics/Schedule nav index
  int _activeChildIndex = 0;
  static const _headerColor = Color(0xFF1A6B4A);

  List<String> _children = [];
  List<String> _childIds = [];
  List<dynamic> _allSlots = [];
  bool _loading = true;
  int _selectedDay = 1; // 1 = Monday, 2 = Tuesday, etc.

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
      setState(() {
        _children = childrenResponse.map((c) {
          final first = (c['first_name'] ?? '').toString();
          final last = (c['last_name'] ?? '').toString();
          final name = [first, last].where((e) => e.isNotEmpty).join(' ').trim();
          final grade = (c['grade_name'] ?? '').toString();
          final section = (c['section_name'] ?? '').toString();
          final classLabel = [grade, section].where((e) => e.isNotEmpty).join('-');
          return classLabel.isEmpty ? name : '$name ($classLabel)';
        }).toList();
        _childIds = childrenResponse
            .map((c) => (c['id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toList();

        if (_children.isNotEmpty && _childIds.isNotEmpty) {
          _loadChildTimetable(_activeChildIndex);
        } else {
          _loading = false;
        }
      });
    } catch (e) {
      setState(() => _loading = false);
      _showErrorSnackBar('Failed to load child list: $e');
    }
  }

  Future<void> _loadChildTimetable(int childIndex) async {
    if (childIndex >= _childIds.length) return;
    setState(() => _loading = true);
    try {
      final studentId = _childIds[childIndex];
      final response = await BackendApiClient.instance.getRawList('/me/timetable?student_id=$studentId');
      setState(() {
        _allSlots = response;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showErrorSnackBar('Failed to load child timetable: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<dynamic> get _daySlots {
    final filtered = _allSlots.where((slot) {
      final dow = slot['day_of_week'] as int? ?? 0;
      return dow == _selectedDay;
    }).toList();
    // Sort slots by period number or start time
    filtered.sort((a, b) {
      final pA = a['period_number'] as int? ?? 0;
      final pB = b['period_number'] as int? ?? 0;
      return pA.compareTo(pB);
    });
    return filtered;
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_children.length, (i) {
          final isActive = i == _activeChildIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _activeChildIndex = i;
              });
              _loadChildTimetable(i);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? _headerColor : AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? _headerColor : AppTheme.outlineVariant,
                ),
              ),
              child: Text(
                _children[i].split(' ').first,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppTheme.onSurface,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withAlpha(80),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(_days.length, (index) {
          final dayNum = index + 1;
          final isActive = _selectedDay == dayNum;
          final dayName = _days[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDay = dayNum),
              child: Container(
                decoration: BoxDecoration(
                  color: isActive ? _headerColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  dayName.substring(0, 3),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppTheme.muted,
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
          Icon(Icons.calendar_today_rounded, size: 48, color: AppTheme.muted),
          const SizedBox(height: 12),
          Text(
            'No classes scheduled for today',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check other days or contact school admin.',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodsList() {
    return ListView.builder(
      itemCount: _daySlots.length,
      itemBuilder: (context, index) {
        final slot = _daySlots[index];
        final subject = slot['subject']?['subject_name'] ?? 'Regular Period';
        final teacher = slot['staff'] != null
            ? '${slot['staff']['first_name'] ?? ''} ${slot['staff']['last_name'] ?? ''}'.trim()
            : 'Unassigned';
        final room = slot['room']?['room_number'] ?? '—';
        final startTime = slot['start_time'] ?? '—';
        final endTime = slot['end_time'] ?? '—';
        final periodNum = slot['period_number'] ?? (index + 1);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _headerColor.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  'P$periodNum',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _headerColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 12, color: AppTheme.muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            teacher,
                            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
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
                children: [
                  Text(
                    '$startTime - $endTime',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.room_rounded, size: 12, color: _headerColor),
                      const SizedBox(width: 2),
                      Text(
                        'Room $room',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _headerColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
