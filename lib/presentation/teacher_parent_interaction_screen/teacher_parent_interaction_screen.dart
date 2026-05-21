import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/teacher_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../services/backend_api_client.dart';
import '../../services/role_access_service.dart';

class TeacherParentInteractionScreen extends StatefulWidget {
  const TeacherParentInteractionScreen({super.key});

  @override
  State<TeacherParentInteractionScreen> createState() =>
      _TeacherParentInteractionScreenState();
}

class _TeacherParentInteractionScreenState
    extends State<TeacherParentInteractionScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 9;
  late TabController _tabController;
  bool _loading = true;

  List<Map<String, dynamic>> _meetings = [];
  List<Map<String, dynamic>> _feedbackLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final storedMeetings = await BackendApiClient.instance.getRawList(
      '/parent-teacher-meetings',
    );
    final mapped = storedMeetings
        .where(_isTeacherMeeting)
        .map(_mapMeeting)
        .toList();
    setState(() {
      _meetings = mapped;
      _feedbackLogs = mapped
          .where((meeting) => meeting['status'] == 'completed')
          .map(
            (meeting) => {
              'parent': meeting['parent'],
              'student': meeting['student'],
              'date': meeting['date'],
              'feedback': meeting['purpose'],
              'outcome': meeting['outcome'] ?? 'neutral',
            },
          )
          .toList();
      _loading = false;
    });
  }

  bool _isTeacherMeeting(Map<String, dynamic> meeting) {
    final teacherId = meeting['teacher_id']?.toString() ?? '';
    return teacherId.isEmpty || teacherId == RoleAccessService.teacherStaffId;
  }

  Map<String, dynamic> _mapMeeting(Map<String, dynamic> meeting) {
    final student = meeting['student'];
    final guardian = meeting['guardian'];
    final event = meeting['event'];
    final section = meeting['section'];
    final slotDate = DateTime.tryParse('${meeting['slot_date'] ?? ''}');
    return {
      'id': meeting['id'],
      'event_id': meeting['event_id'],
      'section_id': meeting['section_id'],
      'teacher_id': meeting['teacher_id'],
      'guardian_id': meeting['guardian_id'],
      'student_id': meeting['student_id'],
      'teacherName': RoleAccessService.teacherName,
      'subject': RoleAccessService.teacherSubject,
      'class': _sectionLabel(section),
      'parent': guardian is Map
          ? guardian['full_name'] ?? meeting['guardian_id'] ?? ''
          : meeting['guardian_id'] ?? '',
      'student': student is Map
          ? '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
                .trim()
          : meeting['student_id'] ?? '',
      'date': slotDate == null ? '' : DateFormat('d MMM yyyy').format(slotDate),
      'slotDate': slotDate?.toUtc().toIso8601String(),
      'time': meeting['slot_time'] ?? '',
      'room': event is Map ? event['location'] ?? '' : '',
      'purpose': meeting['notes'] ?? '',
      'status': meeting['status'] ?? 'scheduled',
      'bookedBy': guardian is Map ? guardian['full_name'] ?? '' : '',
    };
  }

  String _sectionLabel(dynamic section) {
    if (section is! Map) return RoleAccessService.teacherClassName;
    final grade = section['grade_name']?.toString().trim() ?? '';
    final name = section['section_name']?.toString().trim() ?? '';
    final label = [grade, name].where((part) => part.isNotEmpty).join(' ');
    return label.isEmpty ? RoleAccessService.teacherClassName : label;
  }

  Future<void> _saveMeeting(Map<String, dynamic> meeting) async {
    final id = meeting['id']?.toString() ?? '';
    if (id.isEmpty) return;
    await BackendApiClient.instance.updateRaw(
      '/parent-teacher-meetings/$id',
      _meetingPayload(meeting),
    );
    await _loadData();
  }

  Map<String, dynamic> _meetingPayload(Map<String, dynamic> meeting) {
    final slotDate =
        DateTime.tryParse('${meeting['slotDate'] ?? ''}') ?? DateTime.now();
    return {
      'event_id': meeting['event_id'] ?? '',
      'section_id': meeting['section_id'] ?? RoleAccessService.teacherClassId,
      'slot_date': slotDate.toUtc().toIso8601String(),
      'slot_time': meeting['time'] ?? '',
      'duration_min': meeting['duration_min'] ?? 15,
      'teacher_id': meeting['teacher_id'] ?? RoleAccessService.teacherStaffId,
      'guardian_id': meeting['guardian_id'] ?? '',
      'student_id': meeting['student_id'] ?? '',
      'status': meeting['status'] ?? 'scheduled',
      'notes': meeting['purpose'] ?? '',
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawer = TeacherDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Parent Interaction',
        subtitle: 'Schedule PTMs and keep feedback records accessible',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Parent Interaction',
      subtitle: 'Schedule PTMs and keep feedback records accessible',
      drawer: drawer,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DashboardFabWidget(role: DashboardRole.teacher),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: _showScheduleMeetingSheet,
            backgroundColor: AppTheme.primary,
            icon: const Icon(Icons.event_rounded, color: Colors.white),
            label: Text(
              'Schedule PTM',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Meetings'),
          Tab(text: 'Feedback Logs'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMeetingsList(), _buildFeedbackLogs()],
      ),
    );
  }

  Widget _buildMeetingsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _meetings.length,
      itemBuilder: (context, i) {
        final m = _meetings[i];
        final isScheduled = m['status'] == 'scheduled';
        final color = isScheduled ? AppTheme.primary : AppTheme.success;
        final parent =
            m['parent'] as String? ?? m['bookedBy'] as String? ?? 'Parent';
        final student = m['student'] as String? ?? '';
        final classInfo = m['class'] as String? ?? '';
        final date = m['date'] as String? ?? '';
        final time = m['time'] as String? ?? '';
        final purpose = m['purpose'] as String? ?? '';
        final room = m['room'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(40)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Icon(
                      Icons.family_restroom_rounded,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parent,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Parent of $student · Class $classInfo',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (m['status'] as String).toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$date at $time',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.muted,
                    ),
                  ),
                  if (room.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.room_rounded,
                      size: 13,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      room,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Purpose: $purpose',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              if (isScheduled) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showRecordFeedback(m),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text(
                          'Record Feedback',
                          style: GoogleFonts.dmSans(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          setState(() => m['status'] = 'completed');
                          await _saveMeeting(m);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Meeting marked as completed'),
                                backgroundColor: AppTheme.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text(
                          'Mark Done',
                          style: GoogleFonts.dmSans(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedbackLogs() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _feedbackLogs.length,
      itemBuilder: (context, i) {
        final f = _feedbackLogs[i];
        final outcomeColors = {
          'positive': AppTheme.success,
          'neutral': AppTheme.warning,
          'negative': AppTheme.error,
        };
        final color = outcomeColors[f['outcome']] ?? AppTheme.muted;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      f['parent'] as String,
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
                      f['outcome'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Student: ${f['student']} · ${f['date']}',
                style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
              ),
              const SizedBox(height: 8),
              Text(
                f['feedback'] as String,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showScheduleMeetingSheet() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ScheduleMeetingInputPage(onSubmit: _createMeeting),
      ),
    );
    if (!mounted || created != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PTM slot created - parents can now book it'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showRecordFeedback(Map<String, dynamic> meeting) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _RecordFeedbackInputPage(
          meeting: meeting,
          onSubmit: _recordFeedback,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feedback recorded'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _createMeeting(
    String guardianId,
    String time,
    String purpose,
  ) async {
    final newMeeting = {
      'event_id': _meetings.isNotEmpty ? _meetings.first['event_id'] : '',
      'section_id': RoleAccessService.teacherClassId,
      'teacher_id': RoleAccessService.teacherStaffId,
      'guardian_id': guardianId,
      'student_id': RoleAccessService.teacherClassStudents.isNotEmpty
          ? RoleAccessService.teacherClassStudents.first['id']
          : '',
      'teacherName': '',
      'subject': '',
      'class': RoleAccessService.teacherClassName,
      'parent': guardianId,
      'student': '',
      'date': DateFormat(
        'd MMM yyyy',
      ).format(DateTime.now().add(const Duration(days: 7))),
      'slotDate': DateTime.now()
          .add(const Duration(days: 7))
          .toUtc()
          .toIso8601String(),
      'time': time,
      'room': '',
      'purpose': purpose,
      'status': 'available',
      'bookedBy': '',
    };
    if ((newMeeting['event_id'] as String).isEmpty ||
        (newMeeting['student_id'] as String).isEmpty) {
      throw StateError(
        'Backend PTM event and assigned student are required before creating a slot.',
      );
    }
    await BackendApiClient.instance.createRaw(
      '/parent-teacher-meetings',
      _meetingPayload(newMeeting),
    );
    await _loadData();
  }

  Future<void> _recordFeedback(
    Map<String, dynamic> meeting,
    String feedback,
    String outcome,
  ) async {
    setState(() {
      _feedbackLogs.insert(0, {
        'parent': meeting['parent'],
        'student': meeting['student'],
        'date': DateFormat('d MMM yyyy').format(DateTime.now()),
        'feedback': feedback,
        'outcome': outcome,
      });
      meeting['status'] = 'completed';
      meeting['purpose'] = feedback;
    });
    await _saveMeeting(meeting);
  }
}

class _ScheduleMeetingInputPage extends StatefulWidget {
  const _ScheduleMeetingInputPage({required this.onSubmit});

  final Future<void> Function(String guardianId, String time, String purpose)
  onSubmit;

  @override
  State<_ScheduleMeetingInputPage> createState() =>
      _ScheduleMeetingInputPageState();
}

class _ScheduleMeetingInputPageState extends State<_ScheduleMeetingInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _guardianCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  String _time = '4:00 PM';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _guardianCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        _guardianCtrl.text.trim(),
        _time,
        _purposeCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule PTM')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _guardianCtrl,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Guardian ID from backend',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _time,
              decoration: const InputDecoration(labelText: 'Time Slot'),
              items: const [
                '9:00 AM',
                '10:00 AM',
                '11:00 AM',
                '12:00 PM',
                '3:00 PM',
                '4:00 PM',
              ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: _saving ? null : (v) => setState(() => _time = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _purposeCtrl,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Purpose of Meeting',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.infoContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'PTM will be visible to parents only after the backend accepts the meeting slot.',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.info),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GoogleFonts.dmSans(color: AppTheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Schedule Meeting'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordFeedbackInputPage extends StatefulWidget {
  const _RecordFeedbackInputPage({
    required this.meeting,
    required this.onSubmit,
  });

  final Map<String, dynamic> meeting;
  final Future<void> Function(
    Map<String, dynamic> meeting,
    String feedback,
    String outcome,
  )
  onSubmit;

  @override
  State<_RecordFeedbackInputPage> createState() =>
      _RecordFeedbackInputPageState();
}

class _RecordFeedbackInputPageState extends State<_RecordFeedbackInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackCtrl = TextEditingController();
  String _outcome = 'positive';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        widget.meeting,
        _feedbackCtrl.text.trim(),
        _outcome,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Unable to save feedback: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = {
      'positive': AppTheme.success,
      'neutral': AppTheme.warning,
      'negative': AppTheme.error,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Record Feedback')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Meeting with ${widget.meeting['parent']}',
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: colors.entries.map((entry) {
                final selected = _outcome == entry.key;
                return ChoiceChip(
                  label: Text(entry.key),
                  selected: selected,
                  selectedColor: entry.value,
                  labelStyle: GoogleFonts.dmSans(
                    color: selected ? Colors.white : entry.value,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: _saving
                      ? null
                      : (_) => setState(() => _outcome = entry.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _feedbackCtrl,
              enabled: !_saving,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Discussion notes'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GoogleFonts.dmSans(color: AppTheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Feedback'),
            ),
          ],
        ),
      ),
    );
  }
}
