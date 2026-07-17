import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_child_selector.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';

class ParentFeeHub extends StatefulWidget {
  const ParentFeeHub({super.key});

  @override
  State<ParentFeeHub> createState() => _ParentFeeHubState();
}

class _ParentFeeHubState extends State<ParentFeeHub>
    with WidgetsBindingObserver {
  static const Duration _autoRefreshInterval = Duration(seconds: 120);
  DateTime? _lastRefreshAt;
  static const _refreshDebounce = Duration(seconds: 10);
  final int _selectedNavIndex = ParentNav.fees;
  int _activeChildIndex = 0;
  static const _headerColor = Color(0xFF1A6B4A);
  Timer? _autoRefreshTimer;
  NotificationService? _notificationService;
  String _lastNotificationSignal = '';

  List<Map<String, dynamic>> _childrenData = [];
  List<Map<String, dynamic>> _feeStructure = [];
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _loading = true;
  String? _error;

  double get _pendingAmount => _feeStructure.fold(
    0.0,
    (sum, f) => sum + ((f['amount'] as num?)?.toDouble() ?? 0.0),
  );

  Map<String, dynamic>? get _nextPendingFee {
    final pending = _feeStructure
        .where((f) => ((f['amount'] as num?)?.toDouble() ?? 0.0) > 0.0)
        .toList();
    if (pending.isEmpty) return null;
    pending.sort((a, b) => _text(a['dueDate']).compareTo(_text(b['dueDate'])));
    return pending.first;
  }

  Map<String, dynamic>? get _latestClarificationRequest {
    for (final payment in _paymentHistory) {
      if (payment['rawStatus'] == 'clarification_required') return payment;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData(forceRefresh: true);
    unawaited(_bindFeeNotifications());
    _autoRefreshTimer = Timer.periodic(
      _autoRefreshInterval,
      (_) => _loadData(forceRefresh: true, showSpinner: false),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadData(forceRefresh: true, showSpinner: false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _notificationService?.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  Future<void> _bindFeeNotifications() async {
    final service = await NotificationService.getInstance();
    if (!mounted) return;
    _notificationService = service;
    _lastNotificationSignal = service.notifications.isEmpty
        ? ''
        : service.notifications.first.id;
    service.addListener(_onNotificationsChanged);
  }

  void _onNotificationsChanged() {
    final service = _notificationService;
    if (!mounted || service == null || service.notifications.isEmpty) return;
    final latest = service.notifications.first;
    if (latest.id == _lastNotificationSignal) return;
    _lastNotificationSignal = latest.id;
    final isFeeUpdate =
        latest.referenceType == 'fee' ||
        latest.category.contains('fee') ||
        latest.title.toLowerCase().contains('fee payment');
    if (!isFeeUpdate) return;
    _lastRefreshAt = null;
    unawaited(_loadData(forceRefresh: true, showSpinner: false));
  }

  Future<void> _loadData({
    bool forceRefresh = false,
    bool showSpinner = true,
  }) async {
    if (forceRefresh && _lastRefreshAt != null) {
      final elapsed = DateTime.now().difference(_lastRefreshAt!);
      if (elapsed < _refreshDebounce) return;
    }
    _lastRefreshAt = DateTime.now();
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final refreshNonce = forceRefresh
          ? DateTime.now().millisecondsSinceEpoch
          : null;
      final children = await BackendApiClient.instance.getMyStudents(
        refreshNonce: refreshNonce,
      );
      final selectedIndex = await ParentChildSelectionService.indexFor(
        children,
        fallback: _activeChildIndex,
      );
      _activeChildIndex = selectedIndex;
      var feeList = <Map<String, dynamic>>[];
      final historyList = <Map<String, dynamic>>[];

      if (children.isNotEmpty) {
        final child = children[_activeChildIndex];
        final studentId = (child['id'] ?? child['student_id'] ?? '').toString();

        final feeRows = studentId.isEmpty
            ? <Map<String, dynamic>>[]
            : await BackendApiClient.instance.getParentStudentFees(
                studentId,
                refreshNonce: refreshNonce,
              );
        // The linked-child endpoint returns the invoices and their payments.
        // Do not call /fees/invoices here: that is intentionally restricted to
        // principal finance management.
        final invoices = feeRows;
        final paymentRequests = studentId.isEmpty
            ? <Map<String, dynamic>>[]
            : await BackendApiClient.instance.getParentPaymentRequests(
                studentId: studentId,
              );

        feeList =
            feeRows.map((inv) {
              final balance =
                  (inv['balance_amount'] as num?)?.toDouble() ??
                  (inv['balance'] as num?)?.toDouble() ??
                  0.0;
              final paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0.0;
              final total =
                  (inv['net_amount'] as num?)?.toDouble() ??
                  (inv['total_amount'] as num?)?.toDouble() ??
                  balance + paid;
              final feeType = _text(inv['fee_type']);
              return {
                'id': inv['id'],
                'invoiceNumber': inv['invoice_number'] ?? '',
                'component': _text(
                  inv['fee_item_name'],
                  fallback: _feeTypeLabel(feeType),
                ),
                'fee_type': feeType,
                'billing_mode': inv['billing_mode'],
                'priority': inv['priority'],
                'frequency': _billingModeLabel(_text(inv['billing_mode'])),
                'amount': balance,
                'paidAmount': paid,
                'totalAmount': total,
                'dueDate': (inv['due_date'] ?? '').toString(),
                'status': _statusFromFeeRow(inv),
                'monthly_amount': inv['monthly_amount'],
                'term_amount': inv['term_amount'],
                'term_count': inv['term_count'],
                'allowed_month_names': inv['allowed_month_names'],
                'paid_month_names': inv['paid_month_names'],
                'unpaid_month_names': inv['unpaid_month_names'],
                'rejection_reason': inv['rejection_reason'],
                'items': _invoiceItems(inv),
                'student': inv['student'],
              };
            }).toList()..sort((a, b) {
              final left = (a['priority'] as num?)?.toInt() ?? 99;
              final right = (b['priority'] as num?)?.toInt() ?? 99;
              return left.compareTo(right);
            });

        for (final inv in invoices) {
          final payments = inv['payments'];
          if (payments is List) {
            for (final p in payments.whereType<Map>()) {
              final payment = Map<String, dynamic>.from(p);
              final paymentStatus = _text(
                payment['status'],
                fallback: 'completed',
              ).toLowerCase();
              if (!{'completed', 'approved', 'paid'}.contains(paymentStatus)) {
                continue;
              }
              final amount =
                  (payment['amount'] as num?)?.toDouble() ??
                  (payment['amount_paid'] as num?)?.toDouble() ??
                  0.0;
              final receipt = payment['receipt'] is Map
                  ? Map<String, dynamic>.from(payment['receipt'] as Map)
                  : const <String, dynamic>{};
              historyList.add({
                'id': payment['id'] ?? '',
                'invoiceId': inv['id'] ?? '',
                'component': _text(
                  inv['fee_item_name'],
                  fallback: 'Invoice ${inv['invoice_number'] ?? ''}',
                ),
                'amount': amount,
                'date': (payment['paid_at'] ?? payment['payment_date'] ?? '')
                    .toString(),
                'method':
                    (payment['payment_method'] ?? payment['payment_mode'] ?? '')
                        .toString(),
                'receiptNo': _text(
                  receipt['receipt_number'] ??
                      payment['receipt_number'] ??
                      payment['reference_number'],
                ),
                'student': _studentName(child),
                'class': _studentClass(child),
                'rollNo': _studentRoll(child),
                'parentName': '',
                'status': 'Paid',
                'rawStatus': paymentStatus,
                'paymentRequest': {
                  ...payment,
                  'amount': amount,
                  'payment_method':
                      payment['payment_method'] ?? payment['payment_mode'],
                  'payment_mode':
                      payment['payment_method'] ?? payment['payment_mode'],
                  'payment_date': payment['paid_at'] ?? payment['payment_date'],
                  'transaction_ref':
                      receipt['transaction_ref'] ?? payment['reference_number'],
                  'receipt': receipt,
                  'invoice': inv,
                  'student': child,
                },
              });
            }
          }
        }

        for (final request in paymentRequests) {
          final requestStatus = _text(request['status']).toLowerCase();
          // Finalized payments come from the invoice's payments relation.
          // Keep only actionable clarification requests in this hub so the
          // parent can resubmit proof without duplicating receipt history.
          if (requestStatus != 'clarification_required') continue;
          final invoice = request['invoice'] is Map
              ? Map<String, dynamic>.from(request['invoice'] as Map)
              : invoices.firstWhere(
                  (inv) => '${inv['id']}' == '${request['invoice_id']}',
                  orElse: () => const <String, dynamic>{},
                );
          historyList.add({
            'id': request['id'] ?? '',
            'invoiceId': request['invoice_id'] ?? '',
            'component':
                'Invoice ${invoice['invoice_number'] ?? request['invoice_id'] ?? ''}',
            'amount': (request['amount'] as num?)?.toDouble() ?? 0.0,
            'date': (request['payment_date'] ?? request['created_at'] ?? '')
                .toString(),
            'method':
                (request['payment_method'] ?? request['payment_mode'] ?? '')
                    .toString(),
            'receiptNo': (request['request_reference'] ?? '').toString(),
            'student': _studentName(child),
            'class': _studentClass(child),
            'rollNo': _studentRoll(child),
            'parentName': '',
            'status': _paymentStatusLabel(request['status']),
            'rawStatus': requestStatus,
            'paymentRequest': Map<String, dynamic>.from(request),
          });
        }
        historyList.sort(
          (a, b) => (b['date'] ?? '').toString().compareTo(
            (a['date'] ?? '').toString(),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _childrenData = children;
        _feeStructure = feeList;
        _paymentHistory = historyList;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawer = ParentDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (_) {},
    );

    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'My Fees',
        subtitle: 'Fee overview, installments, and payment history',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _childrenData.isEmpty) {
      return SchoolDeskModuleScaffold(
        title: 'My Fees',
        subtitle: 'Fee overview, installments, and payment history',
        drawer: drawer,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error == null
                      ? 'No linked students. Ask the school admin to link students to this parent account.'
                      : 'Unable to load fee data: $_error',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSans(
                    color: context.appTheme.onSurface,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _loadData(forceRefresh: true),
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final clarification = _latestClarificationRequest;

    return SchoolDeskModuleScaffold(
      title: 'My Fees',
      subtitle: 'Fee overview, installments, and payment history',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4FBF8), Color(0xFFF7F8FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () => _loadData(forceRefresh: true, showSpinner: false),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChildSelector(),
                const SizedBox(height: 12),
                _buildHeroBalanceCard(),
                if (clarification != null) ...[
                  const SizedBox(height: 12),
                  _buildActionBanner(clarification),
                ],
                const SizedBox(height: 16),
                _buildFeeSectionHeader(),
                const SizedBox(height: 8),
                if (_feeStructure.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.appTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: context.appTheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          color: context.appTheme.muted,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No fee invoices published yet.',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 14,
                              color: context.appTheme.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._feeStructure.map((fee) => _buildFeeItemCard(fee)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChildSelector() {
    return ParentChildSelector(
      children: _childrenData,
      selectedIndex: _activeChildIndex,
      isLoading: _loading,
      onSelected: (index) {
        setState(() {
          _activeChildIndex = index;
          _loading = true;
        });
        ParentChildSelectionService.saveIndex(_childrenData, index);
        _loadData();
      },
    );
  }

  Widget _buildHeroBalanceCard() {
    final pending = _pendingAmount;
    final nextFee = _nextPendingFee;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: pending > 0
              ? [_headerColor, const Color(0xFF0F9F8D)]
              : [
                  context.appTheme.primary.withAlpha(200),
                  context.appTheme.primary,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _headerColor.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Balance Due',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_feeStructure.length} item${_feeStructure.length == 1 ? '' : 's'}',
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _money(pending),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (pending > 0 && nextFee != null) ...[
            const SizedBox(height: 8),
            Text(
              'Next due: ${nextFee['dueDate']} (${_daysUntil(nextFee['dueDate'])} days left)',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openPaymentFlow(nextFee),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _headerColor,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Pay Now — ${_money(nextFee['amount'])}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  'All Caught Up!',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeeSectionHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: _headerColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Fee Items',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: context.appTheme.onSurface,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: _feeStructure.isEmpty ? null : _openFeeStatement,
          icon: const Icon(Icons.description_outlined, size: 16),
          label: const Text('Statement'),
          style: TextButton.styleFrom(
            foregroundColor: _headerColor,
            visualDensity: VisualDensity.compact,
          ),
        ),
        TextButton.icon(
          onPressed: () =>
              Navigator.pushNamed(context, '/parent/payment-history'),
          icon: const Icon(Icons.history_rounded, size: 16),
          label: const Text('History'),
          style: TextButton.styleFrom(
            foregroundColor: _headerColor,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBanner(Map<String, dynamic> clarification) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.error.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: context.appTheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Clarification Needed',
                  style: GoogleFonts.ibmPlexSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: context.appTheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _text(
              clarification['paymentRequest']?['admin_remarks'],
              fallback:
                  'Principal asked for clearer proof on this transaction.',
            ),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              color: context.appTheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openClarificationResubmit(clarification),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                'Resubmit Proof',
                style: GoogleFonts.ibmPlexSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: context.appTheme.error,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeItemCard(Map<String, dynamic> fee) {
    final balance = (fee['amount'] as num?)?.toDouble() ?? 0.0;
    final total = (fee['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final paid = (fee['paidAmount'] as num?)?.toDouble() ?? 0.0;
    final status = fee['status'] as String;
    final isTuition = fee['fee_type'] == 'tuition';
    final hasLinkedReceipt = _hasLinkedReceiptForInvoice(_text(fee['id']));
    final accent = isTuition ? _headerColor : const Color(0xFF4F46E5);
    final accentSurface = isTuition
        ? const Color(0xFFE8F8F1)
        : const Color(0xFFEEF2FF);

    Color badgeColor = context.appTheme.warning;
    Color badgeBg = context.appTheme.warningContainer;
    if (status == 'Paid') {
      badgeColor = context.appTheme.success;
      badgeBg = context.appTheme.successContainer;
    } else if (status.contains('Pending')) {
      badgeColor = context.appTheme.info;
      badgeBg = context.appTheme.infoContainer;
    } else if (status == 'Rejected' || status == 'Clarification Required') {
      badgeColor = context.appTheme.error;
      badgeBg = context.appTheme.errorContainer;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withAlpha(38)),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentSurface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isTuition ? Icons.school_rounded : Icons.menu_book_rounded,
                  color: accent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fee['component'],
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Due Date: ${fee['dueDate']}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: balance > 0
                      ? context.appTheme.error
                      : context.appTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _money(balance),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.appTheme.onSurface,
                ),
              ),
            ],
          ),
          if (isTuition && total > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? (paid / total) : 0,
                backgroundColor: context.appTheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${((paid / total) * 100).toStringAsFixed(0)}% paid',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 10,
                    color: context.appTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_money(paid)} of ${_money(total)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 10,
                    color: context.appTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (balance > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasLinkedReceipt) ...[
                  OutlinedButton.icon(
                    onPressed: () => _openReceiptForFee(fee),
                    icon: const Icon(Icons.receipt_long, size: 14),
                    label: const Text('Receipt'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _headerColor,
                      side: const BorderSide(color: _headerColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton(
                  onPressed: () => _openPaymentFlow(fee),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Pay Now',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ] else if (hasLinkedReceipt) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openReceiptForFee(fee),
                icon: const Icon(Icons.receipt_long, size: 14),
                label: Text(
                  'Receipt',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _headerColor,
                  side: const BorderSide(color: _headerColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _daysUntil(String dateStr) {
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return 0;
    return parsed.difference(DateTime.now()).inDays;
  }

  Future<Uint8List?> _networkImageBytes(String url) async {
    if (url.isEmpty) return null;
    try {
      return (await NetworkAssetBundle(
        Uri.parse(url),
      ).load(url)).buffer.asUint8List();
    } on Object {
      return null;
    }
  }

  /// Produces one account-wide statement for the currently selected child.
  /// It uses the parent-scoped invoice data already loaded for this child.
  Future<void> _openFeeStatement() async {
    if (_childrenData.isEmpty || _feeStructure.isEmpty) return;
    try {
      final child = Map<String, dynamic>.from(_childrenData[_activeChildIndex]);
      final statementStudent = _feeStructure
          .map((fee) => fee['student'])
          .whereType<Map>()
          .map((student) => Map<String, dynamic>.from(student))
          .firstWhere((student) => student.isNotEmpty, orElse: () => child);
      final statementSection = statementStudent['current_section'] is Map
          ? Map<String, dynamic>.from(
              statementStudent['current_section'] as Map,
            )
          : const <String, dynamic>{};
      final statementGrade = statementSection['grade'] is Map
          ? Map<String, dynamic>.from(statementSection['grade'] as Map)
          : const <String, dynamic>{};
      final statementClass = [
        _text(statementGrade['grade_name']),
        _text(statementSection['section_name']),
      ].where((part) => part.isNotEmpty).join(' - ');
      final school = await BackendApiClient.instance.getCurrentSchool();
      final total = _feeStructure.fold<double>(
        0,
        (sum, fee) => sum + ((fee['totalAmount'] as num?)?.toDouble() ?? 0),
      );
      final paid = _feeStructure.fold<double>(
        0,
        (sum, fee) => sum + ((fee['paidAmount'] as num?)?.toDouble() ?? 0),
      );
      final items = <Map<String, dynamic>>[
        for (final fee in _feeStructure)
          {
            'description': _text(fee['component'], fallback: 'Fee'),
            'amount': (fee['totalAmount'] as num?)?.toDouble() ?? 0,
            'status':
                'Paid ${_money((fee['paidAmount'] as num?)?.toDouble() ?? 0)} · Due ${_money((fee['amount'] as num?)?.toDouble() ?? 0)}',
          },
        for (final fee in _feeStructure)
          if (fee['paid_month_names'] is List &&
              (fee['paid_month_names'] as List).isNotEmpty)
            {
              'description':
                  'Months Paid: ${(fee['paid_month_names'] as List).join(', ')}',
              'amount': 0.0,
              'status': _text(fee['component']),
            },
      ];
      final schoolMap = Map<String, dynamic>.from(school);
      final assets = await Future.wait([
        _networkImageBytes(_text(schoolMap['logo_url'])),
        _networkImageBytes(_text(schoolMap['authorized_signature_url'])),
      ]);
      final bytes = await PdfService.getInstance().generateFeeReceipt(
        documentKind: FeeDocumentKind.accountStatement,
        receiptNo:
            'STMT-${_text(child['id'] ?? child['student_id'], fallback: 'STUDENT')}-${DateTime.now().millisecondsSinceEpoch}',
        studentName: _studentName(child),
        className: statementClass.isEmpty
            ? _studentClass(child)
            : statementClass,
        rollNo: studentIdentifier(statementStudent),
        parentName: '',
        feeItems: items,
        totalAmount: total,
        paidAmount: paid,
        balance: _pendingAmount,
        paymentMode: '',
        paymentDate: DateTime.now(),
        schoolName: _text(schoolMap['name'], fallback: 'School'),
        schoolAddress: [
          schoolMap['address'],
          schoolMap['address_line1'],
          schoolMap['address_line2'],
          schoolMap['city'],
          schoolMap['state'],
          schoolMap['postal_code'],
        ].map(_text).where((value) => value.isNotEmpty).toSet().join(', '),
        schoolLogo: assets[0],
        authorizedSignature: assets[1],
        authorizedSignatoryName: _text(schoolMap['principal_name']),
      );
      if (!mounted) return;
      await PdfService.getInstance().previewDocument(
        context,
        bytes,
        '${_studentName(child)} — Fee Statement',
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to generate fee statement: $error')),
      );
    }
  }

  Future<void> _openPaymentFlow(Map<String, dynamic> fee) async {
    final student = _childrenData.isEmpty
        ? null
        : Map<String, dynamic>.from(_childrenData[_activeChildIndex]);
    final result = await Navigator.pushNamed(
      context,
      '/parent/payment-flow',
      arguments: ParentPaymentSelectionArgs(fees: [fee], student: student),
    );
    if (result != null && mounted) {
      await _loadData(forceRefresh: true);
    }
  }

  Future<void> _openClarificationResubmit(Map<String, dynamic> payment) async {
    final invoiceId = _text(payment['invoiceId']);
    final fee = _feeStructure.firstWhere(
      (row) => _text(row['id']) == invoiceId,
      orElse: () => <String, dynamic>{
        'id': invoiceId,
        'component': payment['component'],
        'amount': payment['amount'],
      },
    );
    final request = payment['paymentRequest'] is Map
        ? Map<String, dynamic>.from(payment['paymentRequest'] as Map)
        : <String, dynamic>{};

    final student = _childrenData.isEmpty
        ? null
        : Map<String, dynamic>.from(_childrenData[_activeChildIndex]);
    final result = await Navigator.pushNamed(
      context,
      '/parent/payment-flow',
      arguments: ParentPaymentSelectionArgs(
        fees: [fee],
        student: student,
        paymentRequest: request,
      ),
    );
    if (result != null && mounted) {
      await _loadData(forceRefresh: true);
    }
  }

  Future<void> _openReceiptForFee(Map<String, dynamic> fee) async {
    final invoiceId = _text(fee['id']);
    final paidRecord = _paymentHistory.firstWhere(
      (payment) =>
          _text(payment['invoiceId']) == invoiceId &&
          _hasLinkedReceipt(payment),
      orElse: () => const <String, dynamic>{},
    );

    final pr = paidRecord['paymentRequest'] is Map
        ? Map<String, dynamic>.from(paidRecord['paymentRequest'] as Map)
        : null;

    if (pr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt is not available for this payment yet.'),
        ),
      );
      return;
    }

    await Navigator.pushNamed(
      context,
      AppRoutes.parentReceipt,
      arguments: ParentPaymentSelectionArgs(
        fees: [fee],
        student: _childrenData[_activeChildIndex],
        paymentRequest: pr,
      ),
    );
    if (mounted) await _loadData(forceRefresh: true, showSpinner: false);
  }

  bool _hasLinkedReceiptForInvoice(String invoiceId) => _paymentHistory.any(
    (payment) =>
        _text(payment['invoiceId']) == invoiceId && _hasLinkedReceipt(payment),
  );

  bool _hasLinkedReceipt(Map<String, dynamic> payment) {
    final status = _text(payment['rawStatus']).toLowerCase();
    if (!{'completed', 'approved', 'paid'}.contains(status)) return false;
    final request = payment['paymentRequest'];
    if (request is! Map) return false;
    final receipt = request['receipt'];
    if (receipt is! Map) return false;
    return _text(receipt['receipt_number']).isNotEmpty;
  }

  String _studentClass(Map<String, dynamic> student) =>
      parentChildClassAndSectionLabel(student);

  String _studentRoll(Map<String, dynamic> student) =>
      '${student['rollNo'] ?? student['roll_no'] ?? student['student_code'] ?? ''}';

  String _statusFromFeeRow(Map<String, dynamic> row) {
    final raw = _text(row['status']).toLowerCase();
    final balance =
        (row['balance_amount'] as num?)?.toDouble() ??
        (row['balance'] as num?)?.toDouble() ??
        0.0;
    switch (raw) {
      case 'paid':
        return 'Paid';
      case 'partial':
        return 'Partial';
      case 'pending_approval':
        return 'Pending Approval';
      case 'payment_pending':
      case 'pending_verification':
      case 'initiated':
      case 'payment_app_opened':
      case 'proof_pending':
        return 'Pending Verification';
      case 'submitted':
        return 'Payment Submitted';
      case 'clarification_required':
        return 'Clarification Required';
      case 'rejected':
        return 'Rejected';
      case 'overdue':
        return 'Due';
    }
    if (balance <= 0) return 'Paid';
    final date = DateTime.tryParse('${row['due_date'] ?? ''}');
    if (date != null && date.isBefore(DateTime.now())) return 'Due';
    return 'Pending';
  }

  List<Map<String, dynamic>> _invoiceItems(Map<String, dynamic> invoice) {
    final raw = invoice['items'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  String _text(dynamic value, {dynamic fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return '${fallback ?? ''}'.trim();
    return text;
  }

  String _feeTypeLabel(String feeType) {
    switch (feeType) {
      case 'book_kit':
        return 'Book & Kit Fee';
      case 'tuition':
        return 'Tuition Fee';
      case 'transport':
        return 'Transport Fee';
      case 'hostel':
        return 'Hostel Fee';
      case 'meals':
        return 'Meals Fee';
      case 'lab':
        return 'Lab Fee';
      case 'sports':
        return 'Sports Fee';
      default:
        if (feeType.isEmpty) return 'Fee';
        final label =
            feeType[0].toUpperCase() +
            feeType.substring(1).replaceAll('_', ' ');
        return '$label Fee';
    }
  }

  String _billingModeLabel(String mode) {
    switch (mode) {
      case 'monthly':
        return 'Monthly';
      case 'one_time':
        return 'One Time';
      case 'term':
        return 'Per Term';
      case 'yearly':
        return 'Yearly';
      default:
        return 'Monthly';
    }
  }

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';

  String _paymentStatusLabel(dynamic raw) {
    switch ('${raw ?? ''}'.toLowerCase()) {
      case 'initiated':
      case 'payment_app_opened':
        return 'Initiated';
      case 'pending_verification':
      case 'submitted':
        return 'Pending Verification';
      case 'clarification_required':
        return 'Clarification Required';
      case 'approved':
      case 'completed':
      case 'paid':
        return 'Paid';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  String _studentName(Map<String, dynamic> student) {
    final name = '${student['name'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
    return '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
        .trim();
  }
}
