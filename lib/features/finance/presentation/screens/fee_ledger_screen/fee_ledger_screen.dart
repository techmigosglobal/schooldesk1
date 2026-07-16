/// Fee Ledger & Dues — merged view showing student accounts and outstanding balances.
library;

import 'package:flutter/material.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_widgets.dart';

class FeeLedgerScreen extends StatefulWidget {
  const FeeLedgerScreen({super.key});

  @override
  State<FeeLedgerScreen> createState() => _FeeLedgerScreenState();
}

class _FeeLedgerScreenState extends State<FeeLedgerScreen> {
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'all'; // all, unpaid, partial, paid

  List<Map<String, dynamic>> _invoices = const [];
  List<Map<String, dynamic>> _payments = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final raw = await api.getInvoices(pageSize: 500);
      if (!mounted) return;
      final invoices = raw.map(normalizeInvoice).toList();
      final allPayments = invoices.expand(normalizePayments).toList()
        ..sort((a, b) => _sortDate(b['date']).compareTo(_sortDate(a['date'])));
      setState(() {
        _invoices = invoices;
        _payments = allPayments;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // ── Student accounts ──────────────────────────────────────────────────────

  List<_StudentAccount> get _accounts {
    final map = <String, _StudentAccount>{};
    for (final inv in _invoices) {
      final sid = textValue(inv['student_id']);
      if (sid.isEmpty) continue;
      final total = numValue(inv['total']);
      final paid = numValue(inv['paid']);
      final balance = numValue(inv['balance']);
      final existing = map[sid];
      if (existing == null) {
        map[sid] = _StudentAccount(
          studentId: sid,
          name: textValue(inv['name'], fallback: 'Student'),
          classLabel: textValue(inv['class']),
          total: total,
          paid: paid,
          balance: balance,
          invoices: [inv],
          payments: _payments.where((p) => p['student_id'] == sid).toList(),
        );
      } else {
        map[sid] = existing.copyWith(
          total: existing.total + total,
          paid: existing.paid + paid,
          balance: existing.balance + balance,
          invoices: [...existing.invoices, inv],
        );
      }
    }
    return map.values.toList()..sort((a, b) => b.balance.compareTo(a.balance));
  }

  List<_StudentAccount> get _filtered {
    var list = _accounts;
    if (_filter == 'unpaid') {
      list = list.where((a) => a.balance > 0 && a.paid == 0).toList();
    }
    if (_filter == 'partial') {
      list = list.where((a) => a.balance > 0 && a.paid > 0).toList();
    }
    if (_filter == 'paid') list = list.where((a) => a.balance <= 0).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((a) => '${a.name} ${a.classLabel}'.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  double get _totalDue => _accounts.fold(0, (s, a) => s + a.balance);
  double get _totalCollected => _accounts.fold(0.0, (s, a) => s + a.paid);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      appBar: AppBar(
        title: const Text(
          'Student Ledger & Dues',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFFF7FAFF),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? FeeEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Error',
              message: _error!,
              actionLabel: 'Retry',
              onAction: _loadData,
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // Metrics
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.22,
                    children: [
                      FeeMetricTile(
                        label: 'Outstanding',
                        value: money(_totalDue),
                        icon: Icons.pending_actions_outlined,
                        color: const Color(0xFFEA580C),
                      ),
                      FeeMetricTile(
                        label: 'Collected',
                        value: money(_totalCollected),
                        icon: Icons.check_circle_outline,
                        color: const Color(0xFF16A34A),
                      ),
                      FeeMetricTile(
                        label: 'Students',
                        value: '${_accounts.length}',
                        icon: Icons.groups_outlined,
                        color: const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search
                  FeeSearchBox(
                    controller: _searchCtrl..text = _query,
                    hint: 'Search student',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 10),

                  // Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in [
                          ('all', 'All'),
                          ('unpaid', 'Unpaid'),
                          ('partial', 'Partial'),
                          ('paid', 'Paid'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(
                                f.$1[0].toUpperCase() + f.$1.substring(1),
                              ),
                              selected: _filter == f.$1,
                              onSelected: (_) => setState(() => _filter = f.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Student list
                  if (_filtered.isEmpty)
                    const FeeEmptyState(
                      icon: Icons.groups_outlined,
                      title: 'No students',
                      message: 'Generate invoices before viewing the ledger.',
                    ),

                  for (final account in _filtered)
                    FeeCard(
                      onTap: () => _showLedgerSheet(account),
                      child: Row(
                        children: [
                          FeeIconBadge(
                            icon: account.balance <= 0
                                ? Icons.check_circle_outline
                                : Icons.account_balance_wallet_outlined,
                            color: account.balance <= 0
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFEA580C),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  account.classLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
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
                                money(account.balance),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: account.balance > 0
                                      ? context.appTheme.error
                                      : context.appTheme.success,
                                ),
                              ),
                              FeeStatusPill(
                                label: account.balance <= 0
                                    ? 'Paid'
                                    : account.paid > 0
                                    ? 'Partial'
                                    : 'Due',
                                color: account.balance <= 0
                                    ? const Color(0xFF16A34A)
                                    : account.paid > 0
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFFEF4444),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // ── Ledger detail sheet ───────────────────────────────────────────────────

  void _showLedgerSheet(_StudentAccount account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Text(
              '${account.name} — ${account.classLabel}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            // Summary
            FeeCard(
              child: Column(
                children: [
                  FeeAmountRow(
                    label: 'Total Fees',
                    value: money(account.total),
                  ),
                  FeeAmountRow(label: 'Paid', value: money(account.paid)),
                  FeeAmountRow(
                    label: 'Balance',
                    value: money(account.balance),
                    danger: account.balance > 0,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Invoices
            const FeeSectionTitle('Invoices'),
            const SizedBox(height: 8),
            if (account.invoices.isEmpty)
              const Text(
                'No invoices found.',
                style: TextStyle(color: Colors.grey),
              ),
            for (final inv in account.invoices)
              FeeCard(
                child: Row(
                  children: [
                    const FeeIconBadge(
                      icon: Icons.receipt_outlined,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            textValue(
                              inv['invoice_number'],
                              fallback: 'Invoice',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            displayDate(inv['due_date']),
                            style: TextStyle(
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
                          money(numValue(inv['total'])),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        if (numValue(inv['balance']) > 0)
                          Text(
                            'Due: ${money(numValue(inv['balance']))}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.appTheme.error,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            // Payment history
            const FeeSectionTitle('Payment History'),
            const SizedBox(height: 8),
            if (account.payments.isEmpty)
              const Text(
                'No payments recorded.',
                style: TextStyle(color: Colors.grey),
              ),
            for (final p in account.payments)
              FeeCard(
                child: Row(
                  children: [
                    const FeeIconBadge(
                      icon: Icons.payments_outlined,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            textValue(p['mode'], fallback: 'Payment'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            displayDate(p['date']),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.appTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      money(numValue(p['amount'])),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // PDF
            if (account.invoices.isNotEmpty)
              FilledButton.icon(
                onPressed: () => _previewPdf(account),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Export Invoice PDF'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _previewPdf(_StudentAccount account) async {
    try {
      final pdfService = PdfService.getInstance();
      final items = account.invoices
          .map(
            (inv) => <String, dynamic>{
              'description': textValue(inv['invoice_number'], fallback: 'Fee'),
              'amount': numValue(inv['total']),
              'status': numValue(inv['balance']) > 0 ? 'Due' : 'Paid',
            },
          )
          .toList();
      final bytes = await pdfService.generateFeeReceipt(
        receiptNo: 'LEDGER-${DateTime.now().millisecondsSinceEpoch}',
        studentName: account.name,
        className: account.classLabel,
        rollNo: account.studentId,
        parentName: '',
        feeItems: items,
        totalAmount: account.total,
        paidAmount: account.paid,
        balance: account.balance,
        paymentMode: 'Ledger',
        paymentDate: DateTime.now(),
      );
      if (!mounted) return;
      await pdfService.previewDocument(context, bytes, 'Student Fee Ledger');
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF error: $e')));
    }
  }

  DateTime _sortDate(Object? v) => DateTime.tryParse('$v') ?? DateTime(2000);
}

class _StudentAccount {
  final String studentId, name, classLabel;
  final double total, paid, balance;
  final List<Map<String, dynamic>> invoices, payments;
  const _StudentAccount({
    required this.studentId,
    required this.name,
    required this.classLabel,
    required this.total,
    required this.paid,
    required this.balance,
    required this.invoices,
    required this.payments,
  });
  _StudentAccount copyWith({
    double? total,
    double? paid,
    double? balance,
    List<Map<String, dynamic>>? invoices,
  }) => _StudentAccount(
    studentId: studentId,
    name: name,
    classLabel: classLabel,
    total: total ?? this.total,
    paid: paid ?? this.paid,
    balance: balance ?? this.balance,
    invoices: invoices ?? this.invoices,
    payments: payments,
  );
}
