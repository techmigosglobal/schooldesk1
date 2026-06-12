import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class ReceiptViewScreen extends StatelessWidget {
  final String transactionId;

  const ReceiptViewScreen({
    super.key,
    required this.transactionId,
  });

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
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {
              // TODO: Implement PDF download
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading receipt...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              // TODO: Implement receipt sharing
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
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
                  // Receipt Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.appTheme.primaryContainer,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: context.appTheme.primary,
                            shape: BoxShape.circle,
                          ),
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
                                'Scholaris Elite',
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: context.appTheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Payment Receipt',
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 14,
                                  color: context.appTheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Receipt Body
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildReceiptRow(context, 'Transaction ID', transactionId),
                        const SizedBox(height: 16),
                        _buildReceiptRow(context, 'Date', '11 Jun 2026, 10:30 AM'),
                        const SizedBox(height: 16),
                        _buildReceiptRow(context, 'Status', 'Successful', isStatus: true),
                        Divider(height: 32, color: context.appTheme.outlineVariant),
                        
                        Text(
                          'Payment Details',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.appTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Mock invoice items
                        _buildInvoiceItem(context, 'Term 1 Tuition Fee', 25000),
                        const SizedBox(height: 12),
                        _buildInvoiceItem(context, 'Transport Fee (Q1)', 5000),
                        const SizedBox(height: 12),
                        _buildInvoiceItem(context, 'Library Deposit', 1500),
                        
                        Divider(height: 32, color: context.appTheme.outlineVariant),
                        
                        // Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount Paid',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: context.appTheme.onSurface,
                              ),
                            ),
                            Text(
                              '₹31,500.00',
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
                  
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.appTheme.background,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: Center(
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(BuildContext context, String label, String value, {bool isStatus = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: isStatus
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.appTheme.success.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    value,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.appTheme.success,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.onSurface,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildInvoiceItem(BuildContext context, String item, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            item,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              color: context.appTheme.onSurface,
            ),
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.appTheme.onSurface,
          ),
        ),
      ],
    );
  }
}
