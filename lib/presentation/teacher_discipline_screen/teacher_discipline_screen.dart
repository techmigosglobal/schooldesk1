import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/teacher_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../services/backend_api_client.dart';
import '../../services/role_access_service.dart';

class TeacherDisciplineScreen extends StatefulWidget {
  const TeacherDisciplineScreen({super.key});

  @override
  State<TeacherDisciplineScreen> createState() =>
      _TeacherDisciplineScreenState();
}

class _TeacherDisciplineScreenState extends State<TeacherDisciplineScreen> {
  int _selectedNavIndex = 11;
  bool _loading = true;

  List<Map<String, dynamic>> _incidents = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final stored = await BackendApiClient.instance.getRawList(
      '/discipline-incidents',
    );
    setState(() {
      _incidents = stored.where(_isTeacherIncident).map(_mapIncident).toList();
      _loading = false;
    });
  }

  bool _isTeacherIncident(Map<String, dynamic> incident) {
    final teacherId = incident['teacher_id']?.toString() ?? '';
    final studentId = incident['student_id']?.toString() ?? '';
    if (teacherId.isNotEmpty && teacherId == RoleAccessService.teacherStaffId) {
      return true;
    }
    return RoleAccessService.teacherClassStudents.any(
      (student) => student['id']?.toString() == studentId,
    );
  }

  Map<String, dynamic> _mapIncident(Map<String, dynamic> incident) {
    final studentId = incident['student_id']?.toString() ?? '';
    final student = RoleAccessService.teacherClassStudents.firstWhere(
      (row) => row['id']?.toString() == studentId,
      orElse: () => const {},
    );
    return {
      'id': incident['id'],
      'teacher_id': incident['teacher_id'] ?? RoleAccessService.teacherStaffId,
      'student_id': studentId,
      'reportedBy': incident['reported_by'] ?? RoleAccessService.teacherName,
      'studentName': incident['student_name'] ?? student['name'] ?? studentId,
      'class':
          incident['class'] ??
          student['class'] ??
          RoleAccessService.teacherClassName,
      'incidentType': incident['incidentType'] ?? incident['type'] ?? 'other',
      'description': incident['description'] ?? incident['title'] ?? '',
      'date': _formatBackendDate(incident['created_at']),
      'severity': incident['severity'] ?? 'medium',
      'status': incident['status'] ?? 'open',
      'escalatedToPrincipal':
          incident['escalated_to_principal'] ?? incident['escalated'] ?? false,
    };
  }

  Future<void> _updateIncident(Map<String, dynamic> inc) async {
    final id = inc['id']?.toString() ?? '';
    if (id.isEmpty) return;
    await BackendApiClient.instance.updateRaw('/discipline-incidents/$id', {
      'teacher_id': inc['teacher_id'] ?? RoleAccessService.teacherStaffId,
      'student_id': inc['student_id'] ?? '',
      'reported_by': inc['reportedBy'] ?? RoleAccessService.teacherName,
      'student_name': inc['studentName'] ?? '',
      'class': inc['class'] ?? RoleAccessService.teacherClassName,
      'type': inc['incidentType'] ?? 'other',
      'description': inc['description'] ?? '',
      'severity': inc['severity'] ?? 'medium',
      'status': inc['status'] ?? 'open',
      'escalated_to_principal': inc['escalatedToPrincipal'] == true,
    });
  }

  Future<void> _escalateToPrincipal(Map<String, dynamic> inc) async {
    await BackendApiClient.instance.createRaw('/complaints', {
      'title': 'Discipline: ${inc['incidentType']} - ${inc['studentName']}',
      'description': inc['description'],
      'category': 'Discipline',
      'submittedBy': inc['reportedBy'] ?? RoleAccessService.teacherName,
      'date': inc['date'],
      'status': 'open',
      'priority': inc['severity'] == 'high' ? 'high' : 'medium',
      'assignedTo': 'Principal',
      'source': 'teacher_discipline',
      'incident_id': inc['id'],
    });
  }

  @override
  Widget build(BuildContext context) {
    final drawer = TeacherDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Discipline & Incidents',
        subtitle: 'Record incidents and coordinate follow-up actions',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Discipline & Incidents',
      subtitle: 'Record incidents and coordinate follow-up actions',
      drawer: drawer,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DashboardFabWidget(role: DashboardRole.teacher),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: _showReportIncidentSheet,
            backgroundColor: AppTheme.error,
            icon: const Icon(Icons.report_rounded, color: Colors.white),
            label: Text(
              'Report Incident',
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
      body: Column(
        children: [
          _buildSummaryBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _incidents.length,
              itemBuilder: (context, i) => _buildIncidentCard(_incidents[i], i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    final open = _incidents.where((i) => i['status'] == 'open').length;
    final escalated = _incidents
        .where((i) => i['status'] == 'escalated')
        .length;
    final resolved = _incidents.where((i) => i['status'] == 'resolved').length;

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildSummaryChip('Open', open, AppTheme.warning),
          const SizedBox(width: 8),
          _buildSummaryChip('Escalated', escalated, AppTheme.error),
          const SizedBox(width: 8),
          _buildSummaryChip('Resolved', resolved, AppTheme.success),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _buildIncidentCard(Map<String, dynamic> inc, int index) {
    final severityColors = {
      'high': AppTheme.error,
      'medium': AppTheme.warning,
      'low': AppTheme.info,
    };
    final statusColors = {
      'open': AppTheme.warning,
      'escalated': AppTheme.error,
      'resolved': AppTheme.success,
    };
    final typeIcons = {
      'misconduct': Icons.warning_rounded,
      'bullying': Icons.person_off_rounded,
      'property': Icons.broken_image_rounded,
      'other': Icons.report_rounded,
    };
    final severity = inc['severity'] as String? ?? 'medium';
    final status = inc['status'] as String? ?? 'open';
    final incidentType =
        inc['incidentType'] as String? ?? inc['type'] as String? ?? 'other';
    final severityColor = severityColors[severity] ?? AppTheme.muted;
    final statusColor = statusColors[status] ?? AppTheme.muted;
    final icon = typeIcons[incidentType] ?? Icons.report_rounded;
    final studentName =
        inc['studentName'] as String? ?? inc['student'] as String? ?? '';
    final classInfo = inc['class'] as String? ?? '';
    final date = inc['date'] as String? ?? '';
    final description = inc['description'] as String? ?? '';
    final escalated =
        inc['escalatedToPrincipal'] as bool? ??
        inc['escalated'] as bool? ??
        false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: severityColor.withAlpha(40)),
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
                  color: severityColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: severityColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Class $classInfo · $date',
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: severityColor.withAlpha(15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$severity severity',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        color: severityColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              incidentType,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: AppTheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          if (escalated)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.escalator_warning_rounded,
                    size: 13,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Escalated to Principal',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.error,
                    ),
                  ),
                ],
              ),
            ),
          if (status == 'open') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      setState(() => inc['status'] = 'resolved');
                      await _updateIncident(inc);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Incident marked as resolved'),
                            backgroundColor: AppTheme.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      'Mark Resolved',
                      style: GoogleFonts.dmSans(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      setState(() {
                        inc['status'] = 'escalated';
                        inc['escalatedToPrincipal'] = true;
                      });
                      await _updateIncident(inc);
                      await _escalateToPrincipal(inc);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Incident escalated to Admin & Principal — visible in Complaints',
                            ),
                            backgroundColor: AppTheme.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.escalator_warning_rounded, size: 14),
                    label: Text(
                      'Escalate',
                      style: GoogleFonts.dmSans(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      padding: const EdgeInsets.symmetric(vertical: 8),
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

  Future<void> _showReportIncidentSheet() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _ReportIncidentPage()),
    );
    if (!mounted || saved != true) return;
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Incident reported and saved'),
        backgroundColor: AppTheme.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatBackendDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '';
    return DateFormat('d MMM yyyy').format(parsed);
  }
}

