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

  int get _totalPending => _feeStructure
      .where((f) => f['status'] == 'Pending')
      .fold(0, (sum, f) => sum + ((f['amount'] as num?)?.toInt() ?? 0));

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
          // Backend integration: invoice/payment values are rendered only from
          // the fee APIs. Missing payment metadata remains empty in the UI.
          return {
            'id': inv['id'],
            'invoiceNumber': inv['invoice_number'] ?? '',
            'component': 'Invoice ${inv['invoice_number'] ?? ''}',
            'frequency': 'Invoice',
            'amount': (inv['balance'] as num?)?.toDouble() ?? 0,
            'paidAmount': (inv['paid_amount'] as num?)?.toDouble() ?? 0,
            'totalAmount':
                (inv['net_amount'] as num?)?.toDouble() ??
                (inv['total_amount'] as num?)?.toDouble() ??
                0,
            'dueDate': (inv['due_date'] ?? '').toString(),
            'status': status == 'paid' ? 'Paid' : 'Pending',
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
        title: 'Fees',
        subtitle: 'Review dues, payment history, and fee structure',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _childrenData.isEmpty) {
      return SchoolDeskModuleScaffold(
        title: 'Fees',
        subtitle: 'Review dues, payment history, and fee structure',
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
      title: 'Fees',
      subtitle: 'Review dues, payment history, and fee structure',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Due Fees'),
          Tab(text: 'History'),
          Tab(text: 'Structure'),
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

  Widget _buildDueFeesTab() {
    final pending = _feeStructure
        .where((f) => f['status'] == 'Pending')
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDueSummaryCard(),
          const SizedBox(height: 16),
          Text(
            'Pending Payments',
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
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: AppTheme.muted,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No fee invoices published yet.',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (pending.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.successContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.success,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No pending fees in published invoices.',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ...pending.map((f) => _feeItemCard(f, true)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openPaymentRequestForm(),
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: Text(
                  'Pay All Pending — ₹$_totalPending',
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
      ),
    );
  }

  Widget _buildDueSummaryCard() {
    final paid = _feeStructure
        .where((f) => f['status'] == 'Paid')
        .fold(0, (sum, f) => sum + ((f['amount'] as num?)?.toInt() ?? 0));
    final total = _feeStructure.fold(
      0,
      (sum, f) => sum + ((f['amount'] as num?)?.toInt() ?? 0),
    );
    final hasInvoices = _feeStructure.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4850A), Color(0xFFE67E22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Pending',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      hasInvoices ? '₹$_totalPending' : '—',
                      style: GoogleFonts.dmSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      hasInvoices
                          ? 'Live invoice status from backend'
                          : 'Published invoice balances will appear here',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? paid / total : 0,
              backgroundColor: Colors.white30,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasInvoices ? '₹$paid of ₹$total paid' : 'No invoices published',
            style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _feeItemCard(Map<String, dynamic> fee, bool showPayBtn) {
    final isPending = fee['status'] == 'Pending';
    final meta = <String>[
      _text(fee['frequency']),
      if (_text(fee['dueDate']).isNotEmpty) 'Due: ${_text(fee['dueDate'])}',
    ].where((part) => part.isNotEmpty).join(' • ');
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
              color: isPending
                  ? AppTheme.warning.withAlpha(20)
                  : AppTheme.successContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPending
                  ? Icons.pending_actions_rounded
                  : Icons.check_circle_rounded,
              color: isPending ? AppTheme.warning : AppTheme.success,
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
                '₹${fee['amount']}',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isPending ? AppTheme.warning : AppTheme.success,
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
                    color: AppTheme.successContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Paid',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success,
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
    final totalAnnual = _feeStructure.fold(
      0,
      (sum, f) => sum + ((f['amount'] as num?)?.toInt() ?? 0),
    );
    final child = _childrenData[_activeChildIndex];
    final className = _studentClass(child);
    if (_feeStructure.isEmpty) {
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
                    ? 'Fee Structure'
                    : 'Fee Structure — Class $className',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Values sourced from generated invoices and balances.',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ..._feeStructure.map((f) => _feeItemCard(f, false)),
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
                'Total Annual Fee:',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '₹$totalAnnual',
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

  Future<void> _openPaymentRequestForm({
    Map<String, dynamic>? singleFee,
  }) async {
    final pendingFees = singleFee != null
        ? [singleFee]
        : _feeStructure.where((f) => f['status'] == 'Pending').toList();
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
