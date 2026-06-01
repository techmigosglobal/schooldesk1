import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/features/leave/presentation/screens/parent_leave_screen/parent_leave_request_form_screen.dart';

class ParentLeaveScreen extends StatefulWidget {
  const ParentLeaveScreen({super.key});

  @override
  State<ParentLeaveScreen> createState() => _ParentLeaveScreenState();
}

class _ParentLeaveScreenState extends State<ParentLeaveScreen> {
  int _selectedNavIndex = 7;
  int _activeChildIndex = 0;
  bool _loading = true;
  String? _error;

  static const _headerColor = Color(0xFF1A6B4A);
  final _api = BackendApiClient.instance;
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final children = await _api.getMyStudents();
      final requests = await _api.getStudentLeaveApplications();
      if (!mounted) return;
      setState(() {
        _children = children;
        _requests = requests;
        if (_activeChildIndex >= _children.length) {
          _activeChildIndex = _children.isEmpty ? 0 : _children.length - 1;
        }
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawer = ParentDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Leave Requests',
        subtitle: 'Request student leave and monitor approval history',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Leave Requests',
      subtitle: 'Request student leave and monitor approval history',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        TextButton.icon(
          onPressed: _children.isEmpty ? null : () => _openRequestForm(),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('New Request', style: GoogleFonts.dmSans(fontSize: 12)),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => _loadData(showSpinner: false),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              _buildErrorState(),
              const SizedBox(height: 16),
            ],
            _buildChildSelector(),
            const SizedBox(height: 16),
            _buildLeaveTypeCards(),
            const SizedBox(height: 16),
            _buildNewRequestButton(),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Request History',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => _loadData(showSpinner: false),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_visibleRequests.isEmpty)
              _buildEmptyHistory()
            else
              ..._visibleRequests.map((request) => _requestCard(request)),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _visibleRequests {
    final activeChild = _activeChild;
    if (activeChild == null) return _requests;
    final studentID = activeChild['id']?.toString() ?? '';
    if (studentID.isEmpty) return _requests;
    return _requests
        .where((request) => request['student_id']?.toString() == studentID)
        .toList();
  }

  Map<String, dynamic>? get _activeChild {
    if (_children.isEmpty || _activeChildIndex >= _children.length) {
      return null;
    }
    return _children[_activeChildIndex];
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error ?? 'Unable to load leave requests',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppTheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _loadData(),
            child: Text('Retry', style: GoogleFonts.dmSans(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildChildSelector() {
    if (_children.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.family_restroom_rounded, color: AppTheme.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No linked students found for this parent account.',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_children.length, (index) {
          final child = _children[index];
          final isActive = index == _activeChildIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: isActive,
              label: Text(_firstName(_studentName(child))),
              selectedColor: _headerColor,
              backgroundColor: AppTheme.surface,
              labelStyle: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppTheme.onSurface,
              ),
              side: BorderSide(
                color: isActive ? _headerColor : AppTheme.outlineVariant,
              ),
              onSelected: (_) => setState(() => _activeChildIndex = index),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLeaveTypeCards() {
    final types = [
      {
        'label': 'Sick Leave',
        'icon': Icons.sick_rounded,
        'color': AppTheme.error,
        'bg': AppTheme.errorContainer,
        'desc': 'Illness or medical reasons',
      },
      {
        'label': 'Personal Leave',
        'icon': Icons.person_rounded,
        'color': AppTheme.primary,
        'bg': AppTheme.primaryContainer,
        'desc': 'Family events or personal work',
      },
      {
        'label': 'Early Pickup',
        'icon': Icons.directions_car_rounded,
        'color': AppTheme.warning,
        'bg': AppTheme.warningContainer,
        'desc': 'Early dismissal request',
      },
      {
        'label': 'Special Permission',
        'icon': Icons.star_rounded,
        'color': const Color(0xFF6C3483),
        'bg': const Color(0xFFF3E5F5),
        'desc': 'Events or competitions',
      },
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: types.length,
      itemBuilder: (_, index) {
        final type = types[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _children.isEmpty
              ? null
              : () => _openRequestForm(type: type['label'] as String),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: type['bg'] as Color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  type['icon'] as IconData,
                  color: type['color'] as Color,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        type['label'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: type['color'] as Color,
                        ),
                      ),
                      Text(
                        type['desc'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppTheme.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewRequestButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _children.isEmpty ? null : () => _openRequestForm(),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(
          'Submit New Leave Request',
          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppTheme.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_rounded, color: AppTheme.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No leave requests found for the selected student.',
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final status = _statusLabel(request['status']);
    final isApproved = status == 'Approved';
    final isPending = status == 'Pending';
    final statusColor = isApproved
        ? AppTheme.success
        : isPending
        ? AppTheme.warning
        : AppTheme.error;
    final statusBg = isApproved
        ? AppTheme.successContainer
        : isPending
        ? AppTheme.warningContainer
        : AppTheme.errorContainer;
    final leaveType = request['leave_type']?.toString() ?? 'Leave';
    final studentName = _requestStudentName(request);
    final fromDate = _dateLabel(request['from_date']);
    final toDate = _dateLabel(request['to_date']);
    final days = _numValue(request['total_days']);
    final reason = request['reason']?.toString() ?? '';
    final decidedBy = _deciderName(request);
    final submittedOn = _dateLabel(
      request['applied_at'] ?? request['created_at'],
    );
    final rejectionReason = request['rejection_reason']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  leaveType,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Child: $studentName',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          ),
          Text(
            'Date: $fromDate${days > 1 ? ' - $toDate' : ''}',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          ),
          Text(
            'Days: ${days.toStringAsFixed(days.truncateToDouble() == days ? 0 : 1)}',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          ),
          Text(
            'Reason: $reason',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          if (isApproved && decidedBy.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.success,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Approved by $decidedBy',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'Rejected' && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Rejected: $rejectionReason',
              style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.error),
            ),
          ],
          if (isPending)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.pending_actions_rounded,
                    size: 13,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Awaiting teacher/admin approval',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.warning,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Submitted: $submittedOn',
            style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Future<void> _openRequestForm({String? type}) async {
    final activeChild = _activeChild;
    if (activeChild == null) return;
    final created = await Navigator.of(context).pushNamed(
      AppRoutes.parentLeaveRequestForm,
      arguments: ParentLeaveRequestFormArgs(
        children: _children,
        initialStudentId: activeChild['id']?.toString() ?? '',
        initialLeaveType: type,
      ),
    );
    if (created == true && mounted) {
      await _loadData(showSpinner: false);
    }
  }

  String _studentName(Map<String, dynamic> row) {
    final explicit = row['name'] ?? row['full_name'] ?? row['student_name'];
    if (explicit != null && explicit.toString().trim().isNotEmpty) {
      return explicit.toString().trim();
    }
    final first = row['first_name']?.toString().trim() ?? '';
    final last = row['last_name']?.toString().trim() ?? '';
    final name = [first, last].where((part) => part.isNotEmpty).join(' ');
    return name.isEmpty ? 'Student' : name;
  }

  String _requestStudentName(Map<String, dynamic> request) {
    final student = request['student'];
    if (student is Map) {
      return _studentName(Map<String, dynamic>.from(student));
    }
    return _studentName(request);
  }

  String _deciderName(Map<String, dynamic> request) {
    final decider = request['decider'];
    if (decider is Map) {
      final row = Map<String, dynamic>.from(decider);
      return (row['name'] ?? row['email'] ?? '').toString();
    }
    return '';
  }

  String _firstName(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? value : parts.first;
  }

  String _statusLabel(dynamic value) {
    final raw = (value ?? 'pending').toString().trim().toLowerCase();
    if (raw.isEmpty) return 'Pending';
    return raw[0].toUpperCase() + raw.substring(1);
  }

  String _dateLabel(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
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

  double _numValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
