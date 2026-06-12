import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/features/finance/presentation/screens/parent_fees_screen/parent_payment_request_form_screen.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/features/finance/data/datasources/parent_fees_remote_datasource.dart';

class ParentPaymentSelectionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> fees;
  final Map<String, dynamic>? student;

  const ParentPaymentSelectionScreen({
    super.key,
    required this.fees,
    this.student,
  });

  @override
  State<ParentPaymentSelectionScreen> createState() =>
      _ParentPaymentSelectionScreenState();
}

class _ParentPaymentSelectionScreenState
    extends State<ParentPaymentSelectionScreen> {
  final Set<String> _selectedInvoiceIds = {};

  List<Map<String, dynamic>> get _pendingFees => widget.fees
      .where((fee) => ((fee['amount'] as num?)?.toDouble() ?? 0) > 0)
      .toList();

  double get _selectedTotalAmount {
    return _pendingFees
        .where((fee) => _selectedInvoiceIds.contains(fee['id']?.toString()))
        .fold<double>(
          0,
          (sum, fee) => sum + ((fee['amount'] as num?)?.toDouble() ?? 0),
        );
  }

  @override
  void initState() {
    super.initState();
    // Auto-select all pending fees initially
    for (final fee in _pendingFees) {
      if (fee['id'] != null) {
        _selectedInvoiceIds.add(fee['id'].toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Select Invoices',
      subtitle: 'Choose the invoices you wish to pay',
      drawer: ParentDrawer(
        selectedIndex: 6,
        onDestinationSelected: (i) {},
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Column(
        children: [
          Expanded(
            child: _pendingFees.isEmpty
                ? _buildEmptyState()
                : _buildSelectionList(),
          ),
          if (_pendingFees.isNotEmpty) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 64,
              color: context.appTheme.success,
            ),
            const SizedBox(height: 16),
            Text(
              'All Caught Up!',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.appTheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no pending invoices to pay at this time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                color: context.appTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingFees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final fee = _pendingFees[index];
        final id = fee['id']?.toString() ?? '';
        final isSelected = _selectedInvoiceIds.contains(id);
        final amount = (fee['amount'] as num?)?.toDouble() ?? 0;
        final dueDate = fee['dueDate'] ?? fee['due_date'] ?? '';

        return InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedInvoiceIds.remove(id);
              } else {
                _selectedInvoiceIds.add(id);
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.appTheme.primaryContainer
                  : context.appTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? context.appTheme.primary.withAlpha(80)
                    : context.appTheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? context.appTheme.primary
                          : context.appTheme.outline,
                      width: 2,
                    ),
                    color: isSelected ? context.appTheme.primary : null,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: context.appTheme.onPrimary,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${fee['component'] ?? fee['invoiceNumber'] ?? 'Invoice'}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.appTheme.onSurface,
                        ),
                      ),
                      if (dueDate.toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Due by $dueDate',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            color: context.appTheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '₹${amount.toStringAsFixed(0)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.appTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        border: Border(
          top: BorderSide(color: context.appTheme.outlineVariant),
        ),
        boxShadow: [
          BoxShadow(
            color: context.appTheme.onSurface.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Selected',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      color: context.appTheme.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${_selectedTotalAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.appTheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _selectedInvoiceIds.isEmpty
                  ? null
                  : () {
                      final selectedFees = _pendingFees
                          .where((fee) =>
                              _selectedInvoiceIds.contains(fee['id']?.toString()))
                          .map((fee) => Map<String, dynamic>.from(fee))
                          .toList();
                      _onProceedToPay(selectedFees);
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                backgroundColor: context.appTheme.primary,
                foregroundColor: context.appTheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Proceed to Pay',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onProceedToPay(List<Map<String, dynamic>> selectedFees) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final datasource = ParentFeesRemoteDataSourceImpl();
      final config = await datasource.getPaymentConfig();
      if (mounted) Navigator.pop(context); // Dismiss loading dialog

      final isRazorpayEnabled = config['razorpay_enabled'] as bool? ?? false;
      if (!isRazorpayEnabled) {
        _navigateToManualPayment(selectedFees);
        return;
      }

      _showPaymentMethodBottomSheet(selectedFees);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading dialog
      _navigateToManualPayment(selectedFees);
    }
  }

  void _showPaymentMethodBottomSheet(List<Map<String, dynamic>> selectedFees) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select Payment Method',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.appTheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.appTheme.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.payment_rounded, color: context.appTheme.primary),
                  ),
                  title: Text(
                    'Pay Online',
                    style: GoogleFonts.ibmPlexSans(
                      fontWeight: FontWeight.w600,
                      color: context.appTheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Card, UPI, Netbanking, Wallet',
                    style: GoogleFonts.ibmPlexSans(color: context.appTheme.muted),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(context); // Close bottom sheet
                    _navigateToOnlinePayment(selectedFees);
                  },
                ),
                const Divider(height: 24),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.appTheme.warning.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.upload_file_rounded, color: context.appTheme.warning),
                  ),
                  title: Text(
                    'Submit Payment Proof',
                    style: GoogleFonts.ibmPlexSans(
                      fontWeight: FontWeight.w600,
                      color: context.appTheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Upload receipt for offline payments',
                    style: GoogleFonts.ibmPlexSans(color: context.appTheme.muted),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(context); // Close bottom sheet
                    _navigateToManualPayment(selectedFees);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToOnlinePayment(List<Map<String, dynamic>> selectedFees) async {
    final selectedIds = selectedFees
        .map((fee) => fee['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    final total = _selectedTotalAmount;
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.parentPaymentProcessing,
      arguments: ParentPaymentProcessingArgs(
        selectedInvoiceIds: selectedIds,
        totalAmount: total,
        student: widget.student,
      ),
    );
    if (!mounted) return;
    if (result != null) Navigator.pop(context, result);
  }

  void _navigateToManualPayment(List<Map<String, dynamic>> selectedFees) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.parentPaymentRequestForm,
      arguments: ParentPaymentRequestFormArgs(
        fees: selectedFees,
        student: widget.student,
      ),
    );
    if (!mounted) return;
    if (result != null) Navigator.pop(context, result);
  }
}
