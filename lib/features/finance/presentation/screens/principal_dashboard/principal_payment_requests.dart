import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/utils/fee_payment_request_status.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/modules/finance/data/api_admin_fees_repository.dart';
import 'package:schooldesk1/modules/finance/domain/admin_fees_repository.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';

class PrincipalPaymentRequests extends StatefulWidget {
  final AdminFeesRepository? repository;

  const PrincipalPaymentRequests({super.key, this.repository});

  @override
  State<PrincipalPaymentRequests> createState() =>
      _PrincipalPaymentRequestsState();
}

class _PrincipalPaymentRequestsState extends State<PrincipalPaymentRequests> {
  AdminFeesRepository get _repository =>
      widget.repository ?? ApiAdminFeesRepository.legacyDefault;

  RepositoryState<Object> _state = const RepositoryState.loading();
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  int _totalRequests = 0;
  String _statusFilter = 'pending';
  List<Map<String, dynamic>> _requests = [];

  final Map<String, TextEditingController> _remarksControllers = {};
  final Map<String, bool> _submittingMap = {};
  final Map<String, String> _decisionMap =
      {}; // 'approved', 'rejected', 'clarification_required'

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    for (final ctrl in _remarksControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRequests({
    bool showSpinner = true,
    bool resetPage = true,
  }) async {
    if (showSpinner) {
      final previous = _state.data;
      setState(() {
        _state = RepositoryState.loading(
          data: previous,
          source: previous == null
              ? RepositorySource.empty
              : RepositorySource.cache,
          isStale: previous != null,
          isRefreshing: previous != null,
        );
        _loadingMore = !resetPage;
      });
    } else if (!resetPage) {
      setState(() => _loadingMore = true);
    }
    try {
      final response = await _repository.loadParentPaymentRequestsPage(
        status: _statusFilter == 'all' ? null : _statusFilter,
        page: resetPage ? 1 : _page + 1,
        pageSize: 20,
      );
      final rows = response.data
          .where((row) => FeePaymentRequestStatus.isReviewRecord(row['status']))
          .toList();
      if (!mounted) return;
      final existingIds = _requests.map((row) => '${row['id'] ?? ''}').toSet();
      final additions = resetPage
          ? rows
          : rows.where((row) => existingIds.add('${row['id'] ?? ''}')).toList();

      // Seed controllers
      for (final r in rows) {
        final id = '${r['id'] ?? ''}';
        if (!_remarksControllers.containsKey(id)) {
          _remarksControllers[id] = TextEditingController();
          _decisionMap[id] = 'approved';
        }
      }

      setState(() {
        _requests = resetPage ? rows : [..._requests, ...additions];
        _page = response.page;
        _totalRequests = response.total;
        _hasMore = response.hasMore;
        _state = const RepositoryState(
          data: Object(),
          source: RepositorySource.remote,
        );
        _loadingMore = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _state = RepositoryState.error(error: error, data: _state.data);
        _loadingMore = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visibleRequests {
    if (_statusFilter == 'all') return _requests;
    if (_statusFilter == 'pending') {
      return _requests
          .where((r) => FeePaymentRequestStatus.isPrincipalPending(r['status']))
          .toList();
    }
    return _requests
        .where(
          (r) =>
              FeePaymentRequestStatus.normalize(r['status']) == _statusFilter,
        )
        .toList();
  }

  Future<void> _submitDecision(Map<String, dynamic> request) async {
    final id = '${request['id'] ?? ''}';
    final decision = _decisionMap[id] ?? 'approved';
    final remarks = _remarksControllers[id]?.text.trim() ?? '';

    if ((decision == 'rejected' || decision == 'clarification_required') &&
        remarks.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter remarks/reason (min 3 chars).'),
        ),
      );
      return;
    }

    setState(() => _submittingMap[id] = true);
    try {
      await _repository.decideParentPaymentRequest(
        id,
        status: decision,
        adminRemarks: remarks,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'approved'
                ? 'Payment request approved.'
                : decision == 'clarification_required'
                ? 'Clarification requested from parent.'
                : 'Payment request rejected.',
          ),
        ),
      );
      _remarksControllers[id]?.clear();
      await _loadRequests(showSpinner: false);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submit failed: $e'),
          backgroundColor: context.appTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingMap[id] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.surface,
      appBar: AppBar(
        title: const Text(
          'Review Payment Proofs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: context.appTheme.onSurface,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _loadRequests(showSpinner: false),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SchoolDeskRepositoryStateView<Object>(
          state: _state,
          onRetry: () => _loadRequests(),
          data: (_) => Column(
            children: [
              _buildSummaryCards(),
              _buildFilterChips(),
              const Divider(height: 1),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _loadRequests(showSpinner: false),
                  child: _visibleRequests.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount:
                              _visibleRequests.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _visibleRequests.length) {
                              return _buildLoadMoreButton();
                            }
                            return _buildRequestCard(
                              _visibleRequests[index],
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final pending = _requests
        .where((r) => FeePaymentRequestStatus.isPrincipalPending(r['status']))
        .length;
    final approved = _requests
        .where(
          (r) =>
              FeePaymentRequestStatus.state(r['status']) ==
              FeePaymentRequestState.approved,
        )
        .length;
    final rejected = _requests
        .where(
          (r) =>
              FeePaymentRequestStatus.state(r['status']) ==
              FeePaymentRequestState.rejected,
        )
        .length;
    final reversed = _requests
        .where(
          (r) =>
              FeePaymentRequestStatus.state(r['status']) ==
              FeePaymentRequestState.reversed,
        )
        .length;
    final clarify = _requests
        .where(
          (r) =>
              FeePaymentRequestStatus.state(r['status']) ==
              FeePaymentRequestState.clarificationRequired,
        )
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: context.appTheme.surfaceVariant.withOpacity(0.2),
      child: Row(
        children: [
          _summaryItem('Pending', pending, Colors.orange),
          _summaryItem('Clarify', clarify, Colors.blue),
          _summaryItem('Approved', approved, Colors.green),
          _summaryItem('Rejected', rejected, Colors.red),
          _summaryItem('Reversed', reversed, Colors.blueGrey),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.ibmPlexSans(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 10,
              color: context.appTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = const [
      ('pending', 'Pending Review'),
      ('clarification_required', 'Clarify'),
      ('approved', 'Approved'),
      ('rejected', 'Rejected'),
      ('reversed', 'Reversed'),
      ('all', 'All'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: filters.map((f) {
          final isSelected = _statusFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: isSelected,
              label: Text(f.$2),
              selectedColor: context.appTheme.primary,
              backgroundColor: context.appTheme.surface,
              side: BorderSide(
                color: isSelected
                    ? context.appTheme.primary
                    : context.appTheme.outlineVariant,
              ),
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : context.appTheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) {
                setState(() => _statusFilter = f.$1);
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: context.appTheme.muted,
            ),
            const SizedBox(height: 12),
            Text(
              'No requests found',
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.bold,
                color: context.appTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> r) {
    final id = '${r['id'] ?? ''}';
    final status = FeePaymentRequestStatus.normalize(r['status']);
    final state = FeePaymentRequestStatus.state(status);
    final isPending = state == FeePaymentRequestState.pending;
    final invoice = r['invoice'] is Map
        ? Map<String, dynamic>.from(r['invoice'] as Map)
        : const <String, dynamic>{};
    final student = r['student'] is Map
        ? Map<String, dynamic>.from(r['student'] as Map)
        : const <String, dynamic>{};
    final parent = r['parent_user'] is Map
        ? Map<String, dynamic>.from(r['parent_user'] as Map)
        : const <String, dynamic>{};

    final studentName =
        '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim();
    final parentName = '${parent['name'] ?? parent['email'] ?? ''}'.trim();
    final invoiceNumber = '${invoice['invoice_number'] ?? ''}';
    final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
    final dateStr = _formatDate(_text(r['payment_date']));
    final method = _text(
      r['payment_method'] ?? r['payment_mode'],
    ).toUpperCase();
    final utr = _text(r['transaction_id']);
    final ref = _text(r['request_reference']);
    final remarks = _text(r['remarks']);
    final adminRemarks = _text(r['admin_remarks']);
    final proofUrl = _text(r['proof_url']);

    final activeDecision = _decisionMap[id] ?? 'approved';
    final isSubmitting = _submittingMap[id] ?? false;

    Color badgeColor = Colors.orange;
    Color badgeBg = Colors.orange.withOpacity(0.1);
    if (state == FeePaymentRequestState.approved) {
      badgeColor = Colors.green;
      badgeBg = Colors.green.withOpacity(0.1);
    } else if (state == FeePaymentRequestState.rejected) {
      badgeColor = Colors.red;
      badgeBg = Colors.red.withOpacity(0.1);
    } else if (state == FeePaymentRequestState.clarificationRequired) {
      badgeColor = Colors.blue;
      badgeBg = Colors.blue.withOpacity(0.1);
    } else if (state == FeePaymentRequestState.reversed) {
      badgeColor = Colors.blueGrey;
      badgeBg = Colors.blueGrey.withOpacity(0.1);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.appTheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    studentName.isEmpty ? 'Student' : studentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    FeePaymentRequestStatus.label(status),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow('Parent', parentName),
            _infoRow('Invoice', invoiceNumber),
            _infoRow('Amount', '₹${amount.toStringAsFixed(0)}'),
            _infoRow('Paid On', dateStr),
            _infoRow('Mode / Ref', '$method (Ref: $ref)'),
            if (utr.isNotEmpty) _infoRow('UTR Reference', utr),
            if (remarks.isNotEmpty) _infoRow('Parent Note', remarks),
            if (adminRemarks.isNotEmpty)
              _infoRow('Reviewer Remarks', adminRemarks),

            if (proofUrl.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Payment Receipt Screenshot',
                style: GoogleFonts.ibmPlexSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: context.appTheme.muted,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showFullImage(proofUrl),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.appTheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    _absoluteMediaUrl(proofUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: context.appTheme.surfaceVariant,
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, size: 24),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            if (isPending) ...[
              const Divider(height: 24),
              Text(
                'Record Verification Decision',
                style: GoogleFonts.ibmPlexSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: context.appTheme.muted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _decisionRadio(id, 'approved', 'Approve', Colors.green),
                  _decisionRadio(
                    id,
                    'clarification_required',
                    'Clarify',
                    Colors.blue,
                  ),
                  _decisionRadio(id, 'rejected', 'Reject', Colors.red),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _remarksControllers[id],
                enabled: !isSubmitting,
                decoration: InputDecoration(
                  labelText: activeDecision == 'approved'
                      ? 'Internal approval notes (Optional)'
                      : activeDecision == 'clarification_required'
                      ? 'What clarification is needed? *'
                      : 'Rejection reason *',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : () => _submitDecision(r),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeDecision == 'approved'
                        ? Colors.green
                        : activeDecision == 'clarification_required'
                        ? Colors.blue
                        : Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          activeDecision == 'approved'
                              ? 'Approve Payment & Record'
                              : activeDecision == 'clarification_required'
                              ? 'Request Parent Clarification'
                              : 'Reject & Notify Parent',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _decisionRadio(String id, String val, String label, Color color) {
    final active = _decisionMap[id] ?? 'approved';
    final selected = active == val;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _decisionMap[id] = val;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : context.appTheme.outlineVariant,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: selected ? color : context.appTheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: context.appTheme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _absoluteMediaUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) return '${EnvConfig.apiOrigin}$trimmed';
    return '${EnvConfig.apiOrigin}/$trimmed';
  }

  void _showFullImage(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              InteractiveViewer(
                child: Image.network(
                  _absoluteMediaUrl(url),
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.isEmpty ? '-' : raw;
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
    return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
  }

  String _text(dynamic value, {dynamic fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return '${fallback ?? ''}'.trim();
    return text;
  }
}
