import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/features/people/presentation/screens/approval_center_screen/widgets/approval_audit_log_widget.dart';
import 'package:schooldesk1/features/people/presentation/screens/approval_center_screen/widgets/approval_item_widget.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/routes/app_routes.dart';

enum ApprovalType {
  account,
  leave,
  studentLeave,
  admission,
  feeConcession,
  fee,
  tc,
  classApproval,
  student,
  event,
  timetable,
  exam,
  document,
  communication,
  helpdesk,
  academicInfo,
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
      case 'fee':
      case 'fees':
        return ApprovalType.fee;
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
      case 'exam':
      case 'exams':
        return ApprovalType.exam;
      case 'document':
      case 'documents':
        return ApprovalType.document;
      case 'communication':
        return ApprovalType.communication;
      case 'helpdesk':
        return ApprovalType.helpdesk;
      case 'academic_info':
        return ApprovalType.academicInfo;
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
  List<String> _sourceErrors = const [];
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
    'Fees',
    'Timetable',
    'Exams',
    'Documents',
    'Communication',
    'Event Posts',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
      _sourceErrors = const [];
    });
    try {
      final sources = await Future.wait([
        _loadApprovalSource('Staff leave', () async {
          final leaves = await BackendApiClient.instance.getLeaveApplications();
          return leaves.map((l) => _staffLeaveApprovalFromModel(l)).toList();
        }),
        _loadApprovalSource(
          'Account approvals',
          () => _loadGenericApprovals(
            path: '/account-approvals',
            type: 'account',
          ),
        ),
        _loadApprovalSource(
          'Principal submissions',
          () => _loadGenericApprovals(path: '/approvals', type: 'approval'),
        ),
        _loadApprovalSource('Student leave', _loadStudentLeaveApprovals),
        _loadApprovalSource(
          'Fee concessions',
          () => _loadGenericApprovals(
            path: '/fees/concessions',
            type: 'fee_concession',
          ),
        ),
        _loadApprovalSource(
          'Transfer certificates',
          () => _loadGenericApprovals(
            path: '/certificates/transfer-requests',
            type: 'tc',
          ),
        ),
        _loadApprovalSource(
          'Classes',
          () => _loadGenericApprovals(path: '/class-approvals', type: 'class'),
        ),
        _loadApprovalSource(
          'Students',
          () => _loadGenericApprovals(
            path: '/student-approvals',
            type: 'student',
          ),
        ),
        _loadApprovalSource(
          'Events',
          () => _loadGenericApprovals(path: '/events/approvals', type: 'event'),
        ),
        _loadApprovalSource(
          'Timetable',
          () => _loadGenericApprovals(
            path: '/timetable/approvals',
            type: 'timetable',
          ),
        ),
      ]);
      final approvals = sources.expand((source) => source.rows).toList();
      final sourceErrors = sources
          .where((source) => source.errorMessage != null)
          .map((source) => '${source.label}: ${source.errorMessage}')
          .toList();
      if (!mounted) return;
      setState(() {
        _allApprovals = approvals.map(ApprovalModel.fromMap).toList();
        _sourceErrors = sourceErrors;
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
    final rows = await BackendApiClient.instance.getRawList(path);
    return rows.map((row) => _genericApprovalFromRow(row, type, path)).toList();
  }

  Future<List<Map<String, dynamic>>> _loadStudentLeaveApprovals() async {
    final rows = await BackendApiClient.instance.getStudentLeaveApplications();
    return rows.map(_studentLeaveApprovalFromRow).toList();
  }

  Map<String, dynamic> _staffLeaveApprovalFromModel(LeaveApplicationModel row) {
    final teacherName = row.staffName.trim().isNotEmpty
        ? row.staffName.trim()
        : _text(row.staffId, fallback: 'Teacher');
    final leaveType = row.leaveTypeName.trim().isNotEmpty
        ? row.leaveTypeName.trim()
        : _text(row.leaveTypeId, fallback: 'Leave request');
    final fromDate = _dateOnly(row.fromDate);
    final toDate = _dateOnly(row.toDate);
    final submitted = _dateOnly(row.appliedAt).isNotEmpty
        ? _dateOnly(row.appliedAt)
        : fromDate;
    return {
      'id': row.id,
      'type': 'leave',
      'requesterName': teacherName,
      'requesterRole': 'Teacher',
      'requesterClass': row.staffDesignation.trim().isEmpty
          ? 'Staff leave'
          : row.staffDesignation.trim(),
      'submittedDate': submitted,
      'summary': '$leaveType - ${row.totalDays.toStringAsFixed(1)} day(s)',
      'details':
          'Teacher: $teacherName\nFrom: $fromDate\nTo: $toDate\nReason: ${row.reason ?? ''}',
      'status': _approvalStatus(row.status),
      'remarks': _text(row.rejectionReason).isEmpty
          ? null
          : _text(row.rejectionReason),
      'actionDate': null,
      'decisionPath': '/leave/applications/${row.id}/approve',
    };
  }

  Future<_ApprovalSourceResult> _loadApprovalSource(
    String label,
    Future<List<Map<String, dynamic>>> Function() loader,
  ) async {
    try {
      return _ApprovalSourceResult(label: label, rows: await loader());
    } catch (error) {
      return _ApprovalSourceResult(
        label: label,
        rows: const [],
        errorMessage: _friendlyError(error),
      );
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
    final resolvedType = type == 'approval' ? _generalApprovalType(row) : type;
    return {
      'id': '${row['id'] ?? ''}',
      'type': resolvedType,
      'requesterName':
          '${row['requester_name'] ?? row['student_name'] ?? row['staff_name'] ?? row['requested_by_user_id'] ?? row['created_by'] ?? 'Requester'}',
      'requesterRole':
          '${row['requester_role'] ?? row['requested_by_role'] ?? row['role'] ?? ''}',
      'requesterClass':
          '${row['requesterClass'] ?? row['class_label'] ?? row['class_name'] ?? row['class'] ?? row['section'] ?? ''}',
      'submittedDate':
          '${row['submitted_at'] ?? row['created_at'] ?? row['date'] ?? ''}'
              .split('T')
              .first,
      'summary':
          '${row['title'] ?? row['module_label'] ?? row['summary'] ?? resolvedType}',
      'details':
          '${row['details'] ?? row['reason'] ?? row['description'] ?? row['purpose'] ?? row['operation_type'] ?? ''}',
      'status': _approvalStatus(row['status']),
      'remarks':
          row['remarks'] ??
          row['rejection_reason'] ??
          row['change_request_note'],
      'actionDate': row['action_date'] ?? row['applied_at'],
      'decisionPath': resolvedType == 'fee_concession'
          ? '$path/${row['id']}/decision'
          : '$path/${row['id']}',
    };
  }

  String _generalApprovalType(Map<String, dynamic> row) {
    final module = _text(row['module']).toLowerCase();
    final type = _text(row['type']).toLowerCase();
    switch (module.isEmpty ? type : module) {
      case 'students':
        return 'student';
      case 'staff':
      case 'user_access':
        return 'account';
      case 'fees':
        return 'fee';
      case 'timetable':
        return 'timetable';
      case 'exams':
        return 'exam';
      case 'documents':
        return 'document';
      case 'communication':
        return 'communication';
      case 'helpdesk':
        return 'helpdesk';
      case 'academic_info':
      case 'attendance_operations':
        return 'class';
      default:
        return type.isEmpty ? 'leave' : type;
    }
  }

  String _approvalStatus(Object? status) {
    final normalized = _text(status, fallback: 'pending').toLowerCase();
    switch (normalized) {
      case 'submitted':
      case 'principal_review':
        return 'pending';
      case 'changes_requested':
        return 'changes_requested';
      case 'applied':
        return 'approved';
      default:
        return normalized;
    }
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
      8: ApprovalType.fee,
      9: ApprovalType.timetable,
      10: ApprovalType.exam,
      11: ApprovalType.document,
      12: ApprovalType.communication,
      13: ApprovalType.event,
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
        backgroundColor: context.appTheme.success,
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
        backgroundColor: context.appTheme.error,
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
    if (path.startsWith('/approvals/')) {
      if (status == 'approved') {
        await BackendApiClient.instance.approveApprovalRequest(approval.id);
        await BackendApiClient.instance.applyApprovalRequest(approval.id);
        return;
      }
      await BackendApiClient.instance.rejectApprovalRequest(
        approval.id,
        reason: remarks,
      );
      return;
    }
    await BackendApiClient.instance.updateRaw(path, {
      'type': approval.type.name,
      'status': status,
      'remarks': remarks,
    });
  }

  Future<void> _handleRequestChanges(
    ApprovalModel approval,
    String note,
  ) async {
    final path = approval.decisionPath;
    if (path == null || !path.startsWith('/approvals/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Change requests are available for principal submissions.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_actionLoadingIds.contains(approval.id)) return;
    setState(() => _actionLoadingIds.add(approval.id));
    try {
      await BackendApiClient.instance.requestApprovalChanges(
        approval.id,
        note: note,
      );
      if (!mounted) return;
      setState(() {
        approval.status = 'changes_requested';
        approval.remarks = note;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes requested'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _actionLoadingIds.remove(approval.id));
    }
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

  String _friendlyError(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Unable to load';
    final compact = raw.replaceAll(RegExp(r'\s+'), ' ');
    return compact.length > 90 ? '${compact.substring(0, 90)}...' : compact;
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
        actions: [
          IconButton(
            tooltip: 'Retry approvals',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        body: Center(
          child: EmptyStateWidget(
            icon: Icons.cloud_off_rounded,
            title: 'Approval center unavailable',
            description: _error!,
          ),
        ),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Approval Center',
      subtitle: '$pendingCount items pending your action',
      drawer: drawer,
      actions: [
        IconButton(
          tooltip: 'Refresh approval queue',
          onPressed: _loading ? null : _loadData,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Event post approvals',
          onPressed: () async {
            final changed = await Navigator.pushNamed(
              context,
              AppRoutes.principalEventApprovals,
            );
            if (changed == true && mounted) await _loadData();
          },
          icon: const Icon(Icons.fact_check_rounded),
        ),
        _PendingApprovalBadge(pendingCount: pendingCount),
      ],
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
      color: context.appTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ApprovalQueueToolbar(
            allItems: allTypeItems,
            visibleCount: items.length,
            sourceErrorCount: _sourceErrors.length,
            selectedStatus: _statusFilter,
            searchController: _searchController,
            onStatusChanged: (value) => setState(() => _statusFilter = value),
            onSearchChanged: (_) => setState(() {}),
          ),
          if (_sourceErrors.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ApprovalSourceHealthBanner(errors: _sourceErrors),
          ],
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
              context.appTheme.warning,
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
                  onRequestChanges: (note) => _handleRequestChanges(a, note),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (resolved.isNotEmpty) ...[
            _buildSectionHeader(
              'Resolved',
              resolved.length,
              context.appTheme.muted,
            ),
            const SizedBox(height: 8),
            ...resolved.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ApprovalItemWidget(
                  approval: a,
                  onApprove: () {},
                  onReject: (_) {},
                  onRequestChanges: (_) {},
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
            color: context.appTheme.onSurface,
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
          backgroundColor: context.appTheme.warningContainer,
          labelStyle: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.appTheme.warning,
          ),
        ),
      ),
    );
  }
}

class _ApprovalSourceResult {
  final String label;
  final List<Map<String, dynamic>> rows;
  final String? errorMessage;

  const _ApprovalSourceResult({
    required this.label,
    required this.rows,
    this.errorMessage,
  });
}

class _ApprovalSourceHealthBanner extends StatelessWidget {
  final List<String> errors;

  const _ApprovalSourceHealthBanner({required this.errors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appTheme.warningContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.warning.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.sync_problem_rounded,
            color: context.appTheme.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${errors.length} approval source${errors.length == 1 ? '' : 's'} need attention',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.appTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  errors.take(3).join('\n'),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    height: 1.35,
                    color: context.appTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalQueueToolbar extends StatelessWidget {
  final List<ApprovalModel> allItems;
  final int visibleCount;
  final int sourceErrorCount;
  final String selectedStatus;
  final TextEditingController searchController;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSearchChanged;

  const _ApprovalQueueToolbar({
    required this.allItems,
    required this.visibleCount,
    required this.sourceErrorCount,
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
    final changesRequested = allItems
        .where((a) => a.status == 'changes_requested')
        .length;
    final resolved = approved + rejected + changesRequested;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final metrics = [
          _ApprovalMetricChip(
            label: 'Pending',
            value: pending,
            color: context.appTheme.warning,
            icon: Icons.hourglass_top_rounded,
          ),
          _ApprovalMetricChip(
            label: 'Approved',
            value: approved,
            color: context.appTheme.success,
            icon: Icons.check_circle_rounded,
          ),
          _ApprovalMetricChip(
            label: 'Rejected',
            value: rejected,
            color: context.appTheme.error,
            icon: Icons.cancel_rounded,
          ),
          _ApprovalMetricChip(
            label: 'Changes',
            value: changesRequested,
            color: context.appTheme.warning,
            icon: Icons.edit_note_rounded,
          ),
          _ApprovalMetricChip(
            label: 'Showing',
            value: visibleCount,
            color: context.appTheme.primary,
            icon: Icons.filter_alt_rounded,
          ),
          _ApprovalMetricChip(
            label: 'Source issues',
            value: sourceErrorCount,
            color: sourceErrorCount == 0
                ? context.appTheme.success
                : context.appTheme.warning,
            icon: sourceErrorCount == 0
                ? Icons.cloud_done_rounded
                : Icons.cloud_sync_rounded,
          ),
        ];

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            color: context.appTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appTheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: context.appTheme.onSurface.withAlpha(10),
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
                      color: context.appTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.fact_check_rounded,
                      color: context.appTheme.primary,
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
                            color: context.appTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pending == 0
                              ? 'No pending items need principal action.'
                              : '$pending request${pending == 1 ? '' : 's'} need a decision.',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            color: context.appTheme.muted,
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
                  fillColor: context.appTheme.surfaceVariant,
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
                    label: 'Changes',
                    value: 'changes_requested',
                    selectedValue: selectedStatus,
                    onChanged: onStatusChanged,
                    count: changesRequested,
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
                    color: context.appTheme.onSurface,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: context.appTheme.muted,
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
      selectedColor: context.appTheme.primaryContainer,
      backgroundColor: context.appTheme.surfaceVariant,
      labelStyle: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected
            ? context.appTheme.primary
            : context.appTheme.onSurfaceVariant,
      ),
      side: BorderSide(
        color: selected
            ? context.appTheme.primary.withAlpha(120)
            : context.appTheme.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
