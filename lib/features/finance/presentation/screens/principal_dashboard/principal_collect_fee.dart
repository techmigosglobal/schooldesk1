import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';

// Only Cash and Others are accepted payment modes.
enum _PaymentMode { cash, other }

extension on _PaymentMode {
  String get label => switch (this) {
    _PaymentMode.cash => 'Cash',
    _PaymentMode.other => 'Others',
  };
  IconData get icon => switch (this) {
    _PaymentMode.cash => Icons.payments_outlined,
    _PaymentMode.other => Icons.more_horiz_rounded,
  };
  Color get color => switch (this) {
    _PaymentMode.cash => const Color(0xFF16A34A),
    _PaymentMode.other => const Color(0xFF6366F1),
  };
}

// ── Fee-type visual metadata ─────────────────────────────────────────────────

class _FeeTypeBadge {
  final String label;
  final Color color;
  final Color bg;
  final IconData icon;
  const _FeeTypeBadge({
    required this.label,
    required this.color,
    required this.bg,
    required this.icon,
  });
}

_FeeTypeBadge _feeTypeBadge(Map<String, dynamic> inv) {
  final raw = textValue(inv['fee_type']).toLowerCase();
  if (raw.contains('tuition') || raw.contains('monthly')) {
    return const _FeeTypeBadge(
      label: 'Tuition Fee',
      color: Color(0xFF1A6B4A),
      bg: Color(0xFFDCFCE7),
      icon: Icons.school_rounded,
    );
  }
  if (raw.contains('book')) {
    return const _FeeTypeBadge(
      label: 'Books Fee',
      color: Color(0xFF1D4ED8),
      bg: Color(0xFFDBEAFE),
      icon: Icons.menu_book_rounded,
    );
  }
  if (raw.contains('kit') || raw.contains('uniform')) {
    return const _FeeTypeBadge(
      label: 'Kit Fee',
      color: Color(0xFF92400E),
      bg: Color(0xFFFEF3C7),
      icon: Icons.backpack_rounded,
    );
  }
  return const _FeeTypeBadge(
    label: 'Fee',
    color: Color(0xFF7C3AED),
    bg: Color(0xFFF5F3FF),
    icon: Icons.receipt_outlined,
  );
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
    } on Object catch (e) {
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
        0.0;
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
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        title: Text(
          'Record Payment',
          style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A6B4A),
        foregroundColor: Colors.white,
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
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Error: $_error'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _selectedInvoice == null
          ? _buildStudentPicker()
          : _buildPaymentForm(),
    );
  }

  // ── Student Picker ────────────────────────────────────────────────────────

  Widget _buildStudentPicker() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A6B4A), Color(0xFF2F9B6F)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Student',
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Find students with outstanding dues',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search by name or class...',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF1A6B4A),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1FAE5)),
            ),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 16),
        if (_filteredDue.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 48,
                    color: Color(0xFF1A6B4A),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No outstanding dues found.',
                    style: GoogleFonts.ibmPlexSans(
                      color: context.appTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        for (final inv in _filteredDue) _buildStudentCard(inv),
      ],
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> inv) {
    final badge = _feeTypeBadge(inv);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
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
                CircleAvatar(
                  backgroundColor: badge.bg,
                  child: Icon(badge.icon, color: badge.color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv['name'] ?? 'Student',
                        style: GoogleFonts.ibmPlexSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${inv['class']}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 12,
                          color: context.appTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Fee type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badge.bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge.label,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badge.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(numValue(inv['balance'])),
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Outstanding',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 10,
                        color: context.appTheme.muted,
                      ),
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
        ),
      ),
    );
  }

  // ── Payment Form ──────────────────────────────────────────────────────────

  Widget _buildPaymentForm() {
    final inv = _selectedInvoice!;
    final badge = _feeTypeBadge(inv);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Student summary header — gradient card
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [badge.color, badge.color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                child: const Icon(Icons.person_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv['name'] ?? 'Student',
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      inv['class'] ?? '',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badge.icon, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            badge.label,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
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
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Change'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Fee breakdown
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invoice Summary',
                style: GoogleFonts.ibmPlexSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _detailRow('Total Invoiced', money(numValue(inv['total']))),
              const Divider(height: 16),
              _detailRow(
                'Total Paid',
                money(numValue(inv['paid'])),
                isSuccess: true,
              ),
              const Divider(height: 16),
              _detailRow(
                'Balance Due',
                money(numValue(inv['balance'])),
                isDanger: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Month selector (tuition only)
        if (_isTuition && _unpaidMonths.isNotEmpty) ...[
          _sectionHeader(
            'Select Months to Pay',
            subtitle: 'Monthly tuition — select in order',
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFF1A6B4A),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Wrap(
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
                  label: Text(
                    isPaid ? '$month ✓' : month,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                      ? const Color(0xFF1A6B4A).withOpacity(0.15)
                      : const Color(0xFF1A6B4A).withOpacity(0.20),
                  checkmarkColor: const Color(0xFF1A6B4A),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Amount
        _sectionHeader(
          'Payment Amount',
          icon: Icons.currency_rupee_rounded,
          color: Colors.orange.shade700,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            labelText: 'Amount to Record',
            prefixText: '₹ ',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1FAE5)),
            ),
          ),
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          onChanged: (_) => _selectMonthsFromAmount(),
        ),

        const SizedBox(height: 20),

        // Payment method
        _sectionHeader(
          'Payment Method',
          icon: Icons.payments_rounded,
          color: const Color(0xFF6366F1),
        ),
        const SizedBox(height: 10),
        Row(
          children: _PaymentMode.values.map((mode) {
            final selected = _paymentMode == mode;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMode = mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? mode.color : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? mode.color : const Color(0xFFE5E7EB),
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: mode.color.withOpacity(0.25),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          mode.icon,
                          size: 22,
                          color: selected ? Colors.white : mode.color,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          mode.label,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : mode.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Reference number
        TextFormField(
          controller: _transactionController,
          decoration: InputDecoration(
            labelText: 'Reference / Receipt No (Optional)',
            prefixIcon: const Icon(Icons.tag_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1FAE5)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Date picker
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Payment Date',
              prefixIcon: const Icon(Icons.calendar_month_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD1FAE5)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(_paymentDate),
                  style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
                ),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Notes
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: 'Administrative Notes (Optional)',
            prefixIcon: const Icon(Icons.notes_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1FAE5)),
            ),
          ),
          maxLines: 2,
        ),

        const SizedBox(height: 32),

        // Submit
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _saving ? null : _confirmPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A6B4A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Record Payment',
                    style: GoogleFonts.ibmPlexSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => setState(() {
              _selectedStudentId = '';
              _selectedMonths.clear();
            }),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A6B4A),
              side: const BorderSide(color: Color(0xFF1A6B4A)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Back to Student List',
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionHeader(
    String title, {
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  color: context.appTheme.muted,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _detailRow(
    String label,
    String val, {
    bool isDanger = false,
    bool isSuccess = false,
  }) {
    final color = isDanger
        ? Colors.orange.shade700
        : isSuccess
        ? const Color(0xFF1A6B4A)
        : context.appTheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            color: context.appTheme.muted,
            fontSize: 13,
          ),
        ),
        Text(
          val,
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
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
    final amount =
        double.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive payment amount.'),
        ),
      );
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF1A6B4A)),
              SizedBox(width: 8),
              Text('Payment Recorded'),
            ],
          ),
          content: Text(
            'Successfully recorded ₹${amount.toStringAsFixed(0)} payment for ${inv['name']}.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A6B4A),
                foregroundColor: Colors.white,
              ),
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
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record: $e'),
          backgroundColor: context.appTheme.error,
        ),
      );
    }
  }
}
