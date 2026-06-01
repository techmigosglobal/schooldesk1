import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedClass = '';
  List<String> _classes = [];
  final Map<String, String> _sectionIdsByClass = {};

  List<Map<String, dynamic>> _attendanceRecords = [];
  List<Map<String, dynamic>> _exceptions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        BackendApiClient.instance.getAttendanceSessions(),
        BackendApiClient.instance.getSections(),
      ]);
      final sessions = results[0] as List<AttendanceSessionModel>;
      final sections = results[1] as List<SectionModel>;
      final classLabels = _classLabels(sections);
      final sectionLabels = {
        for (final section in sections) section.id: _sectionLabel(section),
      };
      if (!mounted) return;
      setState(() {
        _classes = classLabels;
        if (_classes.isNotEmpty && !_classes.contains(_selectedClass)) {
          _selectedClass = _classes.first;
        }
        _attendanceRecords = sessions.map((s) {
          final absent = (s.totalStudents - s.presentCount).clamp(0, 1 << 20);
          return {
            'name': sectionLabels[s.sectionId] ?? s.sectionId,
            'roll': s.periodNumber.toString(),
            'status': s.totalStudents == 0
                ? 'Pending'
                : absent == 0
                ? 'Present'
                : 'Absent',
            'date': s.date.split('T').first,
            'present': s.presentCount,
            'total': s.totalStudents,
            'section_id': s.sectionId,
            'issue': s.totalStudents > 0 && absent > 0,
          };
        }).toList();
        _exceptions = _attendanceRecords
            .where((row) => row['issue'] == true)
            .map(
              (row) => {
                'student': row['name'],
                'class': row['name'],
                'date': row['date'],
                'section_id': row['section_id'],
                'issue':
                    '${row['present']}/${row['total']} students marked present',
                'status': 'Open',
              },
            )
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load attendance live feed from backend. $e';
        _loading = false;
      });
    }
  }

  List<String> _classLabels(List<SectionModel> sections) {
    _sectionIdsByClass.clear();
    final labels = <String>[];
    final seen = <String, int>{};
    for (final section in sections) {
      final base = section.sectionName.trim().isEmpty
          ? section.id
          : section.sectionName.trim();
      final count = (seen[base] ?? 0) + 1;
      seen[base] = count;
      final label = count == 1 ? base : '$base (${section.gradeId})';
      labels.add(label);
      _sectionIdsByClass[label] = section.id;
    }
    return labels;
  }

  List<Map<String, dynamic>> get _filteredAttendanceRecords {
    final sectionId = _sectionIdsByClass[_selectedClass];
    if (sectionId == null || sectionId.isEmpty) return _attendanceRecords;
    return _attendanceRecords
        .where((row) => row['section_id'] == sectionId)
        .toList();
  }

  List<Map<String, dynamic>> get _filteredExceptions {
    final sectionId = _sectionIdsByClass[_selectedClass];
    if (sectionId == null || sectionId.isEmpty) return _exceptions;
    return _exceptions.where((row) => row['section_id'] == sectionId).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawer = AdminDrawer(selectedIndex: 3, onDestinationSelected: (_) {});
    return SchoolDeskModuleScaffold(
      title: 'Attendance Administration',
      subtitle: 'Daily sessions, exceptions, and report exports',
      drawer: drawer,
      railBreakpoint: double.infinity,
      navigationDrawerEnabled: false,
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          tooltip: 'Refresh attendance',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
        ),
        FilledButton.icon(
          onPressed: _loading || _error != null
              ? null
              : () => _exportAttendanceReport('Daily Attendance', 'csv'),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Export'),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Today\'s View'),
          Tab(text: 'Exceptions'),
          Tab(text: 'Reports'),
        ],
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: SchoolDeskStatusPanel.loading(
                message: 'Loading attendance live feed',
              ),
            )
          : _error != null
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: SchoolDeskStatusPanel.error(
                title: 'Attendance unavailable',
                message: _error!,
                onAction: _loadData,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTodayView(),
                _buildExceptions(),
                _buildReports(),
              ],
            ),
    );
  }

  Widget _buildTodayView() {
    final tokens = Theme.of(context).schoolDesk;
    final records = _filteredAttendanceRecords;
    final present = records.where((r) => r['status'] == 'Present').length;
    final absent = records.where((r) => r['status'] == 'Absent').length;
    final late = records.where((r) => r['status'] == 'Late').length;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(tokens.spacing.md),
          child: Column(
            children: [
              SchoolDeskResponsiveGrid(
                minTileWidth: 160,
                mainAxisExtent: 96,
                children: [
                  SchoolDeskKpiCard(
                    title: 'Present',
                    value: '$present',
                    subtitle: 'Marked present',
                    icon: Icons.check_circle_rounded,
                    color: AppTheme.success,
                  ),
                  SchoolDeskKpiCard(
                    title: 'Absent',
                    value: '$absent',
                    subtitle: 'Needs attention',
                    icon: Icons.cancel_rounded,
                    color: AppTheme.error,
                  ),
                  SchoolDeskKpiCard(
                    title: 'Late',
                    value: '$late',
                    subtitle: 'Late arrivals',
                    icon: Icons.schedule_rounded,
                    color: AppTheme.warning,
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.md),
              if (_classes.isEmpty)
                const SchoolDeskStatusPanel.empty(
                  title: 'No backend classes available',
                  message: 'Create class sections before reviewing attendance.',
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedClass,
                  decoration: const InputDecoration(labelText: 'Select Class'),
                  items: _classes
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedClass = v!),
                ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: SchoolDeskStatusPanel.empty(
                    title: 'No attendance sessions',
                    message: 'Marked sessions will appear here from backend.',
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.md,
                    0,
                    tokens.spacing.md,
                    96,
                  ),
                  itemCount: records.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: tokens.spacing.sm),
                  itemBuilder: (_, i) => _buildAttendanceRow(records[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildAttendanceRow(Map<String, dynamic> r) {
    final status = r['status'] as String;
    return SchoolDeskRecordCard(
      title: r['name'] as String,
      subtitle:
          'Period ${r['roll']} • ${r['date']} • ${r['present']}/${r['total']} present',
      leadingIcon: Icons.how_to_reg_rounded,
      semanticLabel: 'Attendance ${r['name']}, period ${r['roll']}, $status',
      chips: [
        SchoolDeskRecordChip(label: status, tone: _attendanceTone(status)),
        if (r['issue'] as bool)
          const SchoolDeskRecordChip(
            label: 'Needs review',
            tone: RecordChipTone.warning,
          ),
      ],
    );
  }

  RecordChipTone _attendanceTone(String status) {
    switch (status) {
      case 'Present':
        return RecordChipTone.success;
      case 'Absent':
        return RecordChipTone.danger;
      case 'Late':
        return RecordChipTone.warning;
      case 'Pending':
        return RecordChipTone.info;
      default:
        return RecordChipTone.neutral;
    }
  }

  Widget _buildExceptions() {
    final tokens = Theme.of(context).schoolDesk;
    final exceptions = _filteredExceptions;
    if (exceptions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: SchoolDeskStatusPanel.empty(
          title: 'No attendance exceptions',
          message: 'Corrections and escalations will appear here.',
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.md,
        tokens.spacing.md,
        tokens.spacing.md,
        96,
      ),
      itemCount: exceptions.length,
      separatorBuilder: (_, __) => SizedBox(height: tokens.spacing.sm),
      itemBuilder: (_, i) {
        final e = exceptions[i];
        final isOpen = e['status'] == 'Open';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOpen
                  ? AppTheme.warningContainer
                  : AppTheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e['student'] as String,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? AppTheme.warningContainer
                          : AppTheme.successContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      e['status'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isOpen ? AppTheme.warning : AppTheme.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${e['class']} • ${e['date']}',
                style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
              ),
              Text(
                e['issue'] as String,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.onSurface,
                ),
              ),
              if (isOpen) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => e['status'] = 'Resolved');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Exception resolved'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text(
                          'Resolve',
                          style: GoogleFonts.dmSans(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Escalated to Principal'),
                              ),
                            ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text(
                          'Escalate',
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

  Widget _buildReports() {
    final reportTypes = [
      {
        'label': 'Daily Attendance Report',
        'icon': Icons.today_rounded,
        'color': AppTheme.primary,
      },
      {
        'label': 'Weekly Summary',
        'icon': Icons.date_range_rounded,
        'color': AppTheme.success,
      },
      {
        'label': 'Monthly Report',
        'icon': Icons.calendar_month_rounded,
        'color': AppTheme.warning,
      },
      {
        'label': 'Class-wise Report',
        'icon': Icons.class_rounded,
        'color': AppTheme.info,
      },
      {
        'label': 'Absentee Report',
        'icon': Icons.person_off_rounded,
        'color': AppTheme.error,
      },
      {
        'label': 'Late Arrivals Report',
        'icon': Icons.access_time_rounded,
        'color': Color(0xFF6C3483),
      },
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: reportTypes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = reportTypes[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (r['color'] as Color).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  r['icon'] as IconData,
                  size: 22,
                  color: r['color'] as Color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  r['label'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        _exportAttendanceReport(r['label'] as String, 'pdf'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    child: Text('PDF', style: GoogleFonts.dmSans(fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () =>
                        _exportAttendanceReport(r['label'] as String, 'csv'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    child: Text('CSV', style: GoogleFonts.dmSans(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportAttendanceReport(String report, String format) async {
    try {
      final export = await BackendApiClient.instance.createReportExport(
        '/attendance/reports/exports',
        reportTitle: report,
        format: format,
        scope: 'admin',
        parameters: {
          'class': _selectedClass,
          'section_id': _sectionIdsByClass[_selectedClass],
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            export['download_url'] == null ||
                    '${export['download_url']}'.trim().isEmpty
                ? '$report export ${export['status'] ?? 'requested'}'
                : '$report export ready: ${export['download_url']}',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance export failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  String _sectionLabel(SectionModel section) {
    final grade = section.gradeName.trim();
    final name = section.sectionName.trim();
    if (grade.isEmpty && name.isEmpty) return section.id;
    if (grade.isEmpty) return name;
    if (name.isEmpty) return grade;
    return '$grade $name';
  }
}
