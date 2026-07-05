/// Collect Fee — streamlined single-screen payment recording.
library;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_widgets.dart';

enum _PaymentMode { cash, cheque, bankTransfer, other }

extension on _PaymentMode {
  String get label => switch (this) {
    _PaymentMode.cash => 'Cash',
    _PaymentMode.cheque => 'Cheque',
    _PaymentMode.bankTransfer => 'Bank Transfer',
    _PaymentMode.other => 'Other',
  };
  IconData get icon => switch (this) {
    _PaymentMode.cash => Icons.payments_outlined,
    _PaymentMode.cheque => Icons.receipt_long_outlined,
    _PaymentMode.bankTransfer => Icons.account_balance_outlined,
    _PaymentMode.other => Icons.more_horiz_rounded,
  };
  Color get color => switch (this) {
    _PaymentMode.cash => const Color(0xFF16A34A),
    _PaymentMode.cheque => const Color(0xFF7C3AED),
    _PaymentMode.bankTransfer => const Color(0xFFEA580C),
    _PaymentMode.other => const Color(0xFFEF4444),
  };
}

class FeeCollectScreen extends StatefulWidget {
  const FeeCollectScreen({super.key});
  @override
  State<FeeCollectScreen> createState() => _FeeCollectScreenState();
}

class _FeeCollectScreenState extends State<FeeCollectScreen> {
  final _amountController = TextEditingController();
  final _transactionController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchCtrl = TextEditingController();
  final Set<String> _selectedMonths = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _query = '';
  String _selectedStudentId = '';
  _PaymentMode _paymentMode = _PaymentMode.cash;
  DateTime _paymentDate = DateTime.now();
  List<Map<String, dynamic>> _invoices = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transactionController.dispose();
    _notesController.dispose();
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
      setState(() {
        _invoices = raw.map(normalizeInvoice).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _dueInvoices =>
      _invoices.where((inv) => numValue(inv['balance']) > 0).toList();

  List<Map<String, dynamic>> get _filteredDue => _dueInvoices.where((inv) {
    if (_query.isEmpty) return true;
    return '${inv['name']} ${inv['class']}'.toLowerCase().contains(
      _query.toLowerCase(),
    );
  }).toList();

  Map<String, dynamic>? get _selectedInvoice {
    if (_selectedStudentId.isEmpty) return null;
    return _dueInvoices.firstWhereOrNull(
      (i) => i['student_id'] == _selectedStudentId,
    );
  }

  bool get _isTuition =>
      _selectedInvoice != null && isTuitionInvoice(_selectedInvoice);
  List<String> get _unpaidMonths =>
      _selectedInvoice != null ? unpaidInvoiceMonths(_selectedInvoice) : [];

  void _recalculateAmount() {
    final inv = _selectedInvoice;
    if (inv == null) return;
    if (!_isTuition) {
      _amountController.text = money(numValue(inv['balance']));
      return;
    }
    final monthly = numValue(inv['monthly_amount']);
    if (_selectedMonths.isEmpty || monthly <= 0) {
      _amountController.text = money(0);
      return;
    }
    final allUnpaid = _unpaidMonths;
    final amount = _selectedMonths.length == allUnpaid.length
        ? numValue(inv['balance'])
        : monthly * _selectedMonths.length;
    _amountController.text = money(amount);
  }

  void _selectMonthsFromAmount() {
    final inv = _selectedInvoice;
    if (!_isTuition || inv == null) return;
    final amount =
        double.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        0;
    final monthly = numValue(inv['monthly_amount']);
    final allUnpaid = _unpaidMonths;
    _selectedMonths.clear();
    if (allUnpaid.isEmpty || monthly <= 0 || amount <= 0) return;
    final count = (amount / monthly).round().clamp(1, allUnpaid.length);
    _selectedMonths.addAll(allUnpaid.take(count));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      appBar: AppBar(
        title: const Text(
          'Collect Fee',
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
          : _selectedInvoice == null
          ? _buildStudentPicker()
          : _buildPaymentForm(),
    );
  }

  Widget _buildStudentPicker() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const FeeSectionTitle('Select Student with Due'),
        const SizedBox(height: 10),
        FeeSearchBox(
          controller: _searchCtrl..text = _query,
          hint: 'Search student',
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 12),
        if (_filteredDue.isEmpty)
          const FeeEmptyState(
            icon: Icons.verified_outlined,
            title: 'No outstanding dues',
            message: 'All student invoices are clear.',
          ),
        for (final inv in _filteredDue)
          FeeCard(
            onTap: () {
              setState(() {
                _selectedStudentId = inv['student_id'];
                _selectedMonths.clear();
              });
              _recalculateAmount();
            },
            child: Row(
              children: [
                FeeIconBadge(
                  icon: Icons.person_outlined,
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv['name'] ?? 'Student',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${inv['class']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                FeeStatusPill(
                  label: money(numValue(inv['balance'])),
                  color: const Color(0xFFEA580C),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentForm() {
    final inv = _selectedInvoice!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        FeeCard(
          child: Row(
            children: [
              FeeIconBadge(
                icon: Icons.person_outlined,
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv['name'] ?? 'Student',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      inv['class'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _selectedStudentId = '';
                  _selectedMonths.clear();
                }),
                child: const Text('Change'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FeeCard(
          child: Column(
            children: [
              FeeAmountRow(
                label: 'Total Fees',
                value: money(numValue(inv['total'])),
              ),
              FeeAmountRow(label: 'Paid', value: money(numValue(inv['paid']))),
              FeeAmountRow(
                label: 'Due',
                value: money(numValue(inv['balance'])),
                danger: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_isTuition && _unpaidMonths.isNotEmpty) ...[
          const FeeSectionTitle('Select Tuition Months'),
          const SizedBox(height: 4),
          Text(
            'Pick continuous unpaid months.',
            style: TextStyle(fontSize: 12, color: context.appTheme.muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allowedInvoiceMonths(inv).map((month) {
              final isPaid = paidInvoiceMonths(inv).contains(month);
              final isSelected = _selectedMonths.contains(month);
              final nextIdx = _selectedMonths.length;
              final canAdd =
                  !isPaid &&
                  (isSelected || _unpaidMonths.indexOf(month) == nextIdx);
              final canRemove =
                  isSelected &&
                  _selectedMonths.length > 1 &&
                  _selectedMonths.last == month;
              return FilterChip(
                label: Text(isPaid ? '$month ✓' : month),
                selected: isPaid || isSelected,
                onSelected: (canAdd || canRemove)
                    ? (_) {
                        setState(() {
                          if (isSelected && canRemove) {
                            _selectedMonths.remove(month);
                          } else if (canAdd) {
                            _selectedMonths.add(month);
                          }
                        });
                        _recalculateAmount();
                      }
                    : null,
                selectedColor: isPaid
                    ? context.appTheme.success.withOpacity(0.16)
                    : context.appTheme.primaryContainer,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '₹ ',
          ),
          onChanged: (_) => _selectMonthsFromAmount(),
        ),
        const SizedBox(height: 12),
        const FeeSectionTitle('Payment Mode'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _PaymentMode.values.map((mode) {
            final selected = _paymentMode == mode;
            return GestureDetector(
              onTap: () => setState(() => _paymentMode = mode),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? mode.color.withOpacity(0.12)
                      : context.appTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? mode.color
                        : context.appTheme.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      mode.icon,
                      size: 18,
                      color: selected ? mode.color : context.appTheme.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mode.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? mode.color
                            : context.appTheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _transactionController,
          decoration: const InputDecoration(
            labelText: 'Reference Number (Optional)',
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _pickDate,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Payment Date'),
            child: Row(
              children: [
                Expanded(
                  child: Text(DateFormat('dd MMM yyyy').format(_paymentDate)),
                ),
                const Icon(Icons.calendar_month_outlined, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes (Optional)'),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving ? null : _confirmPayment,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_rounded),
          label: Text(_saving ? 'Recording...' : 'Confirm Payment'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => setState(() {
            _selectedStudentId = '';
            _selectedMonths.clear();
          }),
          child: const Text('Back to Students'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _paymentDate = picked);
  }

  Future<void> _confirmPayment() async {
    final inv = _selectedInvoice;
    if (inv == null) return;
    final amount =
        double.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        0;
    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.recordPayment(
        PaymentRequest(
          invoiceId: inv['id'],
          receiptNumber:
              'RCP-${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}',
          amountPaid: amount,
          paymentDate: DateFormat('yyyy-MM-dd').format(_paymentDate),
          paymentMode: _paymentMode.label.toLowerCase(),
          transactionId: _transactionController.text.trim().isEmpty
              ? null
              : _transactionController.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF16A34A),
            size: 48,
          ),
          title: const Text('Payment Recorded'),
          content: Text(
            '₹${amount.toStringAsFixed(0)} recorded for ${inv['name']}.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      setState(() {
        _selectedStudentId = '';
        _selectedMonths.clear();
      });
      _amountController.clear();
      _transactionController.clear();
      _notesController.clear();
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: context.appTheme.error,
        ),
      );
    }
  }
}
