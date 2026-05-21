import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../services/notification_service.dart';
import './widgets/approval_audit_log_widget.dart';
import './widgets/approval_item_widget.dart';

enum ApprovalType {
  account,
  leave,
  studentLeave,
  admission,
  feeConcession,
  tc,
  classApproval,
  student,
  event,
  timetable,
}

class ApprovalModel {
  final String id;
  final ApprovalType type;
  final String requesterName;
  final String requesterRole;
  final String requesterClass;
  final String submittedDate;
  final String summary;
  final String details;
  String status; // 'pending', 'approved', 'rejected'
  String? remarks;
  String? actionDate;
  final String? decisionPath;

  ApprovalModel({
    required this.id,
    required this.type,
    required this.requesterName,
    required this.requesterRole,
    required this.requesterClass,
    required this.submittedDate,
    required this.summary,
    required this.details,
    required this.status,
    this.remarks,
    this.actionDate,
    this.decisionPath,
  });

  static ApprovalType _typeFromString(String v) {
    switch (v) {
      case 'account':
        return ApprovalType.account;
      case 'leave':
        return ApprovalType.leave;
      case 'student_leave':
        return ApprovalType.studentLeave;
      case 'admission':
        return ApprovalType.admission;
      case 'fee_concession':
        return ApprovalType.feeConcession;
      case 'tc':
        return ApprovalType.tc;
      case 'class':
        return ApprovalType.classApproval;
      case 'student':
        return ApprovalType.student;
      case 'event':
        return ApprovalType.event;
      case 'timetable':
        return ApprovalType.timetable;
      default:
        return ApprovalType.leave;
    }
  }

