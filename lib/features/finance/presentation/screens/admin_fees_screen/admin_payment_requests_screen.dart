import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/utils/fee_payment_request_status.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/features/finance/presentation/screens/admin_fees_screen/admin_payment_request_decision_screen.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/widgets/desktop_screen_wrapper.dart';
import 'package:schooldesk1/modules/people/data/repositories/api_approval_repository.dart';
import 'package:schooldesk1/modules/people/domain/repositories/approval_repository.dart';

import 'package:schooldesk1/core/navigation/schooldesk_navigation.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';

@immutable
class _PaymentRequestsSnapshot {
  const _PaymentRequestsSnapshot({
    required this.requests,
    required this.page,
    required this.total,
    required this.hasMore,
  });

  final List<Map<String, dynamic>> requests;
  final int page;
  final int total;
  final bool hasMore;
}

class AdminPaymentRequestsScreen extends StatefulWidget {
  const AdminPaymentRequestsScreen({super.key, this.repository});

  final ApprovalRepository? repository;

  @override
  State<AdminPaymentRequestsScreen> createState() =>
      _AdminPaymentRequestsScreenState();
}

class _AdminPaymentRequestsScreenState
    extends State<AdminPaymentRequestsScreen> {
  ApprovalRepository get _repository =>
      widget.repository ?? ApiApprovalRepository.legacyDefault;

  bool _loadingMore = false;
  RepositoryState<_PaymentRequestsSnapshot> _state =
      const RepositoryState.loading();
  String _statusFilter = 'pending';

  _PaymentRequestsSnapshot? get _snapshot => _state.data;
  bool get _hasMore => _snapshot?.hasMore ?? false;
  int get _page => _snapshot?.page ?? 1;
  int get _totalRequests => _snapshot?.total ?? 0;
  List<Map<String, dynamic>> get _requests => _snapshot?.requests ?? const [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests({
    bool showSpinner = true,
    bool resetPage = true,
  }) async {
    final previous = _state.data;
    if (showSpinner) {
      setState(() {
        _state = resetPage
            ? RepositoryState.loading(
                data: previous,
                source: previous == null
                    ? RepositorySource.empty
                    : RepositorySource.cache,
                isStale: previous != null,
                isRefreshing: previous != null,
              )
            : _state;
        _loadingMore = !resetPage;
      });
    } else if (!resetPage) {
      setState(() => _loadingMore = true);
    }
    try {
      final response = await _repository.loadPaymentRequests(
        status: _statusFilter == 'all' ? null : _statusFilter,
        page: resetPage ? 1 : _page + 1,
        pageSize: 20,
      );
      final rows = response.data
          .where((row) => FeePaymentRequestStatus.isReviewRecord(row['status']))
          .toList();
      if (!mounted) return;
      final existingIds = _requests.map((row) => _text(row['id'])).toSet();
      final additions = resetPage
          ? rows
          : rows.where((row) => existingIds.add(_text(row['id']))).toList();
      final requests = resetPage ? rows : [..._requests, ...additions];
      setState(() {
        _state = RepositoryState(
          data: _PaymentRequestsSnapshot(
            requests: requests,
            page: response.page,
            total: response.total,
            hasMore: response.hasMore,
          ),
          source: RepositorySource.remote,
          phase: RepositoryPhase.ready,
          lastUpdated: DateTime.now().toUtc(),
        );
        _loadingMore = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
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
    final isDesktop = DesktopBreakpoints.isDesktopWidth(
      MediaQuery.sizeOf(context).width,
    );

    if (isDesktop) {
      return DesktopScreenWrapper(
        breadcrumbs: const ['Finance', 'Payments'],
        title: 'Payment Requests',
        actions: [
          IconButton(
            tooltip: 'Refresh payment requests',
            onPressed: _state.isLoading
                ? null
                : () => _loadRequests(showSpinner: false),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        maxWidth: 800,
        child: SchoolDeskRepositoryStateView<_PaymentRequestsSnapshot>(
          state: _state,
          onRetry: _loadRequests,
          emptyTitle: 'No payment requests',
          emptyMessage: 'Payment requests are not available for this scope.',
          data: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummary(),
              const SizedBox(height: 14),
              _buildStatusFilters(),
              const SizedBox(height: 14),
              if (_visibleRequests.isEmpty)
                const SchoolDeskStatusPanel.empty(
                  title: 'No payment requests',
                  message: 'Parent payment requests will appear here.',
                )
              else
                ..._visibleRequests.map(_requestCard),
              if (_hasMore) _buildLoadMoreButton(),
            ],
          ),
        ),
      );
    }

    return SchoolDeskModuleScaffold(
      title: 'Payment Requests',
      subtitle: 'Review parent-submitted fee payments',
      drawer: PrincipalDrawer(
        selectedIndex: PrincipalNav.fees,
        onDestinationSelected: (_) {},
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          tooltip: 'Refresh payment requests',
          onPressed: _state.isLoading
              ? null
              : () => _loadRequests(showSpinner: false),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: SchoolDeskRepositoryStateView<_PaymentRequestsSnapshot>(
        state: _state,
        onRetry: _loadRequests,
        emptyTitle: 'No payment requests',
        emptyMessage: 'Payment requests are not available for this scope.',
        data: (_) => RefreshIndicator(
          onRefresh: () => _loadRequests(showSpinner: false),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSummary(),
              const SizedBox(height: 14),
              _buildStatusFilters(),
              const SizedBox(height: 14),
              if (_visibleRequests.isEmpty)
                const SchoolDeskStatusPanel.empty(
                  title: 'No payment requests',
                  message: 'Parent payment requests will appear here.',
                )
              else
                ..._visibleRequests.map(_requestCard),
              if (_hasMore) _buildLoadMoreButton(),
            ],
          ),
        ),
      ),
    );
  }

  void _backToFees() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    SchoolDeskNavigation.go(context, AppRoutes.feeMonitoring);
  }

  List<Map<String, dynamic>> get _visibleRequests {
    if (_statusFilter == 'all') return _requests;
    if (_statusFilter == 'pending') {
      return _requests
          .where(
            (request) =>
                FeePaymentRequestStatus.isPrincipalPending(request['status']),
          )
          .toList();
    }
    return _requests
        .where(
          (request) =>
              FeePaymentRequestStatus.normalize(request['status']) ==
              _statusFilter,
        )
        .toList();
  }

  Widget _buildSummary() {
    final pending = _requests
        .where(
          (request) =>
              FeePaymentRequestStatus.isPrincipalPending(request['status']),
        )
        .length;
    final clarification = _countByStatus('clarification_required');
    final approved = _countByStatus('approved');
    final rejected = _countByStatus('rejected');
    final reversed = _countByStatus('reversed');
    return SchoolDeskResponsiveGrid(
      minTileWidth: 160,
      mainAxisExtent: 112,
      children: [
        SchoolDeskKpiCard(
          title: 'Pending',
          value: '$pending',
          subtitle: 'Needs review',
          icon: Icons.pending_actions_rounded,
          color: context.appTheme.warning,
        ),
        SchoolDeskKpiCard(
          title: 'Clarification',
          value: '$clarification',
          subtitle: 'Waiting parent',
          icon: Icons.help_outline_rounded,
          color: context.appTheme.info,
        ),
        SchoolDeskKpiCard(
          title: 'Approved',
          value: '$approved',
          subtitle: 'Recorded as payments',
          icon: Icons.check_circle_rounded,
          color: context.appTheme.success,
        ),
        SchoolDeskKpiCard(
          title: 'Rejected',
          value: '$rejected',
          subtitle: 'Declined requests',
          icon: Icons.cancel_rounded,
          color: context.appTheme.error,
        ),
        SchoolDeskKpiCard(
          title: 'Reversed',
          value: '$reversed',
          subtitle: 'Payment reversed',
          icon: Icons.undo_rounded,
          color: context.appTheme.muted,
        ),
      ],
    );
  }

  Widget _buildStatusFilters() {
    final filters = const [
      ('pending', 'Pending'),
      ('clarification_required', 'Clarification'),
      ('approved', 'Approved'),
      ('rejected', 'Rejected'),
      ('reversed', 'Reversed'),
      ('all', 'All'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = _statusFilter == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              label: Text(filter.$2),
              onSelected: (_) {
                setState(() => _statusFilter = filter.$1);
                _loadRequests();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: _loadingMore
              ? null
              : () => _loadRequests(showSpinner: false, resetPage: false),
          icon: _loadingMore
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more_rounded),
          label: Text(
            _loadingMore
                ? 'Loading…'
                : 'Load more (${_requests.length} of $_totalRequests)',
          ),
        ),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final status = FeePaymentRequestStatus.normalize(request['status']);
    final requestState = FeePaymentRequestStatus.state(status);
    final statusColor = switch (requestState) {
      FeePaymentRequestState.approved => context.appTheme.success,
      FeePaymentRequestState.rejected => context.appTheme.error,
      FeePaymentRequestState.clarificationRequired => context.appTheme.info,
      FeePaymentRequestState.reversed => context.appTheme.muted,
      _ => context.appTheme.warning,
    };
    final statusBg = switch (requestState) {
      FeePaymentRequestState.approved => context.appTheme.successContainer,
      FeePaymentRequestState.rejected => context.appTheme.errorContainer,
      FeePaymentRequestState.clarificationRequired =>
        context.appTheme.infoContainer,
      FeePaymentRequestState.reversed => context.appTheme.surfaceVariant,
      _ => context.appTheme.warningContainer,
    };
    final invoice = _map(request['invoice']);
    final student = _map(request['student']);
    final parent = _map(request['parent_user']);
    final requestID = _text(request['id']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _studentName(student),
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
                  FeePaymentRequestStatus.label(status),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _detailRow(
            'Parent',
            _text(parent['name'], fallback: parent['email']),
          ),
          _detailRow(
            'Invoice',
            _text(invoice['invoice_number'], fallback: request['invoice_id']),
          ),
          if (_text(request['request_reference']).isNotEmpty)
            _detailRow('Reference', _text(request['request_reference'])),
          _detailRow('Amount', _money(_num(request['amount']))),
          _detailRow('Paid on', _date(request['payment_date'])),
          _detailRow(
            'Mode',
            _text(
              request['payment_method'] ?? request['payment_mode'],
              fallback: '-',
            ),
          ),
          if (_text(request['transaction_id']).isNotEmpty)
            _detailRow('Transaction', _text(request['transaction_id'])),
          if (_text(request['proof_url']).isNotEmpty)
            _detailRow('Proof upload', _text(request['proof_url'])),
          if (_text(request['admin_remarks']).isNotEmpty)
            _detailRow('Remarks', _text(request['admin_remarks'])),
          if (_text(request['proof_url']).isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openProofPreview(_text(request['proof_url'])),
              icon: const Icon(Icons.visibility_rounded, size: 16),
              label: Text(
                'Preview Proof',
                style: GoogleFonts.dmSans(fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _backToFees,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text('Fees', style: GoogleFonts.dmSans(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed:
                      FeePaymentRequestStatus.isPrincipalPending(status) &&
                          requestID.isNotEmpty
                      ? () => _openDecision(request)
                      : null,
                  icon: const Icon(Icons.rate_review_rounded, size: 16),
                  label: Text(
                    FeePaymentRequestStatus.isPrincipalPending(status)
                        ? 'Review'
                        : requestState ==
                              FeePaymentRequestState.clarificationRequired
                        ? 'Waiting Parent'
                        : 'Resolved',
                    style: GoogleFonts.dmSans(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: context.appTheme.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDecision(Map<String, dynamic> request) async {
    final updated = await SchoolDeskNavigation.push(
      context,
      AppRoutes.principalPaymentRequestDecision,
      arguments: AdminPaymentRequestDecisionArgs(request: request),
    );
    if (updated == true && mounted) {
      await _loadRequests(showSpinner: false);
    }
  }

  Future<void> _openProofPreview(String url) {
    return openEventPostMediaPreview(context, EventPostMediaItem.fromUrl(url));
  }

  int _countByStatus(String status) => _requests
      .where(
        (request) =>
            FeePaymentRequestStatus.normalize(request['status']) == status,
      )
      .length;

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  double _num(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String _text(dynamic value, {dynamic fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return '${fallback ?? ''}'.trim();
    return text;
  }

  String _studentName(Map<String, dynamic> student) {
    final name = [
      _text(student['first_name']),
      _text(student['last_name']),
    ].where((part) => part.isNotEmpty).join(' ');
    return name.isEmpty ? 'Student' : name;
  }

  String _money(double value) => '₹${value.toStringAsFixed(0)}';

  String _date(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return '-';
    return parsed.toIso8601String().split('T').first;
  }
}
