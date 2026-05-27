import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/parent_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../services/pdf_service.dart';
import '../../services/backend_api_client.dart';
import '../../routes/app_routes.dart';
import 'parent_payment_request_form_screen.dart';

class ParentFeesScreen extends StatefulWidget {
  const ParentFeesScreen({super.key});

  @override
  State<ParentFeesScreen> createState() => _ParentFeesScreenState();
}

class _ParentFeesScreenState extends State<ParentFeesScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 6;
  late TabController _tabController;
  int _activeChildIndex = 0;
  static const _headerColor = Color(0xFF1A6B4A);

  List<Map<String, dynamic>> _childrenData = [];

  List<Map<String, dynamic>> _feeStructure = [];
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _loading = true;
  String? _error;

  double get _totalAmount => _feeStructure.fold(
    0,
    (sum, f) => sum + ((f['totalAmount'] as num?)?.toDouble() ?? 0),
  );

  double get _paidAmount => _feeStructure.fold(
    0,
    (sum, f) => sum + ((f['paidAmount'] as num?)?.toDouble() ?? 0),
  );

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
      if (_activeChildIndex >= children.length) _activeChildIndex = 0;
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
      color: AppTheme.surface,
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
              _loadData();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? _headerColor : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _studentName(_childrenData[i]).split(' ').first,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppTheme.onSurface,
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(14),
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
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_circle_rounded,
              color: AppTheme.primary,
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
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
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
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_childrenData.length > 1)
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.muted,
            ),
        ],
      ),
    );
  }

  Widget _summaryAmountRow(String label, String amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
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
            style: GoogleFonts.dmSans(
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
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (_feeStructure.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: _emptyRow(
                Icons.receipt_long_rounded,
                'No fee invoices published yet.',
                AppTheme.muted,
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
                    'Pay Now — ${_money(_pendingAmount)}',
                    style: GoogleFonts.dmSans(
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
    final paid = _paidAmount;
    final total = _totalAmount;
    final pending = _pendingAmount;
    final hasInvoices = _feeStructure.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(
                        value: total > 0 ? paid / total : 0,
                        strokeWidth: 13,
                        backgroundColor: AppTheme.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primary,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          total > 0
                              ? '${((paid / total) * 100).toStringAsFixed(0)}%'
                              : '0%',
                          style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          'Paid',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fee Overview',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _summaryAmountRow(
                      'Total Fees',
                      hasInvoices ? _money(total) : '—',
                      AppTheme.primary,
                    ),
                    _summaryAmountRow(
                      'Paid Fees',
                      hasInvoices ? _money(paid) : '—',
                      AppTheme.success,
                    ),
                    _summaryAmountRow(
                      'Pending Fees',
                      hasInvoices ? _money(pending) : '—',
                      AppTheme.error,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (pending > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.error.withAlpha(18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_money(pending)} is due on ${_nextDueDateLabel()}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openPaymentRequestForm(),
                    child: const Text('Pay Now'),
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
    ].where((part) => part.isNotEmpty).join(' • ');
    final statusColor = isPaid
        ? AppTheme.success
        : isPending
        ? AppTheme.warning
        : AppTheme.muted;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending
              ? AppTheme.warning.withAlpha(80)
              : AppTheme.outlineVariant,
        ),
      ),
      child: Row(
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
                Text(
                  _text(fee['component'], fallback: 'Invoice'),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.muted,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money((fee['amount'] as num?)?.toDouble() ?? 0),
                style: GoogleFonts.dmSans(
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
                    'Pay Now',
                    style: GoogleFonts.dmSans(
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
                    style: GoogleFonts.dmSans(
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
    );
  }

  Widget _buildHistoryTab() {
    if (_paymentHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: AppTheme.muted,
            ),
            const SizedBox(height: 12),
            Text(
              'No payment history yet',
              style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.muted),
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
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isPaid
                      ? AppTheme.successContainer
                      : AppTheme.warningContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPaid
                      ? Icons.receipt_long_rounded
                      : Icons.pending_actions_rounded,
                  color: isPaid ? AppTheme.success : AppTheme.warning,
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
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppTheme.muted,
                        ),
                      ),
                    if (receiptNo.isNotEmpty)
                      Text(
                        'Receipt: $receiptNo',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppTheme.muted,
                        ),
                      ),
                    Text(
                      '${p['status']}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: isPaid ? AppTheme.success : AppTheme.warning,
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
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isPaid ? AppTheme.success : AppTheme.warning,
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
                            style: GoogleFonts.dmSans(
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
            style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.muted),
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
            color: AppTheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                className.isEmpty
                    ? 'Fee Types'
                    : 'Fee Types — Class $className',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Values are sourced from generated invoice items.',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppTheme.primary,
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
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                'Total Fee Types:',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _money(totalAnnual),
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_offer_outlined,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _text(row['name'], fallback: 'Fee type'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            _money((row['amount'] as num?)?.toDouble() ?? 0),
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
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
      AppRoutes.parentPaymentRequestForm,
      arguments: ParentPaymentRequestFormArgs(
        fees: pendingFees.map((fee) => Map<String, dynamic>.from(fee)).toList(),
        student: student,
      ),
    );
    if (!mounted) return;
    if (result is ParentPaymentRequestFormResult) {
      await _loadData();
      final reference = result.references.isEmpty
          ? ''
          : ': ${result.references.first}';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.submittedCount} payment request(s) submitted$reference',
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result == true) {
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
    final dueDate = DateTime.tryParse('${invoice['due_date'] ?? ''}');
    final invoiceNumber = _text(invoice['invoice_number']);
    if (dueDate == null) {
      return invoiceNumber.isEmpty
          ? 'Fee installment'
          : 'Invoice $invoiceNumber';
    }
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
    return '${months[dueDate.month - 1]} ${dueDate.year}';
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
      case 'paid':
        return 'Paid';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending verification';
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