  factory ApprovalModel.fromMap(Map<String, dynamic> map) {
    return ApprovalModel(
      id: map['id'] as String,
      type: _typeFromString(map['type'] as String),
      requesterName: map['requesterName'] as String,
      requesterRole: map['requesterRole'] as String,
      requesterClass: map['requesterClass'] as String,
      submittedDate: map['submittedDate'] as String,
      summary: map['summary'] as String,
      details: map['details'] as String,
      status: map['status'] as String,
      remarks: map['remarks'] as String?,
      actionDate: map['actionDate'] as String?,
      decisionPath: map['decisionPath'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'requesterName': requesterName,
    'requesterRole': requesterRole,
    'requesterClass': requesterClass,
    'submittedDate': submittedDate,
    'summary': summary,
    'details': details,
    'status': status,
    'remarks': remarks,
    'actionDate': actionDate,
    'decisionPath': decisionPath,
  };
}

class ApprovalCenterScreen extends StatefulWidget {
  const ApprovalCenterScreen({super.key});

  @override
  State<ApprovalCenterScreen> createState() => _ApprovalCenterScreenState();
}

class _ApprovalCenterScreenState extends State<ApprovalCenterScreen>
    with SingleTickerProviderStateMixin {
  int _selectedDrawerIndex = 3;
  late TabController _tabController;
  List<ApprovalModel> _allApprovals = [];
  bool _loading = true;
  String? _error;
  final Set<String> _actionLoadingIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'pending';

  final List<String> _tabLabels = [
    'All',
    'Accounts',
    'Leave',
    'Admission',
    'Fee',
    'TC',
    'Classes',
    'Students',
    'Event',
    'Timetable',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final leaves = await BackendApiClient.instance.getLeaveApplications();
      final approvals = <Map<String, dynamic>>[];
      approvals.addAll(
        await _loadGenericApprovals(
          path: '/account-approvals',
          type: 'account',
        ),
      );
      approvals.addAll(
        leaves
            .map(
              (l) => {
                'id': l.id,
                'type': 'leave',
                'requesterName': l.staffId,
                'requesterRole': 'Teacher',
                'requesterClass': 'Dept: School',
                'submittedDate': l.fromDate.split('T').first,
                'summary':
                    '${l.leaveTypeId} — ${l.totalDays.toStringAsFixed(1)} day(s)',
                'details':
                    'From: ${l.fromDate.split('T').first}\nTo: ${l.toDate.split('T').first}\nReason: ${l.reason ?? ''}',
                'status': l.status,
                'remarks': l.rejectionReason,
                'actionDate': null,
                'decisionPath': null,
              },
            )
            .toList(),
      );
      approvals.addAll(await _loadStudentLeaveApprovals());
      approvals.addAll(
        await _loadGenericApprovals(
          path: '/admissions/applications',
          type: 'admission',
        ),
      );
      approvals.addAll(
        await _loadGenericApprovals(
          path: '/fees/concessions',
          type: 'fee_concession',
        ),
      );
      approvals.addAll(
        await _loadGenericApprovals(
          path: '/certificates/transfer-requests',
          type: 'tc',
        ),
      );
      approvals.addAll(
        await _loadGenericApprovals(path: '/class-approvals', type: 'class'),
      );
      approvals.addAll(
        await _loadGenericApprovals(
          path: '/student-approvals',
          type: 'student',
        ),
      );
      approvals.addAll(
        await _loadGenericApprovals(path: '/events/approvals', type: 'event'),
      );
      approvals.addAll(
        await _loadGenericApprovals(
          path: '/timetable/approvals',
          type: 'timetable',
        ),
      );
      if (!mounted) return;
      setState(() {
        _allApprovals = approvals.map(ApprovalModel.fromMap).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadGenericApprovals({
    required String path,
    required String type,
  }) async {
    try {
      final rows = await BackendApiClient.instance.getRawList(path);
      return rows
          .map((row) => _genericApprovalFromRow(row, type, path))
          .toList();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _loadStudentLeaveApprovals() async {
    try {
      final rows = await BackendApiClient.instance
          .getStudentLeaveApplications();
      return rows.map(_studentLeaveApprovalFromRow).toList();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Map<String, dynamic> _studentLeaveApprovalFromRow(Map<String, dynamic> row) {
    final student = _asMap(row['student']);
    final parent = _asMap(row['parent_user']);
    final section = _asMap(student['current_section']);
    final grade = _asMap(section['grade']);
    final fromDate = _dateOnly(row['from_date']);
    final toDate = _dateOnly(row['to_date']);
    final days = _text(row['total_days'], fallback: '1');
    final status = _text(row['status'], fallback: 'pending').toLowerCase();
    final studentName = _joinNonEmpty([
      _text(student['first_name']),
      _text(student['last_name']),
    ], fallback: _text(row['student_id'], fallback: 'Student'));
    final parentName = _text(parent['name'], fallback: 'Parent');
    final classLabel = _joinNonEmpty([
      _text(grade['grade_name']),
      _text(section['section_name']),
    ], fallback: _text(row['student_id']));
    return {
      'id': _text(row['id']),
      'type': 'student_leave',
      'requesterName': studentName,
      'requesterRole': 'Parent: $parentName',
      'requesterClass': classLabel,
      'submittedDate': _dateOnly(row['applied_at']),
      'summary':
          '${_text(row['leave_type'], fallback: 'Leave')} — $days day(s)',
      'details':
          'Student: $studentName\nParent: $parentName\nFrom: $fromDate\nTo: $toDate\nReason: ${_text(row['reason'])}',
      'status': status,
      'remarks': _text(row['rejection_reason']).isEmpty
          ? null
          : _text(row['rejection_reason']),
      'actionDate': _dateOnly(row['decided_at']),
      'decisionPath':
          '/student-leave/applications/${_text(row['id'])}/decision',
    };
  }

  Map<String, dynamic> _genericApprovalFromRow(
    Map<String, dynamic> row,
    String type,
    String path,
  ) {
    return {
      'id': '${row['id'] ?? ''}',
      'type': type,
      'requesterName':
          '${row['requester_name'] ?? row['student_name'] ?? row['staff_name'] ?? row['created_by'] ?? 'Requester'}',
      'requesterRole': '${row['requester_role'] ?? row['role'] ?? ''}',
      'requesterClass':
          '${row['requesterClass'] ?? row['class_label'] ?? row['class_name'] ?? row['class'] ?? row['section'] ?? ''}',
      'submittedDate':
          '${row['submitted_at'] ?? row['created_at'] ?? row['date'] ?? ''}'
              .split('T')
              .first,
      'summary': '${row['title'] ?? row['type'] ?? row['summary'] ?? type}',
      'details':
          '${row['details'] ?? row['reason'] ?? row['description'] ?? row['purpose'] ?? ''}',
      'status': '${row['status'] ?? 'pending'}'.toLowerCase(),
      'remarks': row['remarks'] ?? row['rejection_reason'],
      'actionDate': row['action_date'],
      'decisionPath': type == 'fee_concession'
          ? '$path/${row['id']}/decision'
          : '$path/${row['id']}',
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ApprovalModel> _getTypeFilteredApprovals(int tabIndex) {
    if (tabIndex == 0) return _allApprovals;
    if (tabIndex == 2) {
      return _allApprovals
          .where(
            (a) =>
                a.type == ApprovalType.leave ||
                a.type == ApprovalType.studentLeave,
          )
          .toList();
    }
    final typeMap = {
      1: ApprovalType.account,
      3: ApprovalType.admission,
      4: ApprovalType.feeConcession,
      5: ApprovalType.tc,
      6: ApprovalType.classApproval,
      7: ApprovalType.student,
      8: ApprovalType.event,
      9: ApprovalType.timetable,
    };
    return _allApprovals.where((a) => a.type == typeMap[tabIndex]).toList();
  }

  List<ApprovalModel> _getVisibleApprovals(int tabIndex) {
    final query = _searchController.text.trim().toLowerCase();
    return _getTypeFilteredApprovals(tabIndex).where((approval) {
      final matchesStatus = switch (_statusFilter) {
        'all' => true,
        'resolved' => approval.status != 'pending',
        _ => approval.status == _statusFilter,
      };
      if (!matchesStatus) return false;
      if (query.isEmpty) return true;
      final searchable = [
        approval.requesterName,
        approval.requesterRole,
        approval.requesterClass,
        approval.summary,
        approval.details,
        approval.status,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  int _getPendingCount(int tabIndex) {
    return _getTypeFilteredApprovals(
      tabIndex,
    ).where((a) => a.status == 'pending').length;
  }

  Future<void> _handleApprove(ApprovalModel approval) async {
    if (_actionLoadingIds.contains(approval.id)) return;
    final today =
        '${DateTime.now().day} ${_monthName(DateTime.now().month)} ${DateTime.now().year}';
    if (approval.type == ApprovalType.studentLeave) {
      setState(() => _actionLoadingIds.add(approval.id));
      try {
        await BackendApiClient.instance.decideStudentLeaveApplication(
          approval.id,
          status: 'approved',
        );
        setState(() {
          approval.status = 'approved';
          approval.actionDate = today;
          approval.remarks = 'Approved';
        });
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to approve student leave. Please try again.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      } finally {
        if (mounted) {
          setState(() => _actionLoadingIds.remove(approval.id));
        }
      }
    } else if (approval.type == ApprovalType.leave) {
      setState(() => _actionLoadingIds.add(approval.id));
      try {
        await BackendApiClient.instance.decideLeaveApplication(
          approval.id,
          status: 'approved',
          reason: '',
        );
        setState(() {
          approval.status = 'approved';
          approval.actionDate = today;
          approval.remarks = 'Approved';
        });
        // Notify the teacher
        NotificationService.getInstance().then((svc) {
          svc.triggerLeaveStatusAlert(
            status: 'Approved',
            dates: '${approval.requesterName}\'s leave request',
            role: 'teacher',
          );
        });
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to approve. Please try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      } finally {
        if (mounted) {
          setState(() => _actionLoadingIds.remove(approval.id));
        }
      }
    } else {
      setState(() => _actionLoadingIds.add(approval.id));
      try {
        await _decideGenericApproval(approval, 'approved', '');
        setState(() {
          approval.status = 'approved';
          approval.actionDate = today;
          approval.remarks = 'Approved';
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Approval failed: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      } finally {
        if (mounted) {
          setState(() => _actionLoadingIds.remove(approval.id));
        }
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${approval.requesterName}\'s request approved'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleReject(ApprovalModel approval, String remarks) async {
    if (_actionLoadingIds.contains(approval.id)) return;
    final today =
        '${DateTime.now().day} ${_monthName(DateTime.now().month)} ${DateTime.now().year}';
    if (approval.type == ApprovalType.studentLeave) {
      setState(() => _actionLoadingIds.add(approval.id));
      try {
        await BackendApiClient.instance.decideStudentLeaveApplication(
          approval.id,
          status: 'rejected',
          rejectionReason: remarks,
        );
        setState(() {
          approval.status = 'rejected';
          approval.actionDate = today;
          approval.remarks = remarks;
        });
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to reject student leave. Please try again.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      } finally {
        if (mounted) {
          setState(() => _actionLoadingIds.remove(approval.id));
        }
      }
    } else if (approval.type == ApprovalType.leave) {
      setState(() => _actionLoadingIds.add(approval.id));
      try {
        await BackendApiClient.instance.decideLeaveApplication(
          approval.id,
          status: 'rejected',
          reason: remarks,
        );
        setState(() {
          approval.status = 'rejected';
          approval.actionDate = today;
          approval.remarks = remarks;
        });
        // Notify the teacher
        NotificationService.getInstance().then((svc) {
          svc.triggerLeaveStatusAlert(
            status: 'Rejected',
            dates: '${approval.requesterName}\'s leave request',
            role: 'teacher',
          );
        });
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to reject. Please try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      } finally {
        if (mounted) {
          setState(() => _actionLoadingIds.remove(approval.id));
        }
      }
    } else {
      setState(() => _actionLoadingIds.add(approval.id));
      try {
        await _decideGenericApproval(approval, 'rejected', remarks);
        setState(() {
          approval.status = 'rejected';
          approval.actionDate = today;
          approval.remarks = remarks;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rejection failed: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      } finally {
        if (mounted) {
          setState(() => _actionLoadingIds.remove(approval.id));
        }
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${approval.requesterName}\'s request rejected'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _decideGenericApproval(
    ApprovalModel approval,
    String status,
    String remarks,
  ) async {
    final path = approval.decisionPath;
    if (path == null || path.isEmpty || path.endsWith('/')) {
      throw const FormatException('Approval decision path is missing');
    }
    await BackendApiClient.instance.updateRaw(path, {
      'type': approval.type.name,
      'status': status,
      'remarks': remarks,
    });
  }

  String _monthName(int month) {
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
    return months[month - 1];
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  String _text(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  String _dateOnly(Object? value) {
    final text = _text(value);
    if (text.isEmpty) return '';
    return text.split('T').first;
  }

  String _joinNonEmpty(List<String> values, {String fallback = ''}) {
    final joined = values.where((value) => value.trim().isNotEmpty).join(' ');
    return joined.trim().isEmpty ? fallback : joined.trim();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _allApprovals
        .where((a) => a.status == 'pending')
        .length;
    final drawer = PrincipalDrawer(
      selectedIndex: _selectedDrawerIndex,
      onDestinationSelected: (i) => setState(() => _selectedDrawerIndex = i),
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Approval Center',
        subtitle: 'Review pending operational requests and audit decisions',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SchoolDeskModuleScaffold(
        title: 'Approval Center',
        subtitle: 'Review pending operational requests and audit decisions',
        drawer: drawer,
        body: Center(child: Text(_error!)),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Approval Center',
      subtitle: '$pendingCount items pending your action',
      drawer: drawer,
      actions: [_PendingApprovalBadge(pendingCount: pendingCount)],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: List.generate(_tabLabels.length, (i) {
          final tabPendingCount = _getPendingCount(i);
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_tabLabels[i]),
                if (tabPendingCount > 0) ...[
                  const SizedBox(width: 6),
                  Badge(label: Text(tabPendingCount.toString())),
                ],
              ],
            ),
          );
        }),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return TabBarView(
      controller: _tabController,
      children: List.generate(
        _tabLabels.length,
        (tabIndex) => _buildTabContent(tabIndex),
      ),
    );
  }

  Widget _buildTabContent(int tabIndex) {
    final allTypeItems = _getTypeFilteredApprovals(tabIndex);
    final items = _getVisibleApprovals(tabIndex);
    final pending = items.where((a) => a.status == 'pending').toList();
    final resolved = items.where((a) => a.status != 'pending').toList();

    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ApprovalQueueToolbar(
            allItems: allTypeItems,
            visibleCount: items.length,
            selectedStatus: _statusFilter,
            searchController: _searchController,
            onStatusChanged: (value) => setState(() => _statusFilter = value),
            onSearchChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: EmptyStateWidget(
                icon: Icons.task_alt_rounded,
                title: 'No ${_tabLabels[tabIndex]} Approvals',
                description: allTypeItems.isEmpty
                    ? 'All ${_tabLabels[tabIndex].toLowerCase()} requests will appear here.'
                    : 'No requests match the current filters.',
              ),
            ),
          if (pending.isNotEmpty) ...[
            _buildSectionHeader(
              'Pending Action',
              pending.length,
              AppTheme.warning,
            ),
            const SizedBox(height: 8),
            ...pending.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ApprovalItemWidget(
                  approval: a,
                  isActionLoading: _actionLoadingIds.contains(a.id),
                  onApprove: () => _handleApprove(a),
                  onReject: (remarks) => _handleReject(a, remarks),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (resolved.isNotEmpty) ...[
            _buildSectionHeader('Resolved', resolved.length, AppTheme.muted),
            const SizedBox(height: 8),
            ...resolved.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ApprovalItemWidget(
                  approval: a,
                  onApprove: () {},
                  onReject: (_) {},
                ),
              ),
            ),
          ],
          if (tabIndex == 0) ...[
            const SizedBox(height: 16),
            const ApprovalAuditLogWidget(),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withAlpha(38),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            count.toString(),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingApprovalBadge extends StatelessWidget {
  final int pendingCount;

  const _PendingApprovalBadge({required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).shortestSide < 600;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Tooltip(
        message: '$pendingCount pending approvals',
        child: Chip(
          visualDensity: VisualDensity.compact,
          avatar: const Icon(Icons.pending_actions_rounded, size: 16),
          label: Text(compact ? '$pendingCount' : '$pendingCount pending'),
          backgroundColor: AppTheme.warningContainer,
          labelStyle: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.warning,
          ),
        ),
      ),
    );
  }
}

class _ApprovalQueueToolbar extends StatelessWidget {
  final List<ApprovalModel> allItems;
  final int visibleCount;
  final String selectedStatus;
  final TextEditingController searchController;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSearchChanged;

  const _ApprovalQueueToolbar({
    required this.allItems,
    required this.visibleCount,
    required this.selectedStatus,
    required this.searchController,
    required this.onStatusChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pending = allItems.where((a) => a.status == 'pending').length;
    final approved = allItems.where((a) => a.status == 'approved').length;
    final rejected = allItems.where((a) => a.status == 'rejected').length;
    final resolved = approved + rejected;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final metrics = [
          _ApprovalMetricChip(
            label: 'Pending',
            value: pending,
            color: AppTheme.warning,
            icon: Icons.hourglass_top_rounded,
          ),
          _ApprovalMetricChip(
            label: 'Approved',
            value: approved,
            color: AppTheme.success,
            icon: Icons.check_circle_rounded,
          ),
          _ApprovalMetricChip(
            label: 'Rejected',
            value: rejected,
            color: AppTheme.error,
            icon: Icons.cancel_rounded,
          ),
          _ApprovalMetricChip(
            label: 'Showing',
            value: visibleCount,
            color: AppTheme.primary,
            icon: Icons.filter_alt_rounded,
          ),
        ];

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fact_check_rounded,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Approval Queue',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pending == 0
                              ? 'No pending items need principal action.'
                              : '$pending request${pending == 1 ? '' : 's'} need a decision.',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            color: AppTheme.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: metrics),
              const SizedBox(height: 14),
              TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchController.text.trim().isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  hintText: 'Search requester, class, summary, or details',
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ApprovalStatusFilterChip(
                    label: 'Pending',
                    value: 'pending',
                    selectedValue: selectedStatus,
                    onChanged: onStatusChanged,
                  ),
                  _ApprovalStatusFilterChip(
                    label: 'All',
                    value: 'all',
                    selectedValue: selectedStatus,
                    onChanged: onStatusChanged,
                  ),
                  _ApprovalStatusFilterChip(
                    label: 'Resolved',
                    value: 'resolved',
                    selectedValue: selectedStatus,
                    onChanged: onStatusChanged,
                    count: resolved,
                  ),
                  _ApprovalStatusFilterChip(
                    label: 'Approved',
                    value: 'approved',
                    selectedValue: selectedStatus,
                    onChanged: onStatusChanged,
                  ),
                  _ApprovalStatusFilterChip(
                    label: 'Rejected',
                    value: 'rejected',
                    selectedValue: selectedStatus,
                    onChanged: onStatusChanged,
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

class _ApprovalMetricChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _ApprovalMetricChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(48)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalStatusFilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selectedValue;
  final int? count;
  final ValueChanged<String> onChanged;

  const _ApprovalStatusFilterChip({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onChanged,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == selectedValue;
    return ChoiceChip(
      selected: selected,
      label: Text(count == null ? label : '$label ($count)'),
      onSelected: (_) => onChanged(value),
      selectedColor: AppTheme.primaryContainer,
      backgroundColor: AppTheme.surfaceVariant,
      labelStyle: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? AppTheme.primary : AppTheme.onSurfaceVariant,
      ),
      side: BorderSide(
        color: selected
            ? AppTheme.primary.withAlpha(120)
            : AppTheme.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
