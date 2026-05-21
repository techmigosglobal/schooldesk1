import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/backend_api_client.dart';
import '../../services/role_access_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../widgets/teacher_navigation.dart';

class TeacherLessonPlannerScreen extends StatefulWidget {
  const TeacherLessonPlannerScreen({super.key});

  @override
  State<TeacherLessonPlannerScreen> createState() =>
      _TeacherLessonPlannerScreenState();
}

class _TeacherLessonPlannerScreenState extends State<TeacherLessonPlannerScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 4;
  late final String _selectedClass;

  Map<String, List<Map<String, dynamic>>> _syllabusByClass = {};
  List<Map<String, dynamic>> _weeklyPlan = [];

  @override
  void initState() {
    super.initState();
    // Teacher sees only their assigned class in lesson planner
    _selectedClass = RoleAccessService.teacherClassName;
    _loadData();
  }

  Future<void> _loadData() async {
    final records = await BackendApiClient.instance.getRawList('/syllabus');
    final scoped = records.where(_isTeacherRecord).toList();
    final syllabus = <String, List<Map<String, dynamic>>>{
      _selectedClass: scoped.map(_mapSyllabusChapter).toList(),
    };
    setState(() {
      _weeklyPlan = scoped.map(_mapWeeklyPlan).toList();
      _syllabusByClass = syllabus;
    });
  }

  bool _isTeacherRecord(Map<String, dynamic> record) {
    final teacherId = record['teacher_id']?.toString() ?? '';
    final sectionId = record['section_id']?.toString() ?? '';
    if (teacherId.isNotEmpty && teacherId == RoleAccessService.teacherStaffId) {
      return true;
    }
    return sectionId.isEmpty || sectionId == RoleAccessService.teacherClassId;
  }

  Map<String, dynamic> _mapWeeklyPlan(Map<String, dynamic> record) {
    final status = '${record['status'] ?? 'planned'}'.toLowerCase();
    return {
      'id': record['id'],
      'day': _weekdayLabel(record['week'] ?? record['created_at']),
      'class': record['class'] ?? _selectedClass,
      'topic': record['title'] ?? record['topic'] ?? '',
      'status': status == 'completed' || status == 'done' ? 'done' : 'planned',
    };
  }

  Map<String, dynamic> _mapSyllabusChapter(Map<String, dynamic> record) {
    final status = '${record['status'] ?? 'planned'}'.toLowerCase();
    final done = status == 'completed' || status == 'done';
    return {
      'id': record['id'],
      'chapter': record['title'] ?? record['chapter'] ?? '',
      'topics': <String>[
        record['topic'] ??
            record['week'] ??
            record['description'] ??
            'Lesson plan',
      ],
      'completed': <bool>[done],
      'progress': done ? 100 : 0,
    };
  }

  String _weekdayLabel(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return 'Plan';
    return DateFormat('E').format(parsed);
  }

  Future<void> _updateChapterProgress(Map<String, dynamic> ch) async {
    final id = ch['id']?.toString() ?? '';
    if (id.isEmpty) return;
    await BackendApiClient.instance.updateRaw('/syllabus/$id', {
      'status': (ch['progress'] as int? ?? 0) == 100 ? 'completed' : 'planned',
    });
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Lesson Planner',
      subtitle: 'Plan weekly lessons and track syllabus progress',
      drawer: TeacherDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.teacher,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        TextButton.icon(
          onPressed: _showAddLessonPlan,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('Add Plan', style: GoogleFonts.dmSans(fontSize: 12)),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeeklyPlan(),
            const SizedBox(height: 20),
            _buildSyllabusTracker(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyPlan() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This Week\'s Plan',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Week ${((DateTime.now().day - 1) ~/ 7) + 1} — ${DateFormat('MMMM').format(DateTime.now())}',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._weeklyPlan.map((p) => _buildPlanRow(p)),
        ],
      ),
    );
  }

  Widget _buildPlanRow(Map<String, dynamic> p) {
    final statusColors = {
      'done': AppTheme.success,
      'today': AppTheme.primary,
      'planned': AppTheme.muted,
    };
    final statusIcons = {
      'done': Icons.check_circle_rounded,
      'today': Icons.radio_button_checked_rounded,
      'planned': Icons.radio_button_unchecked_rounded,
    };
    final color = statusColors[p['status']] ?? AppTheme.muted;
    final icon = statusIcons[p['status']] ?? Icons.circle_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                p['day'] as String,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
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
                  p['topic'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Class ${p['class']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: color, size: 20),
        ],
      ),
    );
  }

  Widget _buildSyllabusTracker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Syllabus Progress',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [_selectedClass].map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        c,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...(_syllabusByClass[_selectedClass] ?? []).map(
          (ch) => _buildChapterCard(ch),
        ),
      ],
    );
  }

  Widget _buildChapterCard(Map<String, dynamic> ch) {
    final topics = ch['topics'] as List<String>;
    final completed = ch['completed'] as List<bool>;
    final progress = ch['progress'] as int;
    final progressColor = progress == 100
        ? AppTheme.success
        : progress > 50
        ? AppTheme.primary
        : progress > 0
        ? AppTheme.warning
        : AppTheme.muted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  ch['chapter'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: progressColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$progress%',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: progressColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: AppTheme.outlineVariant,
              color: progressColor,
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(topics.length, (i) {
            final isDone = completed[i];
            return GestureDetector(
              onTap: () async {
                setState(() {
                  (ch['completed'] as List<bool>)[i] = !isDone;
                  final doneCount = (ch['completed'] as List<bool>)
                      .where((b) => b)
                      .length;
                  ch['progress'] = (doneCount / topics.length * 100).round();
                });
                await _updateChapterProgress(ch);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 18,
                      color: isDone ? AppTheme.success : AppTheme.muted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      topics[i],
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: isDone ? AppTheme.muted : AppTheme.onSurface,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showAddLessonPlan() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AddLessonPlanPage(selectedClass: _selectedClass),
      ),
    );
    if (!mounted || saved != true) return;
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lesson plan added'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _AddLessonPlanPage extends StatefulWidget {
  final String selectedClass;

  const _AddLessonPlanPage({required this.selectedClass});

  @override
  State<_AddLessonPlanPage> createState() => _AddLessonPlanPageState();
}

class _AddLessonPlanPageState extends State<_AddLessonPlanPage> {
  final _formKey = GlobalKey<FormState>();
  final _topicCtrl = TextEditingController();
  String _selectedDay = 'Mon';
  late String _selectedClass;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedClass = widget.selectedClass;
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.createRaw('/syllabus', {
        'title': _topicCtrl.text.trim(),
        'teacher_id': RoleAccessService.teacherStaffId,
        'section_id': RoleAccessService.teacherClassId,
        'class': _selectedClass,
        'subject': RoleAccessService.teacherSubject,
        'week': DateTime.now().toUtc().toIso8601String(),
        'day': _selectedDay,
        'status': 'planned',
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Lesson plan could not be saved: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Lesson Plan')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_error != null) ...[
                _InputErrorBanner(message: _error!),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                initialValue: _selectedDay,
                decoration: const InputDecoration(labelText: 'Day'),
                items: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _selectedDay = v ?? 'Mon'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedClass,
                decoration: const InputDecoration(labelText: 'Class'),
                items: [widget.selectedClass]
                    .map(
                      (c) =>
                          DropdownMenuItem(value: c, child: Text('Class $c')),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) =>
                          setState(() => _selectedClass = v ?? _selectedClass),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _topicCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Topic'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter a topic.' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputErrorBanner extends StatelessWidget {
  final String message;

  const _InputErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.error),
      ),
    );
  }
}
