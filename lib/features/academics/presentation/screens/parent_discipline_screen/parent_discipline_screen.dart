import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';

class ParentDisciplineScreen extends StatefulWidget {
  const ParentDisciplineScreen({super.key});

  @override
  State<ParentDisciplineScreen> createState() => _ParentDisciplineScreenState();
}

class _ParentDisciplineScreenState extends State<ParentDisciplineScreen> {
  int _selectedNavIndex = 1; // Academics
  int _activeChildIndex = 0;
  static const _headerColor = Color(0xFF1A6B4A);

  List<dynamic> _children = [];
  List<dynamic> _incidents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final children = await BackendApiClient.instance.getMyStudents();
      final incidents = await BackendApiClient.instance.getRawList('/discipline-incidents');
      setState(() {
        _children = children;
        _incidents = incidents;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showErrorSnackBar('Failed to load discipline records: $e');
    }
  }

  String get _activeStudentId {
    if (_children.isEmpty || _activeChildIndex >= _children.length) return '';
    return (_children[_activeChildIndex]['id'] ?? '').toString();
  }

  List<dynamic> get _filteredIncidents {
    final studentId = _activeStudentId;
    if (studentId.isEmpty) return [];
    return _incidents.where((incident) {
      final incStudentId = (incident['student_id'] ?? '').toString();
      return incStudentId == studentId;
    }).toList();
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

  String _formatDate(String dateStr) {
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr.split('T').first;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return AppTheme.error;
      case 'medium':
        return AppTheme.warning;
      case 'low':
      default:
        return AppTheme.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawer = ParentDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );

    return SchoolDeskModuleScaffold(
      title: 'Conduct & Discipline',
      subtitle: 'Monitor student behavior and incident reports',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
          tooltip: 'Refresh discipline logs',
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
                  Expanded(
                    child: _filteredIncidents.isEmpty
                      ? _buildEmptyState()
                      : _buildIncidentsList(),
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
          final c = _children[i];
          final first = (c['first_name'] ?? '').toString();
          final last = (c['last_name'] ?? '').toString();
          final name = [first, last].where((e) => e.isNotEmpty).join(' ').trim();
          final grade = (c['grade_name'] ?? '').toString();
          final section = (c['section_name'] ?? '').toString();
          final classLabel = [grade, section].where((e) => e.isNotEmpty).join('-');
          final label = classLabel.isEmpty ? name : '$name ($classLabel)';

          return GestureDetector(
            onTap: () {
              setState(() {
                _activeChildIndex = i;
              });
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
                label.split(' ').first,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_rounded, size: 48, color: AppTheme.success.withAlpha(120)),
          const SizedBox(height: 12),
          Text(
            'No discipline records found',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Child has a clean conduct sheet.',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentsList() {
    return ListView.builder(
      itemCount: _filteredIncidents.length,
      itemBuilder: (context, index) {
        final incident = _filteredIncidents[index];
        final type = (incident['type'] ?? incident['incident_type'] ?? 'Conduct').toString().toUpperCase();
        final severity = (incident['severity'] ?? 'low').toString();
        final status = (incident['status'] ?? 'open').toString().toUpperCase();
        final desc = (incident['description'] ?? '').toString();
        final reporter = (incident['reported_by'] ?? 'School Staff').toString();
        final date = _formatDate((incident['created_at'] ?? incident['date'] ?? '').toString());

        Color sevColor = _severityColor(severity);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sevColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      type,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: sevColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'STATUS: $status',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    date,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                desc,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppTheme.onSurface,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: AppTheme.outlineVariant),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person_pin_rounded, size: 14, color: AppTheme.muted),
                  const SizedBox(width: 4),
                  Text(
                    'Reported by: $reporter',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.muted,
                    ),
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
