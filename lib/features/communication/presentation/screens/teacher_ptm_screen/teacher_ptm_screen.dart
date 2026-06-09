import 'package:flutter/material.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

class TeacherPTMScreen extends StatefulWidget {
  const TeacherPTMScreen({super.key});

  @override
  State<TeacherPTMScreen> createState() => _TeacherPTMScreenState();
}

class _TeacherPTMScreenState extends State<TeacherPTMScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _dateController = TextEditingController(text: teacherFlowDate(DateTime.now()));
  final _timeController = TextEditingController(text: '16:00');
  final _purposeController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _meetings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPTMFlow();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _loadPTMFlow() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final rows = await BackendApiClient.instance.getRawList('/parent-teacher-meetings');
      final meetings = rows.where(_belongsToTeacher).map(_mapMeeting).toList()
        ..sort((a, b) => teacherFlowText(a['slot_date']).compareTo(teacherFlowText(b['slot_date'])));
      
      if (!mounted) return;
      setState(() {
        _meetings = meetings;
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

  bool _belongsToTeacher(Map<String, dynamic> row) {
    final teacherId = teacherFlowText(row['teacher_id'] ?? row['staff_id']);
    final sectionId = teacherFlowText(row['section_id']);
    if (teacherId.isNotEmpty && teacherId == RoleAccessService.teacherStaffId) {
      return true;
    }
    if (sectionId.isNotEmpty && sectionId == RoleAccessService.teacherClassId) {
      return true;
    }
    return teacherId.isEmpty && sectionId.isEmpty;
  }

  Map<String, dynamic> _mapMeeting(Map<String, dynamic> row) {
    final student = teacherFlowMap(row['student']);
    final guardian = teacherFlowMap(row['guardian']);
    final section = teacherFlowMap(row['section']);
    final gradeName = teacherFlowText(section['grade_name']);
    final sectionName = teacherFlowText(section['section_name']);
    return {
      'id': row['id'],
      'event_id': row['event_id'],
      'section_id': teacherFlowText(row['section_id']),
      'teacher_id': teacherFlowText(row['teacher_id']),
      'guardian_id': teacherFlowText(row['guardian_id']),
      'student_id': teacherFlowText(row['student_id']),
      'student': teacherFlowText(
        row['student_name'],
        fallback: '${teacherFlowText(student['first_name'])} ${teacherFlowText(student['last_name'])}'.trim(),
      ),
      'guardian': teacherFlowText(
        row['guardian_name'],
        fallback: teacherFlowText(guardian['full_name']),
      ),
      'class': [gradeName, sectionName].where((part) => part.trim().isNotEmpty).join(' ').trim(),
      'slot_date': teacherFlowDateOnly(row['slot_date'] ?? row['date']),
      'slot_time': teacherFlowText(row['slot_time'] ?? row['time']),
      'status': teacherFlowText(row['status'], fallback: 'scheduled'),
      'notes': teacherFlowText(row['notes'] ?? row['purpose']),
    };
  }

  Future<void> _createAvailability() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.createRaw('/parent-teacher-meetings', {
        'section_id': RoleAccessService.teacherClassId,
        'teacher_id': RoleAccessService.teacherStaffId,
        'slot_date': _dateController.text.trim(),
        'slot_time': _timeController.text.trim(),
        'duration_min': 15,
        'status': 'available',
        'notes': _purposeController.text.trim(),
      });
      _purposeController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PTM slot shared successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _saving = false);
      await _loadPTMFlow();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateMeetingStatus(Map<String, dynamic> meeting, String status) async {
    final id = teacherFlowText(meeting['id']);
    if (id.isEmpty) return;
    try {
      await BackendApiClient.instance.updateRaw('/parent-teacher-meetings/$id', {
        'status': status,
        'notes': teacherFlowText(meeting['notes']),
        'teacher_id': RoleAccessService.teacherStaffId,
        'section_id': teacherFlowText(meeting['section_id'], fallback: RoleAccessService.teacherClassId),
      });
      await _loadPTMFlow();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update meeting status: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _meetings.where((row) => teacherFlowText(row['status']) == 'available').toList();
    final booked = _meetings.where((row) => ['booked', 'scheduled', 'confirmed'].contains(teacherFlowText(row['status']))).toList();
    final completed = _meetings.where((row) => ['completed', 'cancelled'].contains(teacherFlowText(row['status']))).toList();

    return TeacherFlowScaffold(
      title: 'PTM Management',
      subtitle: 'Schedule slots and view parent bookings',
      selectedIndex: 9, // Communication/PTM index
      loading: _loading,
      error: _error,
      onRefresh: _loadPTMFlow,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'PTM Portal',
            classLabel: teacherCurrentClassLabel(),
            subject: '${booked.length} booked meetings',
            timeLabel: '${available.length} slots available',
            actions: [
              TeacherFlowAction(
                label: 'Share Slot',
                icon: Icons.event_available_rounded,
                filled: true,
                onTap: _saving ? null : _createAvailability,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _slotComposer(),
          const SizedBox(height: 18),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Active Bookings'),
              Tab(text: 'History & Slots'),
            ],
          ),
          SizedBox(
            height: 600,
            child: TabBarView(
              controller: _tabController,
              children: [
                _meetingList(booked),
                _meetingList([...available, ...completed]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotComposer() {
    return TeacherFlowCard(
      icon: Icons.event_available_rounded,
      title: 'Open a parent meeting slot',
      subtitle: 'Share a date and time for parents of this class.',
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _timeController,
                  decoration: const InputDecoration(
                    labelText: 'Time',
                    prefixIcon: Icon(Icons.schedule_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _purposeController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Purpose or note',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meetingList(List<Map<String, dynamic>> meetings) {
    if (meetings.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 14),
        children: const [
          TeacherFlowCard(
            icon: Icons.family_restroom_rounded,
            title: 'No meetings',
            subtitle: 'PTM slots and bookings will appear here.',
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        final row = meetings[index];
        final status = teacherFlowText(row['status'], fallback: 'scheduled');
        final isCompleted = ['completed', 'cancelled'].contains(status);
        final isAvailable = status == 'available';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TeacherFlowCard(
            icon: Icons.family_restroom_rounded,
            title: isAvailable ? 'Available Slot' : teacherFlowText(row['guardian'], fallback: 'Parent'),
            subtitle: '${teacherFlowText(row['student'], fallback: 'No student linked')} · ${teacherFlowText(row['slot_date'])} ${teacherFlowText(row['slot_time'])}',
            status: teacherFlowTitleCase(status),
            statusColor: _statusColor(status),
            body: isCompleted
                ? null
                : TeacherFlowActionWrap(
                    actions: [
                      if (!isAvailable) ...[
                        TeacherFlowAction(
                          label: 'Complete',
                          icon: Icons.done_all_rounded,
                          onTap: () => _updateMeetingStatus(row, 'completed'),
                        ),
                        TeacherFlowAction(
                          label: 'Cancel',
                          icon: Icons.event_busy_rounded,
                          onTap: () => _updateMeetingStatus(row, 'cancelled'),
                        ),
                      ] else ...[
                        TeacherFlowAction(
                          label: 'Remove Slot',
                          icon: Icons.delete_rounded,
                          onTap: () => _updateMeetingStatus(row, 'cancelled'),
                        ),
                      ]
                    ],
                  ),
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.success;
      case 'booked':
      case 'scheduled':
      case 'confirmed':
        return AppTheme.primary;
      case 'cancelled':
        return AppTheme.error;
      case 'available':
      default:
        return teacherFlowAccent;
    }
  }
}