class _ReportIncidentPage extends StatefulWidget {
  const _ReportIncidentPage();

  @override
  State<_ReportIncidentPage> createState() => _ReportIncidentPageState();
}

class _ReportIncidentPageState extends State<_ReportIncidentPage> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _studentCtrl = TextEditingController();
  String _incidentType = 'misconduct';
  String _severity = 'medium';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _descCtrl.dispose();
    _studentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.createRaw('/discipline-incidents', {
        'reportedBy': RoleAccessService.teacherName,
        'reported_by': RoleAccessService.teacherName,
        'teacher_id': RoleAccessService.teacherStaffId,
        'student_id': _studentCtrl.text.trim(),
        'studentName': _studentCtrl.text.trim(),
        'student_name': _studentCtrl.text.trim(),
        'class': RoleAccessService.teacherClassName,
        'incidentType': _incidentType,
        'type': _incidentType,
        'description': _descCtrl.text.trim(),
        'severity': _severity,
        'status': 'open',
        'escalated_to_principal': false,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Incident report could not be saved: $e';
      });
    }
  }

  Widget _choiceChip(
    String value,
    String selected,
    ValueChanged<String> onTap,
  ) {
    final isSelected = selected == value;
    return ChoiceChip(
      label: Text(value),
      selected: isSelected,
      onSelected: _saving ? null : (_) => onTap(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Incident')),
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
              TextFormField(
                controller: _studentCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Student ID or name from backend',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the student ID or name.'
                    : null,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['misconduct', 'bullying', 'property', 'other']
                    .map(
                      (t) => _choiceChip(
                        t,
                        _incidentType,
                        (v) => setState(() => _incidentType = v),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _severity,
                decoration: const InputDecoration(labelText: 'Severity'),
                items: ['low', 'medium', 'high']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _severity = v ?? _severity),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                enabled: !_saving,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Incident description',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the incident description.'
                    : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Report'),
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
