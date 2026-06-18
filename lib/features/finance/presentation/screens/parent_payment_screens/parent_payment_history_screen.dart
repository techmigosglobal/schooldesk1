import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/features/finance/data/datasources/parent_fees_remote_datasource.dart';
import 'package:schooldesk1/features/finance/presentation/screens/parent_payment_screens/receipt_view_screen.dart';

class ParentPaymentHistoryScreen extends StatefulWidget {
  const ParentPaymentHistoryScreen({super.key});

  @override
  State<ParentPaymentHistoryScreen> createState() =>
      _ParentPaymentHistoryScreenState();
}

class _ParentPaymentHistoryScreenState
    extends State<ParentPaymentHistoryScreen> {
  final ParentFeesRemoteDataSource _datasource =
      ParentFeesRemoteDataSourceImpl();
  late Future<List<Map<String, dynamic>>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _paymentsFuture = _datasource.getPaymentHistory();
  }

  void _refresh() {
    setState(() {
      _paymentsFuture = _datasource.getPaymentHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Payment History',
      subtitle: 'View your past transactions and receipts',
      drawer: ParentDrawer(selectedIndex: 6, onDestinationSelected: (i) {}),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _paymentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load payments',
              message: snapshot.error.toString(),
              actionLabel: 'Retry',
              onAction: _refresh,
            );
          }
          final payments = snapshot.data ?? const [];
          if (payments.isEmpty) {
            return const _MessageState(
              icon: Icons.receipt_long_outlined,
              title: 'No payments yet',
              message: 'Your successful online fee payments will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final payment = payments[index];
                return _PaymentHistoryTile(payment: payment);
              },
            ),
          );
        },
      ),
    );
  }
}

class _PaymentHistoryTile extends StatelessWidget {
  const _PaymentHistoryTile({required this.payment});

  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    final receiptId = _text(payment['receipt_id']);
    final receiptNo = _text(payment['receipt_no'], fallback: receiptId);
    final status = _text(payment['status'], fallback: 'success');
    final amount = _amountFromPaise(payment['amount']);
    final paidAt = _formatDate(_text(payment['paid_at']));
    final mode = _text(payment['payment_mode'], fallback: 'UPI');
    final isSuccess = status.toLowerCase() == 'success';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: receiptId.isEmpty
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReceiptViewScreen(
                      transactionId: receiptNo,
                      receiptId: receiptId,
                    ),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      receiptNo,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.appTheme.primary,
                      ),
                    ),
                  ),
                  _StatusChip(isSuccess: isSuccess),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                mode.toUpperCase(),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: context.appTheme.muted,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      paidAt,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.appTheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
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
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isSuccess});

  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? context.appTheme.success : context.appTheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        isSuccess ? 'Successful' : 'Failed',
        style: GoogleFonts.ibmPlexSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel = '',
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: context.appTheme.muted),
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
            if (onAction != null && actionLabel.isNotEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
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

double _amountFromPaise(Object? value) {
  if (value is num) return value.toDouble() / 100;
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw.isEmpty ? '-' : raw;
  return '${parsed.day.toString().padLeft(2, '0')} '
      '${_monthName(parsed.month)} ${parsed.year}';
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
