import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../routes/app_routes.dart';
import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_components.dart';
import '../../widgets/erp_module_scaffold.dart';
import 'admin_payment_request_decision_screen.dart';

class AdminPaymentRequestsScreen extends StatefulWidget {
  const AdminPaymentRequestsScreen({super.key});

  @override
  State<AdminPaymentRequestsScreen> createState() =>
      _AdminPaymentRequestsScreenState();
}

class _AdminPaymentRequestsScreenState
    extends State<AdminPaymentRequestsScreen> {
  bool _loading = true;
  String? _error;
  String _statusFilter = 'pending';
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await BackendApiClient.instance.getParentPaymentRequests(
        pageSize: 100,
      );
      if (!mounted) return;
      setState(() {
        _requests = rows;
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
    return SchoolDeskModuleScaffold(
      title: 'Payment Requests',
      subtitle: 'Review parent-submitted fee payments',
      drawer: AdminDrawer(selectedIndex: 4, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          tooltip: 'Refresh payment requests',
          onPressed: _loading ? null : () => _loadRequests(showSpinner: false),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadRequests(showSpinner: false),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    _buildErrorState(),
                    const SizedBox(height: 16),
                  ],
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
                ],
              ),
            ),
    );
  }

  List<Map<String, dynamic>> get _visibleRequests {
    if (_statusFilter == 'all') return _requests;
    return _requests
        .where(
          (request) =>
              _text(request['status'], fallback: 'pending').toLowerCase() ==
              _statusFilter,
        )
        .toList();
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error ?? 'Unable to load payment requests',
              style: GoogleFonts.dmSans(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _loadRequests,
            child: Text('Retry', style: GoogleFonts.dmSans(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final pending = _countByStatus('pending');
    final approved = _countByStatus('approved');
    final rejected = _countByStatus('rejected');
    return SchoolDeskResponsiveGrid(
      minTileWidth: 160,
      mainAxisExtent: 92,
      children: [
        SchoolDeskKpiCard(
          title: 'Pending',
          value: '$pending',
          subtitle: 'Needs review',
          icon: Icons.pending_actions_rounded,
          color: AppTheme.warning,
        ),
        SchoolDeskKpiCard(
          title: 'Approved',
          value: '$approved',
          subtitle: 'Recorded as payments',
          icon: Icons.check_circle_rounded,
          color: AppTheme.success,
        ),
        SchoolDeskKpiCard(
          title: 'Rejected',
          value: '$rejected',
          subtitle: 'Declined requests',
          icon: Icons.cancel_rounded,
          color: AppTheme.error,
        ),
      ],
    );
  }

  Widget _buildStatusFilters() {
    final filters = const [
      ('pending', 'Pending'),
      ('approved', 'Approved'),
      ('rejected', 'Rejected'),
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
              onSelected: (_) => setState(() => _statusFilter = filter.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final status = _text(request['status'], fallback: 'pending').toLowerCase();
    final statusColor = switch (status) {
      'approved' => AppTheme.success,
      'rejected' => AppTheme.error,
      _ => AppTheme.warning,
    };
    final statusBg = switch (status) {
      'approved' => AppTheme.successContainer,
      'rejected' => AppTheme.errorContainer,
      _ => AppTheme.warningContainer,
    };
    final invoice = _map(request['invoice']);
    final student = _map(request['student']);
    final parent = _map(request['parent_user']);
    final requestID = _text(request['id']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
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
                  _title(status),
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
          _detailRow('Amount', _money(_num(request['amount']))),
          _detailRow('Paid on', _date(request['payment_date'])),
          _detailRow('Mode', _text(request['payment_mode'], fallback: '-')),
          if (_text(request['transaction_id']).isNotEmpty)
            _detailRow('Transaction', _text(request['transaction_id'])),
          if (_text(request['admin_remarks']).isNotEmpty)
            _detailRow('Remarks', _text(request['admin_remarks'])),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text('Fees', style: GoogleFonts.dmSans(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: status == 'pending' && requestID.isNotEmpty
                      ? () => _openDecision(request)
                      : null,
                  icon: const Icon(Icons.rate_review_rounded, size: 16),
                  label: Text(
                    status == 'pending' ? 'Review' : 'Resolved',
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
              style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
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
    final updated = await Navigator.of(context).pushNamed(
      AppRoutes.adminPaymentRequestDecision,
      arguments: AdminPaymentRequestDecisionArgs(request: request),
    );
    if (updated == true && mounted) {
      await _loadRequests(showSpinner: false);
    }
  }

  int _countByStatus(String status) => _requests
      .where(
        (request) =>
            _text(request['status'], fallback: 'pending').toLowerCase() ==
            status,
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

  String _title(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  String _money(double value) => '₹${value.toStringAsFixed(0)}';

  String _date(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return '-';
    return parsed.toIso8601String().split('T').first;
  }
}
