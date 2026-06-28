import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class FeePaymentReceiptScreen extends StatefulWidget {
  const FeePaymentReceiptScreen({super.key});

  @override
  State<FeePaymentReceiptScreen> createState() =>
      _FeePaymentReceiptScreenState();
}

class _FeePaymentReceiptScreenState extends State<FeePaymentReceiptScreen>
    with SingleTickerProviderStateMixin {
  static const Color _headerColor = Color(0xFF1A6B4A);

  late TabController _tabController;
  bool _loading = true;
  bool _processing = false;

  // Payment form
  final _amountCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedMethod = 'UPI';
  String _selectedFeeType = '';
  String _historyStatusFilter = 'all';
  int _activeChildIndex = 0;
  DateTimeRange? _historyDateRange;

  List<Map<String, dynamic>> _children = [];

  List<Map<String, dynamic>> _receipts = [];
  List<Map<String, dynamic>> _invoices = [];

  List<String> get _paymentMethods {
    if (_children.isEmpty) return const ['UPI', 'Cash', 'Bank Transfer'];
    final methods = <String>{'UPI', 'Cash', 'Bank Transfer'};
    for (final receipt in _receipts) {
      if ('${receipt['studentId'] ?? ''}' != _activeStudentId) continue;
      final mode = '${receipt['paymentMethod'] ?? ''}'.trim();
      if (mode.isNotEmpty) methods.add(mode);
    }
    return methods.toList();
  }

  List<String> get _feeTypes {
    final types = <String>{};
    for (final invoice in _activeInvoices) {
      final invoiceNumber = '${invoice['invoice_number'] ?? ''}'.trim();
      final termName = '${invoice['term_name'] ?? invoice['term'] ?? ''}'.trim();
      if (invoiceNumber.isNotEmpty) types.add(invoiceNumber);
      if (termName.isNotEmpty) types.add(termName);
    }
    return types.isEmpty ? const ['Fee Payment'] : types.toList();
  }

  List<int> get _amountSuggestions {
    final amounts = <int>{};
    for (final invoice in _activeInvoices) {
      final balance = (invoice['balance'] as num?)?.toInt() ??
          ((invoice['net_amount'] as num?)?.toInt() ?? 0) -
              ((invoice['paid_amount'] as num?)?.toInt() ?? 0);
      if (balance > 0) amounts.add(balance);
    }
    if (amounts.isEmpty) {
      final due = _activeDueAmount.toInt();
      if (due > 0) amounts.add(due);
    }
    return amounts.take(4).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final children = await BackendApiClient.instance.getMyStudents();
      final safeIndex =
          children.isEmpty
          ? 0
          : (_activeChildIndex >= children.length ? 0 : _activeChildIndex);
      final activeStudentId =
          children.isEmpty
          ? ''
          : '${children[safeIndex]['id'] ?? children[safeIndex]['student_id'] ?? ''}'
                .trim();
      final invoices = await BackendApiClient.instance.getInvoices();
      final paymentRequests = await BackendApiClient.instance
          .getParentPaymentRequests(
            studentId: activeStudentId.isEmpty ? null : activeStudentId,
          );
      final receipts = <Map<String, dynamic>>[];
      for (final invoice in invoices) {
        final payments = invoice['payments'];
        final student = invoice['student'] is Map
            ? Map<String, dynamic>.from(invoice['student'] as Map)
            : const <String, dynamic>{};
        final studentId =
            '${invoice['student_id'] ?? student['id'] ?? student['student_id'] ?? ''}';
        if (payments is List) {
          for (final rawPayment in payments.whereType<Map>()) {
            final payment = Map<String, dynamic>.from(rawPayment);
            final paidAt =
                DateTime.tryParse('${payment['payment_date'] ?? ''}') ??
                DateTime.now();
            receipts.add({
              'id': payment['id'] ?? invoice['id'],
              'receiptNo': payment['receipt_number'] ?? '',
              'studentId': studentId,
              'studentName':
                  '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
                      .trim(),
              'className': student['current_section_id'] ?? '',
              'rollNo': student['student_code'] ?? '',
              'feeType': invoice['invoice_number'] ?? 'Fee Payment',
              'amount': (payment['amount_paid'] as num?)?.toDouble() ?? 0.0,
              'paymentMethod': payment['payment_mode'] ?? '',
              'status': 'Paid',
              'date': paidAt.millisecondsSinceEpoch,
              'transactionId': payment['transaction_id'] ?? '',
            });
          }
        }
      }
      for (final request in paymentRequests) {
        final student = request['student'] is Map
            ? Map<String, dynamic>.from(request['student'] as Map)
            : const <String, dynamic>{};
        final invoice = request['invoice'] is Map
            ? Map<String, dynamic>.from(request['invoice'] as Map)
            : const <String, dynamic>{};
        final requestedAt =
            DateTime.tryParse('${request['payment_date'] ?? ''}') ??
            DateTime.tryParse('${request['created_at'] ?? ''}') ??
            DateTime.now();
        receipts.add({
          'id': request['id'] ?? invoice['id'],
          'receiptNo': request['request_reference'] ?? '',
          'studentId':
              '${request['student_id'] ?? student['id'] ?? student['student_id'] ?? ''}',
          'studentName':
              '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
                  .trim(),
          'className': student['current_section_id'] ?? '',
          'rollNo': student['student_code'] ?? '',
          'feeType': invoice['invoice_number'] ?? 'Fee Payment Request',
          'amount': (request['amount'] as num?)?.toDouble() ?? 0.0,
          'paymentMethod': request['payment_mode'] ?? '',
          'status': _paymentStatusLabel(request['status']),
          'date': requestedAt.millisecondsSinceEpoch,
          'transactionId': request['transaction_id'] ?? '',
        });
      }
      if (!mounted) return;
      setState(() {
        _children = children;
        if (_activeChildIndex >= _children.length) _activeChildIndex = 0;
        _invoices = invoices;
        _receipts = receipts;
        if (_feeTypes.isNotEmpty && !_feeTypes.contains(_selectedFeeType)) {
          _selectedFeeType = _feeTypes.first;
        }
        if (_paymentMethods.isNotEmpty &&
            !_paymentMethods.contains(_selectedMethod)) {
          _selectedMethod = _paymentMethods.first;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _receipts = [];
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_children.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No linked students. Ask the school admin to link students to this parent account.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(context, bottom: _buildPaymentTabs(context)),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          _buildChildSelector(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildPaymentTab(), _buildReceiptHistoryTab()],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context, {
    PreferredSizeWidget? bottom,
  }) {
    return AppBar(
      backgroundColor: _headerColor,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.maybePop(context),
      ),
      titleSpacing: 0,
      title: Text(
        'Fee Payment & Receipts',
        style: GoogleFonts.dmSans(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      bottom: bottom,
    );
  }

  PreferredSizeWidget _buildPaymentTabs(BuildContext context) {
    return TabBar(
      controller: _tabController,
      indicatorColor: context.appTheme.surface,
      labelColor: context.appTheme.surface,
      unselectedLabelColor: context.appTheme.surface60,
      labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
      tabs: const [
        Tab(text: 'Make Payment'),
        Tab(text: 'Receipt History'),
      ],
    );
  }

  Widget _buildChildSelector() {
    return Container(
      color: _headerColor.withAlpha(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: _children.asMap().entries.map((e) {
          final isActive = e.key == _activeChildIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _activeChildIndex = e.key;
                if (_feeTypes.isNotEmpty && !_feeTypes.contains(_selectedFeeType)) {
                  _selectedFeeType = _feeTypes.first;
                }
                if (_paymentMethods.isNotEmpty &&
                    !_paymentMethods.contains(_selectedMethod)) {
                  _selectedMethod = _paymentMethods.first;
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: e.key == 0 ? 8 : 0),
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: isActive ? _headerColor : context.appTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? _headerColor : context.appTheme.muted,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isActive
                          ? context.appTheme.surface.withAlpha(50)
                          : _headerColor.withAlpha(30),
                      child: Text(
                        _studentName(e.value).isEmpty
                            ? '?'
                            : _studentName(e.value).substring(0, 1),
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : _headerColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _studentName(e.value),
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Class ${_studentClass(e.value)}',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: isActive
                                  ? Colors.white70
                                  : context.appTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentTab() {
    final child = _children[_activeChildIndex];
    final dueAmount = _activeDueAmount;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appTheme.muted),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _headerColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _studentName(child).isEmpty
                            ? '?'
                            : _studentName(child).substring(0, 1),
                        style: GoogleFonts.dmSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _headerColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _studentName(child),
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                        Text(
                          'Class ${_studentClass(child)} · Roll No. ${_studentRoll(child)}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: context.appTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dueAmount > 0
                          ? '₹${_formatAmount(dueAmount)} Due'
                          : 'No Due',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD4850A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Payment Details',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),

            // Fee type selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appTheme.muted),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fee Type',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.appTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _feeTypes.map((type) {
                      final isSelected = _selectedFeeType == type;
                      final chipBackground = isSelected
                          ? _headerColor
                          : const Color(0xFFF1F5F3);
                      final chipBorderColor = isSelected
                          ? _headerColor
                          : const Color(0xFFC9D7D0);
                      final chipTextColor = isSelected
                          ? Colors.white
                          : const Color(0xFF23352E);
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => setState(() => _selectedFeeType = type),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            constraints: const BoxConstraints(minHeight: 42),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: chipBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: chipBorderColor),
                            ),
                            child: Text(
                              type,
                              maxLines: 2,
                              overflow: TextOverflow.visible,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: chipTextColor,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Amount entry
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appTheme.muted),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount (₹)',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.appTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: GoogleFonts.dmSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _headerColor,
                      ),
                      hintText: '0.00',
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: 22,
                        color: context.appTheme.muted,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: context.appTheme.muted),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _headerColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter an amount';
                      }
                      final amt = double.tryParse(v);
                      if (amt == null || amt <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _amountSuggestions.map((amt) {
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _amountCtrl.text = amt.toString()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _headerColor.withAlpha(15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _headerColor.withAlpha(60),
                            ),
                          ),
                          child: Text(
                            '₹${_formatAmount(amt.toDouble())}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _headerColor,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Payment method
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appTheme.muted),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Method',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.appTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._paymentMethods.map((method) {
                    final isSelected = _selectedMethod == method;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedMethod = method),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _headerColor.withAlpha(15)
                              : context.appTheme.muted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? _headerColor
                                : context.appTheme.muted,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _methodIcon(method),
                              size: 20,
                              color: isSelected
                                  ? _headerColor
                                  : context.appTheme.muted,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              method,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? _headerColor
                                    : const Color(0xFF1A1A2E),
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: _headerColor,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _processing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _headerColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _processing
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.appTheme.surface,
                        ),
                      )
                    : Text(
                        'Pay Now & Generate Receipt',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptHistoryTab() {
    final childId = _activeStudentId;
    final filtered = _receipts.where((receipt) {
      if ('${receipt['studentId'] ?? ''}' != childId) return false;
      if (_historyStatusFilter != 'all' &&
          '${receipt['status'] ?? ''}'.toLowerCase() != _historyStatusFilter) {
        return false;
      }
      if (_historyDateRange != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(receipt['date'] as int);
        final start = DateTime(
          _historyDateRange!.start.year,
          _historyDateRange!.start.month,
          _historyDateRange!.start.day,
        );
        final end = DateTime(
          _historyDateRange!.end.year,
          _historyDateRange!.end.month,
          _historyDateRange!.end.day,
          23,
          59,
          59,
        );
        if (date.isBefore(start) || date.isAfter(end)) return false;
      }
      return true;
    }).toList()..sort((a, b) => (b['date'] as int).compareTo(a['date'] as int));

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: context.appTheme.muted,
            ),
            const SizedBox(height: 12),
            Text(
              'No receipts yet',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: context.appTheme.muted,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildHistoryFilters(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _buildReceiptCard(filtered[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      color: const Color(0xFFF5F6FA),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _historyStatusFilter,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) => setState(
                () => _historyStatusFilter = (value ?? 'all').toLowerCase(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _pickHistoryDateRange,
            icon: const Icon(Icons.date_range_rounded, size: 18),
            label: Text(
              _historyDateRange == null
                  ? 'Date range'
                  : '${_historyDateRange!.start.day}/${_historyDateRange!.start.month} - ${_historyDateRange!.end.day}/${_historyDateRange!.end.month}',
            ),
          ),
          if (_historyDateRange != null)
            IconButton(
              tooltip: 'Clear date filter',
              onPressed: () => setState(() => _historyDateRange = null),
              icon: const Icon(Icons.clear_rounded),
            ),
        ],
      ),
    );
  }

  Future<void> _pickHistoryDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _historyDateRange,
      saveText: 'Apply',
    );
    if (picked == null || !mounted) return;
    setState(() => _historyDateRange = picked);
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt) {
    final date = DateTime.fromMillisecondsSinceEpoch(receipt['date'] as int);
    final status = receipt['status'] as String;
    final isPaid = status == 'Paid';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appTheme.muted),
        boxShadow: [
          BoxShadow(
            color: context.appTheme.onSurface.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPaid
                      ? const Color(0xFF1A6B4A).withAlpha(20)
                      : const Color(0xFFD4850A).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPaid
                      ? Icons.receipt_rounded
                      : Icons.pending_actions_rounded,
                  color: isPaid
                      ? const Color(0xFF1A6B4A)
                      : const Color(0xFFD4850A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt['feeType'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      '${receipt['receiptNo']} · ${_formatDate(date)}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: context.appTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${_formatAmount((receipt['amount'] as num).toDouble())}',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? const Color(0xFF1A6B4A).withAlpha(20)
                          : const Color(0xFFD4850A).withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isPaid
                            ? const Color(0xFF1A6B4A)
                            : const Color(0xFFD4850A),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.payment_rounded,
                size: 14,
                color: context.appTheme.muted,
              ),
              const SizedBox(width: 6),
              Text(
                receipt['paymentMethod'] as String,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: context.appTheme.muted,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.tag_rounded, size: 14, color: context.appTheme.muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  receipt['transactionId'] as String? ?? '—',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: context.appTheme.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isPaid)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => _downloadReceipt(receipt),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: Text(
                        'PDF',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: _headerColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Share receipt',
                      onPressed: () => _shareReceipt(receipt),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      color: _headerColor,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _processing = true);

    final child = _children[_activeChildIndex];
    final amount = double.parse(_amountCtrl.text.trim());
    final now = DateTime.now();
    final receiptNo =
        'RCP-${now.year}-${now.month.toString().padLeft(2, '0')}-${(_receipts.length + 1).toString().padLeft(3, '0')}';
    final txnId =
        '${_selectedMethod.replaceAll(' ', '').toUpperCase()}${now.millisecondsSinceEpoch}';

    final invoice = _activePayableInvoice;
    if (invoice == null) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payable invoice found from backend')),
      );
      return;
    }

    var newReceipt = {
      'id': invoice['id'],
      'receiptNo': receiptNo,
      'studentId': _activeStudentId,
      'studentName': _studentName(child),
      'className': _studentClass(child),
      'rollNo': _studentRoll(child),
      'feeType': invoice['invoice_number'] ?? _selectedFeeType,
      'amount': amount,
      'paymentMethod': _selectedMethod,
      'status': 'Pending verification',
      'date': now.millisecondsSinceEpoch,
      'transactionId': txnId,
    };

    try {
      final request = await BackendApiClient.instance
          .submitParentPaymentRequest(
            PaymentRequest(
              invoiceId: '${invoice['id']}',
              receiptNumber: receiptNo,
              amountPaid: amount,
              paymentDate: now.toIso8601String().split('T').first,
              paymentMode: _selectedMethod.toLowerCase(),
              transactionId: txnId,
            ),
          );
      final backendReference =
          '${request['request_reference'] ?? request['receipt_number'] ?? ''}'
              .trim();
      final backendTransaction =
          '${request['transaction_id'] ?? request['txn_id'] ?? ''}'.trim();
      final backendMode =
          '${request['payment_mode'] ?? request['mode'] ?? ''}'.trim();
      newReceipt = {
        ...newReceipt,
        'id': request['id'] ?? newReceipt['id'],
        'receiptNo':
            backendReference.isNotEmpty
            ? backendReference
            : newReceipt['receiptNo'],
        'paymentMethod':
            backendMode.isNotEmpty ? backendMode : newReceipt['paymentMethod'],
        'transactionId':
            backendTransaction.isNotEmpty
            ? backendTransaction
            : newReceipt['transactionId'],
        'status': _paymentStatusLabel(request['status']),
      };
      await _loadData();
      if (!mounted) return;
      setState(() {
        _processing = false;
        _amountCtrl.clear();
      });
      _showSuccessDialog(newReceipt);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  String _studentName(Map<String, dynamic> student) {
    final explicitName = '${student['name'] ?? ''}'.trim();
    if (explicitName.isNotEmpty) return explicitName;
    return '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
        .trim();
  }

  String _studentClass(Map<String, dynamic> student) =>
      '${student['class'] ?? student['class_name'] ?? student['current_section_id'] ?? ''}';

  String _studentRoll(Map<String, dynamic> student) =>
      '${student['rollNo'] ?? student['roll_no'] ?? student['student_code'] ?? ''}';

  String _studentId(Map<String, dynamic> student) =>
      '${student['id'] ?? student['student_id'] ?? ''}'.trim();

  String get _activeStudentId {
    if (_children.isEmpty) return '';
    final index = _activeChildIndex >= _children.length ? 0 : _activeChildIndex;
    return _studentId(_children[index]);
  }

  List<Map<String, dynamic>> get _activeInvoices => _invoices.where((invoice) {
    final invoiceStudent = invoice['student'] is Map
        ? Map<String, dynamic>.from(invoice['student'] as Map)
        : const <String, dynamic>{};
    final invoiceStudentId =
        '${invoice['student_id'] ?? invoiceStudent['id'] ?? ''}';
    return invoiceStudentId == _activeStudentId;
  }).toList();

  Map<String, dynamic>? get _activePayableInvoice {
    final payable = _activeInvoices.where((invoice) {
      final balance =
          (invoice['balance'] as num?) ?? (invoice['net_amount'] as num?) ?? 0;
      final status = '${invoice['status'] ?? ''}'.toLowerCase();
      return balance > 0 || status == 'pending' || status == 'overdue';
    }).toList();
    return payable.isEmpty ? null : payable.first;
  }

  double get _activeDueAmount {
    return _activeInvoices.fold<double>(0, (sum, invoice) {
      final balance = (invoice['balance'] as num?)?.toDouble();
      if (balance != null) return sum + balance;
      final net = (invoice['net_amount'] as num?)?.toDouble() ?? 0;
      final paid = (invoice['paid_amount'] as num?)?.toDouble() ?? 0;
      return sum + (net - paid);
    });
  }

  void _showSuccessDialog(Map<String, dynamic> receipt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1A6B4A).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF1A6B4A),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Request Submitted',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${_formatAmount((receipt['amount'] as num).toDouble())} submitted via ${receipt['paymentMethod']} for school verification',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: context.appTheme.muted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Reference: ${receipt['receiptNo']}',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A6B4A),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _tabController.animateTo(1);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.appTheme.muted),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'View History',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _headerColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadReceipt(Map<String, dynamic> receipt) async {
    try {
      final pdfBytes = await _buildReceiptPdf(receipt);
      if (pdfBytes == null || !mounted) return;
      await PdfService.getInstance().previewDocument(
        context,
        pdfBytes,
        'Fee receipt ${receipt['receiptNo']}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not generate PDF: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _shareReceipt(Map<String, dynamic> receipt) async {
    try {
      final pdfBytes = await _buildReceiptPdf(receipt);
      if (pdfBytes == null || !mounted) return;
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'fee_receipt_${receipt['receiptNo']}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share receipt: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<Uint8List?> _buildReceiptPdf(Map<String, dynamic> receipt) async {
    if (receipt['status'] != 'Paid') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt PDF is available after school approval.'),
          ),
        );
      }
      return null;
    }
    final pdfService = PdfService.getInstance();
    final amount = (receipt['amount'] as num).toDouble();
    final date = DateTime.fromMillisecondsSinceEpoch(receipt['date'] as int);
    return pdfService.generateFeeReceipt(
      receiptNo: receipt['receiptNo'] as String,
      studentName: receipt['studentName'] as String,
      className: receipt['className'] as String,
      rollNo: receipt['rollNo'] as String,
      parentName: receipt['parentName'] as String? ?? '',
      feeItems: [
        {
          'description': receipt['feeType'] as String,
          'amount': amount,
          'status': receipt['status'] as String,
        },
      ],
      totalAmount: amount,
      paidAmount: amount,
      balance: 0,
      paymentMode: receipt['paymentMethod'] as String,
      paymentDate: date,
    );
  }

  IconData _methodIcon(String method) {
    switch (method) {
      case 'UPI':
        return Icons.qr_code_rounded;
      case 'Net Banking':
        return Icons.account_balance_rounded;
      case 'Credit Card':
        return Icons.credit_card_rounded;
      case 'Debit Card':
        return Icons.credit_card_outlined;
      case 'Cash':
        return Icons.money_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  String _formatAmount(double amount) {
    final str = amount.toStringAsFixed(0);
    final result = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) result.write(',');
      result.write(str[i]);
      count++;
    }
    return result.toString().split('').reversed.join();
  }

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

  String _formatDate(DateTime dt) {
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
