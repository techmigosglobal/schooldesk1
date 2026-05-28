import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../routes/app_routes.dart';
import '../../services/backend_api_client.dart';
import '../../services/notification_route_resolver.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/principal_directory_ui.dart';

enum _InboxFilter { actionRequired, notifications, approvals, events, resolved }

enum _InboxKind { approval, notification }

class PrincipalOperationalInboxScreen extends StatefulWidget {
  const PrincipalOperationalInboxScreen({super.key});

  @override
  State<PrincipalOperationalInboxScreen> createState() =>
      _PrincipalOperationalInboxScreenState();
}

class _PrincipalOperationalInboxScreenState
    extends State<PrincipalOperationalInboxScreen> {
  final Set<String> _busyIds = {};
  List<_InboxItem> _items = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  _InboxFilter _filter = _InboxFilter.actionRequired;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notifications = await _loadNotifications();
      final approvals = await _loadApprovals();
      final items = [...approvals, ...notifications]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<List<_InboxItem>> _loadNotifications() async {
    final service = await NotificationService.getInstance();
    return service
        .getNotificationsForRole('principal')
        .map(_InboxItem.fromNotification)
        .toList();
  }

  Future<List<_InboxItem>> _loadApprovals() async {
    final items = <_InboxItem>[];
    try {
      final leaves = await BackendApiClient.instance.getLeaveApplications();
      items.addAll(leaves.map(_InboxItem.fromStaffLeave));
    } catch (_) {}
    try {
      final leaves = await BackendApiClient.instance
          .getStudentLeaveApplications();
      items.addAll(leaves.map(_InboxItem.fromStudentLeave));
    } catch (_) {}

    final genericSources = const [
      _ApprovalSource('/account-approvals', 'Account Access', Icons.person_add),
      _ApprovalSource(
        '/admissions/applications',
        'Admission',
        Icons.school_rounded,
      ),
      _ApprovalSource(
        '/fees/concessions',
        'Fee Concession',
        Icons.savings_rounded,
        decisionSuffix: '/decision',
      ),
      _ApprovalSource(
        '/certificates/transfer-requests',
        'Transfer Certificate',
        Icons.description_rounded,
      ),
      _ApprovalSource(
        '/class-approvals',
        'Class Change',
        Icons.meeting_room_rounded,
      ),
      _ApprovalSource(
        '/student-approvals',
        'Student Update',
        Icons.badge_rounded,
      ),
      _ApprovalSource(
        '/events/approvals',
        'Event Approval',
        Icons.event_available_rounded,
        category: 'event',
      ),
      _ApprovalSource(
        '/timetable/approvals',
        'Timetable Approval',
        Icons.calendar_view_week_rounded,
      ),
    ];
    for (final source in genericSources) {
      try {
        final rows = await BackendApiClient.instance.getRawList(source.path);
        items.addAll(
          rows.map((row) => _InboxItem.fromGenericApproval(row, source)),
        );
      } catch (_) {}
    }
    return items;
  }

  List<_InboxItem> get _visibleItems {
    final query = _query.trim().toLowerCase();
    return _items.where((item) {
      final matchesSearch =
          query.isEmpty ||
          [
            item.title,
            item.subtitle,
            item.body,
            item.category,
            item.status,
          ].join(' ').toLowerCase().contains(query);
      if (!matchesSearch) return false;
      return switch (_filter) {
        _InboxFilter.actionRequired => item.actionRequired,
        _InboxFilter.notifications => item.kind == _InboxKind.notification,
        _InboxFilter.approvals => item.kind == _InboxKind.approval,
        _InboxFilter.events => item.category == 'event',
        _InboxFilter.resolved => !item.actionRequired,
      };
    }).toList();
  }

  int get _actionRequired => _items.where((item) => item.actionRequired).length;

  int get _unread => _items
      .where((item) => item.kind == _InboxKind.notification && item.unread)
      .length;

  int get _highPriority => _items.where((item) => item.highPriority).length;

  int get _eventApprovals =>
      _items.where((item) => item.category == 'event').length;

  Future<void> _openItem(_InboxItem item) async {
    if (item.kind == _InboxKind.approval) {
      final route = item.category == 'event'
          ? AppRoutes.eventsCalendar
          : AppRoutes.approvalCenter;
      await Navigator.of(context).pushNamed(route);
      await _loadData();
      return;
    }

    if (item.unread) {
      await _markNotificationRead(item);
    }
    final target = NotificationRouteResolver.resolve(
      data: item.routingData,
      currentRole: 'principal',
    );
    if (!mounted) return;
    await Navigator.of(
      context,
    ).pushNamed(target.route, arguments: target.arguments);
    await _loadData();
  }

  Future<void> _markNotificationRead(_InboxItem item) async {
    if (item.notificationId.isEmpty) return;
    setState(() => _busyIds.add(item.id));
    try {
      final service = await NotificationService.getInstance();
      await service.markAsRead(item.notificationId);
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to mark as read: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(item.id));
    }
  }

  Future<void> _decide(_InboxItem item, String status) async {
    if (_busyIds.contains(item.id)) return;
    String remarks = '';
    if (status == 'rejected') {
      final value = await _askRejectReason(item);
      if (value == null) return;
      remarks = value;
    }

    setState(() => _busyIds.add(item.id));
    try {
      if (item.decisionKind == 'staff_leave') {
        await BackendApiClient.instance.decideLeaveApplication(
          item.sourceId,
          status: status,
          reason: remarks,
        );
      } else if (item.decisionKind == 'student_leave') {
        await BackendApiClient.instance.decideStudentLeaveApplication(
          item.sourceId,
          status: status,
          rejectionReason: remarks,
        );
      } else if (item.decisionPath.isNotEmpty) {
        await BackendApiClient.instance.updateRaw(item.decisionPath, {
          'status': status,
          'remarks': remarks,
        });
      } else {
        throw const FormatException('Approval decision path is missing');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved' ? 'Request approved' : 'Request rejected',
          ),
          backgroundColor: status == 'approved'
              ? AppTheme.success
              : AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Decision failed: $error'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(item.id));
    }
  }

  Future<String?> _askRejectReason(_InboxItem item) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject ${item.shortCategory}?'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Reason',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
    return PrincipalDirectoryScaffold(
      title: 'Operational Inbox',
      subtitle: 'Approvals, messages, alerts, and events needing attention',
      loading: _loading,
      error: _error,
      onRefresh: _loadData,
      isEmpty: !_loading && _error == null && visible.isEmpty,
      emptyState: EmptyStateWidget(
        icon: Icons.mark_email_read_rounded,
        title: 'Inbox is clear',
        description: _items.isEmpty
            ? 'New approvals and notifications will appear here.'
            : 'No items match the current filter.',
      ),
      filters: _buildFilters(),
      slivers: [
        SliverToBoxAdapter(
          child: PrincipalDirectoryMetricStrip(
            metrics: [
              PrincipalDirectoryMetric(
                label: 'Action Required',
                value: '$_actionRequired',
                icon: Icons.pending_actions_rounded,
                color: Colors.orange,
                tone: const Color(0xFFFFF4E5),
              ),
              PrincipalDirectoryMetric(
                label: 'Unread',
                value: '$_unread',
                icon: Icons.markunread_rounded,
                color: Colors.indigo,
                tone: const Color(0xFFEAF0FF),
              ),
              PrincipalDirectoryMetric(
                label: 'High Priority',
                value: '$_highPriority',
                icon: Icons.priority_high_rounded,
                color: AppTheme.error,
                tone: const Color(0xFFFFEEEE),
              ),
              PrincipalDirectoryMetric(
                label: 'Events',
                value: '$_eventApprovals',
                icon: Icons.event_available_rounded,
                color: Colors.teal,
                tone: const Color(0xFFE4FAF6),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 96),
          sliver: SliverList.separated(
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = visible[index];
              return _InboxCard(
                item: item,
                busy: _busyIds.contains(item.id),
                onOpen: () => _openItem(item),
                onApprove: item.canDecide
                    ? () => _decide(item, 'approved')
                    : null,
                onReject: item.canDecide
                    ? () => _decide(item, 'rejected')
                    : null,
                onMarkRead: item.kind == _InboxKind.notification && item.unread
                    ? () => _markNotificationRead(item)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 6),
      child: Column(
        children: [
          PrincipalDirectorySearchBox(
            hint: 'Search approvals, messages, alerts...',
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in _InboxFilter.values) ...[
                  PrincipalDirectoryChip(
                    label: _filterLabel(filter),
                    icon: _filterIcon(filter),
                    selected: _filter == filter,
                    onTap: () => setState(() => _filter = filter),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(_InboxFilter filter) {
    return switch (filter) {
      _InboxFilter.actionRequired => 'Action Required',
      _InboxFilter.notifications => 'Notifications',
      _InboxFilter.approvals => 'Approvals',
      _InboxFilter.events => 'Events',
      _InboxFilter.resolved => 'Resolved',
    };
  }

  IconData _filterIcon(_InboxFilter filter) {
    return switch (filter) {
      _InboxFilter.actionRequired => Icons.pending_actions_rounded,
      _InboxFilter.notifications => Icons.notifications_none_rounded,
      _InboxFilter.approvals => Icons.fact_check_rounded,
      _InboxFilter.events => Icons.event_available_rounded,
      _InboxFilter.resolved => Icons.task_alt_rounded,
    };
  }
}

class _InboxCard extends StatelessWidget {
  final _InboxItem item;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onMarkRead;

  const _InboxCard({
    required this.item,
    required this.busy,
    required this.onOpen,
    this.onApprove,
    this.onReject,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    return PrincipalDirectoryCard(
      icon: item.icon,
      title: item.title,
      subtitle: item.subtitle,
      status: item.statusLabel,
      statusColor: item.statusColor,
      onTap: onOpen,
      chips: [
        PrincipalInfoPill(
          icon: Icons.category_rounded,
          label: item.shortCategory,
        ),
        PrincipalInfoPill(icon: Icons.schedule_rounded, label: item.dateLabel),
        if (item.highPriority)
          const PrincipalInfoPill(
            icon: Icons.priority_high_rounded,
            label: 'High priority',
          ),
        if (item.unread)
          const PrincipalInfoPill(
            icon: Icons.markunread_rounded,
            label: 'Unread',
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.body.isNotEmpty)
            Text(
              item.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: principalDirectoryMuted,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (item.actionRequired || onMarkRead != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.actionRequired) ...[
                  FilledButton.icon(
                    onPressed: busy ? null : onApprove,
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ],
                if (onMarkRead != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onMarkRead,
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('Mark read'),
                  ),
              ],
            ),
          ],
        ],
      ),
      trailing: IconButton(
        tooltip: 'Open',
        onPressed: onOpen,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _InboxItem {
  final String id;
  final String sourceId;
  final _InboxKind kind;
  final String title;
  final String subtitle;
  final String body;
  final String category;
  final String status;
  final DateTime createdAt;
  final bool unread;
  final bool highPriority;
  final String notificationId;
  final String decisionKind;
  final String decisionPath;
  final Map<String, dynamic> routingData;
  final IconData icon;

  const _InboxItem({
    required this.id,
    required this.sourceId,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.unread,
    required this.highPriority,
    required this.notificationId,
    required this.decisionKind,
    required this.decisionPath,
    required this.routingData,
    required this.icon,
  });

  factory _InboxItem.fromNotification(AppNotification notification) {
    final category = notification.referenceType.isNotEmpty
        ? notification.referenceType.toLowerCase()
        : notification.category.toLowerCase();
    return _InboxItem(
      id: 'notification:${notification.id}',
      sourceId: notification.referenceId,
      kind: _InboxKind.notification,
      title: notification.title,
      subtitle: notification.isRead ? 'Notification' : 'Unread notification',
      body: notification.body,
      category: category,
      status: notification.isRead ? 'read' : 'unread',
      createdAt: notification.timestamp,
      unread: !notification.isRead,
      highPriority: notification.priority == NotificationPriority.high,
      notificationId: notification.id,
      decisionKind: '',
      decisionPath: '',
      routingData: notification.routingData,
      icon: _iconForCategory(category),
    );
  }

  factory _InboxItem.fromStaffLeave(dynamic leave) {
    final fromDate = _dateOnly(leave.fromDate);
    final toDate = _dateOnly(leave.toDate);
    final status = _text(leave.status, fallback: 'pending').toLowerCase();
    return _InboxItem(
      id: 'staff_leave:${leave.id}',
      sourceId: '${leave.id}',
      kind: _InboxKind.approval,
      title: 'Staff leave approval',
      subtitle: 'Teacher ${leave.staffId}',
      body:
          'From $fromDate to $toDate | ${leave.totalDays.toStringAsFixed(1)} day(s)\n${_text(leave.reason)}',
      category: 'leave',
      status: status,
      createdAt: DateTime.tryParse(fromDate) ?? DateTime.now(),
      unread: false,
      highPriority: status == 'pending',
      notificationId: '',
      decisionKind: 'staff_leave',
      decisionPath: '',
      routingData: const {'reference_type': 'leave', 'role': 'principal'},
      icon: Icons.event_busy_rounded,
    );
  }

  factory _InboxItem.fromStudentLeave(Map<String, dynamic> row) {
    final student = _asMap(row['student']);
    final parent = _asMap(row['parent_user']);
    final status = _text(row['status'], fallback: 'pending').toLowerCase();
    final studentName = _joinNonEmpty([
      _text(student['first_name']),
      _text(student['last_name']),
    ], fallback: _text(row['student_id'], fallback: 'Student'));
    return _InboxItem(
      id: 'student_leave:${_text(row['id'])}',
      sourceId: _text(row['id']),
      kind: _InboxKind.approval,
      title: 'Student leave approval',
      subtitle:
          '$studentName | Parent: ${_text(parent['name'], fallback: 'Parent')}',
      body:
          'From ${_dateOnly(row['from_date'])} to ${_dateOnly(row['to_date'])}\n${_text(row['reason'])}',
      category: 'leave',
      status: status,
      createdAt:
          DateTime.tryParse(_dateOnly(row['applied_at'])) ?? DateTime.now(),
      unread: false,
      highPriority: status == 'pending',
      notificationId: '',
      decisionKind: 'student_leave',
      decisionPath: '/student-leave/applications/${_text(row['id'])}/decision',
      routingData: const {'reference_type': 'leave', 'role': 'principal'},
      icon: Icons.family_restroom_rounded,
    );
  }

  factory _InboxItem.fromGenericApproval(
    Map<String, dynamic> row,
    _ApprovalSource source,
  ) {
    final id = _text(row['id']);
    final status = _text(row['status'], fallback: 'pending').toLowerCase();
    final title = _text(
      row['title'] ?? row['summary'] ?? row['request_title'],
      fallback: source.label,
    );
    final requester = _text(
      row['requester_name'] ??
          row['student_name'] ??
          row['staff_name'] ??
          row['created_by'],
      fallback: 'Requester',
    );
    final category = source.category;
    return _InboxItem(
      id: '${source.path}:$id',
      sourceId: id,
      kind: _InboxKind.approval,
      title: title,
      subtitle: '${source.label} | $requester',
      body: _text(
        row['details'] ?? row['reason'] ?? row['description'] ?? row['purpose'],
      ),
      category: category,
      status: status,
      createdAt:
          DateTime.tryParse(_text(row['submitted_at'] ?? row['created_at'])) ??
          DateTime.now(),
      unread: false,
      highPriority: status == 'pending',
      notificationId: '',
      decisionKind: 'generic',
      decisionPath: '$source.path/$id${source.decisionSuffix}',
      routingData: {'reference_type': category, 'role': 'principal'},
      icon: source.icon,
    );
  }

  bool get actionRequired =>
      kind == _InboxKind.approval &&
      (status == 'pending' || status == 'submitted' || status == 'requested');

  bool get canDecide => actionRequired && sourceId.isNotEmpty;

  String get statusLabel => _titleCase(status.replaceAll('_', ' '));

  String get shortCategory => _titleCase(category.replaceAll('_', ' '));

  Color get statusColor {
    return switch (status) {
      'approved' || 'read' => AppTheme.success,
      'rejected' || 'cancelled' => AppTheme.error,
      'pending' || 'submitted' || 'requested' || 'unread' => Colors.orange,
      _ => principalDirectoryAccent,
    };
  }

  String get dateLabel {
    return '${createdAt.day} ${_monthName(createdAt.month)}';
  }
}

class _ApprovalSource {
  final String path;
  final String label;
  final IconData icon;
  final String category;
  final String decisionSuffix;

  const _ApprovalSource(
    this.path,
    this.label,
    this.icon, {
    this.category = 'approval',
    this.decisionSuffix = '',
  });
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

String _titleCase(String value) {
  return value
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
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
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}

IconData _iconForCategory(String category) {
  return switch (category) {
    'event' => Icons.event_available_rounded,
    'fee' || 'fee_due' => Icons.account_balance_wallet_rounded,
    'exam' || 'exam_reminder' => Icons.assignment_rounded,
    'message' => Icons.chat_bubble_outline_rounded,
    'announcement' || 'notice' => Icons.campaign_rounded,
    'leave' || 'pending_approval' => Icons.pending_actions_rounded,
    _ => Icons.notifications_none_rounded,
  };
}
