import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';

class AdminPaymentRequestDecisionArgs {
  final Map<String, dynamic> request;

  const AdminPaymentRequestDecisionArgs({required this.request});
}

class AdminPaymentRequestDecisionScreen extends StatefulWidget {
  final AdminPaymentRequestDecisionArgs args;

  const AdminPaymentRequestDecisionScreen({super.key, required this.args});

  @override
  State<AdminPaymentRequestDecisionScreen> createState() =>
      _AdminPaymentRequestDecisionScreenState();
}

class _AdminPaymentRequestDecisionScreenState
    extends State<AdminPaymentRequestDecisionScreen> {
  final _remarksController = TextEditingController();
  String _decision = 'approved';
  bool _submitting = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.args.request;
    return SchoolDeskModuleScaffold(
      title: 'Review Payment',
      subtitle: 'Approve or reject a parent payment request',
      drawer: AdminDrawer(selectedIndex: 4, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Form(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDetails(request),
            const SizedBox(height: 16),
            _buildDecisionSelector(),
            const SizedBox(height: 14),
            TextFormField(
              controller: _remarksController,
              enabled: !_submitting,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: _decision == 'approved'
                    ? 'Admin remarks'
                    : 'Rejection reason',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _decision == 'approved'
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 18,
                    ),
              label: Text(
                _submitting ? 'Saving...' : '${_title(_decision)} Request',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(
                'Back to Requests',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(Map<String, dynamic> request) {
    final invoice = _map(request['invoice']);
    final student = _map(request['student']);
    final parent = _map(request['parent_user']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _studentName(student),
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _detailRow(
            'Parent',
            _text(parent['name'], fallback: parent['email']),
          ),
          _detailRow(
            'Invoice',
            _text(invoice['invoice_number'], fallback: request['invoice_id']),
          ),
          _detailRow('Amount', _money(_num(request['amount']))),
          _detailRow('Payment date', _date(request['payment_date'])),
          _detailRow('Mode', _text(request['payment_mode'], fallback: '-')),
          if (_text(request['transaction_id']).isNotEmpty)
            _detailRow('Transaction', _text(request['transaction_id'])),
          if (_text(request['remarks']).isNotEmpty)
            _detailRow('Parent note', _text(request['remarks'])),
        ],
      ),
    );
  }

  Widget _buildDecisionSelector() {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            selected: _decision == 'approved',
            label: const Text('Approve'),
            avatar: const Icon(Icons.check_rounded, size: 16),
            onSelected: _submitting
                ? null
                : (_) => setState(() => _decision = 'approved'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ChoiceChip(
            selected: _decision == 'rejected',
            label: const Text('Reject'),
            avatar: const Icon(Icons.close_rounded, size: 16),
            onSelected: _submitting
                ? null
                : (_) => setState(() => _decision = 'rejected'),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final requestID = _text(widget.args.request['id']);
    if (requestID.isEmpty) {
      _showError('Payment request ID is missing.');
      return;
    }
    final remarks = _remarksController.text.trim();
    if (_decision == 'rejected' && remarks.length < 3) {
      _showError('Enter a rejection reason.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await BackendApiClient.instance.decideParentPaymentRequest(
        requestID,
        status: _decision,
        adminRemarks: remarks,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment request ${_decision == 'approved' ? 'approved' : 'rejected'}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(error.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  double _num(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String _text(dynamic value, {dynamic fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return '${fallback ?? ''}'.trim();
    return text;
  }

  String _studentName(Map<String, dynamic> student) {
    final name = [
      _text(student['first_name']),
      _text(student['last_name']),
    ].where((part) => part.isNotEmpty).join(' ');
    return name.isEmpty ? 'Student' : name;
  }

  String _money(double value) => '₹${value.toStringAsFixed(0)}';

  String _date(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return '-';
    return parsed.toIso8601String().split('T').first;
  }

  String _title(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
