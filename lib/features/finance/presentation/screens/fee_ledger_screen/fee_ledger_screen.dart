/// Fee Ledger & Dues — merged view showing student accounts and outstanding balances.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                  _LedgerSummary(
                    outstanding: _totalDue,
                    collected: _totalCollected,
                    students: _accounts.length,
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
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _filter == f.$1
                                      ? context.appTheme.onPrimary
                                      : context.appTheme.onSurface,
                                ),
                              ),
                              selected: _filter == f.$1,
                              selectedColor: context.appTheme.primary,
                              checkmarkColor: context.appTheme.onPrimary,
                              side: BorderSide(
                                color: _filter == f.$1
                                    ? context.appTheme.primary
                                    : context.appTheme.outlineVariant,
                              ),
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
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: context.appTheme.muted,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                                  inv['fee_item_name'],
                                  fallback: 'Fee invoice',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Due ${displayDate(inv['due_date'])}',
                                style: TextStyle(
                                  fontSize: 12,
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
                              money(numValue(inv['total'])),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            if (numValue(inv['balance']) > 0)
                              Text(
                                'Due ${money(numValue(inv['balance']))}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: context.appTheme.error,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      textValue(inv['invoice_number'], fallback: 'Invoice'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _previewInvoice(account, inv),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Invoice PDF'),
                        ),
                        if (numValue(inv['balance']) > 0)
                          FilledButton.icon(
                            onPressed: () => _recordPayment(account, inv),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Record payment'),
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
                    if (_isFinalizedPayment(p) &&
                        textValue(p['receipt']).isNotEmpty)
                      IconButton(
                        tooltip: 'Receipt PDF',
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        onPressed: () => _previewReceipt(account, p),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // Print from the single student-ledger workspace.
            if (account.invoices.isNotEmpty)
              FilledButton.icon(
                onPressed: () => _previewPdf(account),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Print account statement'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordPayment(
    _StudentAccount account,
    Map<String, dynamic> invoice,
  ) async {
    final draft = await showDialog<_LedgerPaymentDraft>(
      context: context,
      builder: (dialogContext) => _LedgerPaymentDialog(
        invoiceLabel: textValue(invoice['fee_item_name'], fallback: 'Fee'),
        balance: numValue(invoice['balance']),
      ),
    );
    if (draft == null) return;
    try {
      final result = await BackendApiClient.instance
          .createRaw('/fees/payments', {
            'invoice_id': invoice['id'],
            'amount': draft.amount,
            'payment_method': draft.method,
            'payment_date': _dateIso(draft.date),
            if (draft.reference.isNotEmpty) 'reference_number': draft.reference,
            if (draft.notes.isNotEmpty) 'remarks': draft.notes,
          });
      if (!mounted) return;
      Navigator.of(context).pop();
      await _loadData();
      if (!mounted) return;
      final receiptNumber = textValue(result['receipt_number']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            receiptNumber.isEmpty
                ? 'Payment recorded for ${account.name}.'
                : 'Payment recorded. Receipt $receiptNumber is ready.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to record payment: $error'),
          backgroundColor: context.appTheme.error,
        ),
      );
    }
  }

  String _dateIso(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
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
        documentKind: FeeDocumentKind.accountStatement,
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

  Future<void> _previewInvoice(
    _StudentAccount account,
    Map<String, dynamic> invoice,
  ) async {
    try {
      final pdfService = PdfService.getInstance();
      final total = numValue(invoice['total']);
      final paid = numValue(invoice['paid']);
      final balance = numValue(invoice['balance']);
      final bytes = await pdfService.generateFeeReceipt(
        documentKind: FeeDocumentKind.feeInvoice,
        receiptNo: textValue(invoice['invoice_number'], fallback: 'Invoice'),
        studentName: account.name,
        className: account.classLabel,
        rollNo: account.studentId,
        parentName: '',
        feeItems: [
          {
            'description': textValue(invoice['fee_item_name'], fallback: 'Fee'),
            'amount': total,
            'status': balance > 0 ? 'Due' : 'Paid',
          },
        ],
        totalAmount: total,
        paidAmount: paid,
        balance: balance,
        paymentMode: '',
        paymentDate: DateTime.now(),
      );
      if (!mounted) return;
      await pdfService.previewDocument(
        context,
        bytes,
        '${textValue(invoice['invoice_number'], fallback: 'Fee')} — Invoice',
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invoice PDF error: $e')));
    }
  }

  Future<void> _previewReceipt(
    _StudentAccount account,
    Map<String, dynamic> payment,
  ) async {
    try {
      final pdfService = PdfService.getInstance();
      final snapshot = payment['receipt_snapshot'] is Map
          ? Map<String, dynamic>.from(payment['receipt_snapshot'] as Map)
          : const <String, dynamic>{};
      final totals = snapshot['source_totals'] is Map
          ? Map<String, dynamic>.from(snapshot['source_totals'] as Map)
          : const <String, dynamic>{};
      final source = snapshot['source_snapshot'] is Map
          ? Map<String, dynamic>.from(snapshot['source_snapshot'] as Map)
          : const <String, dynamic>{};
      final invoice = _invoices.firstWhere(
        (row) => textValue(row['id']) == textValue(payment['invoice_id']),
        orElse: () => const <String, dynamic>{},
      );
      final paid = numValue(totals['this_payment_amount'] ?? payment['amount']);
      final receiptNumber = textValue(payment['receipt']);
      if (receiptNumber.isEmpty) {
        throw StateError('The finalized payment does not have a receipt yet.');
      }
      final rawItems = source['fee_items'] is List
          ? (source['fee_items'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : const <Map<String, dynamic>>[];
      final school = await BackendApiClient.instance.getCurrentSchool();
      final assets = await Future.wait([
        _networkImageBytes(textValue(school['logo_url'])),
        _networkImageBytes(textValue(school['authorized_signature_url'])),
      ]);
      final bytes = await pdfService.generateFeeReceipt(
        documentKind: FeeDocumentKind.paymentReceipt,
        receiptNo: receiptNumber,
        studentName: account.name,
        className: account.classLabel,
        rollNo: account.studentId,
        parentName: '',
        feeItems: rawItems.isEmpty
            ? [
                {
                  'description': textValue(
                    source['invoice_number'] ?? invoice['fee_item_name'],
                    fallback: 'Fee payment',
                  ),
                  'amount': paid,
                  'status': 'Paid',
                },
              ]
            : rawItems,
        totalAmount: numValue(
          totals['total_amount'] ?? (invoice.isEmpty ? paid : invoice['total']),
        ),
        paidAmount: numValue(totals['paid_amount'] ?? paid),
        balance: numValue(totals['balance'] ?? invoice['balance']),
        paymentMode: textValue(
          source['payment_method'] ?? payment['mode'],
          fallback: 'Payment',
        ),
        paymentDate: _sortDate(source['payment_date'] ?? payment['date']),
        transactionReference: textValue(
          source['reference_number'] ?? payment['transaction_id'],
        ),
        thisPaymentAmount: paid,
        schoolName: textValue(school['name'], fallback: 'SchoolDesk'),
        schoolAddress: _schoolAddress(school),
        schoolLogo: assets[0],
        authorizedSignature: assets[1],
        authorizedSignatoryName: textValue(school['principal_name']),
      );
      if (!mounted) return;
      await pdfService.previewDocument(
        context,
        bytes,
        '${textValue(payment['receipt'], fallback: 'Payment')} — Receipt',
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Receipt PDF error: $e')));
    }
  }

  Future<Uint8List?> _networkImageBytes(String url) async {
    if (url.trim().isEmpty) return null;
    try {
      return (await NetworkAssetBundle(
        Uri.parse(url),
      ).load(url)).buffer.asUint8List();
    } on Object {
      return null;
    }
  }

  String _schoolAddress(Map<String, dynamic> school) => [
    school['address'],
    school['address_line1'],
    school['address_line2'],
    school['city'],
    school['state'],
    school['postal_code'],
  ].map(textValue).where((value) => value.isNotEmpty).toSet().join(', ');

  bool _isFinalizedPayment(Map<String, dynamic> payment) {
    return const {
      'completed',
      'approved',
      'paid',
      'success',
    }.contains(textValue(payment['status']).toLowerCase());
  }

  DateTime _sortDate(Object? v) => DateTime.tryParse('$v') ?? DateTime(2000);
}

class _LedgerSummary extends StatelessWidget {
  const _LedgerSummary({
    required this.outstanding,
    required this.collected,
    required this.students,
  });

  final double outstanding;
  final double collected;
  final int students;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        label: 'Outstanding',
        value: money(outstanding),
        icon: Icons.pending_actions_outlined,
        color: context.appTheme.error,
      ),
      (
        label: 'Collected',
        value: money(collected),
        icon: Icons.check_circle_outline,
        color: context.appTheme.success,
      ),
      (
        label: 'Students',
        value: '$students',
        icon: Icons.groups_outlined,
        color: context.appTheme.primary,
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 112),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appTheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(metrics[index].icon, color: metrics[index].color),
                  const SizedBox(height: 8),
                  Text(
                    metrics[index].label,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: context.appTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      metrics[index].value,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: context.appTheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (index < metrics.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _LedgerPaymentDraft {
  const _LedgerPaymentDraft({
    required this.amount,
    required this.date,
    required this.method,
    required this.reference,
    required this.notes,
  });

  final double amount;
  final DateTime date;
  final String method;
  final String reference;
  final String notes;
}

class _LedgerPaymentDialog extends StatefulWidget {
  const _LedgerPaymentDialog({
    required this.invoiceLabel,
    required this.balance,
  });

  final String invoiceLabel;
  final double balance;

  @override
  State<_LedgerPaymentDialog> createState() => _LedgerPaymentDialogState();
}

class _LedgerPaymentDialogState extends State<_LedgerPaymentDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.balance.toStringAsFixed(0),
  );
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  String _method = 'cash';

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.invoiceLabel,
              style: TextStyle(color: context.appTheme.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                helperText: 'Remaining balance: ${money(widget.balance)}',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _method,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'upi', child: Text('UPI')),
                DropdownMenuItem(
                  value: 'bank_transfer',
                  child: Text('Bank transfer'),
                ),
                DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) => setState(() => _method = value ?? 'cash'),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Payment date'),
              subtitle: Text(
                '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
              ),
              onTap: _pickDate,
            ),
            TextField(
              controller: _reference,
              decoration: const InputDecoration(
                labelText: 'Reference (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final amount = double.tryParse(_amount.text.trim()) ?? 0;
            if (amount <= 0 || amount > widget.balance) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Enter an amount from ₹1 to ${money(widget.balance)}.',
                  ),
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              _LedgerPaymentDraft(
                amount: amount,
                date: _date,
                method: _method,
                reference: _reference.text.trim(),
                notes: _notes.text.trim(),
              ),
            );
          },
          child: const Text('Save payment'),
        ),
      ],
    );
  }
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
