import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_child_selector.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/features/leave/presentation/screens/parent_leave_screen/parent_leave_request_form_screen.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_leave_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_leave_repository.dart';

import 'package:schooldesk1/core/navigation/schooldesk_navigation.dart';

@immutable
class _ParentLeaveSnapshot {
  final List<Map<String, dynamic>> children;
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> leaveTypes;

  const _ParentLeaveSnapshot({
    required this.children,
    required this.requests,
    required this.leaveTypes,
  });
}

class ParentLeaveScreen extends StatefulWidget {
  final ParentLeaveRepository? repository;

  const ParentLeaveScreen({super.key, this.repository});

  @override
  State<ParentLeaveScreen> createState() => _ParentLeaveScreenState();
}

class _ParentLeaveScreenState extends State<ParentLeaveScreen> {
  int _selectedNavIndex = ParentNav.leave;
  int _activeChildIndex = 0;
  RepositoryState<_ParentLeaveSnapshot> _state =
      const RepositoryState.loading();

  List<Map<String, dynamic>> get _children => _state.data?.children ?? const [];
  List<Map<String, dynamic>> get _requests => _state.data?.requests ?? const [];
  List<Map<String, dynamic>> get _leaveTypes =>
      _state.data?.leaveTypes ?? const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({
    bool showSpinner = true,
    bool forceRefresh = false,
  }) async {
    final previous = _state.data;
    if (showSpinner) {
      setState(() {
        _state = RepositoryState.loading(
          data: previous,
          source: previous == null
              ? RepositorySource.empty
              : RepositorySource.cache,
          isStale: previous != null,
          isRefreshing: previous != null,
        );
      });
    }
    try {
      final repository =
          widget.repository ?? ApiParentLeaveRepository.legacyDefault;
      final childrenResult = await repository.getChildren(
        forceRefresh: forceRefresh,
      );
      if (childrenResult.isFailure) {
        throw StateError(
          childrenResult.failureOrNull?.message ??
              'Unable to load linked students',
        );
      }
      final children = childrenResult.dataOrNull!;
      final selectedIndex = await ParentChildSelectionService.indexFor(
        children,
        fallback: _activeChildIndex,
      );
      final safeSelectedIndex = children.isEmpty
          ? 0
          : selectedIndex.clamp(0, children.length - 1);
      final selectedChild = children.isNotEmpty
          ? children[safeSelectedIndex]
          : null;
      final studentId = selectedChild?['id']?.toString() ?? '';
      final requestsResult = studentId.isEmpty
          ? const Result.ok(<Map<String, dynamic>>[])
          : await repository.getRequests(
              studentId: studentId,
              forceRefresh: forceRefresh,
            );
      if (requestsResult.isFailure) {
        throw StateError(
          requestsResult.failureOrNull?.message ??
              'Unable to load leave requests',
        );
      }
      final leaveTypesResult = await repository.getLeaveTypes(
        forceRefresh: forceRefresh,
      );
      if (leaveTypesResult.isFailure) {
        throw StateError(
          leaveTypesResult.failureOrNull?.message ??
              'Unable to load school leave types',
        );
      }
      if (!mounted) return;
      setState(() {
        final requests = requestsResult.dataOrNull!;
        final leaveTypes = leaveTypesResult.dataOrNull!;
        _state = RepositoryState(
          data: _ParentLeaveSnapshot(
            children: children,
            requests: requests,
            leaveTypes: leaveTypes,
          ),
          source: RepositorySource.remote,
          phase: children.isEmpty
              ? RepositoryPhase.empty
              : RepositoryPhase.ready,
          lastUpdated: DateTime.now().toUtc(),
        );
        _activeChildIndex = safeSelectedIndex;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _state = previous == null
            ? RepositoryState.error(error: error)
            : RepositoryState(
                data: previous,
                source: RepositorySource.cache,
                isStale: true,
                error: error,
                lastUpdated: _state.lastUpdated,
              );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawer = ParentDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );
    return SchoolDeskModuleScaffold(
      title: 'Leave Requests',
      subtitle: 'Request student leave and monitor approval history',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,

      body: SchoolDeskRepositoryStateView<_ParentLeaveSnapshot>(
        state: _state,
        onRetry: () => _loadData(forceRefresh: true),
        emptyTitle: 'No linked students',
        emptyMessage: 'No linked students found for this parent account.',
        loadingMessage: 'Loading leave requests…',
        data: (_) => RefreshIndicator(
          onRefresh: () => _loadData(showSpinner: false, forceRefresh: true),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                    onPressed: () =>
                        _loadData(showSpinner: false, forceRefresh: true),
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

  Widget _buildChildSelector() {
    if (_children.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appTheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.family_restroom_rounded, color: context.appTheme.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No linked students found for this parent account.',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: context.appTheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return ParentChildSelector(
      children: _children,
      selectedIndex: _activeChildIndex,
      onSelected: (index) {
        setState(() => _activeChildIndex = index);
        ParentChildSelectionService.saveIndex(_children, index);
        _loadData(showSpinner: false);
      },
    );
  }

  Widget _buildLeaveTypeCards() {
    final palette = <List<Color>>[
      [const Color(0xFF0F766E), const Color(0xFF34D399)],
      [const Color(0xFF1D4ED8), const Color(0xFF60A5FA)],
      [const Color(0xFFD97706), const Color(0xFFFBBF24)],
      [const Color(0xFF7C3AED), const Color(0xFFA78BFA)],
    ];
    final types = _leaveTypes
        .map(_leaveTypeLabel)
        .where((label) => label.isNotEmpty)
        .toList();
    if (types.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appTheme.outlineVariant),
        ),
        child: Text(
          'No school leave types are configured for parent requests.',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: context.appTheme.onSurfaceVariant,
          ),
        ),
      );
    }
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
        final label = types[index];
        final gradient = palette[index % palette.length];
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _children.isEmpty
                ? null
                : () => _openRequestForm(type: label),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withAlpha(60),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.event_busy_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'School-configured leave type',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: Colors.white.withAlpha(210),
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
          ),
        );
      },
    );
  }

  Widget _buildNewRequestButton() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _children.isEmpty || _leaveTypes.isEmpty
            ? null
            : () => _openRequestForm(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: _children.isEmpty
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF1A6B4A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: _children.isEmpty || _leaveTypes.isEmpty
                ? context.appTheme.surfaceVariant
                : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: _children.isEmpty || _leaveTypes.isEmpty
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF1A6B4A).withAlpha(60),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_rounded,
                size: 20,
                color: _children.isEmpty || _leaveTypes.isEmpty
                    ? context.appTheme.muted
                    : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                'Submit New Leave Request',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _children.isEmpty || _leaveTypes.isEmpty
                      ? context.appTheme.muted
                      : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_rounded, color: context.appTheme.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No leave requests found for the selected student.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: context.appTheme.muted,
              ),
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
        ? context.appTheme.success
        : isPending
        ? context.appTheme.warning
        : context.appTheme.error;
    final leaveType = request['leave_type']?.toString() ?? 'Leave';
    final studentName = _requestStudentName(request);
    final fromDate = _dateLabel(request['from_date'] ?? request['start_date']);
    final toDate = _dateLabel(request['to_date'] ?? request['end_date']);
    final days = _numValue(request['total_days']);
    final reason = request['reason']?.toString() ?? '';
    final decidedBy = _deciderName(request);
    final submittedOn = _dateLabel(
      request['applied_at'] ?? request['created_at'],
    );
    final rejectionReason = request['rejection_reason']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appTheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: statusColor.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent left bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor, statusColor.withAlpha(160)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Card content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
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
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                statusColor.withAlpha(30),
                                statusColor.withAlpha(18),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: statusColor.withAlpha(60),
                            ),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _infoRow(Icons.person_rounded, 'Child: $studentName'),
                    _infoRow(
                      Icons.calendar_today_rounded,
                      'Date: $fromDate${days > 1 ? ' – $toDate' : ''}',
                    ),
                    _infoRow(
                      Icons.schedule_rounded,
                      'Days: ${days.toStringAsFixed(days.truncateToDouble() == days ? 0 : 1)}',
                    ),
                    if (reason.isNotEmpty)
                      _infoRow(Icons.notes_rounded, 'Reason: $reason'),
                    if (isApproved && decidedBy.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: context.appTheme.success,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Approved by $decidedBy',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: context.appTheme.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (status == 'Rejected' && rejectionReason.isNotEmpty)
                      _infoRow(
                        Icons.cancel_rounded,
                        'Rejected: $rejectionReason',
                        color: context.appTheme.error,
                      ),
                    if (isPending)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.pending_actions_rounded,
                              size: 13,
                              color: context.appTheme.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Awaiting teacher/admin approval',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: context.appTheme.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Submitted: $submittedOn',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: context.appTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: color ?? context.appTheme.muted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: color ?? context.appTheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRequestForm({String? type}) async {
    final activeChild = _activeChild;
    if (activeChild == null) return;
    final created = await SchoolDeskNavigation.push(
      context,
      AppRoutes.parentLeaveRequestForm,
      arguments: ParentLeaveRequestFormArgs(
        children: _children,
        initialStudentId: activeChild['id']?.toString() ?? '',
        initialLeaveType: type,
        repository: widget.repository,
        leaveTypes: _leaveTypes,
      ),
    );
    if (created == true && mounted) {
      await _loadData(showSpinner: false, forceRefresh: true);
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

  String _leaveTypeLabel(Map<String, dynamic> row) {
    for (final key in const ['leave_name', 'name', 'leave_type', 'type']) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
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
