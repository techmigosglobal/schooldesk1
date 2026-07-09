import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class ParentFeeHub extends StatefulWidget {
  const ParentFeeHub({super.key});

  @override
  State<ParentFeeHub> createState() => _ParentFeeHubState();
}

class _ParentFeeHubState extends State<ParentFeeHub> with WidgetsBindingObserver {
  static const Duration _autoRefreshInterval = Duration(seconds: 120);
  DateTime? _lastRefreshAt;
  static const _refreshDebounce = Duration(seconds: 10);
  final int _selectedNavIndex = ParentNav.fees;
  int _activeChildIndex = 0;
  static const _headerColor = Color(0xFF1A6B4A);
  Timer? _autoRefreshTimer;

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
    super.dispose();
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
      final refreshNonce = forceRefresh ? DateTime.now().millisecondsSinceEpoch : null;
      final children = await BackendApiClient.instance.getMyStudents(
        refreshNonce: refreshNonce,
      );
      final selectedIndex = await ParentChildSelectionService.indexFor(
        children,
        fallback: _activeChildIndex,
      );
      _activeChildIndex = selectedIndex;
      var feeList = <Map<String, dynamic>>[];
      var historyList = <Map<String, dynamic>>[];

      if (children.isNotEmpty) {
        final child = children[_activeChildIndex];
        final studentId = (child['id'] ?? child['student_id'] ?? '').toString();
        
        final feeRows = studentId.isEmpty
            ? <Map<String, dynamic>>[]
            : await BackendApiClient.instance.getParentStudentFees(
                studentId,
                refreshNonce: refreshNonce,
              );
        final invoices = studentId.isEmpty
            ? <Map<String, dynamic>>[]
            : await BackendApiClient.instance.getInvoices(
                studentId: studentId,
                refreshNonce: refreshNonce,
              );
        final paymentRequests = studentId.isEmpty
            ? <Map<String, dynamic>>[]
            : await BackendApiClient.instance.getParentPaymentRequests(
                studentId: studentId,
              );

        feeList = feeRows.map((inv) {
          final balance = (inv['balance_amount'] as num?)?.toDouble() ??
              (inv['balance'] as num?)?.toDouble() ??
              0.0;
          final paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0.0;
          final total = (inv['total_amount'] as num?)?.toDouble() ?? balance + paid;
          final feeType = _text(inv['fee_type']);
          return {
            'id': inv['id'],
            'invoiceNumber': inv['invoice_number'] ?? '',
            'component': _text(
              inv['fee_item_name'],
              fallback: feeType == 'book_kit' ? 'Book & Kit Fee' : 'Tuition Fee',
            ),
            'fee_type': feeType,
            'billing_mode': inv['billing_mode'],
            'priority': inv['priority'],
            'frequency': feeType == 'book_kit' ? 'One Time' : 'Tuition',
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
          };
        }).toList()
          ..sort((a, b) {
            final left = (a['priority'] as num?)?.toInt() ?? 99;
            final right = (b['priority'] as num?)?.toInt() ?? 99;
            return left.compareTo(right);
          });

        for (final inv in invoices) {
          final payments = inv['payments'];
          if (payments is List) {
            for (final p in payments.whereType<Map>()) {
              final payment = Map<String, dynamic>.from(p);
              historyList.add({
                'id': payment['id'] ?? '',
                'component': 'Invoice ${inv['invoice_number'] ?? ''}',
                'amount': (payment['amount_paid'] as num?)?.toDouble() ?? 0.0,
                'date': (payment['payment_date'] ?? '').toString(),
                'method': (payment['payment_mode'] ?? '').toString(),
                'receiptNo': (payment['receipt_number'] ?? '').toString(),
                'student': _studentName(child),
                'class': _studentClass(child),
                'rollNo': _studentRoll(child),
                'parentName': '',
                'status': 'Paid',
                'rawStatus': 'completed',
              });
            }
          }
        }
        
        for (final request in paymentRequests) {
          final invoice = request['invoice'] is Map
              ? Map<String, dynamic>.from(request['invoice'] as Map)
              : invoices.firstWhere(
                  (inv) => '${inv['id']}' == '${request['invoice_id']}',
                  orElse: () => const <String, dynamic>{},
                );
          historyList.add({
            'id': request['id'] ?? '',
            'invoiceId': request['invoice_id'] ?? '',
            'component': 'Invoice ${invoice['invoice_number'] ?? request['invoice_id'] ?? ''}',
            'amount': (request['amount'] as num?)?.toDouble() ?? 0.0,
            'date': (request['payment_date'] ?? request['created_at'] ?? '').toString(),
            'method': (request['payment_mode'] ?? '').toString(),
            'receiptNo': (request['request_reference'] ?? '').toString(),
            'student': _studentName(child),
            'class': _studentClass(child),
            'rollNo': _studentRoll(child),
            'parentName': '',
            'status': _paymentStatusLabel(request['status']),
            'rawStatus': '${request['status'] ?? ''}'.toLowerCase(),
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
    } catch (e) {
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
                  style: GoogleFonts.ibmPlexSans(color: context.appTheme.onSurface),
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
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.parent),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: RefreshIndicator(
        onRefresh: () => _loadData(forceRefresh: true, showSpinner: false),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChildSelector(),
              const SizedBox(height: 16),
              _buildHeroBalanceCard(),
              if (clarification != null) ...[
                const SizedBox(height: 14),
                _buildActionBanner(clarification),
              ],
              const SizedBox(height: 20),
              Text(
                'Fee Items',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.appTheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              if (_feeStructure.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.appTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.appTheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: context.appTheme.muted, size: 24),
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
              const SizedBox(height: 24),
              Text(
                'Quick Access',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.appTheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              _buildQuickAccess(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChildSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_childrenData.length, (i) {
          final isActive = i == _activeChildIndex;
          return GestureDetector(
            onTap: () {
              if (isActive) return;
              setState(() {
                _activeChildIndex = i;
                _loading = true;
              });
              ParentChildSelectionService.saveIndex(_childrenData, i);
              _loadData();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? _headerColor : context.appTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: isActive ? null : Border.all(color: context.appTheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isActive)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    _studentName(_childrenData[i]).split(' ').first,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : context.appTheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeroBalanceCard() {
    final pending = _pendingAmount;
    final nextFee = _nextPendingFee;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: pending > 0
              ? [_headerColor, _headerColor.withRed(30).withGreen(120)]
              : [context.appTheme.primary.withAlpha(200), context.appTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _headerColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance Due',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _money(pending),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (pending > 0 && nextFee != null) ...[
            const SizedBox(height: 12),
            Text(
              'Next due: ${nextFee['dueDate']} (${_daysUntil(nextFee['dueDate'])} days left)',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openPaymentFlow(nextFee),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _headerColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Pay Now — ${_money(nextFee['amount'])}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
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
              Icon(Icons.warning_amber_rounded, color: context.appTheme.error, size: 20),
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
              fallback: 'Principal asked for clearer proof on this transaction.',
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
                style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: context.appTheme.error,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  fee['component'],
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.appTheme.onSurface,
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
                  color: balance > 0 ? context.appTheme.error : context.appTheme.muted,
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
                valueColor: AlwaysStoppedAnimation<Color>(_headerColor),
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
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => _openPaymentFlow(fee),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _headerColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pay Now',
                      style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 14),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () {
                  final paidRequest = _paymentHistory.firstWhere(
                    (p) => p['invoiceId'] == fee['id'] && p['rawStatus'] == 'completed',
                    orElse: () => const <String, dynamic>{},
                  );
                  if (paidRequest.isNotEmpty) {
                    Navigator.pushNamed(
                      context,
                      '/parent/receipt',
                      arguments: ParentPaymentSelectionArgs(
                        fees: [fee],
                        student: _childrenData[_activeChildIndex],
                        paymentRequest: paidRequest['paymentRequest'],
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.receipt_long, size: 14),
                label: Text(
                  'Receipt',
                  style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _headerColor,
                  side: const BorderSide(color: _headerColor),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAccess() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/parent/payment-history',
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: context.appTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appTheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Icon(Icons.history_rounded, color: _headerColor, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    'Payment History',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.appTheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _daysUntil(String dateStr) {
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return 0;
    return parsed.difference(DateTime.now()).inDays;
  }

  Future<void> _openPaymentFlow(Map<String, dynamic> fee) async {
    final student = _childrenData.isEmpty ? null : Map<String, dynamic>.from(_childrenData[_activeChildIndex]);
    final result = await Navigator.pushNamed(
      context,
      '/parent/payment-flow',
      arguments: ParentPaymentSelectionArgs(
        fees: [fee],
        student: student,
      ),
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
    
    final student = _childrenData.isEmpty ? null : Map<String, dynamic>.from(_childrenData[_activeChildIndex]);
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

  String _studentClass(Map<String, dynamic> student) =>
      '${student['class'] ?? student['class_name'] ?? student['current_section_id'] ?? ''}';

  String _studentRoll(Map<String, dynamic> student) =>
      '${student['rollNo'] ?? student['roll_no'] ?? student['student_code'] ?? ''}';

  String _statusFromFeeRow(Map<String, dynamic> row) {
    final raw = _text(row['status']).toLowerCase();
    final balance = (row['balance_amount'] as num?)?.toDouble() ??
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
    return '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim();
  }
}
