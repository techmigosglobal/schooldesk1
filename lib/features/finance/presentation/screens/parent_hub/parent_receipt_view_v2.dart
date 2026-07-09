import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';

class ParentReceiptViewV2 extends StatefulWidget {
  final ParentPaymentSelectionArgs args;

  const ParentReceiptViewV2({super.key, required this.args});

  @override
  State<ParentReceiptViewV2> createState() => _ParentReceiptViewV2State();
}

class _ParentReceiptViewV2State extends State<ParentReceiptViewV2> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic> _receiptData = const {};

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    final pr = widget.args.paymentRequest;
    if (pr != null) {
      final invoice = pr['invoice'] is Map ? Map<String, dynamic>.from(pr['invoice'] as Map) : const <String, dynamic>{};
      final student = pr['student'] is Map ? Map<String, dynamic>.from(pr['student'] as Map) : const <String, dynamic>{};

      setState(() {
        _receiptData = {
          'receipt_no': pr['receipt_id'] ?? pr['id'] ?? '',
          'school_name': invoice['school_name'] ?? 'School',
          'amount': (pr['amount'] as num?)?.toDouble() ?? 0.0,
          'payment_mode': pr['payment_mode'] ?? 'UPI',
          'paid_at': pr['reviewed_at'] ?? pr['updated_at'] ?? pr['created_at'] ?? '',
          'student_name': '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim(),
          'invoice_number': invoice['invoice_number'] ?? '',
          'transaction_ref': pr['transaction_ref'] ?? pr['transaction_id'] ?? '',
        };
        _loading = false;
      });
      return;
    }

    // fallback load
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await BackendApiClient.instance.getParentPaymentRequests(
        studentId: widget.args.student?['id'],
      );
      if (list.isNotEmpty) {
        final prMatch = list.first;
        final invoice = prMatch['invoice'] is Map ? Map<String, dynamic>.from(prMatch['invoice'] as Map) : const <String, dynamic>{};
        final student = prMatch['student'] is Map ? Map<String, dynamic>.from(prMatch['student'] as Map) : const <String, dynamic>{};

        setState(() {
          _receiptData = {
            'receipt_no': prMatch['receipt_id'] ?? prMatch['id'] ?? '',
            'school_name': invoice['school_name'] ?? 'School',
            'amount': (prMatch['amount'] as num?)?.toDouble() ?? 0.0,
            'payment_mode': prMatch['payment_mode'] ?? 'UPI',
            'paid_at': prMatch['reviewed_at'] ?? prMatch['updated_at'] ?? prMatch['created_at'] ?? '',
            'student_name': '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim(),
            'invoice_number': invoice['invoice_number'] ?? '',
            'transaction_ref': prMatch['transaction_ref'] ?? prMatch['transaction_id'] ?? '',
          };
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Receipt not found.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.surface,
      appBar: AppBar(
        title: Text(
          'Receipt',
          style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: context.appTheme.onSurface,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _buildReceiptContent(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: context.appTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Receipt',
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Verify your internet connection and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(color: context.appTheme.muted),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadReceipt,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptContent() {
    final receiptNo = _text(_receiptData['receipt_no']);
    final schoolName = _text(_receiptData['school_name'], fallback: 'School');
    final amount = (_receiptData['amount'] as num?)?.toDouble() ?? 0.0;
    final mode = _text(_receiptData['payment_mode'], fallback: 'UPI');
    final paidAt = _formatDateTime(_text(_receiptData['paid_at']));
    final studentName = _text(_receiptData['student_name']);
    final invoiceNo = _text(_receiptData['invoice_number']);
    final transactionRef = _text(_receiptData['transaction_ref']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: context.appTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appTheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: context.appTheme.onSurface.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A6B4A).withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF1A6B4A),
                        foregroundColor: Colors.white,
                        child: Icon(Icons.school_rounded),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schoolName,
                              style: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Payment Receipt',
                              style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1A6B4A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _receiptRow('Receipt No', receiptNo),
                      const Divider(height: 24),
                      if (transactionRef.isNotEmpty) ...[
                        _receiptRow('Transaction ID', transactionRef),
                        const Divider(height: 24),
                      ],
                      if (studentName.isNotEmpty) ...[
                        _receiptRow('Student Name', studentName),
                        const Divider(height: 24),
                      ],
                      if (invoiceNo.isNotEmpty) ...[
                        _receiptRow('Invoice No', invoiceNo),
                        const Divider(height: 24),
                      ],
                      _receiptRow('Date & Time', paidAt),
                      const Divider(height: 24),
                      _receiptRow('Payment Mode', mode.toUpperCase()),
                      const Divider(height: 24),
                      _receiptRow('Status', 'Successful', isStatus: true),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount Paid',
                            style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1A6B4A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.appTheme.surfaceVariant.withOpacity(0.2),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Text(
                    'This is a computer generated receipt and does not require a physical signature.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSans(fontSize: 11, color: context.appTheme.muted, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Simulating Share
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Receipt shared successfully')),
                    );
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A6B4A),
                    side: const BorderSide(color: Color(0xFF1A6B4A)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.done_rounded),
                  label: const Text('Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A6B4A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isStatus = false}) {
    final valWidget = isStatus
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.appTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.bold, color: context.appTheme.success),
            ),
          )
        : Text(
            value,
            style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold, fontSize: 13),
          );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(color: context.appTheme.muted, fontSize: 13),
        ),
        valWidget,
      ],
    );
  }

  String _text(dynamic value, {dynamic fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return '${fallback ?? ''}'.trim();
    return text;
  }

  String _formatDateTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.isEmpty ? '-' : raw;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year} · ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }
}
