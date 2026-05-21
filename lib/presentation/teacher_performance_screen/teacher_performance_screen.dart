import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend_api_client.dart';
import '../../services/role_access_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../widgets/teacher_navigation.dart';

class TeacherPerformanceScreen extends StatefulWidget {
  const TeacherPerformanceScreen({super.key});

  @override
  State<TeacherPerformanceScreen> createState() =>
      _TeacherPerformanceScreenState();
}

class _TeacherPerformanceScreenState extends State<TeacherPerformanceScreen> {
  int _selectedNavIndex = 5;
  late String _selectedClass;
  String _filterType = 'All';
  bool _loading = true;

  Map<String, List<Map<String, dynamic>>> _studentPerformance = {};

  @override
  void initState() {
    super.initState();
    _selectedClass = RoleAccessService.teacherClassName;
    _loadData();
  }

  Future<void> _loadData() async {
    final rows = <Map<String, dynamic>>[];
    for (final student in RoleAccessService.teacherClassStudents) {
      final marks = await _try(
        () => BackendApiClient.instance.getRawList(
          '/students/${student['id']}/marks',
        ),
      );
      rows.add(_studentPerformanceRow(student, marks ?? []));
    }
    setState(() {
      _studentPerformance = {_selectedClass: rows};
      _loading = false;
    });
  }

  Map<String, dynamic> _studentPerformanceRow(
    Map<String, dynamic> student,
    List<Map<String, dynamic>> marksRows,
  ) {
    final marks = marksRows.map((row) {
      final score = row['marks_obtained'] ?? row['marks'] ?? 0;
      if (score is num) return score.round().clamp(0, 100);
      return (num.tryParse(score.toString()) ?? 0).round().clamp(0, 100);
    }).toList();
    final average = marks.isEmpty
        ? 0.0
        : marks.reduce((a, b) => a + b) / marks.length;
    return {
      'id': student['id'],
      'name': student['name'],
      'roll': student['roll'] ?? '',
      'participation': marksRows.isEmpty ? 'Not recorded' : 'Recorded',
      'marks': marks,
      'avg': average,
      'status': average >= 85
          ? 'excellent'
          : average >= 70
          ? 'good'
          : average >= 50
          ? 'average'
          : 'weak',
      'trend': marks.length >= 2
          ? marks.last > marks.first
                ? 'up'
                : marks.last < marks.first
                ? 'down'
                : 'flat'
          : 'flat',
    };
  }

  Future<T?> _try<T>(Future<T> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> get _filteredStudents {
    final students = _studentPerformance[_selectedClass] ?? [];
    if (_filterType == 'All') return students;
    return students
        .where((s) => s['status'] == _filterType.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Student Performance',
        subtitle: 'Review student progress, strengths, and support needs',
        drawer: TeacherDrawer(
          selectedIndex: _selectedNavIndex,
          onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Student Performance',
      subtitle: 'Review student progress, strengths, and support needs',
      drawer: TeacherDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.teacher,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredStudents.length,
              itemBuilder: (context, i) =>
                  _buildStudentCard(_filteredStudents[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final all = _studentPerformance[_selectedClass] ?? [];
    final excellent = all.where((s) => s['status'] == 'excellent').length;
    final weak = all.where((s) => s['status'] == 'weak').length;

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [_selectedClass].map((c) {
                final isSelected = _selectedClass == c;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedClass = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Class $c',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryChip('Excellent', excellent, AppTheme.success),
              const SizedBox(width: 8),
              _buildSummaryChip('Weak', weak, AppTheme.error),
              const SizedBox(width: 8),
              _buildSummaryChip('Total', all.length, AppTheme.primary),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Excellent', 'Good', 'Average', 'Weak'].map((
                f,
              ) {
                final isSelected = _filterType == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _filterType = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.secondary
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        f,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> s) {
    final marks = (s['marks'] as List).whereType<int>().toList();
    final avg = s['avg'] as double;
    final status = s['status'] as String;
    final trend = s['trend'] as String;
    final statusColors = {
      'excellent': AppTheme.success,
      'good': AppTheme.info,
      'average': AppTheme.warning,
      'weak': AppTheme.error,
    };
    final color = statusColors[status] ?? AppTheme.muted;
    final trendIcon = trend == 'up'
        ? Icons.trending_up_rounded
        : trend == 'down'
        ? Icons.trending_down_rounded
        : Icons.trending_flat_rounded;
    final trendColor = trend == 'up'
        ? AppTheme.success
        : trend == 'down'
        ? AppTheme.error
        : AppTheme.muted;

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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    s['name'].toString().substring(0, 1),
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
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
                      s['name'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Roll ${s['roll']} · Participation: ${s['participation']}',
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
                    '${avg.toStringAsFixed(1)}%',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trendIcon, size: 14, color: trendColor),
                      Text(
                        trend,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: trendColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (marks.isEmpty)
            Text(
              'No backend marks recorded yet',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
            )
          else
            Row(
              children: List.generate(marks.length, (i) {
                final label = 'T${i + 1}';
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      children: [
                        Container(
                          height: 40,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            height: marks[i] / 100 * 40,
                            decoration: BoxDecoration(
                              color: color.withAlpha(60),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${marks[i]}',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        Text(
                          label,
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showAddObservation(s),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                child: Text(
                  'Add Note',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              if (status == 'weak')
                TextButton(
                  onPressed: () async {
                    await BackendApiClient.instance
                        .createRaw('/student-alerts', {
                          'student_id': s['id'],
                          'student_name': s['name'],
                          'teacher_id': RoleAccessService.teacherStaffId,
                          'type': 'academic_support',
                          'status': 'open',
                          'title': 'Support recommended for ${s['name']}',
                        });
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Support recommendation sent for ${s['name']}',
                        ),
                        backgroundColor: AppTheme.warning,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  child: Text(
                    'Recommend Support',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddObservation(Map<String, dynamic> s) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _AddObservationPage(student: s)),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Observation saved for ${s['name']}'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _AddObservationPage extends StatefulWidget {
  final Map<String, dynamic> student;

  const _AddObservationPage({required this.student});

  @override
  State<_AddObservationPage> createState() => _AddObservationPageState();
}

class _AddObservationPageState extends State<_AddObservationPage> {
  final _formKey = GlobalKey<FormState>();
  final _noteCtrl = TextEditingController();
  String _noteType = 'academic';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.createRaw('/student-notes', {
        'student_id': widget.student['id'],
        'student_name': widget.student['name'],
        'teacher_id': RoleAccessService.teacherStaffId,
        'class': RoleAccessService.teacherClassName,
        'category': _noteType,
        'note': _noteCtrl.text.trim(),
        'priority': 'medium',
        'visibility': 'staff',
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Observation could not be saved: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentName = '${widget.student['name'] ?? 'Student'}';
    return Scaffold(
      appBar: AppBar(title: Text('Add Observation - $studentName')),
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['academic', 'strength', 'participation']
                    .map(
                      (t) => ChoiceChip(
                        label: Text(t),
                        selected: _noteType == t,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _noteType = t),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteCtrl,
                enabled: !_saving,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observation note',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter an observation note.'
                    : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Observation'),
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
