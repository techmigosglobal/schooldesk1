import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/features/finance/presentation/screens/parent_payment_screens/receipt_view_screen.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class ParentPaymentSuccessScreen extends StatelessWidget {
  final String transactionId;
  final String receiptId;
  final double amountPaid;
  final List<String> invoiceIds;
  final String date;

  const ParentPaymentSuccessScreen({
    super.key,
    required this.transactionId,
    this.receiptId = '',
    required this.amountPaid,
    required this.invoiceIds,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.appTheme.onSurface),
          onPressed: () => Navigator.of(
            context,
          ).popUntil((route) => route.isFirst), // Or custom logic
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.appTheme.success,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: context.appTheme.onPrimary,
                  size: 64,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Payment Successful!',
                textAlign: TextAlign.center,
                style: GoogleFonts.sourceSerif4(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: context.appTheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Thank you. Your payment has been received and processed successfully.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: context.appTheme.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.appTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.appTheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: context.appTheme.onSurface.withAlpha(5),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildDetailRow(context, 'Transaction ID', transactionId),
                    Divider(height: 32, color: context.appTheme.outlineVariant),
                    _buildDetailRow(context, 'Date', date.split(' ')[0]),
                    Divider(height: 32, color: context.appTheme.outlineVariant),
                    _buildDetailRow(
                      context,
                      'Amount Paid',
                      '₹${amountPaid.toStringAsFixed(2)}',
                      isHighlight: true,
                    ),
                    Divider(height: 32, color: context.appTheme.outlineVariant),
                    _buildDetailRow(
                      context,
                      'Invoices Paid',
                      invoiceIds.join(', '),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReceiptViewScreen(
                        transactionId: transactionId,
                        receiptId: receiptId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('View Full Receipt'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: context.appTheme.primary,
                  foregroundColor: context.appTheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  textStyle: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  // Navigate back to fees or home
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: context.appTheme.primary,
                  side: BorderSide(color: context.appTheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Return to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.ibmPlexSans(
              fontSize: isHighlight ? 18 : 14,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
              color: isHighlight ? Colors.blue : context.appTheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
