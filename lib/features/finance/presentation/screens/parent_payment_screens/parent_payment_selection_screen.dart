import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/features/finance/presentation/screens/parent_fees_screen/parent_payment_request_form_screen.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/routes/app_routes.dart';

class ParentPaymentSelectionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> fees;
  final Map<String, dynamic>? student;
  final Map<String, dynamic>? paymentRequest;

  const ParentPaymentSelectionScreen({
    super.key,
    required this.fees,
    this.student,
    this.paymentRequest,
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
      title: 'Select installment',
      subtitle: 'Choose the fee installment you want to pay now',
      drawer: ParentDrawer(
        selectedIndex: ParentNav.fees,
        onDestinationSelected: (_) {},
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
        final instNum = fee['installment_number'];
        final instTotal = fee['installment_count'];
        final hasInstallmentInfo = instNum != null && instTotal != null;

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
                      if (hasInstallmentInfo) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.appTheme.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: context.appTheme.primary.withAlpha(40),
                                ),
                              ),
                              child: Text(
                                'Installment $instNum of $instTotal',
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.appTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
        border: Border(top: BorderSide(color: context.appTheme.outlineVariant)),
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
                    'Selected installment total',
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
                          .where(
                            (fee) => _selectedInvoiceIds.contains(
                              fee['id']?.toString(),
                            ),
                          )
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
                'Pay installment',
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
    _navigateToManualPayment(selectedFees);
  }

  void _navigateToManualPayment(List<Map<String, dynamic>> selectedFees) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.parentPaymentRequestForm,
      arguments: ParentPaymentRequestFormArgs(
        fees: selectedFees,
        student: widget.student,
        paymentRequest: widget.paymentRequest,
      ),
    );
    if (!mounted) return;
    if (result != null) Navigator.pop(context, result);
  }
}
