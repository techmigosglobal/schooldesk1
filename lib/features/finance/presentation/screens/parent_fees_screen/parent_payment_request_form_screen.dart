import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';

@immutable
class ParentPaymentRequestFormArgs {
  final List<Map<String, dynamic>> fees;
  final Map<String, dynamic>? student;

  const ParentPaymentRequestFormArgs({required this.fees, this.student});
}

@immutable
class ParentPaymentRequestFormResult {
  final int submittedCount;
  final List<String> references;

  const ParentPaymentRequestFormResult({
    required this.submittedCount,
    required this.references,
  });
}

class ParentPaymentRequestFormScreen extends StatefulWidget {
  final ParentPaymentRequestFormArgs args;

  const ParentPaymentRequestFormScreen({super.key, required this.args});

  @override
  State<ParentPaymentRequestFormScreen> createState() =>
      _ParentPaymentRequestFormScreenState();
}

class _ParentPaymentRequestFormScreenState
    extends State<ParentPaymentRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _referenceController;
  late final TextEditingController _paymentDateController;
  final _remarksController = TextEditingController();
  String _paymentMode = 'cash';
  bool _submitting = false;
  int _selectedNavIndex = 6;

  static const _paymentModes = [('cash', 'Cash', Icons.money_rounded)];

  List<Map<String, dynamic>> get _fees => widget.args.fees
      .where((fee) {
        final invoiceId = '${fee['id'] ?? ''}'.trim();
        final amount = (fee['amount'] as num?)?.toDouble() ?? 0;
        return invoiceId.isNotEmpty && amount > 0;
      })
      .map((fee) => Map<String, dynamic>.from(fee))
      .toList();

  double get _totalAmount => _fees.fold<double>(
    0,
    (sum, fee) => sum + ((fee['amount'] as num?)?.toDouble() ?? 0),
  );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _referenceController = TextEditingController(
      text:
          'PARENT-${now.year}${_two(now.month)}${_two(now.day)}-${now.millisecondsSinceEpoch.toString().substring(8)}',
    );
    _paymentDateController = TextEditingController(text: _dateInput(now));
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _paymentDateController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawer = ParentDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );
    return SchoolDeskModuleScaffold(
      title: 'Submit Payment Request',
      subtitle: 'Send payment details to the school office for verification',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStudentSummary(),
            const SizedBox(height: 14),
            _buildFeeBreakdown(),
            const SizedBox(height: 14),
            _buildReferenceFields(),
            const SizedBox(height: 14),
            _buildPaymentModePicker(),
            const SizedBox(height: 14),
            TextFormField(
              controller: _remarksController,
              enabled: !_submitting,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notes for school office',
                hintText: 'Optional transaction note or payer details',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submitting || _fees.isEmpty ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _submitting
                    ? 'Submitting...'
                    : 'Submit Cash ₹${_totalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(
                'Back to Fees',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentSummary() {
    final student = widget.args.student ?? const <String, dynamic>{};
    final name = _studentName(student);
    final classLabel =
        '${student['class'] ?? student['class_name'] ?? student['current_section_id'] ?? ''}'
            .trim();
    return _panel(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.account_circle_rounded,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Linked student' : name,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                if (classLabel.isNotEmpty)
                  Text(
                    classLabel,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeBreakdown() {
    if (_fees.isEmpty) {
      return _panel(
        child: Text(
          'No pending invoice is available for payment request.',
          style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.error),
        ),
      );
    }
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice Breakdown',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ..._fees.map(
            (fee) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${fee['component'] ?? fee['invoiceNumber'] ?? 'Invoice'}',
                      style: GoogleFonts.dmSans(fontSize: 12),
                    ),
                  ),
                  Text(
                    'INR ${((fee['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 16),
          Row(
            children: [
              Text(
                'Total request amount',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                'INR ${_totalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceFields() {
    return _panel(
      child: Column(
        children: [
          TextFormField(
            controller: _referenceController,
            enabled: !_submitting,
            decoration: const InputDecoration(
              labelText: 'Payment reference',
              hintText: 'Transaction ID or receipt reference',
            ),
            validator: (value) {
              if ((value ?? '').trim().length < 3) {
                return 'Enter a payment reference';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _paymentDateController,
            enabled: !_submitting,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Payment date',
              hintText: 'YYYY-MM-DD',
            ),
            validator: (value) {
              final raw = (value ?? '').trim();
              if (raw.isEmpty) return 'Required';
              if (!_isIsoDate(raw)) return 'Use YYYY-MM-DD';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentModePicker() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Method',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ..._paymentModes.map((mode) {
            final selected = _paymentMode == mode.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: _submitting
                    ? null
                    : () => setState(() => _paymentMode = mode.$1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withAlpha(16)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? AppTheme.primary
                          : AppTheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        mode.$3,
                        size: 18,
                        color: selected ? AppTheme.primary : AppTheme.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          mode.$2,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: child,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final references = <String>[];
    try {
      for (final fee in _fees) {
        final request = await BackendApiClient.instance
            .submitParentPaymentRequest(
              PaymentRequest(
                invoiceId: '${fee['id']}',
                receiptNumber: _referenceController.text.trim(),
                amountPaid: (fee['amount'] as num?)?.toDouble() ?? 0,
                paymentDate: _paymentDateController.text.trim(),
                paymentMode: 'cash',
              ),
              remarks: _remarksController.text.trim(),
            );
        final reference = '${request['request_reference'] ?? ''}'.trim();
        if (reference.isNotEmpty) references.add(reference);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment request submitted for school verification'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(
        context,
        ParentPaymentRequestFormResult(
          submittedCount: _fees.length,
          references: references,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _studentName(Map<String, dynamic> student) {
    final name = '${student['name'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
    return '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
        .trim();
  }

  bool _isIsoDate(String raw) {
    final match = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw);
    return match && DateTime.tryParse(raw) != null;
  }

  String _dateInput(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';

  String _two(int value) => value.toString().padLeft(2, '0');
}
