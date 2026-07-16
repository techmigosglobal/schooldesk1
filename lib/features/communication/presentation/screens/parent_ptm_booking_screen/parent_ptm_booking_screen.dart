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

class ParentPTMBookingScreen extends StatefulWidget {
  const ParentPTMBookingScreen({super.key});

  @override
  State<ParentPTMBookingScreen> createState() => _ParentPTMBookingScreenState();
}

class _ParentPTMBookingScreenState extends State<ParentPTMBookingScreen> {
  int _selectedNavIndex = ParentNav.ptm;
  int _activeChildIndex = 0;
  static const _headerColor = Color(0xFF1A6B4A);

  List<dynamic> _children = [];
  List<dynamic> _ptmSlots = [];
  bool _loading = true;
  bool _classTeacherOnly = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final children = await BackendApiClient.instance.getMyStudents();
      final slots = await BackendApiClient.instance.getRawList(
        '/parent-teacher-meetings',
      );
      final childRows = children
          .whereType<Map>()
          .map((child) => Map<String, dynamic>.from(child))
          .toList();
      final selectedIndex = await ParentChildSelectionService.indexFor(
        childRows,
        fallback: _activeChildIndex,
      );
      setState(() {
        _children = children;
        _ptmSlots = slots;
        _activeChildIndex = selectedIndex;
        _loading = false;
      });
    } on Object catch (e) {
      setState(() => _loading = false);
      _showErrorSnackBar('Failed to load PTM slots: $e');
    }
  }

  String get _activeStudentId {
    if (_children.isEmpty || _activeChildIndex >= _children.length) return '';
    return (_children[_activeChildIndex]['id'] ?? '').toString();
  }

  List<dynamic> get _filteredSlots {
    final studentId = _activeStudentId;
    var slots = _ptmSlots.where((slot) {
      final slotStudentId = (slot['student_id'] ?? '').toString();
      return slotStudentId.isEmpty || slotStudentId == studentId;
    }).toList();

    if (_classTeacherOnly) {
      slots = slots.where((slot) {
        final subject =
            (slot['subject'] ?? slot['teacher']?['designation'] ?? '')
                .toString()
                .toLowerCase();
        return subject.contains('class teacher') ||
            subject.contains('homeroom');
      }).toList();
    }
    return slots;
  }

  List<dynamic> get _availableSlots =>
      _filteredSlots.where((s) => !_isBooked(s)).toList();
  List<dynamic> get _bookedSlots => _filteredSlots.where(_isBooked).toList();

  bool _isBooked(dynamic slot) {
    final status = (slot['status'] ?? '').toString().toLowerCase();
    return status == 'booked' || status == 'confirmed';
  }

  String _teacherNameForSlot(dynamic slot) {
    final teacher = (slot['teacher'] is Map)
        ? Map<String, dynamic>.from(slot['teacher'] as Map)
        : <String, dynamic>{};
    final fromTeacher =
        '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'.trim();
    if (fromTeacher.isNotEmpty) return fromTeacher;
    final fromFlat =
        '${slot['teacher_first_name'] ?? ''} ${slot['teacher_last_name'] ?? ''}'
            .trim();
    if (fromFlat.isNotEmpty) return fromFlat;
    return (slot['teacher_name'] ?? '').toString().trim();
  }

  String _reasonForSlot(dynamic slot) {
    return (slot['notes'] ?? slot['reason'] ?? '').toString().trim();
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

  String _formatDateString(String dateStr) {
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr.split('T').first;
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
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    final drawer = ParentDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );

    return SchoolDeskModuleScaffold(
      title: 'PTM Slots',
      subtitle: 'View meeting slots shared by your child\'s teachers',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
          tooltip: 'Refresh PTM slots',
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
                  _buildTeacherFilter(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        Text(
                          'Available Meeting Slots',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.appTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_availableSlots.isEmpty)
                          _buildEmptyState(
                            'No available slots matching criteria',
                          )
                        else
                          ..._availableSlots.map(_buildAvailableSlotCard),
                        const SizedBox(height: 24),
                        Text(
                          'Your Bookings',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.appTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_bookedSlots.isEmpty)
                          _buildEmptyState('No booked meetings')
                        else
                          ..._bookedSlots.map(_buildBookedSlotCard),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildChildSelector() {
    if (_children.isEmpty) return const SizedBox.shrink();
    final children = _children
        .whereType<Map>()
        .map((child) => Map<String, dynamic>.from(child))
        .toList();
    return ParentChildSelector(
      children: children,
      selectedIndex: _activeChildIndex,
      onSelected: (index) {
        setState(() => _activeChildIndex = index);
        ParentChildSelectionService.saveIndex(children, index);
      },
    );
  }

  Widget _buildTeacherFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_list_rounded,
            size: 18,
            color: context.appTheme.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Show Class Teacher slots only',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: context.appTheme.onSurface,
              ),
            ),
          ),
          Switch.adaptive(
            value: _classTeacherOnly,
            activeColor: _headerColor,
            onChanged: (val) {
              setState(() {
                _classTeacherOnly = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: context.appTheme.muted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableSlotCard(dynamic slot) {
    final teacher = slot['teacher'] ?? {};
    final teacherName = _teacherNameForSlot(slot);
    final subject =
        slot['subject'] ??
        teacher['designation'] ??
        slot['teacher_role'] ??
        'Teacher';
    final date = _formatDateString((slot['slot_date'] ?? '').toString());
    final time = (slot['slot_time'] ?? '').toString();
    final duration = slot['duration_min'] ?? slot['duration'] ?? 15;
    final room = slot['event']?['location'] ?? 'Meeting Room';
    final reason = _reasonForSlot(slot);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _headerColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              teacherName.isNotEmpty
                  ? teacherName.substring(0, 1).toUpperCase()
                  : 'T',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
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
                  teacherName.isEmpty ? 'Teacher slot' : teacherName,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.onSurface,
                  ),
                ),
                Text(
                  subject,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: context.appTheme.muted,
                  ),
                ),
                const SizedBox(height: 6),
                if (reason.isNotEmpty) ...[
                  Text(
                    'Reason: $reason',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: context.appTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: context.appTheme.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          date,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: context.appTheme.muted,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: context.appTheme.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$time ($duration mins)',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: context.appTheme.muted,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: context.appTheme.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          room,
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
          Chip(
            avatar: const Icon(Icons.visibility_rounded, size: 16),
            label: Text(
              (slot['status'] ?? 'available').toString(),
              style: GoogleFonts.dmSans(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookedSlotCard(dynamic slot) {
    final teacher = slot['teacher'] ?? {};
    final teacherName = _teacherNameForSlot(slot);
    final subject =
        slot['subject'] ??
        teacher['designation'] ??
        slot['teacher_role'] ??
        'Teacher';
    final date = _formatDateString((slot['slot_date'] ?? '').toString());
    final time = (slot['slot_time'] ?? '').toString();
    final reason = _reasonForSlot(slot);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appTheme.success.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: context.appTheme.success,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teacherName.isEmpty ? 'Teacher slot' : teacherName,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.onSurface,
                  ),
                ),
                Text(
                  subject,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: context.appTheme.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$date at $time',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: context.appTheme.onSurfaceVariant,
                  ),
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Reason: $reason',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: context.appTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.appTheme.successContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Booked',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.appTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
