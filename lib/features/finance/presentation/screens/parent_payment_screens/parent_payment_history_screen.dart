import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/features/finance/presentation/screens/parent_payment_screens/receipt_view_screen.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class ParentPaymentHistoryScreen extends StatelessWidget {
  const ParentPaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data for payment history
    final List<Map<String, dynamic>> payments = [
      {
        'id': 'TXN-987654321',
        'date': '11 Jun 2026',
        'amount': 31500.0,
        'status': 'success',
        'items': 'Term 1 Tuition, Transport, Library'
      },
      {
        'id': 'TXN-123456789',
        'date': '05 Mar 2026',
        'amount': 15000.0,
        'status': 'success',
        'items': 'Term 2 Tuition'
      },
      {
        'id': 'TXN-456789123',
        'date': '10 Jan 2026',
        'amount': 5000.0,
        'status': 'failed',
        'items': 'Transport Fee'
      },
    ];

    return SchoolDeskModuleScaffold(
      title: 'Payment History',
      subtitle: 'View your past transactions and receipts',
      drawer: ParentDrawer(
        selectedIndex: 6, // Keep it aligned with finance/fees section
        onDestinationSelected: (i) {},
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: payments.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final payment = payments[index];
          final isSuccess = payment['status'] == 'success';

          return Container(
            decoration: BoxDecoration(
              color: context.appTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appTheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: context.appTheme.onSurface.withAlpha(5),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: isSuccess
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReceiptViewScreen(
                            transactionId: payment['id'],
                          ),
                        ),
                      );
                    }
                  : null, // Don't show receipt for failed payments
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          payment['id'],
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.appTheme.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSuccess ? context.appTheme.success.withAlpha(20) : context.appTheme.error.withAlpha(20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isSuccess ? 'Successful' : 'Failed',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSuccess ? context.appTheme.success : context.appTheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      payment['items'],
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.appTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 12,
                                color: context.appTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              payment['date'],
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: context.appTheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '₹${payment['amount'].toStringAsFixed(2)}',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.appTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
