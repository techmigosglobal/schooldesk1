import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class ParentFeesScreen extends StatefulWidget {
  const ParentFeesScreen({super.key});

  @override
  State<ParentFeesScreen> createState() => _ParentFeesScreenState();
}

class _ParentFeesScreenState extends State<ParentFeesScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = ParentNav.fees;
  late TabController _tabController;
  int _activeChildIndex = 0;
  static const _headerColor = Color(0xFF1A6B4A);

  List<Map<String, dynamic>> _childrenData = [];

  List<Map<String, dynamic>> _feeStructure = [];
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _loading = true;
  String? _error;

  // Returns the earliest unpaid invoice (null if none pending).
  Map<String, dynamic>? get _nextPendingFee {
    final pending = _feeStructure
        .where((f) => ((f['amount'] as num?)?.toDouble() ?? 0) > 0)
        .toList();
    if (pending.isEmpty) return null;
    // Sort by due date ascending to find the most imminent invoice.
    pending.sort(
      (a, b) => (_text(a['dueDate'])).compareTo(_text(b['dueDate'])),
    );
    return pending.first;
  }

  // Total pending across all invoices (used for bottom bar label).
  double get _pendingAmount => _feeStructure.fold(
    0,
    (sum, f) => sum + ((f['amount'] as num?)?.toDouble() ?? 0),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final children = await BackendApiClient.instance.getMyStudents();
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
        final invoices = studentId.isEmpty
            ? <Map<String, dynamic>>[]
            : await BackendApiClient.instance.getInvoices(studentId: studentId);
        final paymentRequests = studentId.isEmpty
            ? <Map<String, dynamic>>[]
            : await BackendApiClient.instance.getParentPaymentRequests(
                studentId: studentId,
              );
        feeList = invoices.map((inv) {
          final status = (inv['status'] ?? '').toString().toLowerCase();
          final balance = (inv['balance'] as num?)?.toDouble() ?? 0;
          final paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0;
          final total =
              (inv['net_amount'] as num?)?.toDouble() ??
              (inv['total_amount'] as num?)?.toDouble() ??
              balance + paid;
          // Backend integration: invoice/payment values are rendered only from
          // the fee APIs. Missing payment metadata remains empty in the UI.
          return {
            'id': inv['id'],
            'invoiceNumber': inv['invoice_number'] ?? '',
            'component': _installmentLabel(inv),
            'frequency': 'Installment',
            'amount': balance,
            'paidAmount': paid,
            'totalAmount': total,
            'dueDate': (inv['due_date'] ?? '').toString(),
            'status': _statusFromInvoice(status, balance, inv['due_date']),
            'items': _invoiceItems(inv),
            // Installment position fields for badge and progress indicator
            'installment_number': inv['installment_number'],
            'installment_count':
                inv['installment_count'] ?? inv['total_installments'],
          };
        }).toList();

        for (final inv in invoices) {
          final payments = inv['payments'];
          if (payments is List) {
            for (final p in payments.whereType<Map>()) {
              final payment = Map<String, dynamic>.from(p);
              historyList.add({
                'id': payment['id'] ?? '',
                'component': 'Invoice ${inv['invoice_number'] ?? ''}',
                'amount': (payment['amount_paid'] as num?)?.toDouble() ?? 0,
                'date': (payment['payment_date'] ?? '').toString(),
                'method': (payment['payment_mode'] ?? '').toString(),
                'receiptNo': (payment['receipt_number'] ?? '').toString(),
                'student': _studentName(child),
                'class': _studentClass(child),
                'rollNo': _studentRoll(child),
                'parentName': '',
                'status': 'Paid',
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
            'component':
                'Invoice ${invoice['invoice_number'] ?? request['invoice_id'] ?? ''}',
            'amount': (request['amount'] as num?)?.toDouble() ?? 0,
            'date': (request['payment_date'] ?? request['created_at'] ?? '')
                .toString(),
            'method': (request['payment_mode'] ?? '').toString(),
            'receiptNo': (request['request_reference'] ?? '').toString(),
            'student': _studentName(child),
            'class': _studentClass(child),
            'rollNo': _studentRoll(child),
            'parentName': '',
            'status': _paymentStatusLabel(request['status']),
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawer = ParentDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'My Fees',
        subtitle: 'Fee overview, installments, and payment history',
        drawer: drawer,
        body: const _FeeLoadingSkeleton(),
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
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'My Fees',
      subtitle: 'Fee overview, installments, and payment history',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Fees'),
          Tab(text: 'Payments'),
          Tab(text: 'Fee Types'),
        ],
      ),
      body: Column(
        children: [
          _buildChildSelector(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDueFeesTab(),
                _buildHistoryTab(),
                _buildStructureTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildSelector() {
    return Container(
      color: context.appTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(_childrenData.length, (i) {
          final isActive = i == _activeChildIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _activeChildIndex = i;
                _loading = true;
              });
              ParentChildSelectionService.saveIndex(_childrenData, i);
              _loadData();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? _headerColor
                    : context.appTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _studentName(_childrenData[i]).split(' ').first,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : context.appTheme.onSurface,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFeeStudentCard(Map<String, dynamic> child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: context.appTheme.onSurface.withAlpha(14),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: context.appTheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_circle_rounded,
              color: context.appTheme.primary,
              size: 34,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _studentName(child).isEmpty
                      ? 'Linked student'
                      : _studentName(child),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.appTheme.onSurface,
                  ),
                ),
                Text(
                  [
                    _studentClass(child),
                    if (_studentRoll(child).isNotEmpty)
                      'Adm No: ${_studentRoll(child)}',
                  ].where((part) => part.trim().isNotEmpty).join(' | '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    color: context.appTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_childrenData.length > 1)
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: context.appTheme.muted,
            ),
        ],
      ),
    );
  }

  Widget _emptyRow(IconData icon, String message, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDueFeesTab() {
    final child = _childrenData[_activeChildIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeeStudentCard(child),
          const SizedBox(height: 14),
          _buildDueSummaryCard(),
          const SizedBox(height: 16),
          Text(
            'Fee Installments',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
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
              child: _emptyRow(
                Icons.receipt_long_rounded,
                'No fee invoices published yet.',
                context.appTheme.muted,
              ),
            )
          else ...[
            ..._feeStructure.map((f) => _feeItemCard(f, true)),
            if (_pendingAmount > 0) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openPaymentRequestForm(),
                  icon: const Icon(Icons.payment_rounded, size: 18),
                  label: Text(
                    'Pay installment — ${_money(_pendingAmount)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _headerColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDueSummaryCard() {
    final pending = _pendingAmount;
    final hasInvoices = _feeStructure.isNotEmpty;
    if (!hasInvoices) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appTheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appTheme.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tuition & Fees',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.appTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pending > 0
                          ? 'Your next scheduled installment is approaching.'
                          : 'Your account is fully paid for the current term.',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.appTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.appTheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: context.appTheme.primary.withAlpha(20),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: context.appTheme.primary,
                  size: 24,
                ),
              ),
            ],
          ),
          if (pending > 0) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appTheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Installment Due',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.appTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _money(
                          (_nextPendingFee?['amount'] as num?)?.toDouble() ??
                              pending,
                        ),
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: context.appTheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Due by ${_nextDueDateLabel()}',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.appTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          _openPaymentRequestForm(singleFee: _nextPendingFee),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appTheme.primary,
                        foregroundColor: context.appTheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Pay installment',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _feeItemCard(Map<String, dynamic> fee, bool showPayBtn) {
    final status = _text(fee['status'], fallback: 'Pending');
    final isPending = status == 'Pending' || status == 'Due';
    final isPaid = status == 'Paid';
    final meta = <String>[
      if (_text(fee['dueDate']).isNotEmpty) 'Due: ${_text(fee['dueDate'])}',
    ].where((part) => part.isNotEmpty).join(' \u2022 ');
    final statusColor = isPaid
        ? context.appTheme.success
        : isPending
        ? context.appTheme.warning
        : context.appTheme.muted;

    // Installment position fields
    final instNum = fee['installment_number'];
    final instTotal = fee['installment_count'];
    final hasInstallmentInfo = instNum != null && instTotal != null;
    final instProgress = hasInstallmentInfo
        ? (int.tryParse('$instNum') ?? 0) /
              (int.tryParse('$instTotal') ?? 1)
              .clamp(1, double.infinity)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending
              ? context.appTheme.warning.withAlpha(80)
              : context.appTheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPaid
                      ? Icons.check_circle_rounded
                      : isPending
                      ? Icons.schedule_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _text(fee['component'], fallback: 'Invoice'),
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (hasInstallmentInfo)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _headerColor.withAlpha(18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _headerColor.withAlpha(50),
                              ),
                            ),
                            child: Text(
                              '$instNum/$instTotal',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _headerColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          color: context.appTheme.muted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _money((fee['amount'] as num?)?.toDouble() ?? 0),
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                  if (showPayBtn && isPending)
                    TextButton(
                      onPressed: () => _openPaymentRequestForm(singleFee: fee),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      child: Text(
                        'Pay installment',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _headerColor,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Installment progress bar
          if (hasInstallmentInfo && instProgress != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: instProgress,
                      minHeight: 5,
                      backgroundColor:
                          context.appTheme.outlineVariant.withAlpha(80),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isPaid ? context.appTheme.success : _headerColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Installment $instNum of $instTotal',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.muted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_paymentHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: context.appTheme.muted,
            ),
            const SizedBox(height: 12),
            Text(
              'No payment history yet',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                color: context.appTheme.muted,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _paymentHistory.length,
      itemBuilder: (_, i) {
        final p = _paymentHistory[i];
        final isPaid = p['status'] == 'Paid';
        final meta = <String>[
          _text(p['date']),
          _text(p['method']),
        ].where((part) => part.isNotEmpty).join(' • ');
        final receiptNo = _text(p['receiptNo']);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appTheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isPaid
                      ? context.appTheme.successContainer
                      : context.appTheme.warningContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPaid
                      ? Icons.receipt_long_rounded
                      : Icons.pending_actions_rounded,
                  color: isPaid
                      ? context.appTheme.success
                      : context.appTheme.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(p['component'], fallback: 'Payment record'),
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          color: context.appTheme.muted,
                        ),
                      ),
                    if (receiptNo.isNotEmpty)
                      Text(
                        'Receipt: $receiptNo',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          color: context.appTheme.muted,
                        ),
                      ),
                    Text(
                      '${p['status']}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 11,
                        color: isPaid
                            ? context.appTheme.success
                            : context.appTheme.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${p['amount']}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isPaid
                          ? context.appTheme.success
                          : context.appTheme.warning,
                    ),
                  ),
                  if (isPaid)
                    TextButton(
                      onPressed: () => _downloadReceipt(p),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.download_rounded,
                            size: 14,
                            color: Color(0xFF1A6B4A),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Receipt',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 11,
                              color: _headerColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStructureTab() {
    final feeTypes = _feeTypeBreakdown();
    final totalAnnual = feeTypes.fold<double>(
      0,
      (sum, f) => sum + ((f['amount'] as num?)?.toDouble() ?? 0),
    );
    final child = _childrenData[_activeChildIndex];
    final className = _studentClass(child);
    if (feeTypes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Fee structure will appear after invoices are published.',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              color: context.appTheme.muted,
            ),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appTheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                className.isEmpty
                    ? 'Fee Types'
                    : 'Fee Types — Class $className',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Values are sourced from generated invoice items.',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  color: context.appTheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...feeTypes.map((f) => _feeTypeCard(f)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                'Total Fee Types:',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _money(totalAnnual),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.appTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _feeTypeCard(Map<String, dynamic> row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.appTheme.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.local_offer_outlined,
              color: context.appTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _text(row['name'], fallback: 'Fee type'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            _money((row['amount'] as num?)?.toDouble() ?? 0),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.appTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _feeTypeBreakdown() {
    final totals = <String, double>{};
    for (final fee in _feeStructure) {
      final items = fee['items'];
      if (items is! List || items.isEmpty) {
        final name = _text(fee['component'], fallback: 'Fee');
        totals[name] =
            (totals[name] ?? 0) +
            ((fee['totalAmount'] as num?)?.toDouble() ?? 0);
        continue;
      }
      for (final rawItem in items.whereType<Map>()) {
        final item = Map<String, dynamic>.from(rawItem);
        final category = item['fee_category'] is Map
            ? Map<String, dynamic>.from(item['fee_category'] as Map)
            : const <String, dynamic>{};
        final name = _text(
          item['description'] ?? category['category_name'] ?? category['name'],
          fallback: 'Fee',
        );
        totals[name] =
            (totals[name] ?? 0) + ((item['amount'] as num?)?.toDouble() ?? 0);
      }
    }
    return totals.entries
        .map((entry) => {'name': entry.key, 'amount': entry.value})
        .toList();
  }

  Future<void> _openPaymentRequestForm({
    Map<String, dynamic>? singleFee,
  }) async {
    final pendingFees = singleFee != null
        ? [singleFee]
        : _feeStructure
              .where((f) => ((f['amount'] as num?)?.toDouble() ?? 0) > 0)
              .toList();
    if (pendingFees.isEmpty) return;
    final student = _childrenData.isEmpty
        ? null
        : Map<String, dynamic>.from(_childrenData[_activeChildIndex]);
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.parentPaymentSelection,
      arguments: ParentPaymentSelectionArgs(
        fees: pendingFees.map((fee) => Map<String, dynamic>.from(fee)).toList(),
        student: student,
      ),
    );
    if (!mounted) return;
    if (result != null) {
      await _loadData();
    }
  }

  String _studentName(Map<String, dynamic> student) {
    final name = '${student['name'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
    return '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
        .trim();
  }

  String _studentClass(Map<String, dynamic> student) =>
      '${student['class'] ?? student['class_name'] ?? student['current_section_id'] ?? ''}';

  String _studentRoll(Map<String, dynamic> student) =>
      '${student['rollNo'] ?? student['roll_no'] ?? student['student_code'] ?? ''}';

  String _installmentLabel(Map<String, dynamic> invoice) {
    final term = invoice['term'];
    String base = '';
    if (term is Map) {
      final termName = term['term_name'] ?? term['name'] ?? '';
      if (termName.toString().isNotEmpty) {
        base = termName.toString();
      }
    }
    if (base.isEmpty) {
      final dueDate = DateTime.tryParse('${invoice['due_date'] ?? ''}');
      final invoiceNumber = _text(invoice['invoice_number']);
      if (dueDate == null) {
        base = invoiceNumber.isEmpty
            ? 'Fee installment'
            : 'Invoice $invoiceNumber';
      } else {
        const months = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
        base = '${months[dueDate.month - 1]} ${dueDate.year}';
      }
    }
    // Append installment number if available (e.g., "1 of 3")
    final instNum = invoice['installment_number'];
    final instTotal = invoice['installment_count'] ?? invoice['total_installments'];
    if (instNum != null && instTotal != null) {
      return '$base ($instNum of $instTotal)';
    } else if (instNum != null) {
      return '$base (#$instNum)';
    }
    return base;
  }

  String _statusFromInvoice(String rawStatus, double balance, Object? dueDate) {
    if (rawStatus == 'paid' || balance <= 0) return 'Paid';
    final date = DateTime.tryParse('${dueDate ?? ''}');
    if (date != null && date.isBefore(DateTime.now())) return 'Due';
    return 'Upcoming';
  }

  List<Map<String, dynamic>> _invoiceItems(Map<String, dynamic> invoice) {
    final raw = invoice['items'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  String _nextDueDateLabel() {
    final dueRows = _feeStructure
        .where((row) => (row['amount'] as num?) != null)
        .where((row) => ((row['amount'] as num?)?.toDouble() ?? 0) > 0)
        .toList();
    dueRows.sort((a, b) => _text(a['dueDate']).compareTo(_text(b['dueDate'])));
    return dueRows.isEmpty ? 'the due date' : _text(dueRows.first['dueDate']);
  }

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';

  String _paymentStatusLabel(dynamic raw) {
    switch ('${raw ?? ''}'.toLowerCase()) {
      case 'approved':
        return 'Verified & Approved';
      case 'paid':
        return 'Paid';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      case 'submitted':
        return 'Pending Principal Approval';
      default:
        return 'Pending Verification';
    }
  }

  Future<void> _downloadReceipt(Map<String, dynamic> payment) async {
    try {
      final pdfService = PdfService.getInstance();
      final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
      final paymentDate = DateTime.tryParse(_text(payment['date']));
      if (paymentDate == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt date is not available from backend yet.'),
          ),
        );
        return;
      }
      final rawItems = payment['items'];
      final List<Map<String, dynamic>> feeItems = rawItems is List
          ? rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [
              {
                'description': payment['component'] ?? 'Fee',
                'amount': amount,
                'status': 'Paid',
              },
            ];

      final pdfBytes = await pdfService.generateFeeReceipt(
        receiptNo: _text(payment['receiptNo']),
        studentName: _text(payment['student']),
        className: _text(payment['class']),
        rollNo: _text(payment['rollNo']),
        parentName: _text(payment['parentName']),
        feeItems: feeItems,
        totalAmount: amount,
        paidAmount: amount,
        balance: 0,
        paymentMode: _text(payment['method']),
        paymentDate: paymentDate,
      );
      if (!mounted) return;
      await pdfService.previewDocument(
        context,
        pdfBytes,
        'Receipt ${_text(payment['receiptNo'], fallback: 'Preview')}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate receipt. Please try again.'),
          ),
        );
      }
    }
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}

class _FeeLoadingSkeleton extends StatelessWidget {
  const _FeeLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final shimmerBase = context.appTheme.surfaceVariant.withOpacity(0.4);
    final shimmerHighlight = context.appTheme.surfaceVariant.withOpacity(0.7);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card skeleton
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: shimmerBase,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: shimmerHighlight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 200,
                  height: 20,
                  decoration: BoxDecoration(
                    color: shimmerHighlight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 160,
                  height: 12,
                  decoration: BoxDecoration(
                    color: shimmerHighlight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Fee row skeletons
        for (var i = 0; i < 4; i++) ...[
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: shimmerBase,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: shimmerHighlight,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 12,
                        decoration: BoxDecoration(
                          color: shimmerHighlight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 90,
                        height: 10,
                        decoration: BoxDecoration(
                          color: shimmerHighlight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 14,
                  decoration: BoxDecoration(
                    color: shimmerHighlight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
