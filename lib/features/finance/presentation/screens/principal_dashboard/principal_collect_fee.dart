import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';

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

class PrincipalCollectFee extends StatefulWidget {
  const PrincipalCollectFee({super.key});

  @override
  State<PrincipalCollectFee> createState() => _PrincipalCollectFeeState();
}

class _PrincipalCollectFeeState extends State<PrincipalCollectFee> {
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
      final raw = await api.getInvoices(pageSize: 1000);
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
    return '${inv['name']} ${inv['class']}'.toLowerCase().contains(_query.toLowerCase());
  }).toList();

  Map<String, dynamic>? get _selectedInvoice {
    if (_selectedStudentId.isEmpty) return null;
    return _dueInvoices.firstWhereOrNull((i) => i['student_id'] == _selectedStudentId);
  }

  bool get _isTuition => _selectedInvoice != null && isTuitionInvoice(_selectedInvoice);
  List<String> get _unpaidMonths => _selectedInvoice != null ? unpaidInvoiceMonths(_selectedInvoice) : [];

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
    final amount = double.tryParse(_amountController.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
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
      backgroundColor: context.appTheme.surface,
      appBar: AppBar(
        title: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: context.appTheme.onSurface,
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Error: $_error'),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _selectedInvoice == null
                  ? _buildStudentPicker()
                  : _buildPaymentForm(),
    );
  }

  Widget _buildStudentPicker() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Select Student with Outstanding Dues',
          style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search student or class...',
            prefixIcon: const Icon(Icons.search_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 16),
        if (_filteredDue.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                'No outstanding invoices found.',
                style: TextStyle(color: context.appTheme.muted),
              ),
            ),
          ),
        for (final inv in _filteredDue)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.appTheme.outlineVariant),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _selectedStudentId = inv['student_id'];
                  _selectedMonths.clear();
                });
                _recalculateAmount();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF1A6B4A),
                      foregroundColor: Colors.white,
                      child: Icon(Icons.person_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inv['name'] ?? 'Student',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${inv['class']}',
                            style: TextStyle(fontSize: 12, color: context.appTheme.muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      money(numValue(inv['balance'])),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentForm() {
    final inv = _selectedInvoice!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: context.appTheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF1A6B4A),
                  foregroundColor: Colors.white,
                  child: Icon(Icons.person_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv['name'] ?? 'Student',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        inv['class'] ?? '',
                        style: TextStyle(fontSize: 12, color: context.appTheme.muted),
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
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: context.appTheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _detailRow('Total Invoiced', money(numValue(inv['total']))),
                const Divider(height: 16),
                _detailRow('Total Paid', money(numValue(inv['paid']))),
                const Divider(height: 16),
                _detailRow('Balance Due', money(numValue(inv['balance'])), isDanger: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_isTuition && _unpaidMonths.isNotEmpty) ...[
          Text('Select Tuition Months to Pay', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allowedInvoiceMonths(inv).map((month) {
              final isPaid = paidInvoiceMonths(inv).contains(month);
              final isSelected = _selectedMonths.contains(month);
              final nextIdx = _selectedMonths.length;
              final canAdd = !isPaid && (isSelected || _unpaidMonths.indexOf(month) == nextIdx);
              final canRemove = isSelected && _selectedMonths.length > 1 && _selectedMonths.last == month;
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
                    ? context.appTheme.success.withOpacity(0.15)
                    : const Color(0xFF1A6B4A).withOpacity(0.15),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          decoration: const InputDecoration(labelText: 'Recording Amount Paid', prefixText: '₹ ', border: OutlineInputBorder()),
          onChanged: (_) => _selectMonthsFromAmount(),
        ),
        const SizedBox(height: 20),
        Text('Select Payment Method', style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _PaymentMode.values.map((mode) {
            final selected = _paymentMode == mode;
            return GestureDetector(
              onTap: () => setState(() => _paymentMode = mode),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? mode.color.withOpacity(0.12) : context.appTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? mode.color : context.appTheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(mode.icon, size: 16, color: selected ? mode.color : context.appTheme.muted),
                    const SizedBox(width: 8),
                    Text(
                      mode.label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? mode.color : context.appTheme.onSurface),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _transactionController,
          decoration: const InputDecoration(labelText: 'Reference Number / Cheque No (Optional)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Payment Date', border: OutlineInputBorder()),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('dd MMM yyyy').format(_paymentDate)),
                const Icon(Icons.calendar_month_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(labelText: 'Administrative Notes (Optional)', border: OutlineInputBorder()),
          maxLines: 2,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _confirmPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A6B4A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() {
              _selectedStudentId = '';
              _selectedMonths.clear();
            }),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A6B4A),
              side: const BorderSide(color: Color(0xFF1A6B4A)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Back to Student List'),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _detailRow(String label, String val, {bool isDanger = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: context.appTheme.muted, fontSize: 13)),
        Text(
          val,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDanger ? Colors.orange : context.appTheme.onSurface,
          ),
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
    final amount = double.tryParse(_amountController.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid positive payment amount.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.recordPayment(
        PaymentRequest(
          invoiceId: inv['id'],
          receiptNumber: 'RCP-${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}',
          amountPaid: amount,
          paymentDate: DateFormat('yyyy-MM-dd').format(_paymentDate),
          paymentMode: _paymentMode.label.toLowerCase(),
          transactionId: _transactionController.text.trim().isEmpty ? null : _transactionController.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Success'),
          content: Text('Successfully recorded ₹${amount.toStringAsFixed(0)} offline payment for ${inv['name']}.'),
          actions: [
            TextButton(
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
        SnackBar(content: Text('Failed to record: $e'), backgroundColor: context.appTheme.error),
      );
    }
  }
}
