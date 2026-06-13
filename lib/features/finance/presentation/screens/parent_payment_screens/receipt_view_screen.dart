import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/finance/data/datasources/parent_fees_remote_datasource.dart';

class ReceiptViewScreen extends StatefulWidget {
  final String transactionId;
  final String receiptId;

  const ReceiptViewScreen({
    super.key,
    required this.transactionId,
    this.receiptId = '',
  });

  @override
  State<ReceiptViewScreen> createState() => _ReceiptViewScreenState();
}

class _ReceiptViewScreenState extends State<ReceiptViewScreen> {
  final ParentFeesRemoteDataSource _datasource =
      ParentFeesRemoteDataSourceImpl();
  late Future<Map<String, dynamic>> _receiptFuture;

  @override
  void initState() {
    super.initState();
    _receiptFuture = _loadReceipt();
  }

  Future<Map<String, dynamic>> _loadReceipt() async {
    final receiptId = widget.receiptId.trim();
    if (receiptId.isEmpty) {
      throw Exception('Receipt is not available for this transaction yet.');
    }
    return _datasource.getReceipt(receiptId);
  }

  void _refresh() {
    setState(() {
      _receiptFuture = _loadReceipt();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.surface,
      appBar: AppBar(
        title: Text(
          'Receipt Details',
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w600,
            color: context.appTheme.onSurface,
          ),
        ),
        backgroundColor: context.appTheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.appTheme.onSurface),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _receiptFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ReceiptMessage(
              title: 'Unable to load receipt',
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }
          return _ReceiptBody(
            transactionId: widget.transactionId,
            receipt: snapshot.data ?? const {},
          );
        },
      ),
    );
  }
}

class _ReceiptBody extends StatelessWidget {
  const _ReceiptBody({required this.transactionId, required this.receipt});

  final String transactionId;
  final Map<String, dynamic> receipt;

  @override
  Widget build(BuildContext context) {
    final receiptNo = _text(receipt['receipt_no'], fallback: transactionId);
    final amount = _amount(receipt['amount']);
    final mode = _text(receipt['payment_mode'], fallback: 'Razorpay');
    final paidAt = _formatDateTime(_text(receipt['paid_at']));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appTheme.outlineVariant),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.appTheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: context.appTheme.primary,
                    child: Icon(
                      Icons.school_rounded,
                      color: context.appTheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SchoolDesk',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.appTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Payment Receipt',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.appTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _ReceiptRow(label: 'Receipt No', value: receiptNo),
                  _ReceiptDivider(),
                  _ReceiptRow(label: 'Transaction ID', value: transactionId),
                  _ReceiptDivider(),
                  _ReceiptRow(label: 'Date', value: paidAt),
                  _ReceiptDivider(),
                  _ReceiptRow(label: 'Payment Mode', value: mode.toUpperCase()),
                  _ReceiptDivider(),
                  _ReceiptRow(
                    label: 'Status',
                    value: 'Successful',
                    isStatus: true,
                  ),
                  _ReceiptDivider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount Paid',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.appTheme.onSurface,
                        ),
                      ),
                      Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: context.appTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.appTheme.background,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Text(
                'This is a computer generated receipt and does not require a physical signature.',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: context.appTheme.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isStatus = false,
  });

  final String label;
  final String value;
  final bool isStatus;

  @override
  Widget build(BuildContext context) {
    final valueWidget = isStatus
        ? Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: context.appTheme.success.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                value,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.appTheme.success,
                ),
              ),
            ),
          )
        : Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.appTheme.onSurface,
            ),
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              color: context.appTheme.muted,
            ),
          ),
        ),
        Expanded(flex: 3, child: valueWidget),
      ],
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 28, color: context.appTheme.outlineVariant);
  }
}

class _ReceiptMessage extends StatelessWidget {
  const _ReceiptMessage({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: context.appTheme.muted,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.appTheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                color: context.appTheme.muted,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

double _amount(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatDateTime(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw.isEmpty ? '-' : raw;
  return '${parsed.day.toString().padLeft(2, '0')} '
      '${_monthName(parsed.month)} ${parsed.year}, '
      '${parsed.hour.toString().padLeft(2, '0')}:'
      '${parsed.minute.toString().padLeft(2, '0')}';
}

String _monthName(int month) {
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
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}
